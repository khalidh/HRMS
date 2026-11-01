#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
sqlcl_bin="${SQLCL_BIN:-sql}"
install_script="$repo_root/ts-plsql-oracle-forms-hrms/data/migration/00_install_test.sql"
schema_test="$repo_root/tests/sql/foundation_schema.sql"
app_errors_test="$repo_root/tests/plsql/test_pkg_app_errors.sql"
validation_test="$repo_root/tests/plsql/test_pkg_validation_us1.sql"

usage() {
    cat <<'USAGE'
Usage:
  scripts/deploy-hrms.sh --install-test-schema
  scripts/deploy-hrms.sh --check-schema
  scripts/deploy-hrms.sh --import-apex apex/application/<versioned-export>.sql
  scripts/deploy-hrms.sh --plan

Required environment:
  SQLCL_BIN                    SQLcl executable (default: sql)
  HRMS_DB_CONNECT              HRMS test-schema connection
  HRMS_INSTALL_CONFIRMATION    INSTALL_EMPTY_HRMS_TEST_SCHEMA
  APEX_DB_CONNECT              APEX workspace developer connection (APEX import only)

The test installer refuses any non-empty HRMS schema. It is not an upgrade or
production installer. Schema changes must be delivered through reviewed,
versioned migrations before a production deployment workflow is enabled.
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
    --plan)
        printf '%s\n' \
            '1. Use --install-test-schema only against a dedicated, empty HRMS test schema.' \
            '2. Run --check-schema after installation to verify objects and least privilege.' \
            '3. Import a versioned APEX export with --import-apex from a workspace developer connection.' \
            '4. Do not treat this initial-schema installer as a production upgrade mechanism.'
        exit 0
        ;;
    --install-test-schema)
        require_sqlcl
        [[ -n "${HRMS_DB_CONNECT:-}" ]] || fail "HRMS_DB_CONNECT must be set."
        [[ "${HRMS_INSTALL_CONFIRMATION:-}" == 'INSTALL_EMPTY_HRMS_TEST_SCHEMA' ]] \
            || fail "Set HRMS_INSTALL_CONFIRMATION=INSTALL_EMPTY_HRMS_TEST_SCHEMA to confirm an isolated test schema."
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" \
            "@$install_script" INSTALL_EMPTY_HRMS_TEST_SCHEMA
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" "@$schema_test"
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" "@$app_errors_test"
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" "@$validation_test"
        ;;
    --check-schema)
        require_sqlcl
        [[ -n "${HRMS_DB_CONNECT:-}" ]] || fail "HRMS_DB_CONNECT must be set."
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" "@$schema_test"
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" "@$app_errors_test"
        "$sqlcl_bin" -S -L "$HRMS_DB_CONNECT" "@$validation_test"
        ;;
    --import-apex)
        [[ $# -eq 2 ]] || fail "--import-apex requires one versioned SQL export path."
        require_sqlcl
        [[ -n "${APEX_DB_CONNECT:-}" ]] || fail "APEX_DB_CONNECT must be set."
        export_path="$(resolve_versioned_export "$2")"
        "$sqlcl_bin" -S -L "$APEX_DB_CONNECT" "@$export_path"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
