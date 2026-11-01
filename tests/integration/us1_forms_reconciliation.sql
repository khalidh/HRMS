-- Requires reviewed, anonymized reference data supplied by the Forms owner.
-- Define these HRMS test-only tables from that fixture before running:
--   US1_FORMS_EMPLOYEE_REFERENCE
--     EMP_ID, DEPT_ID, JOB_ID, MANAGER_EMP_ID, EMPLOYMENT_STATUS, HIRE_DATE
--   US1_FORMS_DEPARTMENT_REFERENCE
--     DEPT_ID, PARENT_DEPT_ID, EMPLOYEE_COUNT
-- Run from an authenticated APEX session with authorized organization scope.
DECLARE
    v_employee_fixture_count PLS_INTEGER;
    v_department_fixture_count PLS_INTEGER;
    v_mismatch_count PLS_INTEGER;
    v_employee_row_count PLS_INTEGER;
    v_department_row_count PLS_INTEGER;
    v_hr_view_permission_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_employee_fixture_count
      FROM USER_TABLES table_record
     WHERE table_record.TABLE_NAME = 'US1_FORMS_EMPLOYEE_REFERENCE';

    SELECT COUNT(*)
      INTO v_department_fixture_count
      FROM USER_TABLES table_record
     WHERE table_record.TABLE_NAME = 'US1_FORMS_DEPARTMENT_REFERENCE';

    IF v_employee_fixture_count != 1 OR v_department_fixture_count != 1 THEN
        RAISE_APPLICATION_ERROR(
            -20280,
            'Forms reconciliation is blocked: reviewed employee and department reference fixtures are required.'
        );
    END IF;

    SELECT COUNT(*)
      INTO v_hr_view_permission_count
      FROM HRMS.VW_APP_USER_PERMISSIONS permission
     WHERE permission.ROLE_CODE = 'HR'
       AND permission.MODULE_CODE = 'EMPLOYEE'
       AND permission.ACTION_CODE = 'VIEW';

    IF v_hr_view_permission_count = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20283,
            'Forms reconciliation requires an authenticated HR role with explicit employee-view permission.'
        );
    END IF;

    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM HRMS.US1_FORMS_EMPLOYEE_REFERENCE'
       INTO v_employee_row_count;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM HRMS.US1_FORMS_DEPARTMENT_REFERENCE'
       INTO v_department_row_count;

    IF v_employee_row_count = 0 OR v_department_row_count = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20284,
            'Forms reconciliation is blocked: reference fixtures must contain employee and department rows.'
        );
    END IF;

    EXECUTE IMMEDIATE q'[
        SELECT COUNT(*)
          FROM (
                SELECT reference_row.EMP_ID
                  FROM HRMS.US1_FORMS_EMPLOYEE_REFERENCE reference_row
                  FULL OUTER JOIN HRMS.VW_APP_EMPLOYEES target_row
                    ON target_row.EMP_ID = reference_row.EMP_ID
                 WHERE reference_row.EMP_ID IS NULL
                    OR target_row.EMP_ID IS NULL
                    OR DECODE(target_row.DEPT_ID, reference_row.DEPT_ID, 0, 1) = 1
                    OR DECODE(target_row.JOB_ID, reference_row.JOB_ID, 0, 1) = 1
                    OR DECODE(target_row.MANAGER_EMP_ID, reference_row.MANAGER_EMP_ID, 0, 1) = 1
                    OR DECODE(target_row.EMPLOYMENT_STATUS, reference_row.EMPLOYMENT_STATUS, 0, 1) = 1
                    OR DECODE(target_row.HIRE_DATE, reference_row.HIRE_DATE, 0, 1) = 1
               )
    ]'
    INTO v_mismatch_count;

    IF v_mismatch_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20281,
            'Forms/APEX employee reconciliation found ' || v_mismatch_count || ' row mismatches.'
        );
    END IF;

    EXECUTE IMMEDIATE q'[
        SELECT COUNT(*)
          FROM (
                SELECT reference_row.DEPT_ID
                  FROM HRMS.US1_FORMS_DEPARTMENT_REFERENCE reference_row
                  FULL OUTER JOIN (
                      SELECT department.DEPT_ID,
                             department.PARENT_DEPT_ID,
                             COUNT(employee.EMP_ID) AS EMPLOYEE_COUNT
                        FROM HRMS.VW_APP_ORG_DEPARTMENTS department
                        LEFT JOIN HRMS.VW_APP_EMPLOYEES employee
                          ON employee.DEPT_ID = department.DEPT_ID
                       GROUP BY department.DEPT_ID, department.PARENT_DEPT_ID
                  ) target_row
                    ON target_row.DEPT_ID = reference_row.DEPT_ID
                 WHERE reference_row.DEPT_ID IS NULL
                    OR target_row.DEPT_ID IS NULL
                    OR DECODE(target_row.PARENT_DEPT_ID, reference_row.PARENT_DEPT_ID, 0, 1) = 1
                    OR DECODE(target_row.EMPLOYEE_COUNT, reference_row.EMPLOYEE_COUNT, 0, 1) = 1
               )
    ]'
    INTO v_mismatch_count;

    IF v_mismatch_count > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20282,
            'Forms/APEX organization reconciliation found ' || v_mismatch_count || ' mismatches.'
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('PASS: Forms/APEX employee, headcount, and organization reconciliation.');
END;
/
