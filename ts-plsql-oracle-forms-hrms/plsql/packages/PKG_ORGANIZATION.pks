CREATE OR REPLACE PACKAGE HRMS.PKG_ORGANIZATION AS
    FUNCTION create_department(
        p_dept_code       IN VARCHAR2,
        p_dept_name       IN VARCHAR2,
        p_parent_dept_id  IN NUMBER DEFAULT NULL,
        p_cost_center     IN VARCHAR2 DEFAULT NULL,
        p_manager_emp_id  IN NUMBER DEFAULT NULL,
        p_location_code   IN VARCHAR2 DEFAULT NULL
    ) RETURN NUMBER;

    PROCEDURE update_department(
        p_dept_id         IN NUMBER,
        p_dept_code       IN VARCHAR2,
        p_dept_name       IN VARCHAR2,
        p_parent_dept_id  IN NUMBER,
        p_cost_center     IN VARCHAR2,
        p_manager_emp_id  IN NUMBER,
        p_location_code   IN VARCHAR2,
        p_active_flag     IN VARCHAR2
    );

    PROCEDURE create_location(
        p_location_code   IN VARCHAR2,
        p_location_name   IN VARCHAR2,
        p_city            IN VARCHAR2,
        p_state_province  IN VARCHAR2,
        p_country_code    IN VARCHAR2
    );

    PROCEDURE update_location(
        p_location_code   IN VARCHAR2,
        p_location_name   IN VARCHAR2,
        p_city            IN VARCHAR2,
        p_state_province  IN VARCHAR2,
        p_country_code    IN VARCHAR2,
        p_active_flag     IN VARCHAR2
    );

    FUNCTION create_job_grade(
        p_grade_code      IN VARCHAR2,
        p_grade_name      IN VARCHAR2,
        p_min_salary      IN NUMBER,
        p_max_salary      IN NUMBER
    ) RETURN NUMBER;

    PROCEDURE update_job_grade(
        p_grade_id        IN NUMBER,
        p_grade_code      IN VARCHAR2,
        p_grade_name      IN VARCHAR2,
        p_min_salary      IN NUMBER,
        p_max_salary      IN NUMBER,
        p_active_flag     IN VARCHAR2
    );

    FUNCTION create_job_title(
        p_job_code        IN VARCHAR2,
        p_job_title       IN VARCHAR2,
        p_job_family      IN VARCHAR2,
        p_grade_id        IN NUMBER
    ) RETURN NUMBER;

    PROCEDURE update_job_title(
        p_job_id          IN NUMBER,
        p_job_code        IN VARCHAR2,
        p_job_title       IN VARCHAR2,
        p_job_family      IN VARCHAR2,
        p_grade_id        IN NUMBER,
        p_active_flag     IN VARCHAR2
    );
END PKG_ORGANIZATION;
/
