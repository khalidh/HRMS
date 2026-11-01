CREATE OR REPLACE PACKAGE BODY HRMS.PKG_SECURITY AS
-- ============================================================================
-- PKG_SECURITY - Authentication & Authorization Package Body
-- ============================================================================

    -- VULNERABILITY: Encryption key hard-coded in source
    c_encryption_key RAW(32) := UTL_RAW.CAST_TO_RAW('HR$ystem_3ncrypt10n_K3y_2024!!');
    c_session_timeout_min CONSTANT NUMBER := 30;

    -- -----------------------------------------------------------------------
    -- hash_password
    -- WEAKNESS: Uses MD5 - should use stronger algorithm
    -- -----------------------------------------------------------------------
    FUNCTION hash_password(
        p_password IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN RAWTOHEX(
            DBMS_CRYPTO.HASH(
                UTL_RAW.CAST_TO_RAW(p_password),
                DBMS_CRYPTO.HASH_MD5
            )
        );
    END hash_password;

    -- -----------------------------------------------------------------------
    -- authenticate
    -- VULNERABILITY: No brute-force protection (no lockout after N failures)
    -- -----------------------------------------------------------------------
    FUNCTION authenticate(
        p_username   IN VARCHAR2,
        p_password   IN VARCHAR2,
        p_ip_address IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER IS
        v_emp_id     NUMBER;
        v_session_id NUMBER;
        v_stored_hash VARCHAR2(200);
        v_input_hash  VARCHAR2(200);
    BEGIN
        -- Look up user
        BEGIN
            SELECT EMP_ID INTO v_emp_id
            FROM EMPLOYEES
            WHERE UPPER(EMAIL) = UPPER(p_username)
            AND EMPLOYMENT_STATUS = 'ACTIVE';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- VULNERABILITY: Timing attack - different response time for
                -- invalid user vs invalid password
                RAISE_APPLICATION_ERROR(-20301, 'Invalid username or password');
            WHEN TOO_MANY_ROWS THEN
                -- Multiple employees with same email - use first active one
                SELECT MIN(EMP_ID) INTO v_emp_id
                FROM EMPLOYEES
                WHERE UPPER(EMAIL) = UPPER(p_username)
                AND EMPLOYMENT_STATUS = 'ACTIVE';
        END;

        -- NOTE: In the real system, passwords are stored in a separate
        -- USER_CREDENTIALS table. For this legacy codebase, we simulate
        -- authentication against a simplified model.

        -- Create session
        SELECT SEQ_USER_SESSION.NEXTVAL INTO v_session_id FROM DUAL;

        INSERT INTO USER_SESSIONS (
            SESSION_ID, EMP_ID, USERNAME, LOGIN_TIME,
            IP_ADDRESS, SESSION_STATUS, CREATED_DATE
        ) VALUES (
            v_session_id, v_emp_id, p_username, SYSDATE,
            p_ip_address, 'ACTIVE', SYSDATE
        );

        -- Set session context
        PKG_EMPLOYEE.set_session_context(p_username, v_emp_id);

        PKG_AUDIT.log_action('USER_SESSIONS', v_session_id, 'INSERT', p_username);

        RETURN v_session_id;
    END authenticate;

    -- -----------------------------------------------------------------------
    -- logout
    -- -----------------------------------------------------------------------
    PROCEDURE logout(
        p_session_id IN NUMBER
    ) IS
    BEGIN
        UPDATE USER_SESSIONS SET
            LOGOUT_TIME = SYSDATE,
            SESSION_STATUS = 'CLOSED'
        WHERE SESSION_ID = p_session_id;
    END logout;

    -- -----------------------------------------------------------------------
    -- is_session_valid
    -- -----------------------------------------------------------------------
    FUNCTION is_session_valid(
        p_session_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_status VARCHAR2(20);
        v_login_time DATE;
    BEGIN
        SELECT SESSION_STATUS, LOGIN_TIME
        INTO v_status, v_login_time
        FROM USER_SESSIONS
        WHERE SESSION_ID = p_session_id;

        IF v_status != 'ACTIVE' THEN
            RETURN FALSE;
        END IF;

        -- Check timeout
        IF (SYSDATE - v_login_time) * 24 * 60 > c_session_timeout_min THEN
            -- Auto-expire session
            UPDATE USER_SESSIONS SET
                SESSION_STATUS = 'EXPIRED',
                LOGOUT_TIME = SYSDATE
            WHERE SESSION_ID = p_session_id;
            RETURN FALSE;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END is_session_valid;

    -- -----------------------------------------------------------------------
    -- has_permission
    -- APEX requests use explicit grants and authenticated employee scope.
    -- The legacy branch remains for Forms callers during migration.
    -- -----------------------------------------------------------------------
    FUNCTION has_permission(
        p_emp_id IN NUMBER,
        p_module IN VARCHAR2,
        p_action IN VARCHAR2 DEFAULT 'VIEW'
    ) RETURN BOOLEAN IS
        v_dept_id  NUMBER;
        v_grade_id NUMBER;
        v_permission_count PLS_INTEGER;
        v_module_code VARCHAR2(30) := UPPER(TRIM(p_module));
        v_action_code VARCHAR2(30) := UPPER(TRIM(p_action));
    BEGIN
        IF v_module_code IS NULL OR v_action_code IS NULL THEN
            RETURN FALSE;
        END IF;

        IF v_action_code = 'EDIT' THEN
            v_action_code := 'UPDATE';
        END IF;

        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            IF v_module_code IN (
                   'EMPLOYEE',
                   'LEAVE',
                   'PAYROLL',
                   'PERFORMANCE',
                   'AUDIT',
                   'REPORT'
               )
               AND p_emp_id IS NOT NULL
               AND NOT HRMS.PKG_APP_CONTEXT.is_employee_in_scope(p_emp_id)
            THEN
                RETURN FALSE;
            END IF;

            SELECT COUNT(*)
              INTO v_permission_count
              FROM HRMS.VW_APP_USER_PERMISSIONS permission
             WHERE permission.MODULE_CODE = v_module_code
               AND permission.ACTION_CODE = v_action_code;

            RETURN v_permission_count > 0;
        END IF;

        SELECT e.DEPT_ID, j.GRADE_ID
        INTO v_dept_id, v_grade_id
        FROM EMPLOYEES e
        JOIN JOB_TITLES j ON e.JOB_ID = j.JOB_ID
        WHERE e.EMP_ID = p_emp_id;

        -- Simplified permission model:
        -- Grade >= 8: Full access to all modules
        -- Grade >= 5: View all, edit own department
        -- Grade < 5: View/edit own records only

        IF v_grade_id >= 8 THEN
            RETURN TRUE;  -- Senior management - full access
        END IF;

        IF v_action_code = 'VIEW' AND v_grade_id >= 5 THEN
            RETURN TRUE;  -- Mid-level can view all
        END IF;

        -- Module-specific rules
        IF v_module_code = 'LEAVE' AND v_action_code IN ('CREATE', 'VIEW') THEN
            RETURN TRUE;  -- Everyone can submit/view own leave
        END IF;

        IF v_module_code = 'EMPLOYEE' AND v_action_code = 'VIEW' THEN
            RETURN TRUE;  -- Everyone can view own profile
        END IF;

        RETURN FALSE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END has_permission;

    -- -----------------------------------------------------------------------
    -- encrypt_ssn / decrypt_ssn
    -- -----------------------------------------------------------------------
    FUNCTION encrypt_ssn(
        p_ssn IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_raw RAW(2000);
    BEGIN
        v_raw := DBMS_CRYPTO.ENCRYPT(
            src => UTL_RAW.CAST_TO_RAW(p_ssn),
            typ => DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5,
            key => c_encryption_key
        );
        RETURN RAWTOHEX(v_raw);
    END encrypt_ssn;

    FUNCTION decrypt_ssn(
        p_encrypted IN VARCHAR2
    ) RETURN VARCHAR2 IS
        v_raw RAW(2000);
    BEGIN
        v_raw := DBMS_CRYPTO.DECRYPT(
            src => HEXTORAW(p_encrypted),
            typ => DBMS_CRYPTO.ENCRYPT_AES256 + DBMS_CRYPTO.CHAIN_CBC + DBMS_CRYPTO.PAD_PKCS5,
            key => c_encryption_key
        );
        RETURN UTL_RAW.CAST_TO_VARCHAR2(v_raw);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '***DECRYPT_ERROR***';
    END decrypt_ssn;

    -- -----------------------------------------------------------------------
    -- change_password
    -- -----------------------------------------------------------------------
    PROCEDURE change_password(
        p_emp_id       IN NUMBER,
        p_old_password IN VARCHAR2,
        p_new_password IN VARCHAR2
    ) IS
    BEGIN
        -- Password complexity check
        IF LENGTH(p_new_password) < 8 THEN
            RAISE_APPLICATION_ERROR(-20310, 'Password must be at least 8 characters');
        END IF;

        IF NOT REGEXP_LIKE(p_new_password, '[A-Z]') THEN
            RAISE_APPLICATION_ERROR(-20311, 'Password must contain an uppercase letter');
        END IF;

        IF NOT REGEXP_LIKE(p_new_password, '[0-9]') THEN
            RAISE_APPLICATION_ERROR(-20312, 'Password must contain a number');
        END IF;

        -- NOTE: Actual password update would go to USER_CREDENTIALS table
        -- This is a stub for the legacy system model

        PKG_AUDIT.log_action('USER_CREDENTIALS', p_emp_id, 'UPDATE', USER);
    END change_password;

END PKG_SECURITY;
/
