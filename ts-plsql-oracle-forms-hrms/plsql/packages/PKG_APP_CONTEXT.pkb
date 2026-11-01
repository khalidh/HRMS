CREATE OR REPLACE PACKAGE BODY HRMS.PKG_APP_CONTEXT AS

    g_apex_username   VARCHAR2(255);
    g_apex_session_id NUMBER;
    g_context_ready   BOOLEAN := FALSE;

    PROCEDURE reset_context IS
    BEGIN
        g_apex_username := NULL;
        g_apex_session_id := NULL;
        g_context_ready := FALSE;
    END reset_context;

    PROCEDURE assert_context IS
        v_apex_session_id NUMBER;
    BEGIN
        v_apex_session_id :=
            TO_NUMBER(APEX_UTIL.GET_SESSION_STATE('APP_SESSION'));

        IF NOT g_context_ready
           OR NOT APEX_AUTHENTICATION.IS_AUTHENTICATED
           OR APEX_APPLICATION.G_USER IS NULL
           OR APEX_APPLICATION.G_USER != g_apex_username
           OR v_apex_session_id IS NULL
           OR v_apex_session_id != g_apex_session_id
        THEN
            reset_context;
            RAISE_APPLICATION_ERROR(
                -20092,
                'Authenticated HRMS application context is not initialized.'
            );
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            reset_context;
            RAISE;
    END assert_context;

    PROCEDURE initialize_context IS
        v_apex_username   APEX_APPLICATION.G_USER%TYPE;
        v_apex_session_id NUMBER;
    BEGIN
        reset_context;

        IF NOT APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            RAISE_APPLICATION_ERROR(
                -20091,
                'An authenticated APEX session is required.'
            );
        END IF;

        v_apex_username := APEX_APPLICATION.G_USER;
        v_apex_session_id := TO_NUMBER(APEX_UTIL.GET_SESSION_STATE('APP_SESSION'));

        IF v_apex_username IS NULL
           OR v_apex_session_id IS NULL
           OR v_apex_session_id <= 0
        THEN
            RAISE_APPLICATION_ERROR(
                -20091,
                'An authenticated APEX session is required.'
            );
        END IF;

        g_apex_username := v_apex_username;
        g_apex_session_id := v_apex_session_id;
        g_context_ready := TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            reset_context;
            RAISE;
    END initialize_context;

    PROCEDURE clear_context IS
    BEGIN
        reset_context;
    END clear_context;

    FUNCTION get_apex_username RETURN VARCHAR2 IS
    BEGIN
        assert_context;
        RETURN g_apex_username;
    END get_apex_username;

    FUNCTION get_apex_session_id RETURN NUMBER IS
    BEGIN
        assert_context;
        RETURN g_apex_session_id;
    END get_apex_session_id;

    FUNCTION get_employee_id RETURN NUMBER IS
        v_employee_id NUMBER;
    BEGIN
        assert_context;

        EXECUTE IMMEDIATE q'[
            SELECT ui.emp_id
              FROM HRMS.HRMS_USER_IDENTITIES ui
              JOIN HRMS.EMPLOYEES e
                ON e.emp_id = ui.emp_id
             WHERE ui.sso_subject = :subject
               AND ui.active_flag = 'Y'
               AND (ui.valid_from IS NULL OR ui.valid_from <= SYSTIMESTAMP)
               AND (ui.valid_to IS NULL OR ui.valid_to > SYSTIMESTAMP)
               AND e.employment_status = 'ACTIVE'
               AND e.active_flag = 'Y'
        ]'
        INTO v_employee_id
        USING g_apex_username;

        RETURN v_employee_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20093,
                'The authenticated identity is not mapped to an active HRMS employee.'
            );
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(
                -20094,
                'The authenticated identity has more than one active HRMS mapping.'
            );
        WHEN OTHERS THEN
            IF SQLCODE = -942 THEN
                RAISE_APPLICATION_ERROR(
                    -20095,
                    'HRMS identity mapping is unavailable; complete the security schema setup.'
                );
            END IF;
            RAISE;
    END get_employee_id;

    FUNCTION is_employee_in_scope (
        in_target_employee_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_current_employee_id NUMBER;
        v_scope_match_count   PLS_INTEGER;
    BEGIN
        assert_context;

        IF in_target_employee_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20096,
                'Target employee ID is required for a scope check.'
            );
        END IF;

        v_current_employee_id := get_employee_id;

        EXECUTE IMMEDIATE q'[
            SELECT COUNT(*)
              FROM (
                    SELECT employee.emp_id
                      FROM HRMS.EMPLOYEES employee
                     START WITH employee.emp_id = :manager_employee_id
                   CONNECT BY NOCYCLE PRIOR employee.emp_id = employee.manager_emp_id
                    UNION
                    SELECT employee.emp_id
                      FROM HRMS.EMPLOYEES employee
                     START WITH employee.emp_id IN (
                           SELECT delegation.delegator_emp_id
                             FROM HRMS.HRMS_EMPLOYEE_SCOPE_DELEGATIONS delegation
                            WHERE delegation.delegate_emp_id = :delegate_employee_id
                              AND delegation.active_flag = 'Y'
                              AND delegation.valid_from <= SYSDATE
                              AND (delegation.valid_to IS NULL OR delegation.valid_to > SYSDATE)
                       )
                   CONNECT BY NOCYCLE PRIOR employee.emp_id = employee.manager_emp_id
                   ) scoped
             WHERE scoped.emp_id = :target_employee_id
        ]'
        INTO v_scope_match_count
        USING v_current_employee_id, v_current_employee_id, in_target_employee_id;

        RETURN v_scope_match_count > 0;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
        WHEN OTHERS THEN
            IF SQLCODE = -942 THEN
                RAISE_APPLICATION_ERROR(
                    -20095,
                    'HRMS employee hierarchy is unavailable; complete the core schema setup.'
                );
            END IF;
            RAISE;
    END is_employee_in_scope;

END PKG_APP_CONTEXT;
/
