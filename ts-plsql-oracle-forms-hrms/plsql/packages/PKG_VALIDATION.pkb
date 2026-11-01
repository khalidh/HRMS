CREATE OR REPLACE PACKAGE BODY HRMS.PKG_VALIDATION AS
-- ============================================================================
-- PKG_VALIDATION - Centralized Validation Package Body
-- ============================================================================

    FUNCTION validate_date_range(
        p_start_date IN DATE,
        p_end_date   IN DATE
    ) RETURN BOOLEAN IS
    BEGIN
        IF p_start_date IS NULL OR p_end_date IS NULL THEN
            RETURN FALSE;
        END IF;
        RETURN p_end_date >= p_start_date;
    END validate_date_range;

    FUNCTION validate_salary_for_grade(
        p_salary   IN NUMBER,
        p_grade_id IN NUMBER
    ) RETURN VARCHAR2 IS
        v_min NUMBER;
        v_max NUMBER;
        v_grade_name VARCHAR2(50);
    BEGIN
        IF p_salary IS NULL OR p_grade_id IS NULL THEN
            RETURN 'Salary and grade are required';
        END IF;

        SELECT MIN_SALARY, MAX_SALARY, GRADE_NAME
        INTO v_min, v_max, v_grade_name
        FROM JOB_GRADES
        WHERE GRADE_ID = p_grade_id;

        IF p_salary < v_min THEN
            RETURN 'Salary ' || TO_CHAR(p_salary, 'FM$999,999,990.00') ||
                   ' is below minimum for grade ' || v_grade_name ||
                   ' (' || TO_CHAR(v_min, 'FM$999,999,990.00') || ')';
        ELSIF p_salary > v_max THEN
            RETURN 'Salary ' || TO_CHAR(p_salary, 'FM$999,999,990.00') ||
                   ' exceeds maximum for grade ' || v_grade_name ||
                   ' (' || TO_CHAR(v_max, 'FM$999,999,990.00') || ')';
        END IF;

        RETURN NULL;  -- Valid
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Invalid grade ID: ' || p_grade_id;
    END validate_salary_for_grade;

    FUNCTION validate_email_format(
        p_email IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_email IS NULL OR PKG_COMMON.is_valid_email(p_email);
    END validate_email_format;

    FUNCTION validate_phone_format(
        p_phone IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_phone IS NULL OR PKG_COMMON.is_valid_phone(p_phone);
    END validate_phone_format;

    FUNCTION validate_emp_number_format(
        p_emp_number IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_emp_number IS NOT NULL
           AND REGEXP_LIKE(p_emp_number, '^EMP-[0-9]{6}$');
    END validate_emp_number_format;

    FUNCTION validate_employment_type(
        p_employment_type IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_employment_type IS NOT NULL
           AND UPPER(TRIM(p_employment_type)) IN (
            'FULL_TIME',
            'PART_TIME',
            'CONTRACT',
            'INTERN'
        );
    END validate_employment_type;

    FUNCTION validate_employment_status(
        p_employment_status IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN p_employment_status IS NOT NULL
           AND UPPER(TRIM(p_employment_status)) IN (
            'ACTIVE',
            'ON_LEAVE',
            'SUSPENDED',
            'TERMINATED'
        );
    END validate_employment_status;

    FUNCTION validate_department(
        p_dept_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_count PLS_INTEGER;
    BEGIN
        IF p_dept_id IS NULL THEN
            RETURN FALSE;
        END IF;

        SELECT COUNT(*)
          INTO v_count
          FROM HRMS.DEPARTMENTS department
         WHERE department.DEPT_ID = p_dept_id
           AND department.ACTIVE_FLAG = 'Y';

        RETURN v_count = 1;
    END validate_department;

    FUNCTION validate_job(
        p_job_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_count PLS_INTEGER;
    BEGIN
        IF p_job_id IS NULL THEN
            RETURN FALSE;
        END IF;

        SELECT COUNT(*)
          INTO v_count
          FROM HRMS.JOB_TITLES job_title
          JOIN HRMS.JOB_GRADES job_grade
            ON job_grade.GRADE_ID = job_title.GRADE_ID
         WHERE job_title.JOB_ID = p_job_id
           AND job_title.ACTIVE_FLAG = 'Y'
           AND job_grade.ACTIVE_FLAG = 'Y';

        RETURN v_count = 1;
    END validate_job;

    FUNCTION validate_location(
        p_location_code IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_count PLS_INTEGER;
    BEGIN
        IF p_location_code IS NULL THEN
            RETURN TRUE;
        END IF;

        SELECT COUNT(*)
          INTO v_count
          FROM HRMS.LOCATIONS location
         WHERE location.LOCATION_CODE = UPPER(TRIM(p_location_code))
           AND location.ACTIVE_FLAG = 'Y';

        RETURN v_count = 1;
    END validate_location;

    FUNCTION validate_manager(
        p_manager_emp_id IN NUMBER,
        p_emp_id         IN NUMBER DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_count PLS_INTEGER;
    BEGIN
        IF p_manager_emp_id IS NULL THEN
            RETURN TRUE;
        END IF;

        SELECT COUNT(*)
          INTO v_count
          FROM HRMS.EMPLOYEES manager
         WHERE manager.EMP_ID = p_manager_emp_id
           AND manager.EMPLOYMENT_STATUS = 'ACTIVE'
           AND manager.ACTIVE_FLAG = 'Y';

        IF v_count != 1 OR p_manager_emp_id = p_emp_id THEN
            RETURN FALSE;
        END IF;

        RETURN validate_manager_hierarchy(p_emp_id, p_manager_emp_id);
    END validate_manager;

    FUNCTION validate_manager_hierarchy(
        p_emp_id         IN NUMBER,
        p_manager_emp_id IN NUMBER
    ) RETURN BOOLEAN IS
        v_cycle_count PLS_INTEGER;
    BEGIN
        IF p_emp_id IS NULL OR p_manager_emp_id IS NULL THEN
            RETURN TRUE;
        END IF;

        SELECT COUNT(*)
          INTO v_cycle_count
          FROM (
                SELECT employee.EMP_ID
                  FROM HRMS.EMPLOYEES employee
                 START WITH employee.EMP_ID = p_manager_emp_id
               CONNECT BY NOCYCLE PRIOR employee.MANAGER_EMP_ID = employee.EMP_ID
               )
         WHERE EMP_ID = p_emp_id;

        RETURN v_cycle_count = 0;
    END validate_manager_hierarchy;

    FUNCTION validate_employee_dates(
        p_hire_date         IN DATE,
        p_termination_date  IN DATE,
        p_employment_status IN VARCHAR2
    ) RETURN BOOLEAN IS
        v_status VARCHAR2(20) := UPPER(TRIM(p_employment_status));
    BEGIN
        IF p_hire_date IS NULL
           OR NOT validate_employment_status(v_status)
           OR (p_termination_date IS NOT NULL AND p_termination_date < p_hire_date)
        THEN
            RETURN FALSE;
        END IF;

        RETURN (v_status = 'TERMINATED' AND p_termination_date IS NOT NULL)
            OR (v_status != 'TERMINATED' AND p_termination_date IS NULL);
    END validate_employee_dates;

    FUNCTION is_future_date(
        p_date IN DATE
    ) RETURN BOOLEAN IS
    BEGIN
        RETURN TRUNC(p_date) > TRUNC(SYSDATE);
    END is_future_date;

    FUNCTION is_business_day(
        p_date          IN DATE,
        p_location_code IN VARCHAR2 DEFAULT NULL
    ) RETURN BOOLEAN IS
        v_day VARCHAR2(3);
        v_holiday_count NUMBER;
    BEGIN
        v_day := TO_CHAR(p_date, 'DY', 'NLS_DATE_LANGUAGE=AMERICAN');
        IF v_day IN ('SAT', 'SUN') THEN
            RETURN FALSE;
        END IF;

        SELECT COUNT(*) INTO v_holiday_count
        FROM HOLIDAYS
        WHERE HOLIDAY_DATE = TRUNC(p_date)
        AND ACTIVE_FLAG = 'Y'
        AND (LOCATION_CODE IS NULL OR LOCATION_CODE = p_location_code);

        RETURN v_holiday_count = 0;
    END is_business_day;

    FUNCTION validate_required_fields(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER
    ) RETURN VARCHAR2 IS
    BEGIN
        -- Simplified validation - in production would use data dictionary
        -- to check NOT NULL columns
        IF p_table_name = 'EMPLOYEES' THEN
            DECLARE
                v_rec EMPLOYEES%ROWTYPE;
            BEGIN
                SELECT * INTO v_rec FROM EMPLOYEES WHERE EMP_ID = p_record_id;
                IF v_rec.FIRST_NAME IS NULL THEN RETURN 'First Name is required'; END IF;
                IF v_rec.LAST_NAME IS NULL THEN RETURN 'Last Name is required'; END IF;
                IF v_rec.HIRE_DATE IS NULL THEN RETURN 'Hire Date is required'; END IF;
                IF v_rec.DEPT_ID IS NULL THEN RETURN 'Department is required'; END IF;
                IF v_rec.JOB_ID IS NULL THEN RETURN 'Job Title is required'; END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RETURN 'Record not found';
            END;
        END IF;
        RETURN NULL;
    END validate_required_fields;

END PKG_VALIDATION;
/
