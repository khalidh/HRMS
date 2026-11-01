# HRMS Authorization

## Source of truth

The role catalog is `HRMS.HRMS_ROLES`; actions are the module/action pairs in `HRMS.HRMS_ACTIONS`. Effective permissions are time-bounded grants in `HRMS.HRMS_ROLE_ACTIONS` and time-bounded user assignments in `HRMS.HRMS_USER_ROLES`.

The schema seeds role and action definitions only. It creates no role-action grants or employee-role assignments. Access is denied until an administrator explicitly configures both. Authentication identifies the user; it does not grant business access.

## Role capabilities

This is the minimum capability baseline from [the role-access contract](../../specs/001-oracle-apex-migration/contracts/role-access.md), not a set of automatic grants. Each listed action must be granted explicitly and scoped by the secured views and business packages.

| Role | Minimum capabilities when explicitly granted | Data scope |
|---|---|---|
| `EMPLOYEE` | `EMPLOYEE.VIEW/UPDATE`, `LEAVE.VIEW/CREATE/CANCEL`, `PERFORMANCE.VIEW/UPDATE` | Own employee record and own requests, reviews, and goals only. Grant profile, dependent, or contact sub-actions only when the corresponding self-service page is approved. |
| `MANAGER` | `EMPLOYEE.VIEW`, `ORGANIZATION.VIEW`, `LEAVE.VIEW/APPROVE/REJECT`, `PERFORMANCE.VIEW/UPDATE/APPROVE` | Current team hierarchy and valid delegated scope. Employee profile, dependent, contact, and history actions are not implied. |
| `HR` | `EMPLOYEE.VIEW/CREATE/UPDATE/TERMINATE`, `EMPLOYEE.PROFILE_VIEW/DEPENDENTS_VIEW/CONTACTS_VIEW/HISTORY_VIEW`, `ORGANIZATION.VIEW/UPDATE`, `AUDIT.VIEW`, `LEAVE.VIEW/CREATE/APPROVE/REJECT/CANCEL`, `PERFORMANCE.VIEW/CREATE/UPDATE/APPROVE`, `REPORT.VIEW` | Authorized HR organization and employee scope. Each sub-action still requires an explicit grant. |
| `PAYROLL` | `PAYROLL.VIEW/CALCULATE/APPROVE/PAY/REVERSE`, `REPORT.VIEW` | Payroll data needed for assigned duties. |
| `ADMIN` | `ADMIN.VIEW/UPDATE/MANAGE/EXECUTE` | Technical configuration and operations; no implicit access to employee, payroll, or secret data. |
| `AUDITOR` | `AUDIT.VIEW`, `REPORT.VIEW`; add `AUDIT.EXPORT` or `REPORT.EXPORT` only when separately approved | Read-only and limited to explicitly authorized records and exports. |

Exports are separate actions (`EMPLOYEE.EXPORT`, `LEAVE.EXPORT`, `PAYROLL.EXPORT`, `PERFORMANCE.EXPORT`, `AUDIT.EXPORT`, `REPORT.EXPORT`); viewing a page does not grant export access. Sensitive columns such as national identifiers, bank details, tax data, and attachments require a distinct permission before any page or export exposes them. The current action catalog does not yet define those column-level actions; add and review them before implementing those displays.

For US1, employee profile, dependent, contact, and history regions require their respective `EMPLOYEE.*_VIEW` action in addition to the base employee scope. The audit region requires `AUDIT.VIEW`. Organization maintenance requires `ORGANIZATION.UPDATE`; the page delegates changes to `PKG_ORGANIZATION`, which checks the grant again. No role-action grants are seeded by the schema.

## APEX enforcement

- Define authorization checks against effective grants in `HRMS.VW_APP_USER_PERMISSIONS`; do not infer permissions from an APEX username, role label, hidden navigation entry, or client-side state.
- Apply authorization to pages, regions, processes, buttons, downloads, AJAX callbacks, and exports. UI conditions improve usability but are never the security boundary.
- Use `HRMS.VW_APP_EMPLOYEES` for employee lists. It enforces `EMPLOYEE.VIEW`, limits rows to the caller's valid scope, and omits sensitive columns. Do not query `HRMS.EMPLOYEES` directly from a page for user-facing lists.
- Keep transaction and row-level checks in the secured views and `PKG_SECURITY` / business packages. Manager scope comes from the current hierarchy and valid delegations, not a client-supplied employee ID.
- Initialize the authenticated context through `HRMS.PKG_APP_CONTEXT`; protected operations fail closed when that context or the required grant is missing.
- Audit sensitive reads, denied access, permission changes, and authorized exports. Never put tokens or secrets in audit attributes.

## Administration and review

Grant role actions and employee role assignments through an approved, audited administration process. Use validity dates and deactivate obsolete grants; do not edit the seeded catalogs to imply access. Review effective grants after role changes and test `ALLOW` and `DENY` cases for each role and scope.

The role descriptions and data-scope rules in the contract are authoritative. Changes to this capability baseline require review against that contract and the action catalog.
