-- Run only from an authenticated APEX test session in an isolated HRMS test
-- schema. The transfer is rolled back; the successful audit event is retained.
DECLARE
    v_employee_id       NUMBER := TO_NUMBER(:P99_TEST_EMP_ID);
    v_target_dept_id    NUMBER := TO_NUMBER(:P99_TARGET_DEPT_ID);
    v_expected_last_name VARCHAR2(50) := UPPER(TRIM(:P99_EXPECTED_LAST_NAME));
    v_old_dept_id       NUMBER;
    v_current_dept_id   NUMBER;
    v_found_count       PLS_INTEGER := 0;
    v_history_count     PLS_INTEGER;
    v_audit_count       PLS_INTEGER;
    v_audit_id_before   NUMBER;
    v_cursor            HRMS.PKG_EMPLOYEE.t_emp_cursor;
    v_result_emp_id     NUMBER;
    v_emp_number        VARCHAR2(20);
    v_first_name        VARCHAR2(50);
    v_last_name         VARCHAR2(50);
    v_hire_date         DATE;
    v_dept_id           NUMBER;
    v_dept_name         VARCHAR2(100);
    v_job_title         VARCHAR2(100);
    v_status            VARCHAR2(20);
    v_location_code     VARCHAR2(10);

    PROCEDURE assert_true(
        in_condition IN BOOLEAN,
        in_message   IN VARCHAR2
    ) IS
    BEGIN
        IF in_condition IS NULL OR NOT in_condition THEN
            RAISE_APPLICATION_ERROR(-20260, in_message);
        END IF;
    END assert_true;
BEGIN
    SAVEPOINT us1_lifecycle_test_start;

    IF NOT APEX_AUTHENTICATION.IS_AUTHENTICATED
       OR v_employee_id IS NULL
       OR v_target_dept_id IS NULL
       OR v_expected_last_name IS NULL
    THEN
        RAISE_APPLICATION_ERROR(-20261, 'Authenticated session and approved lifecycle fixtures are required.');
    END IF;

    HRMS.PKG_APP_CONTEXT.initialize_context;
    assert_true(
        HRMS.PKG_SECURITY.has_permission(v_employee_id, 'EMPLOYEE', 'VIEW'),
        'The test identity must have explicit view permission for the employee.'
    );
    assert_true(
        HRMS.PKG_SECURITY.has_permission(v_employee_id, 'EMPLOYEE', 'UPDATE'),
        'The test identity must have explicit update permission for the employee.'
    );

    HRMS.PKG_EMPLOYEE.search_employees(
        p_cursor    => v_cursor,
        p_last_name => v_expected_last_name
    );

    LOOP
        FETCH v_cursor
         INTO v_result_emp_id,
              v_emp_number,
              v_first_name,
              v_last_name,
              v_hire_date,
              v_dept_id,
              v_dept_name,
              v_job_title,
              v_status,
              v_location_code;
        EXIT WHEN v_cursor%NOTFOUND;

        assert_true(
            HRMS.PKG_APP_CONTEXT.is_employee_in_scope(v_result_emp_id),
            'Employee search returned a record outside the authenticated scope.'
        );
        v_found_count := v_found_count + 1;
    END LOOP;
    CLOSE v_cursor;

    assert_true(v_found_count > 0, 'Employee search did not return the expected fixture.');

    SELECT department.EMP_ID
      INTO v_result_emp_id
      FROM HRMS.VW_APP_EMPLOYEE_HIERARCHY department
     WHERE department.EMP_ID = v_employee_id
       AND ROWNUM = 1;

    SELECT employee.DEPT_ID
      INTO v_old_dept_id
      FROM HRMS.EMPLOYEES employee
     WHERE employee.EMP_ID = v_employee_id;

    assert_true(v_old_dept_id != v_target_dept_id, 'Transfer fixture must use a different active department.');
    SELECT NVL(MAX(audit_record.AUDIT_ID), 0)
      INTO v_audit_id_before
      FROM HRMS.AUDIT_LOG audit_record;

    HRMS.PKG_EMPLOYEE.transfer_employee(
        p_emp_id         => v_employee_id,
        p_new_dept_id    => v_target_dept_id,
        p_effective_date => SYSDATE,
        p_reason_code    => 'TEST'
    );

    SELECT COUNT(*)
      INTO v_history_count
      FROM HRMS.EMPLOYEE_HISTORY history
     WHERE history.EMP_ID = v_employee_id
       AND history.CHANGE_TYPE = 'TRANSFER'
       AND history.EFFECTIVE_DATE >= TRUNC(SYSDATE)
       AND history.EFFECTIVE_DATE < TRUNC(SYSDATE) + 1
       AND history.NEW_DEPT_ID = v_target_dept_id;

    SELECT COUNT(*)
      INTO v_audit_count
      FROM HRMS.AUDIT_LOG audit_record
     WHERE audit_record.AUDIT_ID > v_audit_id_before
       AND audit_record.TABLE_NAME = 'EMPLOYEES'
       AND audit_record.RECORD_ID = v_employee_id
       AND audit_record.ACTION_TYPE = 'UPDATE';

    assert_true(v_history_count > 0, 'A successful transfer must create employee history.');
    assert_true(v_audit_count > 0, 'A successful transfer must create an audit event.');

    SELECT employee.DEPT_ID
      INTO v_current_dept_id
      FROM HRMS.EMPLOYEES employee
     WHERE employee.EMP_ID = v_employee_id;

    assert_true(
        v_current_dept_id = v_target_dept_id,
        'A successful transfer must update the employee current department.'
    );

    ROLLBACK TO us1_lifecycle_test_start;
    DBMS_OUTPUT.PUT_LINE(
        'PASS: secure search, hierarchy, transfer history, audit, and transaction rollback.'
    );
EXCEPTION
    WHEN OTHERS THEN
        IF v_cursor%ISOPEN THEN
            CLOSE v_cursor;
        END IF;
        ROLLBACK TO us1_lifecycle_test_start;
        RAISE;
END;
/
