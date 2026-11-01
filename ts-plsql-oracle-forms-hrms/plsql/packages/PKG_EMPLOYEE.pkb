CREATE OR REPLACE PACKAGE BODY HRMS.PKG_EMPLOYEE AS
-- ============================================================================
-- PKG_EMPLOYEE - Employee Management Package Body
-- ============================================================================

    -- Private constants
    c_emp_number_prefix  CONSTANT VARCHAR2(3) := 'EMP';
    -- Private forward declarations
    PROCEDURE log_history(
        p_emp_id        IN NUMBER,
        p_change_type   IN VARCHAR2,
        p_effective_date IN DATE,
        p_old_dept_id   IN NUMBER DEFAULT NULL,
        p_new_dept_id   IN NUMBER DEFAULT NULL,
        p_old_job_id    IN NUMBER DEFAULT NULL,
        p_new_job_id    IN NUMBER DEFAULT NULL,
        p_old_manager   IN NUMBER DEFAULT NULL,
        p_new_manager   IN NUMBER DEFAULT NULL,
        p_old_salary    IN NUMBER DEFAULT NULL,
        p_new_salary    IN NUMBER DEFAULT NULL,
        p_old_location  IN VARCHAR2 DEFAULT NULL,
        p_new_location  IN VARCHAR2 DEFAULT NULL,
        p_reason_code   IN VARCHAR2 DEFAULT NULL,
        p_comments      IN VARCHAR2 DEFAULT NULL,
        p_user          IN VARCHAR2 DEFAULT USER
    );

    PROCEDURE validate_dept(p_dept_id IN NUMBER);
    PROCEDURE validate_manager(p_manager_id IN NUMBER, p_emp_id IN NUMBER DEFAULT NULL);
    FUNCTION get_next_emp_id RETURN NUMBER;
    FUNCTION resolve_actor(p_user IN VARCHAR2) RETURN VARCHAR2;
    PROCEDURE assert_authorized(
        p_emp_id IN NUMBER,
        p_module IN VARCHAR2,
        p_action IN VARCHAR2
    );

    -- -----------------------------------------------------------------------
    -- generate_emp_number
    -- Generates next employee number: EMP-NNNNNN
    -- BUG: race condition under concurrent inserts - no SELECT FOR UPDATE
    -- -----------------------------------------------------------------------
    FUNCTION generate_emp_number RETURN VARCHAR2 IS
        v_next_number NUMBER;
        v_new_number VARCHAR2(20);
    BEGIN
        LOOP
            SELECT SEQ_EMP_NUMBER.NEXTVAL
              INTO v_next_number
              FROM DUAL;

            IF v_next_number > 999999 THEN
                RAISE_APPLICATION_ERROR(-20240, 'The employee number sequence is exhausted.');
            END IF;

            v_new_number := c_emp_number_prefix || '-' || LPAD(v_next_number, 6, '0');

            SELECT COUNT(*)
              INTO v_next_number
              FROM HRMS.EMPLOYEES employee
             WHERE employee.EMP_NUMBER = v_new_number;

            EXIT WHEN v_next_number = 0;
        END LOOP;

        RETURN v_new_number;
    END generate_emp_number;

    -- -----------------------------------------------------------------------
    -- get_next_emp_id
    -- -----------------------------------------------------------------------
    FUNCTION get_next_emp_id RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT SEQ_EMPLOYEE.NEXTVAL INTO v_id FROM DUAL;
        RETURN v_id;
    END get_next_emp_id;

    -- -----------------------------------------------------------------------
    -- validate_dept
    -- -----------------------------------------------------------------------
    PROCEDURE validate_dept(p_dept_id IN NUMBER) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM DEPARTMENTS
        WHERE DEPT_ID = p_dept_id
        AND ACTIVE_FLAG = 'Y';

        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Invalid or inactive department: ' || p_dept_id);
        END IF;
    END validate_dept;

    -- -----------------------------------------------------------------------
    -- validate_manager
    -- Checks manager exists and is active. Also prevents circular reporting.
    -- -----------------------------------------------------------------------
    PROCEDURE validate_manager(p_manager_id IN NUMBER, p_emp_id IN NUMBER DEFAULT NULL) IS
    BEGIN
        IF NOT PKG_VALIDATION.validate_manager(p_manager_id, p_emp_id) THEN
            RAISE_APPLICATION_ERROR(-20004, 'The selected manager is inactive or creates a reporting cycle.');
        END IF;
    END validate_manager;

    FUNCTION resolve_actor(p_user IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            RETURN HRMS.PKG_APP_CONTEXT.get_apex_username;
        END IF;

        RETURN NVL(g_current_user, p_user);
    END resolve_actor;

    PROCEDURE assert_authorized(
        p_emp_id IN NUMBER,
        p_module IN VARCHAR2,
        p_action IN VARCHAR2
    ) IS
        v_subject_emp_id NUMBER := p_emp_id;
    BEGIN
        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            IF v_subject_emp_id IS NULL THEN
                v_subject_emp_id := HRMS.PKG_APP_CONTEXT.get_employee_id;
            END IF;
        ELSIF v_subject_emp_id IS NULL THEN
            v_subject_emp_id := g_current_emp_id;
        END IF;

        IF v_subject_emp_id IS NULL
           OR NOT HRMS.PKG_SECURITY.has_permission(
               v_subject_emp_id,
               p_module,
               p_action
           )
        THEN
            RAISE_APPLICATION_ERROR(-20304, 'The requested employee operation is not authorized.');
        END IF;
    END assert_authorized;

    -- -----------------------------------------------------------------------
    -- log_history
    -- Records employee change history
    -- -----------------------------------------------------------------------
    PROCEDURE log_history(
        p_emp_id        IN NUMBER,
        p_change_type   IN VARCHAR2,
        p_effective_date IN DATE,
        p_old_dept_id   IN NUMBER DEFAULT NULL,
        p_new_dept_id   IN NUMBER DEFAULT NULL,
        p_old_job_id    IN NUMBER DEFAULT NULL,
        p_new_job_id    IN NUMBER DEFAULT NULL,
        p_old_manager   IN NUMBER DEFAULT NULL,
        p_new_manager   IN NUMBER DEFAULT NULL,
        p_old_salary    IN NUMBER DEFAULT NULL,
        p_new_salary    IN NUMBER DEFAULT NULL,
        p_old_location  IN VARCHAR2 DEFAULT NULL,
        p_new_location  IN VARCHAR2 DEFAULT NULL,
        p_reason_code   IN VARCHAR2 DEFAULT NULL,
        p_comments      IN VARCHAR2 DEFAULT NULL,
        p_user          IN VARCHAR2 DEFAULT USER
    ) IS
    BEGIN
        INSERT INTO EMPLOYEE_HISTORY (
            HIST_ID, EMP_ID, CHANGE_TYPE, EFFECTIVE_DATE,
            OLD_DEPT_ID, NEW_DEPT_ID, OLD_JOB_ID, NEW_JOB_ID,
            OLD_MANAGER_ID, NEW_MANAGER_ID, OLD_SALARY, NEW_SALARY,
            OLD_LOCATION, NEW_LOCATION, REASON_CODE, COMMENTS,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            SEQ_EMP_HISTORY.NEXTVAL, p_emp_id, p_change_type, p_effective_date,
            p_old_dept_id, p_new_dept_id, p_old_job_id, p_new_job_id,
            p_old_manager, p_new_manager, p_old_salary, p_new_salary,
            p_old_location, p_new_location, p_reason_code, p_comments,
            p_user, SYSDATE
        );
    END log_history;

    -- -----------------------------------------------------------------------
    -- create_employee
    -- -----------------------------------------------------------------------
    FUNCTION create_employee(
        p_first_name      IN VARCHAR2,
        p_last_name       IN VARCHAR2,
        p_hire_date       IN DATE,
        p_dept_id         IN NUMBER,
        p_job_id          IN NUMBER,
        p_manager_emp_id  IN NUMBER DEFAULT NULL,
        p_location_code   IN VARCHAR2 DEFAULT NULL,
        p_employment_type IN VARCHAR2 DEFAULT 'FULL_TIME',
        p_base_salary     IN NUMBER DEFAULT NULL,
        p_email           IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) RETURN NUMBER IS
        v_emp_id     NUMBER;
        v_emp_number VARCHAR2(20);
        v_location   VARCHAR2(10);
        v_grade_id   NUMBER;
        v_actor      VARCHAR2(255);
    BEGIN
        SAVEPOINT employee_create_start;
        assert_authorized(NULL, 'EMPLOYEE', 'CREATE');
        v_actor := resolve_actor(p_user);

        -- Validate inputs
        IF TRIM(p_first_name) IS NULL OR TRIM(p_last_name) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, 'First name and last name are required.');
        END IF;

        IF p_hire_date IS NULL
           OR NOT PKG_VALIDATION.validate_employment_type(p_employment_type)
           OR NOT PKG_VALIDATION.validate_email_format(p_email)
        THEN
            RAISE_APPLICATION_ERROR(-20010, 'One or more employee fields are invalid.');
        END IF;

        validate_dept(p_dept_id);
        validate_manager(p_manager_emp_id);
        IF NOT PKG_VALIDATION.validate_employee_dates(p_hire_date, NULL, 'ACTIVE') THEN
            RAISE_APPLICATION_ERROR(-20010, 'The hire date is invalid.');
        END IF;

        -- Validate job exists
        BEGIN
            IF NOT PKG_VALIDATION.validate_job(p_job_id) THEN
                RAISE NO_DATA_FOUND;
            END IF;

            SELECT job_title.GRADE_ID
              INTO v_grade_id
              FROM HRMS.JOB_TITLES job_title
             WHERE job_title.JOB_ID = p_job_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20011, 'Invalid or inactive job: ' || p_job_id);
        END;

        IF NOT PKG_VALIDATION.validate_location(p_location_code) THEN
            RAISE_APPLICATION_ERROR(-20003, 'The selected location is inactive or unavailable.');
        END IF;

        -- Validate salary against grade range
        IF p_base_salary IS NOT NULL THEN
            DECLARE
                v_min NUMBER;
                v_max NUMBER;
            BEGIN
                SELECT MIN_SALARY, MAX_SALARY
                INTO v_min, v_max
                FROM JOB_GRADES
                WHERE GRADE_ID = v_grade_id;

                IF p_base_salary < v_min OR p_base_salary > v_max THEN
                    -- NOTE: This is a soft warning, not an error
                    -- Forms trigger WHEN-VALIDATE-ITEM shows warning dialog
                    -- but allows override with manager approval
                    IF g_debug_mode THEN
                        DBMS_OUTPUT.PUT_LINE('WARNING: Salary ' || p_base_salary ||
                            ' outside grade range [' || v_min || '-' || v_max || ']');
                    END IF;
                END IF;
            END;
        END IF;

        -- Default location from department if not specified
        IF p_location_code IS NULL THEN
            SELECT department.LOCATION_CODE
              INTO v_location
              FROM HRMS.DEPARTMENTS department
             WHERE department.DEPT_ID = p_dept_id;
        ELSE
            v_location := p_location_code;
        END IF;

        IF NOT PKG_VALIDATION.validate_location(v_location) THEN
            RAISE_APPLICATION_ERROR(-20003, 'The employee location is inactive or unavailable.');
        END IF;

        -- Generate IDs
        v_emp_id := get_next_emp_id();
        v_emp_number := generate_emp_number();

        -- Insert employee record
        INSERT INTO EMPLOYEES (
            EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
            HIRE_DATE, DEPT_ID, JOB_ID, MANAGER_EMP_ID,
            LOCATION_CODE, EMPLOYMENT_TYPE, EMPLOYMENT_STATUS,
            EMAIL, ACTIVE_FLAG,
            CREATED_BY, CREATED_DATE
        ) VALUES (
            v_emp_id, v_emp_number, UPPER(TRIM(p_first_name)), UPPER(TRIM(p_last_name)),
            p_hire_date, p_dept_id, p_job_id, p_manager_emp_id,
            v_location, UPPER(TRIM(p_employment_type)), 'ACTIVE',
            LOWER(TRIM(p_email)), 'Y',
            v_actor, SYSDATE
        );

        -- Create initial salary record
        IF p_base_salary IS NOT NULL THEN
            -- NOTE: Circular dependency - calls PKG_PAYROLL.create_salary_record
            -- which in turn may call PKG_EMPLOYEE.is_active for validation
            PKG_PAYROLL.create_salary_record(
                p_emp_id         => v_emp_id,
                p_effective_date => p_hire_date,
                p_base_salary    => p_base_salary,
                p_change_reason  => 'NEW_HIRE',
                p_user           => v_actor
            );
        END IF;

        -- Log history
        log_history(
            p_emp_id        => v_emp_id,
            p_change_type   => 'HIRE',
            p_effective_date => p_hire_date,
            p_new_dept_id   => p_dept_id,
            p_new_job_id    => p_job_id,
            p_new_manager   => p_manager_emp_id,
            p_new_salary    => p_base_salary,
            p_new_location  => v_location,
            p_user          => v_actor
        );

        -- Audit trail
        PKG_AUDIT.log_action(
            p_table_name => 'EMPLOYEES',
            p_record_id  => v_emp_id,
            p_action     => 'INSERT',
            p_user       => v_actor
        );

        -- Send welcome notification
        PKG_NOTIFICATION.send_notification(
            p_recipient_emp_id => v_emp_id,
            p_type             => 'EMAIL',
            p_subject          => 'Welcome to the Company',
            p_body             => 'Dear ' || p_first_name || ', Welcome aboard! ' ||
                                  'Your employee number is ' || v_emp_number || '.',
            p_user             => v_actor
        );

        -- Notify manager
        IF p_manager_emp_id IS NOT NULL THEN
            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => p_manager_emp_id,
                p_type             => 'EMAIL',
                p_subject          => 'New Direct Report: ' || p_first_name || ' ' || p_last_name,
                p_body             => p_first_name || ' ' || p_last_name ||
                                      ' has been added as your direct report, starting ' ||
                                      TO_CHAR(p_hire_date, 'MM/DD/YYYY') || '.',
                p_user             => v_actor
            );
        END IF;

        RETURN v_emp_id;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK TO employee_create_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.CREATE',
                -20002,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
        WHEN OTHERS THEN
            ROLLBACK TO employee_create_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.CREATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END create_employee;

    -- -----------------------------------------------------------------------
    -- update_employee
    -- Updates only non-NULL parameters (partial update pattern)
    -- -----------------------------------------------------------------------
    PROCEDURE update_employee(
        p_emp_id          IN NUMBER,
        p_first_name      IN VARCHAR2 DEFAULT NULL,
        p_last_name       IN VARCHAR2 DEFAULT NULL,
        p_email           IN VARCHAR2 DEFAULT NULL,
        p_phone_work      IN VARCHAR2 DEFAULT NULL,
        p_phone_mobile    IN VARCHAR2 DEFAULT NULL,
        p_address_line1   IN VARCHAR2 DEFAULT NULL,
        p_address_line2   IN VARCHAR2 DEFAULT NULL,
        p_city            IN VARCHAR2 DEFAULT NULL,
        p_state_province  IN VARCHAR2 DEFAULT NULL,
        p_postal_code     IN VARCHAR2 DEFAULT NULL,
        p_country_code    IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT employee_update_start;
        assert_authorized(p_emp_id, 'EMPLOYEE', 'UPDATE');
        v_actor := resolve_actor(p_user);

        IF (p_first_name IS NOT NULL AND TRIM(p_first_name) IS NULL)
           OR (p_last_name IS NOT NULL AND TRIM(p_last_name) IS NULL)
           OR NOT PKG_VALIDATION.validate_email_format(p_email)
           OR NOT PKG_VALIDATION.validate_phone_format(p_phone_work)
           OR NOT PKG_VALIDATION.validate_phone_format(p_phone_mobile)
        THEN
            RAISE_APPLICATION_ERROR(-20010, 'One or more employee fields are invalid.');
        END IF;

        IF NOT emp_exists(p_emp_id) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found: ' || p_emp_id);
        END IF;

        UPDATE EMPLOYEES SET
            FIRST_NAME     = NVL(UPPER(TRIM(p_first_name)), FIRST_NAME),
            LAST_NAME      = NVL(UPPER(TRIM(p_last_name)), LAST_NAME),
            EMAIL          = NVL(LOWER(TRIM(p_email)), EMAIL),
            PHONE_WORK     = NVL(p_phone_work, PHONE_WORK),
            PHONE_MOBILE   = NVL(p_phone_mobile, PHONE_MOBILE),
            ADDRESS_LINE1  = NVL(p_address_line1, ADDRESS_LINE1),
            ADDRESS_LINE2  = NVL(p_address_line2, ADDRESS_LINE2),
            CITY           = NVL(p_city, CITY),
            STATE_PROVINCE = NVL(p_state_province, STATE_PROVINCE),
            POSTAL_CODE    = NVL(p_postal_code, POSTAL_CODE),
            COUNTRY_CODE   = NVL(p_country_code, COUNTRY_CODE),
            MODIFIED_BY    = v_actor,
            MODIFIED_DATE  = SYSDATE
        WHERE EMP_ID = p_emp_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee update failed: ' || p_emp_id);
        END IF;

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', v_actor);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO employee_update_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.UPDATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END update_employee;

    -- -----------------------------------------------------------------------
    -- get_employee
    -- -----------------------------------------------------------------------
    FUNCTION get_employee(
        p_emp_id IN NUMBER
    ) RETURN t_emp_rec IS
        v_rec t_emp_rec;
    BEGIN
        assert_authorized(p_emp_id, 'EMPLOYEE', 'VIEW');

        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            SELECT e.EMP_ID,
                   e.EMP_NUMBER,
                   e.FIRST_NAME,
                   e.LAST_NAME,
                   e.HIRE_DATE,
                   e.DEPT_ID,
                   e.JOB_ID,
                   e.MANAGER_EMP_ID,
                   e.EMPLOYMENT_STATUS
              INTO v_rec.emp_id,
                   v_rec.emp_number,
                   v_rec.first_name,
                   v_rec.last_name,
                   v_rec.hire_date,
                   v_rec.dept_id,
                   v_rec.job_id,
                   v_rec.manager_emp_id,
                   v_rec.employment_status
              FROM HRMS.VW_APP_EMPLOYEES e
             WHERE e.EMP_ID = p_emp_id;

            IF PKG_SECURITY.has_permission(p_emp_id, 'PAYROLL', 'VIEW') THEN
                SELECT MAX(salary_record.BASE_SALARY)
                       KEEP (DENSE_RANK LAST ORDER BY salary_record.EFFECTIVE_DATE)
                  INTO v_rec.base_salary
                  FROM HRMS.SALARY_RECORDS salary_record
                 WHERE salary_record.EMP_ID = p_emp_id
                   AND salary_record.ACTIVE_FLAG = 'Y'
                   AND salary_record.EFFECTIVE_DATE <= SYSDATE
                   AND (salary_record.END_DATE IS NULL
                        OR salary_record.END_DATE > SYSDATE);
            ELSE
                v_rec.base_salary := NULL;
            END IF;
        ELSE
            SELECT e.EMP_ID,
                   e.EMP_NUMBER,
                   e.FIRST_NAME,
                   e.LAST_NAME,
                   e.HIRE_DATE,
                   e.DEPT_ID,
                   e.JOB_ID,
                   e.MANAGER_EMP_ID,
                   e.EMPLOYMENT_STATUS
              INTO v_rec.emp_id,
                   v_rec.emp_number,
                   v_rec.first_name,
                   v_rec.last_name,
                   v_rec.hire_date,
                   v_rec.dept_id,
                   v_rec.job_id,
                   v_rec.manager_emp_id,
                   v_rec.employment_status
              FROM HRMS.EMPLOYEES e
             WHERE e.EMP_ID = p_emp_id;

            IF PKG_SECURITY.has_permission(p_emp_id, 'PAYROLL', 'VIEW') THEN
                SELECT MAX(salary_record.BASE_SALARY)
                       KEEP (DENSE_RANK LAST ORDER BY salary_record.EFFECTIVE_DATE)
                  INTO v_rec.base_salary
                  FROM HRMS.SALARY_RECORDS salary_record
                 WHERE salary_record.EMP_ID = p_emp_id
                   AND salary_record.ACTIVE_FLAG = 'Y'
                   AND salary_record.EFFECTIVE_DATE <= SYSDATE
                   AND (salary_record.END_DATE IS NULL
                        OR salary_record.END_DATE > SYSDATE);
            ELSE
                v_rec.base_salary := NULL;
            END IF;
        END IF;

        RETURN v_rec;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found or outside the authorized scope.');
    END get_employee;

    -- -----------------------------------------------------------------------
    -- get_employee_by_number
    -- -----------------------------------------------------------------------
    FUNCTION get_employee_by_number(
        p_emp_number IN VARCHAR2
    ) RETURN t_emp_rec IS
        v_emp_id NUMBER;
    BEGIN
        assert_authorized(NULL, 'EMPLOYEE', 'VIEW');

        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            SELECT employee.EMP_ID
              INTO v_emp_id
              FROM HRMS.VW_APP_EMPLOYEES employee
             WHERE employee.EMP_NUMBER = p_emp_number;
        ELSE
            SELECT employee.EMP_ID
              INTO v_emp_id
              FROM HRMS.EMPLOYEES employee
             WHERE employee.EMP_NUMBER = p_emp_number;
        END IF;

        RETURN get_employee(v_emp_id);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found or outside the authorized scope.');
    END get_employee_by_number;

    -- -----------------------------------------------------------------------
    -- search_employees
    -- Search with bind variables and caller-specific row scope.
    -- -----------------------------------------------------------------------
    PROCEDURE search_employees(
        p_cursor         OUT t_emp_cursor,
        p_last_name      IN VARCHAR2 DEFAULT NULL,
        p_first_name     IN VARCHAR2 DEFAULT NULL,
        p_dept_id        IN NUMBER DEFAULT NULL,
        p_status         IN VARCHAR2 DEFAULT NULL,
        p_location_code  IN VARCHAR2 DEFAULT NULL,
        p_hire_date_from IN DATE DEFAULT NULL,
        p_hire_date_to   IN DATE DEFAULT NULL
    ) IS
    BEGIN
        assert_authorized(NULL, 'EMPLOYEE', 'VIEW');

        IF p_status IS NOT NULL
           AND NOT PKG_VALIDATION.validate_employment_status(p_status)
        THEN
            RAISE_APPLICATION_ERROR(-20010, 'The requested employment status is invalid.');
        END IF;

        IF p_dept_id IS NOT NULL
           AND NOT PKG_VALIDATION.validate_department(p_dept_id)
        THEN
            RAISE_APPLICATION_ERROR(-20003, 'The requested department is inactive or unavailable.');
        END IF;

        IF p_location_code IS NOT NULL
           AND NOT PKG_VALIDATION.validate_location(p_location_code)
        THEN
            RAISE_APPLICATION_ERROR(-20003, 'The requested location is inactive or unavailable.');
        END IF;

        IF p_hire_date_from IS NOT NULL
           AND p_hire_date_to IS NOT NULL
           AND NOT PKG_VALIDATION.validate_date_range(p_hire_date_from, p_hire_date_to)
        THEN
            RAISE_APPLICATION_ERROR(-20010, 'The hire-date range is invalid.');
        END IF;

        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            OPEN p_cursor FOR
                SELECT employee.EMP_ID,
                       employee.EMP_NUMBER,
                       employee.FIRST_NAME,
                       employee.LAST_NAME,
                       employee.HIRE_DATE,
                       employee.DEPT_ID,
                       employee.DEPT_NAME,
                       employee.JOB_TITLE,
                       employee.EMPLOYMENT_STATUS,
                       employee.LOCATION_CODE
                  FROM HRMS.VW_APP_EMPLOYEE_ORGANIZATION employee
                 WHERE (p_last_name IS NULL
                         OR UPPER(employee.LAST_NAME) LIKE '%' || UPPER(TRIM(p_last_name)) || '%')
                   AND (p_first_name IS NULL
                         OR UPPER(employee.FIRST_NAME) LIKE '%' || UPPER(TRIM(p_first_name)) || '%')
                   AND (p_dept_id IS NULL OR employee.DEPT_ID = p_dept_id)
                   AND (p_status IS NULL OR employee.EMPLOYMENT_STATUS = UPPER(TRIM(p_status)))
                   AND (p_location_code IS NULL
                        OR employee.LOCATION_CODE = UPPER(TRIM(p_location_code)))
                   AND (p_hire_date_from IS NULL OR employee.HIRE_DATE >= p_hire_date_from)
                   AND (p_hire_date_to IS NULL OR employee.HIRE_DATE < p_hire_date_to + 1)
                 ORDER BY employee.FULL_NAME;
        ELSE
            OPEN p_cursor FOR
                SELECT employee.EMP_ID,
                       employee.EMP_NUMBER,
                       employee.FIRST_NAME,
                       employee.LAST_NAME,
                       employee.HIRE_DATE,
                       employee.DEPT_ID,
                       department.DEPT_NAME,
                       job_title.JOB_TITLE,
                       employee.EMPLOYMENT_STATUS,
                       employee.LOCATION_CODE
                  FROM HRMS.EMPLOYEES employee
                  JOIN HRMS.DEPARTMENTS department
                    ON department.DEPT_ID = employee.DEPT_ID
                  JOIN HRMS.JOB_TITLES job_title
                    ON job_title.JOB_ID = employee.JOB_ID
                 WHERE (p_last_name IS NULL
                        OR UPPER(employee.LAST_NAME) LIKE '%' || UPPER(TRIM(p_last_name)) || '%')
                   AND (p_first_name IS NULL
                        OR UPPER(employee.FIRST_NAME) LIKE '%' || UPPER(TRIM(p_first_name)) || '%')
                   AND (p_dept_id IS NULL OR employee.DEPT_ID = p_dept_id)
                   AND (p_status IS NULL OR employee.EMPLOYMENT_STATUS = UPPER(TRIM(p_status)))
                   AND (p_location_code IS NULL
                        OR employee.LOCATION_CODE = UPPER(TRIM(p_location_code)))
                   AND (p_hire_date_from IS NULL OR employee.HIRE_DATE >= p_hire_date_from)
                   AND (p_hire_date_to IS NULL OR employee.HIRE_DATE < p_hire_date_to + 1)
                 ORDER BY employee.LAST_NAME, employee.FIRST_NAME;
        END IF;
    END search_employees;

    -- -----------------------------------------------------------------------
    -- transfer_employee
    -- -----------------------------------------------------------------------
    PROCEDURE transfer_employee(
        p_emp_id          IN NUMBER,
        p_new_dept_id     IN NUMBER,
        p_new_job_id      IN NUMBER DEFAULT NULL,
        p_new_manager_id  IN NUMBER DEFAULT NULL,
        p_new_location    IN VARCHAR2 DEFAULT NULL,
        p_effective_date  IN DATE DEFAULT SYSDATE,
        p_reason_code     IN VARCHAR2 DEFAULT NULL,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_old_rec EMPLOYEES%ROWTYPE;
        v_new_job_id NUMBER;
        v_new_location VARCHAR2(10);
        v_new_manager_id NUMBER;
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT employee_transfer_start;
        assert_authorized(p_emp_id, 'EMPLOYEE', 'UPDATE');
        v_actor := resolve_actor(p_user);

        -- Get current record
        SELECT *
          INTO v_old_rec
          FROM HRMS.EMPLOYEES employee
         WHERE employee.EMP_ID = p_emp_id
           FOR UPDATE NOWAIT;

        IF v_old_rec.EMPLOYMENT_STATUS != 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(-20012,
                'Cannot transfer non-active employee. Status: ' || v_old_rec.EMPLOYMENT_STATUS);
        END IF;

        -- Validate new department
        validate_dept(p_new_dept_id);
        IF p_effective_date IS NULL OR p_effective_date < v_old_rec.HIRE_DATE THEN
            RAISE_APPLICATION_ERROR(-20012, 'The transfer effective date is invalid.');
        END IF;

        -- Default job and location
        v_new_job_id := NVL(p_new_job_id, v_old_rec.JOB_ID);
        v_new_location := NVL(p_new_location, v_old_rec.LOCATION_CODE);
        v_new_manager_id := NVL(p_new_manager_id, v_old_rec.MANAGER_EMP_ID);

        IF NOT PKG_VALIDATION.validate_job(v_new_job_id)
           OR NOT PKG_VALIDATION.validate_location(v_new_location)
        THEN
            RAISE_APPLICATION_ERROR(-20011, 'The selected job or location is inactive.');
        END IF;
        validate_manager(v_new_manager_id, p_emp_id);

        -- Update employee
        UPDATE EMPLOYEES SET
            DEPT_ID        = p_new_dept_id,
            JOB_ID         = v_new_job_id,
            MANAGER_EMP_ID = NVL(p_new_manager_id, MANAGER_EMP_ID),
            LOCATION_CODE  = v_new_location,
            MODIFIED_BY    = v_actor,
            MODIFIED_DATE  = SYSDATE
        WHERE EMP_ID = p_emp_id;

        -- Log history
        log_history(
            p_emp_id         => p_emp_id,
            p_change_type    => 'TRANSFER',
            p_effective_date => p_effective_date,
            p_old_dept_id    => v_old_rec.DEPT_ID,
            p_new_dept_id    => p_new_dept_id,
            p_old_job_id     => v_old_rec.JOB_ID,
            p_new_job_id     => v_new_job_id,
            p_old_manager    => v_old_rec.MANAGER_EMP_ID,
            p_new_manager    => v_new_manager_id,
            p_old_location   => v_old_rec.LOCATION_CODE,
            p_new_location   => v_new_location,
            p_reason_code    => p_reason_code,
            p_comments       => p_comments,
            p_user           => v_actor
        );

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', v_actor);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO employee_transfer_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.TRANSFER',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END transfer_employee;

    -- -----------------------------------------------------------------------
    -- promote_employee
    -- -----------------------------------------------------------------------
    PROCEDURE promote_employee(
        p_emp_id          IN NUMBER,
        p_new_job_id      IN NUMBER,
        p_new_salary      IN NUMBER,
        p_effective_date  IN DATE DEFAULT SYSDATE,
        p_comments        IN VARCHAR2 DEFAULT NULL,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_employee_status VARCHAR2(20);
        v_hire_date DATE;
        v_old_job_id NUMBER;
        v_old_salary NUMBER;
        v_grade_id NUMBER;
        v_validation_error VARCHAR2(4000);
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT employee_promote_start;
        assert_authorized(p_emp_id, 'EMPLOYEE', 'UPDATE');
        v_actor := resolve_actor(p_user);

        SELECT employee.JOB_ID,
               employee.HIRE_DATE,
               employee.EMPLOYMENT_STATUS
          INTO v_old_job_id,
               v_hire_date,
               v_employee_status
          FROM HRMS.EMPLOYEES employee
         WHERE employee.EMP_ID = p_emp_id
           FOR UPDATE;

        IF v_employee_status != 'ACTIVE'
           OR p_effective_date IS NULL
           OR p_effective_date < v_hire_date
           OR p_new_salary IS NULL
           OR p_new_salary <= 0
           OR NOT PKG_VALIDATION.validate_job(p_new_job_id)
        THEN
            RAISE_APPLICATION_ERROR(-20011, 'The promotion details are invalid.');
        END IF;

        SELECT job_title.GRADE_ID
          INTO v_grade_id
          FROM HRMS.JOB_TITLES job_title
         WHERE job_title.JOB_ID = p_new_job_id;

        v_validation_error := PKG_VALIDATION.validate_salary_for_grade(
            p_salary   => p_new_salary,
            p_grade_id => v_grade_id
        );
        IF v_validation_error IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20013, v_validation_error);
        END IF;

        -- Get current salary
        SELECT NVL(
                   MAX(salary_record.BASE_SALARY)
                       KEEP (DENSE_RANK LAST ORDER BY salary_record.EFFECTIVE_DATE),
                   0
               )
          INTO v_old_salary
          FROM HRMS.SALARY_RECORDS salary_record
         WHERE salary_record.EMP_ID = p_emp_id
           AND salary_record.ACTIVE_FLAG = 'Y'
           AND salary_record.EFFECTIVE_DATE <= p_effective_date
           AND (salary_record.END_DATE IS NULL
                OR salary_record.END_DATE > p_effective_date);

        -- Update job
        UPDATE EMPLOYEES SET
            JOB_ID        = p_new_job_id,
            MODIFIED_BY   = v_actor,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id;

        -- Create new salary record
        PKG_PAYROLL.create_salary_record(
            p_emp_id         => p_emp_id,
            p_effective_date => p_effective_date,
            p_base_salary    => p_new_salary,
            p_change_reason  => 'PROMOTION',
            p_change_pct     => CASE WHEN v_old_salary > 0
                                     THEN ROUND(((p_new_salary - v_old_salary) / v_old_salary) * 100, 2)
                                     ELSE NULL END,
            p_user           => v_actor
        );

        -- Log history
        log_history(
            p_emp_id         => p_emp_id,
            p_change_type    => 'PROMOTION',
            p_effective_date => p_effective_date,
            p_old_job_id     => v_old_job_id,
            p_new_job_id     => p_new_job_id,
            p_old_salary     => v_old_salary,
            p_new_salary     => p_new_salary,
            p_comments       => p_comments,
            p_user           => v_actor
        );

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', v_actor);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO employee_promote_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.PROMOTE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END promote_employee;

    -- -----------------------------------------------------------------------
    -- terminate_employee
    -- -----------------------------------------------------------------------
    PROCEDURE terminate_employee(
        p_emp_id           IN NUMBER,
        p_termination_date IN DATE,
        p_reason           IN VARCHAR2,
        p_comments         IN VARCHAR2 DEFAULT NULL,
        p_user             IN VARCHAR2 DEFAULT USER
    ) IS
        v_emp EMPLOYEES%ROWTYPE;
        v_pending_leave NUMBER;
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT employee_terminate_start;
        assert_authorized(p_emp_id, 'EMPLOYEE', 'TERMINATE');
        v_actor := resolve_actor(p_user);

        SELECT *
          INTO v_emp
          FROM HRMS.EMPLOYEES employee
         WHERE employee.EMP_ID = p_emp_id
           FOR UPDATE;

        IF v_emp.EMPLOYMENT_STATUS = 'TERMINATED'
           OR p_reason IS NULL
           OR TRIM(p_reason) IS NULL
           OR NOT PKG_VALIDATION.validate_employee_dates(
               v_emp.HIRE_DATE,
               p_termination_date,
               'TERMINATED'
           )
        THEN
            RAISE_APPLICATION_ERROR(-20005, 'The termination details are invalid.');
        END IF;

        -- Check for pending leave requests
        SELECT COUNT(*) INTO v_pending_leave
        FROM LEAVE_REQUESTS
        WHERE EMP_ID = p_emp_id
        AND STATUS = 'PENDING';

        IF v_pending_leave > 0 THEN
            -- Auto-cancel pending leave requests
            UPDATE LEAVE_REQUESTS
            SET STATUS = 'CANCELLED',
                CANCEL_REASON = 'Auto-cancelled due to termination',
                CANCELLED_DATE = SYSDATE,
                MODIFIED_BY = v_actor,
                MODIFIED_DATE = SYSDATE
            WHERE EMP_ID = p_emp_id
            AND STATUS = 'PENDING';
        END IF;

        -- Update employee status
        UPDATE EMPLOYEES SET
            EMPLOYMENT_STATUS  = 'TERMINATED',
            TERMINATION_DATE   = p_termination_date,
            TERMINATION_REASON = p_reason,
            ACTIVE_FLAG        = 'N',
            MODIFIED_BY        = v_actor,
            MODIFIED_DATE      = SYSDATE
        WHERE EMP_ID = p_emp_id;

        -- End current salary record
        UPDATE SALARY_RECORDS
        SET END_DATE = p_termination_date,
            ACTIVE_FLAG = 'N',
            MODIFIED_BY = v_actor,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND ACTIVE_FLAG = 'Y';

        -- Deactivate pay elements
        UPDATE EMPLOYEE_PAY_ELEMENTS
        SET END_DATE = p_termination_date,
            ACTIVE_FLAG = 'N',
            MODIFIED_BY = v_actor,
            MODIFIED_DATE = SYSDATE
        WHERE EMP_ID = p_emp_id
        AND ACTIVE_FLAG = 'Y';

        -- Log history
        log_history(
            p_emp_id         => p_emp_id,
            p_change_type    => 'TERMINATION',
            p_effective_date => p_termination_date,
            p_reason_code    => p_reason,
            p_comments       => p_comments,
            p_user           => v_actor
        );

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', v_actor);

        -- Send notifications
        IF v_emp.MANAGER_EMP_ID IS NOT NULL THEN
            PKG_NOTIFICATION.send_notification(
                p_recipient_emp_id => v_emp.MANAGER_EMP_ID,
                p_type             => 'EMAIL',
                p_subject          => 'Employee Termination: ' || v_emp.FIRST_NAME || ' ' || v_emp.LAST_NAME,
                p_body             => v_emp.FIRST_NAME || ' ' || v_emp.LAST_NAME ||
                                      ' termination effective ' || TO_CHAR(p_termination_date, 'MM/DD/YYYY'),
                p_user             => v_actor
            );
        END IF;

        -- TODO: Integrate with benefits system to trigger COBRA
        -- TODO: Revoke system access via PKG_SECURITY
        -- TODO: Calculate final pay via PKG_PAYROLL.calculate_final_pay

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO employee_terminate_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.TERMINATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END terminate_employee;

    -- -----------------------------------------------------------------------
    -- rehire_employee
    -- -----------------------------------------------------------------------
    PROCEDURE rehire_employee(
        p_emp_id          IN NUMBER,
        p_rehire_date     IN DATE,
        p_dept_id         IN NUMBER,
        p_job_id          IN NUMBER,
        p_base_salary     IN NUMBER,
        p_user            IN VARCHAR2 DEFAULT USER
    ) IS
        v_current_status VARCHAR2(20);
        v_termination_date DATE;
        v_manager_emp_id NUMBER;
        v_grade_id NUMBER;
        v_validation_error VARCHAR2(4000);
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT employee_rehire_start;
        assert_authorized(p_emp_id, 'EMPLOYEE', 'UPDATE');
        v_actor := resolve_actor(p_user);

        SELECT employee.EMPLOYMENT_STATUS,
               employee.TERMINATION_DATE,
               employee.MANAGER_EMP_ID
          INTO v_current_status,
               v_termination_date,
               v_manager_emp_id
          FROM HRMS.EMPLOYEES employee
         WHERE employee.EMP_ID = p_emp_id
           FOR UPDATE;

        IF v_current_status != 'TERMINATED'
           OR v_termination_date IS NULL
           OR p_rehire_date <= v_termination_date
           OR NOT PKG_VALIDATION.validate_employee_dates(
               p_rehire_date,
               NULL,
               'ACTIVE'
           )
           OR p_base_salary IS NULL
           OR p_base_salary <= 0
           OR NOT PKG_VALIDATION.validate_job(p_job_id)
        THEN
            RAISE_APPLICATION_ERROR(-20005, 'The rehire details are invalid.');
        END IF;

        validate_dept(p_dept_id);
        validate_manager(v_manager_emp_id, p_emp_id);
        SELECT job_title.GRADE_ID
          INTO v_grade_id
          FROM HRMS.JOB_TITLES job_title
         WHERE job_title.JOB_ID = p_job_id;

        v_validation_error := PKG_VALIDATION.validate_salary_for_grade(
            p_salary   => p_base_salary,
            p_grade_id => v_grade_id
        );
        IF v_validation_error IS NOT NULL THEN
            RAISE_APPLICATION_ERROR(-20013, v_validation_error);
        END IF;

        UPDATE EMPLOYEES SET
            EMPLOYMENT_STATUS  = 'ACTIVE',
            HIRE_DATE          = p_rehire_date,
            TERMINATION_DATE   = NULL,
            TERMINATION_REASON = NULL,
            DEPT_ID            = p_dept_id,
            JOB_ID             = p_job_id,
            ACTIVE_FLAG        = 'Y',
            MODIFIED_BY        = v_actor,
            MODIFIED_DATE      = SYSDATE
        WHERE EMP_ID = p_emp_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Employee not found for rehire: ' || p_emp_id);
        END IF;

        -- Create new salary record
        PKG_PAYROLL.create_salary_record(
            p_emp_id         => p_emp_id,
            p_effective_date => p_rehire_date,
            p_base_salary    => p_base_salary,
            p_change_reason  => 'REHIRE',
            p_user           => v_actor
        );

        log_history(p_emp_id, 'REHIRE', p_rehire_date,
            p_new_dept_id => p_dept_id,
            p_new_job_id  => p_job_id,
            p_new_salary  => p_base_salary,
            p_user        => v_actor);

        PKG_AUDIT.log_action('EMPLOYEES', p_emp_id, 'UPDATE', v_actor);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO employee_rehire_start;
            HRMS.PKG_APP_ERRORS.handle_error(
                'EMPLOYEE.REHIRE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END rehire_employee;

    -- -----------------------------------------------------------------------
    -- get_direct_reports
    -- -----------------------------------------------------------------------
    FUNCTION get_direct_reports(
        p_manager_emp_id IN NUMBER
    ) RETURN t_emp_id_table IS
        v_result t_emp_id_table;
        v_idx    BINARY_INTEGER := 0;
    BEGIN
        FOR r IN (
            SELECT EMP_ID
            FROM EMPLOYEES
            WHERE MANAGER_EMP_ID = p_manager_emp_id
            AND EMPLOYMENT_STATUS = 'ACTIVE'
            ORDER BY LAST_NAME, FIRST_NAME
        ) LOOP
            v_idx := v_idx + 1;
            v_result(v_idx) := r.EMP_ID;
        END LOOP;

        RETURN v_result;
    END get_direct_reports;

    -- -----------------------------------------------------------------------
    -- get_org_chart
    -- Recursive query - known to time out for orgs with >500 employees
    -- -----------------------------------------------------------------------
    FUNCTION get_org_chart(
        p_root_emp_id IN NUMBER,
        p_max_depth   IN NUMBER DEFAULT 10
    ) RETURN t_emp_cursor IS
        v_cursor t_emp_cursor;
    BEGIN
        OPEN v_cursor FOR
            SELECT LEVEL AS depth,
                   EMP_ID, EMP_NUMBER, FIRST_NAME, LAST_NAME,
                   DEPT_ID, JOB_ID, MANAGER_EMP_ID
            FROM EMPLOYEES
            WHERE EMPLOYMENT_STATUS = 'ACTIVE'
            START WITH EMP_ID = p_root_emp_id
            CONNECT BY PRIOR EMP_ID = MANAGER_EMP_ID
            AND LEVEL <= p_max_depth
            ORDER SIBLINGS BY LAST_NAME, FIRST_NAME;

        RETURN v_cursor;
    END get_org_chart;

    -- -----------------------------------------------------------------------
    -- get_headcount_by_dept
    -- -----------------------------------------------------------------------
    FUNCTION get_headcount_by_dept(
        p_dept_id    IN NUMBER DEFAULT NULL,
        p_as_of_date IN DATE DEFAULT SYSDATE
    ) RETURN NUMBER IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM EMPLOYEES
        WHERE (p_dept_id IS NULL OR DEPT_ID = p_dept_id)
        AND EMPLOYMENT_STATUS = 'ACTIVE'
        AND HIRE_DATE <= p_as_of_date
        AND (TERMINATION_DATE IS NULL OR TERMINATION_DATE > p_as_of_date);

        RETURN v_count;
    END get_headcount_by_dept;

    -- -----------------------------------------------------------------------
    -- get_tenure_years
    -- -----------------------------------------------------------------------
    FUNCTION get_tenure_years(
        p_emp_id IN NUMBER
    ) RETURN NUMBER IS
        v_hire_date DATE;
        v_end_date  DATE;
    BEGIN
        SELECT HIRE_DATE, NVL(TERMINATION_DATE, SYSDATE)
        INTO v_hire_date, v_end_date
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        RETURN ROUND(MONTHS_BETWEEN(v_end_date, v_hire_date) / 12, 1);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_tenure_years;

    -- -----------------------------------------------------------------------
    -- is_active
    -- -----------------------------------------------------------------------
    FUNCTION is_active(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT EMPLOYMENT_STATUS
        INTO v_status
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        RETURN v_status = 'ACTIVE';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END is_active;

    -- -----------------------------------------------------------------------
    -- validate_employee
    -- -----------------------------------------------------------------------
    FUNCTION validate_employee(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_emp EMPLOYEES%ROWTYPE;
    BEGIN
        SELECT * INTO v_emp FROM EMPLOYEES WHERE EMP_ID = p_emp_id;

        -- Basic validations
        IF v_emp.FIRST_NAME IS NULL OR v_emp.LAST_NAME IS NULL THEN
            RETURN FALSE;
        END IF;

        IF v_emp.HIRE_DATE IS NULL THEN
            RETURN FALSE;
        END IF;

        IF v_emp.EMPLOYMENT_STATUS = 'ACTIVE' AND v_emp.ACTIVE_FLAG != 'Y' THEN
            RETURN FALSE;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END validate_employee;

    -- -----------------------------------------------------------------------
    -- emp_exists
    -- -----------------------------------------------------------------------
    FUNCTION emp_exists(
        p_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

        RETURN v_count > 0;
    END emp_exists;

    -- -----------------------------------------------------------------------
    -- set_session_context
    -- -----------------------------------------------------------------------
    PROCEDURE set_session_context(
        p_user    IN VARCHAR2,
        p_emp_id  IN NUMBER
    ) IS
    BEGIN
        g_current_user := p_user;
        g_current_emp_id := p_emp_id;

        SELECT DEPT_ID INTO g_current_dept_id
        FROM EMPLOYEES
        WHERE EMP_ID = p_emp_id;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            g_current_dept_id := NULL;
    END set_session_context;

END PKG_EMPLOYEE;
/
