#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
sqlcl_bin="${SQLCL_BIN:-sql}"
staging_rollback="$repo_root/ts-plsql-oracle-forms-hrms/data/migration/03_rollback.sql"

usage() {
    cat <<'USAGE'
Usage:
  scripts/rollback-hrms.sh --staging-batch <positive-integer-id>
  scripts/rollback-hrms.sh --restore-apex apex/application/<known-good-export>.sql

Required environment:
  SQLCL_BIN                       SQLcl executable (default: sql)
  HRMS_DB_CONNECT                 HRMS connection (staging rollback only)
  HRMS_ROLLBACK_CONFIRMATION      CONFIRM_STAGING_ROLLBACK
  APEX_DB_CONNECT                 APEX workspace developer connection (APEX restore only)

Staging rollback only cancels one RUNNING batch and removes its staging rows.
APEX restore imports a prior, versioned application export; it does not restore
schema objects or business data.
USAGE
}

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 2
}

require_sqlcl() {
    command -v "$sqlcl_bin" >/dev/null 2>&1 || fail "SQLcl not found; set SQLCL_BIN to its executable."
}

resolve_versioned_export() {
    local requested_path="$1"
    local resolved_path
    resolved_path="$(realpath -e -- "$requested_path")" || fail "APEX export file does not exist."
    [[ "$resolved_path" == "$repo_root/apex/application/"* ]] \
        || fail "APEX export must be versioned under apex/application/."
    [[ "$resolved_path" == *.sql ]] || fail "APEX export must be a .sql file."
    printf '%s\n' "$resolved_path"
}

case "${1:-}" in
    --help|-h)
        usage
        exit 0
        ;;
    --staging-batch)
        [[ $# -eq 2 ]] || fail "--staging-batch requires one batch execution ID."
        [[ "$2" =~ ^[1-9][0-9]*$ ]] || fail "Batch execution ID must be a positive integer."
        [[ "${HRMS_ROLLBACK_CONFIRMATION:-}" == 'CONFIRM_STAGING_ROLLBACK' ]] \
            || fail "Set HRMS_ROLLBACK_CONFIRMATION=CONFIRM_STAGING_ROLLBACK to confirm."
        [[ -n "${HRMS_DB_CONNECT:-}" ]] || fail "HRMS_DB_CONNECT must be set."
        command -v "$sqlcl_bin" >/dev/null 2>&1 \
            || fail "SQLcl not found; set SQLCL_BIN to its executable."
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" \
            "@$staging_rollback" "$2" CONFIRM_STAGING_ROLLBACK
        ;;
    --restore-apex)
        [[ $# -eq 2 ]] || fail "--restore-apex requires one known-good versioned SQL export path."
        [[ -n "${APEX_DB_CONNECT:-}" ]] || fail "APEX_DB_CONNECT must be set."
        command -v "$sqlcl_bin" >/dev/null 2>&1 \
            || fail "SQLcl not found; set SQLCL_BIN to its executable."
        export_path="$(resolve_versioned_export "$2")"
        "$sqlcl_bin" -S -L "$APEX_DB_CONNECT" "@$export_path"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
