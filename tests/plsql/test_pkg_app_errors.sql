SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    v_error_code      NUMBER;
    v_error_message   VARCHAR2(4000);
    v_backtrace       VARCHAR2(4000);
    v_log_count       PLS_INTEGER;
    v_context_code    VARCHAR2(60) := 'TEST_' || RAWTOHEX(SYS_GUID());

    PROCEDURE assert_true(
        in_condition IN BOOLEAN,
        in_message   IN VARCHAR2
    ) IS
    BEGIN
        IF in_condition IS NULL OR NOT in_condition THEN
            RAISE_APPLICATION_ERROR(-20997, in_message);
        END IF;
    END assert_true;
BEGIN
    assert_true(
        HRMS.PKG_APP_ERRORS.get_error_code(-20001) = 'EMPLOYEE_NOT_FOUND',
        'The employee-not-found error code was not normalized.'
    );
    assert_true(
        HRMS.PKG_APP_ERRORS.get_error_code(0) = 'UNEXPECTED_ERROR',
        'Unknown error codes must map to UNEXPECTED_ERROR.'
    );
    assert_true(
        HRMS.PKG_APP_ERRORS.get_user_message(-20001, 'en') =
            'The employee could not be found.',
        'The English employee-not-found message is incorrect.'
    );
    assert_true(
        HRMS.PKG_APP_ERRORS.get_user_message(-20003, 'fr-CA') =
            'Le département sélectionné est indisponible.',
        'The French employee message is incorrect.'
    );

    BEGIN
        HRMS.PKG_APP_ERRORS.raise_user_error(-20001, 'en');
    EXCEPTION
        WHEN OTHERS THEN
            v_error_code := SQLCODE;
            v_error_message := SQLERRM;
    END;

    assert_true(v_error_code = -20999, 'The public application error code is not stable.');
    assert_true(
        INSTR(v_error_message, 'The employee could not be found.') > 0,
        'The normalized error did not return the safe English message.'
    );

    BEGIN
        RAISE_APPLICATION_ERROR(-20001, 'Synthetic error used only by the test.');
    EXCEPTION
        WHEN OTHERS THEN
            v_error_code := SQLCODE;
            v_backtrace := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
    END;

    HRMS.PKG_APP_ERRORS.log_error(
        in_context_code      => v_context_code,
        in_oracle_error_code => v_error_code,
        in_error_backtrace   => v_backtrace
    );

    SELECT COUNT(*)
      INTO v_log_count
      FROM HRMS.AUDIT_LOG audit_record
     WHERE audit_record.TABLE_NAME = 'APPLICATION_ERRORS'
       AND audit_record.ACTION_TYPE = 'ERROR'
       AND JSON_VALUE(audit_record.NEW_VALUES, '$.context' RETURNING VARCHAR2(60)) =
           v_context_code;

    assert_true(v_log_count = 1, 'The normalized error was not written to the audit log.');

    DELETE FROM HRMS.AUDIT_LOG audit_record
     WHERE audit_record.TABLE_NAME = 'APPLICATION_ERRORS'
       AND audit_record.ACTION_TYPE = 'ERROR'
       AND JSON_VALUE(audit_record.NEW_VALUES, '$.context' RETURNING VARCHAR2(60)) =
           v_context_code;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('PASS: PKG_APP_ERRORS mapping, safe messages, raising, and audit logging.');
EXCEPTION
    WHEN OTHERS THEN
        DELETE FROM HRMS.AUDIT_LOG audit_record
         WHERE audit_record.TABLE_NAME = 'APPLICATION_ERRORS'
           AND audit_record.ACTION_TYPE = 'ERROR'
           AND JSON_VALUE(audit_record.NEW_VALUES, '$.context' RETURNING VARCHAR2(60)) =
               v_context_code;
        COMMIT;
        RAISE;
END;
/

EXIT SUCCESS
