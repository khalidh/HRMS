# US1 employee and organization acceptance journey

## Preconditions

- Deploy the versioned schema to an isolated HRMS test schema and pass
  [`foundation_schema.sql`](../sql/foundation_schema.sql).
- Import an APEX 26.2 export after an application/workspace ID is assigned.
- Configure an authenticated test identity, initialize `PKG_APP_CONTEXT`, and explicitly
  grant only the role actions required by the test.
- Load approved, anonymized employee/organization fixtures. No reference fixtures are
  currently available in the repository.
- Do not use real employee data or run lifecycle mutations in a shared environment.

## Journey

1. Sign in as an employee and open Employee Search.
   - Verify only the employee's authorized scope is returned.
   - Search by first name, last name, department, status, location, and hire-date range.
   - Confirm paging, sort, empty state, keyboard access, and visible labels.
2. Open the employee profile.
   - Verify profile, dependent, contact, history, and audit tabs each require their own
     server-side authorization.
   - Confirm SSN, date of birth, salary, free-text audit payloads, and bank/tax data are absent.
3. Attempt a direct URL and an out-of-scope employee ID.
   - Confirm the secured view and package deny access even when a button is hidden or bypassed.
4. Sign in as a manager.
   - Verify current and delegated reports are visible; unrelated employees are not.
   - Confirm the manager cannot update or terminate employees without a separately approved grant.
5. Sign in as HR with explicit view/update/terminate grants.
   - Update an employee profile and perform a transfer in the isolated test schema.
   - Verify employee state, lifecycle history, and audit metadata; confirm the failed-operation
     path leaves no partial employee/history changes.
6. Exercise promotion, termination, and rehire dialogs.
   - Verify reason/date/grade validations, confirmation, success handling, and refresh behavior.
   - Confirm each action is denied when its specific authorization is removed.
7. Sign in as an auditor.
   - Verify authorized read-only employee/audit metadata and denial of employee updates,
     termination, and unapproved exports.
8. Run [`us1_forms_reconciliation.sql`](../integration/us1_forms_reconciliation.sql) after
   the Forms owner supplies reviewed, anonymized employee and department reference tables.

## Release checks

- Run the APEX accessibility checker and keyboard-only navigation on pages 50-53.
- Verify contrast, accessible names, form errors, dialog focus/return behavior, and mobile
  report usability.
- Record the APEX export revision, fixture revision, role grants, and reconciliation result.

The page descriptors in `apex/application/pages/` are not an APEX export; this journey
cannot be run in a browser until the workspace, application export, and fixtures exist.
