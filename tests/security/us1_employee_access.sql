-- Run this block from an authenticated APEX test page after its Page 0
-- process initializes PKG_APP_CONTEXT. Supply the P99_* test items from an
-- approved, anonymized fixture; this file is not a standalone SQLcl login test.
DECLARE
    v_expected_role       VARCHAR2(30) := UPPER(TRIM(:P99_EXPECTED_ROLE));
    v_current_employee_id NUMBER := HRMS.PKG_APP_CONTEXT.get_employee_id;
    v_in_scope_employee_id NUMBER := TO_NUMBER(:P99_IN_SCOPE_EMP_ID);
    v_out_scope_employee_id NUMBER := TO_NUMBER(:P99_OUT_SCOPE_EMP_ID);
    v_count               PLS_INTEGER;

    PROCEDURE assert_true(
        in_condition IN BOOLEAN,
        in_message   IN VARCHAR2
    ) IS
    BEGIN
        IF in_condition IS NULL OR NOT in_condition THEN
            RAISE_APPLICATION_ERROR(-20250, in_message);
        END IF;
    END assert_true;
BEGIN
    IF NOT APEX_AUTHENTICATION.IS_AUTHENTICATED
       OR v_expected_role IS NULL
       OR v_expected_role NOT IN ('EMPLOYEE', 'MANAGER', 'HR', 'AUDITOR')
       OR v_in_scope_employee_id IS NULL
       OR v_out_scope_employee_id IS NULL
    THEN
        RAISE_APPLICATION_ERROR(-20251, 'Authenticated role and fixture employee IDs are required.');
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM HRMS.HRMS_USER_ROLES user_role
     WHERE user_role.EMP_ID = v_current_employee_id
       AND user_role.ROLE_CODE = v_expected_role
       AND user_role.ACTIVE_FLAG = 'Y'
       AND user_role.VALID_FROM <= SYSDATE
       AND (user_role.VALID_TO IS NULL OR user_role.VALID_TO > SYSDATE);

    assert_true(v_count = 1, 'The authenticated test employee lacks the expected active role.');

    CASE v_expected_role
        WHEN 'EMPLOYEE' THEN
            assert_true(
                v_in_scope_employee_id = v_current_employee_id,
                'The employee test target must be the authenticated employee.'
            );
            assert_true(
                HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'VIEW'),
                'The employee must be allowed to view their own authorized record.'
            );
            assert_true(
                NOT HRMS.PKG_SECURITY.has_permission(v_out_scope_employee_id, 'EMPLOYEE', 'UPDATE'),
                'The employee must not update an out-of-scope record.'
            );
            assert_true(
                NOT HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'TERMINATE'),
                'The employee role must not implicitly grant termination.'
            );
        WHEN 'MANAGER' THEN
            assert_true(
                HRMS.PKG_APP_CONTEXT.is_employee_in_scope(v_in_scope_employee_id),
                'The manager test target must be in the current or delegated hierarchy.'
            );
            assert_true(
                NOT HRMS.PKG_APP_CONTEXT.is_employee_in_scope(v_out_scope_employee_id),
                'The manager fixture must include an unrelated employee outside the hierarchy.'
            );
            assert_true(
                HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'VIEW'),
                'The manager must be allowed to view the in-scope employee.'
            );
            assert_true(
                NOT HRMS.PKG_SECURITY.has_permission(v_out_scope_employee_id, 'EMPLOYEE', 'VIEW'),
                'The manager must not view an out-of-scope employee.'
            );
            assert_true(
                NOT HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'UPDATE'),
                'The manager role must not implicitly grant employee updates.'
            );
        WHEN 'HR' THEN
            assert_true(
                HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'VIEW')
                AND HRMS.PKG_SECURITY.has_permission(v_out_scope_employee_id, 'EMPLOYEE', 'VIEW'),
                'HR access to both authorized organization records must be explicitly granted.'
            );
            assert_true(
                HRMS.PKG_SECURITY.has_permission(v_out_scope_employee_id, 'EMPLOYEE', 'UPDATE'),
                'HR lifecycle updates must be granted explicitly.'
            );
        WHEN 'AUDITOR' THEN
            assert_true(
                HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'AUDIT', 'VIEW'),
                'Auditor access to audit metadata must be granted explicitly.'
            );
            assert_true(
                NOT HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'UPDATE')
                AND NOT HRMS.PKG_SECURITY.has_permission(v_in_scope_employee_id, 'EMPLOYEE', 'TERMINATE'),
                'The auditor role must remain read-only for employee lifecycle operations.'
            );
    END CASE;

    SELECT COUNT(*)
      INTO v_count
      FROM HRMS.VW_APP_EMPLOYEES employee
     WHERE employee.EMP_ID = v_in_scope_employee_id;

    assert_true(v_count = 1, 'The secure employee list must expose the authorized in-scope record.');

    IF NOT HRMS.PKG_SECURITY.has_permission(
        v_in_scope_employee_id,
        'EMPLOYEE',
        'PROFILE_VIEW'
    ) THEN
        SELECT COUNT(*)
          INTO v_count
          FROM HRMS.VW_APP_EMPLOYEE_PROFILE employee_profile
         WHERE employee_profile.EMP_ID = v_in_scope_employee_id;

        assert_true(v_count = 0, 'Profile fields must remain hidden without PROFILE_VIEW.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('PASS: US1 employee role and scope access checks for ' || v_expected_role || '.');
END;
/
