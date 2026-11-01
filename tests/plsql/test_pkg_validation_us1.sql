SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    PROCEDURE assert_true(
        in_condition IN BOOLEAN,
        in_message   IN VARCHAR2
    ) IS
    BEGIN
        IF in_condition IS NULL OR NOT in_condition THEN
            RAISE_APPLICATION_ERROR(-20270, in_message);
        END IF;
    END assert_true;
BEGIN
    assert_true(
        HRMS.PKG_VALIDATION.validate_emp_number_format('EMP-123456'),
        'A canonical employee number must be accepted.'
    );
    assert_true(
        NOT HRMS.PKG_VALIDATION.validate_emp_number_format('EMP-12345X'),
        'An invalid employee number must be rejected.'
    );
    assert_true(
        NOT HRMS.PKG_VALIDATION.validate_emp_number_format(NULL),
        'A missing employee number must be rejected.'
    );
    assert_true(
        HRMS.PKG_VALIDATION.validate_email_format(NULL)
        AND HRMS.PKG_VALIDATION.validate_email_format('test@example.org')
        AND NOT HRMS.PKG_VALIDATION.validate_email_format('invalid-email'),
        'Optional and malformed email values were not validated correctly.'
    );
    assert_true(
        HRMS.PKG_VALIDATION.validate_phone_format(NULL)
        AND HRMS.PKG_VALIDATION.validate_phone_format('+1 (555) 010-1234')
        AND NOT HRMS.PKG_VALIDATION.validate_phone_format('555'),
        'Optional and malformed phone values were not validated correctly.'
    );
    assert_true(
        HRMS.PKG_VALIDATION.validate_employment_type('full_time')
        AND NOT HRMS.PKG_VALIDATION.validate_employment_type('TEMPORARY'),
        'Employment types were not validated against the supported values.'
    );
    assert_true(
        HRMS.PKG_VALIDATION.validate_employment_status('active')
        AND NOT HRMS.PKG_VALIDATION.validate_employment_status('PENDING'),
        'Employment statuses were not validated against the supported values.'
    );
    assert_true(
        HRMS.PKG_VALIDATION.validate_employee_dates(
            DATE '2024-01-01',
            NULL,
            'ACTIVE'
        ),
        'An active employee with a valid hire date must pass date validation.'
    );
    assert_true(
        NOT HRMS.PKG_VALIDATION.validate_employee_dates(
            DATE '2024-01-01',
            DATE '2023-12-31',
            'TERMINATED'
        ),
        'A termination date before hire must be rejected.'
    );
    assert_true(
        NOT HRMS.PKG_VALIDATION.validate_employee_dates(
            DATE '2024-01-01',
            NULL,
            'TERMINATED'
        ),
        'A terminated employee must have a termination date.'
    );
    assert_true(
        NOT HRMS.PKG_VALIDATION.validate_department(-1)
        AND NOT HRMS.PKG_VALIDATION.validate_job(-1)
        AND NOT HRMS.PKG_VALIDATION.validate_location('US1-NONE')
        AND NOT HRMS.PKG_VALIDATION.validate_manager(-1),
        'Unknown or inactive organization references must be rejected.'
    );

    DBMS_OUTPUT.PUT_LINE('PASS: US1 employee field, date, and organization-reference validations.');
END;
/

EXIT SUCCESS
