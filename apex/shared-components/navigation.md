# HRMS Navigation and Shared LOVs

## Navigation model

Use a responsive APEX navigation menu based on the Forms `HRMS_MENU` inventory. Show a module entry only when its page exists and the authenticated user has the corresponding view authorization. Direct URLs and page processes must enforce the same authorization on the server.

| Navigation entry | Source workflow | Required authorization |
|---|---|---|
| Employees and organization | `HRMS_EMPLOYEE` | `EMPLOYEE.VIEW`; organization pages also require `ORGANIZATION.VIEW`. |
| Leave management | `HRMS_LEAVE` | `LEAVE.VIEW`; create, approve, reject, and cancel actions are checked separately. |
| Payroll processing | `HRMS_PAYROLL` | `PAYROLL.VIEW`; calculation, approval, payment, reversal, and export are checked separately. |
| Performance reviews | `HRMS_PERFORMANCE` | `PERFORMANCE.VIEW`; create, update, approval, and export are checked separately. |
| Reports and analytics | Referenced by `HRMS_MENU`; no Forms report module is present in the current inventory | `REPORT.VIEW`; exports also require `REPORT.EXPORT`. Keep hidden until report pages exist. |
| System administration | Referenced by `HRMS_MENU`; no Forms administration module is present in the current inventory | `ADMIN.VIEW`; each administrative operation requires its own action. Keep hidden until pages exist. |
| Audit | Shared operational capability; no APEX audit page is present in the current inventory | `AUDIT.VIEW`; audit exports also require `AUDIT.EXPORT`. Keep hidden until pages exist. |

The common menu contains only available authorized destinations and the APEX-provided sign-out action. Do not reproduce Forms record commands such as Insert, Delete, or Enter Query as global actions; expose page-specific operations only when their business authorization is satisfied. Keep reports and administration unavailable rather than linking to placeholder pages.

Module subnavigation follows the source workflows:

- Leave: My Requests, Submit Request, Pending Approvals, Team Calendar.
- Payroll: Pay Periods, Payroll Runs, Pay Details.
- Performance: Review Cycles, My Reviews, Goals.

Use a consistent page title and breadcrumb hierarchy. Keep a direct link available for each authorized page so navigation visibility is not required for access-control enforcement.

## Shared List of Values

Use stable static IDs with the `LOV_` prefix. Return the key value and display a readable label; do not use a display value as a database key. The source definitions below are derived from the current schema and Forms exports. Apply a bind-based search and authorization appropriate to the page's operation.

| Static ID | Purpose | Source and filter | Security notes |
|---|---|---|---|
| `LOV_DEPARTMENTS` | Department selection | `HRMS.DEPARTMENTS`; active rows ordered by department name | Require `ORGANIZATION.VIEW` and filter through an authorized organization scope. The current schema has no dedicated department-scope view; do not expose a global list until the secure query is defined. |
| `LOV_JOB_TITLES` | Job title selection | `HRMS.JOB_TITLES` joined to `HRMS.JOB_GRADES`; active job titles and grades | Expose only in authorized employee/job workflows; return `JOB_ID`. |
| `LOV_LOCATIONS` | Location selection | `HRMS.LOCATIONS`; active rows ordered by location name | Expose only in authorized workflows; return `LOCATION_CODE`. |
| `LOV_MANAGERS` | Manager selection | `HRMS.VW_APP_EMPLOYEES`; active employees in the caller's permitted scope | Require `EMPLOYEE.VIEW`; use the secure view, not the unrestricted employee table. |
| `LOV_EMPLOYEES` | Employee selection in authorized workflows | `HRMS.VW_APP_EMPLOYEES` | Require `EMPLOYEE.VIEW`; do not include sensitive columns. |
| `LOV_LEAVE_TYPES` | Leave type selection | `HRMS.LEAVE_TYPES`; active rows ordered by leave type name | Return `LEAVE_TYPE_ID`; retain the package's business validation on submission. |
| `LOV_PAY_PERIODS` | Payroll period selection | `HRMS.PAY_PERIODS`; use eligible states for the operation (for run creation, `OPEN`) | Require `PAYROLL.VIEW`; state transitions remain package-controlled. |
| `LOV_RUN_TYPES` | Payroll run type | Static codes from the `PAYROLL_RUNS` check constraint: `REGULAR`, `SUPPLEMENTAL`, `BONUS`, `FINAL` | Keep synchronized with the database constraint; do not expose as a general status editor. |
| `LOV_HALF_DAY_PERIOD` | Half-day selection | Static codes from the leave request constraint: `AM`, `PM` | Use only when the half-day flag is enabled. |

Forms also lists gender, marital status, country, employment status, and leave status values. Do not create shared lists for these until their canonical reference source and permitted values are confirmed; several are not backed by a reference table in the current schema. Do not use a LOV to bypass a package-controlled status transition.

## Shared component conventions

- Keep static IDs stable across pages and document changes here.
- Use the native APEX item type appropriate to the interaction; provide accessible labels, keyboard selection, and a clear no-results state.
- Escape display values and never concatenate user input into SQL. Use binds for search terms.
- For existing historical records, display inactive reference values when needed, but do not offer them for new selections.
- Log sensitive exports through the approved audit flow; a LOV itself must not expose fields outside its authorized scope.
