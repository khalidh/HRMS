CREATE OR REPLACE PACKAGE BODY HRMS.PKG_ORGANIZATION AS

    FUNCTION resolve_actor RETURN VARCHAR2 IS
    BEGIN
        IF NOT APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            RAISE_APPLICATION_ERROR(-20091, 'An authenticated APEX session is required.');
        END IF;

        RETURN HRMS.PKG_APP_CONTEXT.get_apex_username;
    END resolve_actor;

    PROCEDURE assert_update_permission IS
        v_actor VARCHAR2(255);
    BEGIN
        v_actor := resolve_actor;
        IF NOT HRMS.PKG_SECURITY.has_permission(NULL, 'ORGANIZATION', 'UPDATE') THEN
            RAISE_APPLICATION_ERROR(-20304, 'Organization updates are not authorized.');
        END IF;
    END assert_update_permission;

    PROCEDURE assert_active_flag(p_active_flag IN VARCHAR2) IS
    BEGIN
        IF p_active_flag IS NULL OR UPPER(TRIM(p_active_flag)) NOT IN ('Y', 'N') THEN
            RAISE_APPLICATION_ERROR(-20020, 'The active flag must be Y or N.');
        END IF;
    END assert_active_flag;

    PROCEDURE assert_department_data(
        p_dept_id        IN NUMBER,
        p_dept_code      IN VARCHAR2,
        p_dept_name      IN VARCHAR2,
        p_parent_dept_id IN NUMBER,
        p_manager_emp_id IN NUMBER,
        p_location_code  IN VARCHAR2
    ) IS
        v_count PLS_INTEGER;
    BEGIN
        IF p_dept_code IS NULL
           OR NOT REGEXP_LIKE(UPPER(TRIM(p_dept_code)), '^[A-Z0-9_-]{1,20}$')
           OR TRIM(p_dept_name) IS NULL
        THEN
            RAISE_APPLICATION_ERROR(-20020, 'Department code and name are required and must be valid.');
        END IF;

        IF p_dept_id IS NOT NULL AND p_dept_id = p_parent_dept_id THEN
            RAISE_APPLICATION_ERROR(-20020, 'A department cannot be its own parent.');
        END IF;

        IF p_parent_dept_id IS NOT NULL THEN
            SELECT COUNT(*)
              INTO v_count
              FROM HRMS.DEPARTMENTS department
             WHERE department.DEPT_ID = p_parent_dept_id
               AND department.ACTIVE_FLAG = 'Y';

            IF v_count != 1 THEN
                RAISE_APPLICATION_ERROR(-20020, 'The parent department must be active.');
            END IF;

            IF p_dept_id IS NOT NULL THEN
                SELECT COUNT(*)
                  INTO v_count
                  FROM (
                        SELECT department.DEPT_ID
                          FROM HRMS.DEPARTMENTS department
                         START WITH department.DEPT_ID = p_parent_dept_id
                       CONNECT BY NOCYCLE PRIOR department.DEPT_ID = department.PARENT_DEPT_ID
                       )
                 WHERE DEPT_ID = p_dept_id;

                IF v_count > 0 THEN
                    RAISE_APPLICATION_ERROR(-20020, 'The department change would create a hierarchy cycle.');
                END IF;
            END IF;
        END IF;

        IF p_manager_emp_id IS NOT NULL
           AND NOT HRMS.PKG_VALIDATION.validate_manager(p_manager_emp_id)
        THEN
            RAISE_APPLICATION_ERROR(-20020, 'The department manager must be an active employee.');
        END IF;

        IF NOT HRMS.PKG_VALIDATION.validate_location(p_location_code) THEN
            RAISE_APPLICATION_ERROR(-20020, 'The department location must be active.');
        END IF;
    END assert_department_data;

    PROCEDURE assert_location_data(
        p_location_code IN VARCHAR2,
        p_location_name IN VARCHAR2,
        p_country_code  IN VARCHAR2
    ) IS
    BEGIN
        IF p_location_code IS NULL
           OR NOT REGEXP_LIKE(UPPER(TRIM(p_location_code)), '^[A-Z0-9_-]{1,10}$')
           OR TRIM(p_location_name) IS NULL
           OR (p_country_code IS NOT NULL
               AND NOT REGEXP_LIKE(UPPER(TRIM(p_country_code)), '^[A-Z]{2,3}$'))
        THEN
            RAISE_APPLICATION_ERROR(-20020, 'Location code, name, or country code is invalid.');
        END IF;
    END assert_location_data;

    PROCEDURE assert_grade_data(
        p_grade_code IN VARCHAR2,
        p_grade_name IN VARCHAR2,
        p_min_salary IN NUMBER,
        p_max_salary IN NUMBER
    ) IS
    BEGIN
        IF p_grade_code IS NULL
           OR NOT REGEXP_LIKE(UPPER(TRIM(p_grade_code)), '^[A-Z0-9_-]{1,10}$')
           OR TRIM(p_grade_name) IS NULL
           OR p_min_salary IS NULL
           OR p_max_salary IS NULL
           OR p_min_salary < 0
           OR p_max_salary < p_min_salary
        THEN
            RAISE_APPLICATION_ERROR(-20020, 'Job-grade code, name, or salary range is invalid.');
        END IF;
    END assert_grade_data;

    PROCEDURE assert_job_data(
        p_job_code  IN VARCHAR2,
        p_job_title IN VARCHAR2,
        p_grade_id  IN NUMBER
    ) IS
        v_count PLS_INTEGER;
    BEGIN
        IF p_job_code IS NULL
           OR NOT REGEXP_LIKE(UPPER(TRIM(p_job_code)), '^[A-Z0-9_-]{1,20}$')
           OR TRIM(p_job_title) IS NULL
        THEN
            RAISE_APPLICATION_ERROR(-20020, 'Job code and title are required and must be valid.');
        END IF;

        SELECT COUNT(*)
          INTO v_count
          FROM HRMS.JOB_GRADES grade
         WHERE grade.GRADE_ID = p_grade_id
           AND grade.ACTIVE_FLAG = 'Y';

        IF v_count != 1 THEN
            RAISE_APPLICATION_ERROR(-20020, 'The job grade must be active.');
        END IF;
    END assert_job_data;

    PROCEDURE log_reference_change(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_action     IN VARCHAR2,
        p_actor      IN VARCHAR2,
        p_key_value  IN VARCHAR2
    ) IS
        v_payload CLOB;
    BEGIN
        SELECT JSON_OBJECT(
                   'key' VALUE p_key_value
                   RETURNING CLOB
               )
          INTO v_payload
          FROM DUAL;

        HRMS.PKG_AUDIT.log_action(
            p_table_name => p_table_name,
            p_record_id  => p_record_id,
            p_action     => p_action,
            p_user       => p_actor,
            p_new_values => v_payload
        );
    END log_reference_change;

    FUNCTION create_department(
        p_dept_code       IN VARCHAR2,
        p_dept_name       IN VARCHAR2,
        p_parent_dept_id  IN NUMBER DEFAULT NULL,
        p_cost_center     IN VARCHAR2 DEFAULT NULL,
        p_manager_emp_id  IN NUMBER DEFAULT NULL,
        p_location_code   IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER IS
        v_dept_id NUMBER;
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_create_department;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_department_data(
            NULL,
            p_dept_code,
            p_dept_name,
            p_parent_dept_id,
            p_manager_emp_id,
            p_location_code
        );

        SELECT HRMS.SEQ_DEPARTMENT.NEXTVAL INTO v_dept_id FROM DUAL;
        INSERT INTO HRMS.DEPARTMENTS (
            DEPT_ID, DEPT_CODE, DEPT_NAME, PARENT_DEPT_ID, COST_CENTER,
            MANAGER_EMP_ID, LOCATION_CODE, ACTIVE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            v_dept_id, UPPER(TRIM(p_dept_code)), TRIM(p_dept_name),
            p_parent_dept_id, TRIM(p_cost_center), p_manager_emp_id,
            UPPER(TRIM(p_location_code)), 'Y', v_actor, SYSDATE
        );

        RETURN v_dept_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_create_department;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.DEPARTMENT.CREATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END create_department;

    PROCEDURE update_department(
        p_dept_id         IN NUMBER,
        p_dept_code       IN VARCHAR2,
        p_dept_name       IN VARCHAR2,
        p_parent_dept_id  IN NUMBER,
        p_cost_center     IN VARCHAR2,
        p_manager_emp_id  IN NUMBER,
        p_location_code   IN VARCHAR2,
        p_active_flag     IN VARCHAR2
    ) IS
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_update_department;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_active_flag(p_active_flag);
        assert_department_data(
            p_dept_id,
            p_dept_code,
            p_dept_name,
            p_parent_dept_id,
            p_manager_emp_id,
            p_location_code
        );

        UPDATE HRMS.DEPARTMENTS department
           SET department.DEPT_CODE = UPPER(TRIM(p_dept_code)),
               department.DEPT_NAME = TRIM(p_dept_name),
               department.PARENT_DEPT_ID = p_parent_dept_id,
               department.COST_CENTER = TRIM(p_cost_center),
               department.MANAGER_EMP_ID = p_manager_emp_id,
               department.LOCATION_CODE = UPPER(TRIM(p_location_code)),
               department.ACTIVE_FLAG = UPPER(TRIM(p_active_flag)),
               department.MODIFIED_BY = v_actor,
               department.MODIFIED_DATE = SYSDATE
         WHERE department.DEPT_ID = p_dept_id;

        IF SQL%ROWCOUNT != 1 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Department does not exist.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_update_department;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.DEPARTMENT.UPDATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END update_department;

    PROCEDURE create_location(
        p_location_code   IN VARCHAR2,
        p_location_name   IN VARCHAR2,
        p_city            IN VARCHAR2,
        p_state_province  IN VARCHAR2,
        p_country_code    IN VARCHAR2
    ) IS
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_create_location;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_location_data(p_location_code, p_location_name, p_country_code);

        INSERT INTO HRMS.LOCATIONS (
            LOCATION_CODE, LOCATION_NAME, CITY, STATE_PROVINCE, COUNTRY_CODE,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            UPPER(TRIM(p_location_code)), TRIM(p_location_name), TRIM(p_city),
            TRIM(p_state_province), UPPER(TRIM(p_country_code)), 'Y', v_actor, SYSDATE
        );

        log_reference_change(
            'LOCATIONS',
            0,
            'INSERT',
            v_actor,
            UPPER(TRIM(p_location_code))
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_create_location;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.LOCATION.CREATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END create_location;

    PROCEDURE update_location(
        p_location_code   IN VARCHAR2,
        p_location_name   IN VARCHAR2,
        p_city            IN VARCHAR2,
        p_state_province  IN VARCHAR2,
        p_country_code    IN VARCHAR2,
        p_active_flag     IN VARCHAR2
    ) IS
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_update_location;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_active_flag(p_active_flag);
        assert_location_data(p_location_code, p_location_name, p_country_code);

        UPDATE HRMS.LOCATIONS location
           SET location.LOCATION_NAME = TRIM(p_location_name),
               location.CITY = TRIM(p_city),
               location.STATE_PROVINCE = TRIM(p_state_province),
               location.COUNTRY_CODE = UPPER(TRIM(p_country_code)),
               location.ACTIVE_FLAG = UPPER(TRIM(p_active_flag)),
               location.MODIFIED_BY = v_actor,
               location.MODIFIED_DATE = SYSDATE
         WHERE location.LOCATION_CODE = UPPER(TRIM(p_location_code));

        IF SQL%ROWCOUNT != 1 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Location does not exist.');
        END IF;

        log_reference_change(
            'LOCATIONS',
            0,
            'UPDATE',
            v_actor,
            UPPER(TRIM(p_location_code))
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_update_location;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.LOCATION.UPDATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END update_location;

    FUNCTION create_job_grade(
        p_grade_code IN VARCHAR2,
        p_grade_name IN VARCHAR2,
        p_min_salary IN NUMBER,
        p_max_salary IN NUMBER
    ) RETURN NUMBER IS
        v_grade_id NUMBER;
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_create_job_grade;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_grade_data(p_grade_code, p_grade_name, p_min_salary, p_max_salary);

        SELECT HRMS.SEQ_JOB_GRADE.NEXTVAL INTO v_grade_id FROM DUAL;
        INSERT INTO HRMS.JOB_GRADES (
            GRADE_ID, GRADE_CODE, GRADE_NAME, MIN_SALARY, MAX_SALARY,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            v_grade_id, UPPER(TRIM(p_grade_code)), TRIM(p_grade_name),
            p_min_salary, p_max_salary, 'Y', v_actor, SYSDATE
        );

        log_reference_change(
            'JOB_GRADES', v_grade_id, 'INSERT', v_actor, UPPER(TRIM(p_grade_code))
        );
        RETURN v_grade_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_create_job_grade;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.GRADE.CREATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END create_job_grade;

    PROCEDURE update_job_grade(
        p_grade_id    IN NUMBER,
        p_grade_code  IN VARCHAR2,
        p_grade_name  IN VARCHAR2,
        p_min_salary  IN NUMBER,
        p_max_salary  IN NUMBER,
        p_active_flag IN VARCHAR2
    ) IS
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_update_job_grade;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_active_flag(p_active_flag);
        assert_grade_data(p_grade_code, p_grade_name, p_min_salary, p_max_salary);

        UPDATE HRMS.JOB_GRADES grade
           SET grade.GRADE_CODE = UPPER(TRIM(p_grade_code)),
               grade.GRADE_NAME = TRIM(p_grade_name),
               grade.MIN_SALARY = p_min_salary,
               grade.MAX_SALARY = p_max_salary,
               grade.ACTIVE_FLAG = UPPER(TRIM(p_active_flag)),
               grade.MODIFIED_BY = v_actor,
               grade.MODIFIED_DATE = SYSDATE
         WHERE grade.GRADE_ID = p_grade_id;

        IF SQL%ROWCOUNT != 1 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Job grade does not exist.');
        END IF;

        log_reference_change(
            'JOB_GRADES', p_grade_id, 'UPDATE', v_actor, UPPER(TRIM(p_grade_code))
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_update_job_grade;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.GRADE.UPDATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END update_job_grade;

    FUNCTION create_job_title(
        p_job_code   IN VARCHAR2,
        p_job_title  IN VARCHAR2,
        p_job_family IN VARCHAR2,
        p_grade_id   IN NUMBER
    ) RETURN NUMBER IS
        v_job_id NUMBER;
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_create_job_title;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_job_data(p_job_code, p_job_title, p_grade_id);

        SELECT HRMS.SEQ_JOB_TITLE.NEXTVAL INTO v_job_id FROM DUAL;
        INSERT INTO HRMS.JOB_TITLES (
            JOB_ID, JOB_CODE, JOB_TITLE, JOB_FAMILY, GRADE_ID,
            ACTIVE_FLAG, CREATED_BY, CREATED_DATE
        ) VALUES (
            v_job_id, UPPER(TRIM(p_job_code)), TRIM(p_job_title), TRIM(p_job_family),
            p_grade_id, 'Y', v_actor, SYSDATE
        );

        log_reference_change(
            'JOB_TITLES', v_job_id, 'INSERT', v_actor, UPPER(TRIM(p_job_code))
        );
        RETURN v_job_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_create_job_title;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.JOB.CREATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END create_job_title;

    PROCEDURE update_job_title(
        p_job_id       IN NUMBER,
        p_job_code     IN VARCHAR2,
        p_job_title    IN VARCHAR2,
        p_job_family   IN VARCHAR2,
        p_grade_id     IN NUMBER,
        p_active_flag  IN VARCHAR2
    ) IS
        v_actor VARCHAR2(255);
    BEGIN
        SAVEPOINT org_update_job_title;
        assert_update_permission;
        v_actor := resolve_actor;
        assert_active_flag(p_active_flag);
        assert_job_data(p_job_code, p_job_title, p_grade_id);

        UPDATE HRMS.JOB_TITLES job_title
           SET job_title.JOB_CODE = UPPER(TRIM(p_job_code)),
               job_title.JOB_TITLE = TRIM(p_job_title),
               job_title.JOB_FAMILY = TRIM(p_job_family),
               job_title.GRADE_ID = p_grade_id,
               job_title.ACTIVE_FLAG = UPPER(TRIM(p_active_flag)),
               job_title.MODIFIED_BY = v_actor,
               job_title.MODIFIED_DATE = SYSDATE
         WHERE job_title.JOB_ID = p_job_id;

        IF SQL%ROWCOUNT != 1 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Job title does not exist.');
        END IF;

        log_reference_change(
            'JOB_TITLES', p_job_id, 'UPDATE', v_actor, UPPER(TRIM(p_job_code))
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO org_update_job_title;
            HRMS.PKG_APP_ERRORS.handle_error(
                'ORGANIZATION.JOB.UPDATE',
                SQLCODE,
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
    END update_job_title;

END PKG_ORGANIZATION;
/
