CREATE OR REPLACE PACKAGE BODY HRMS.PKG_AUDIT AS

    PROCEDURE resolve_audit_context(
        in_requested_user  IN VARCHAR2,
        out_changed_by     OUT VARCHAR2,
        out_sso_subject    OUT VARCHAR2,
        out_apex_session   OUT NUMBER,
        out_client_ip      OUT VARCHAR2,
        out_database_session OUT VARCHAR2
    ) IS
    BEGIN
        out_sso_subject := NULL;
        out_apex_session := NULL;
        out_client_ip := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
        out_database_session := SYS_CONTEXT('USERENV', 'SESSIONID');

        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            out_sso_subject := HRMS.PKG_APP_CONTEXT.get_apex_username;
            out_changed_by := out_sso_subject;
            out_apex_session := HRMS.PKG_APP_CONTEXT.get_apex_session_id;
            out_client_ip := OWA_UTIL.GET_CGI_ENV('REMOTE_ADDR');
            IF out_client_ip IS NULL THEN
                out_client_ip := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
            END IF;
        ELSE
            out_changed_by := NVL(in_requested_user, USER);
        END IF;
    END resolve_audit_context;

    PROCEDURE log_action(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_action     IN VARCHAR2,
        p_user       IN VARCHAR2 DEFAULT USER,
        p_old_values IN CLOB DEFAULT NULL,
        p_new_values IN CLOB DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        v_changed_by       VARCHAR2(255);
        v_sso_subject      VARCHAR2(255);
        v_apex_session_id  NUMBER;
        v_client_ip        VARCHAR2(50);
        v_database_session VARCHAR2(100);
    BEGIN
        resolve_audit_context(
            in_requested_user   => p_user,
            out_changed_by      => v_changed_by,
            out_sso_subject     => v_sso_subject,
            out_apex_session    => v_apex_session_id,
            out_client_ip       => v_client_ip,
            out_database_session => v_database_session
        );

        INSERT INTO HRMS.AUDIT_LOG (
            AUDIT_ID,
            TABLE_NAME,
            RECORD_ID,
            ACTION_TYPE,
            OLD_VALUES,
            NEW_VALUES,
            CHANGED_BY,
            CHANGED_DATE,
            IP_ADDRESS,
            SESSION_ID,
            SSO_SUBJECT,
            APEX_SESSION_ID,
            CLIENT_IP_ADDRESS
        ) VALUES (
            HRMS.SEQ_AUDIT.NEXTVAL,
            p_table_name,
            p_record_id,
            UPPER(p_action),
            p_old_values,
            p_new_values,
            v_changed_by,
            SYSDATE,
            v_client_ip,
            v_database_session,
            v_sso_subject,
            v_apex_session_id,
            v_client_ip
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END log_action;

    PROCEDURE log_export(
        in_module_code   IN VARCHAR2,
        in_report_code   IN VARCHAR2,
        in_export_format IN VARCHAR2,
        in_row_count     IN NUMBER,
        in_result        IN VARCHAR2,
        in_reason_code   IN VARCHAR2 DEFAULT NULL
    ) IS
        v_action VARCHAR2(20);
        v_payload CLOB;
    BEGIN
        IF in_module_code IS NULL
           OR in_report_code IS NULL
           OR in_export_format IS NULL
           OR NOT REGEXP_LIKE(in_module_code, '^[A-Z0-9_]{1,30}$')
           OR NOT REGEXP_LIKE(in_report_code, '^[A-Z0-9_]{1,30}$')
           OR NOT REGEXP_LIKE(in_export_format, '^[A-Z0-9_]{1,20}$')
           OR in_result IS NULL
           OR in_result NOT IN ('SUCCEEDED', 'DENIED', 'FAILED')
           OR (in_row_count IS NOT NULL AND (in_row_count < 0 OR in_row_count != TRUNC(in_row_count)))
           OR (in_reason_code IS NOT NULL AND NOT REGEXP_LIKE(in_reason_code, '^[A-Z0-9_]{1,50}$'))
        THEN
            RAISE_APPLICATION_ERROR(-20081, 'Invalid export audit details.');
        END IF;

        v_action :=
            CASE in_result
                WHEN 'SUCCEEDED' THEN 'EXPORT'
                WHEN 'DENIED' THEN 'EXPORT_DENIED'
                ELSE 'EXPORT_FAILED'
            END;

        SELECT JSON_OBJECT(
                   'module' VALUE in_module_code,
                   'report' VALUE in_report_code,
                   'format' VALUE in_export_format,
                   'row_count' VALUE in_row_count,
                   'result' VALUE in_result,
                   'reason_code' VALUE in_reason_code
                   NULL ON NULL
                   RETURNING CLOB
               )
          INTO v_payload
          FROM dual;

        log_action(
            p_table_name => 'APEX_EXPORT',
            p_record_id  => 0,
            p_action     => v_action,
            p_old_values => NULL,
            p_new_values => v_payload
        );
    END log_export;

    PROCEDURE purge_old_records(
        p_days_to_keep IN NUMBER DEFAULT 365,
        p_user         IN VARCHAR2 DEFAULT USER
    ) IS
        v_deleted NUMBER;
    BEGIN
        DELETE FROM HRMS.AUDIT_LOG audit_record
         WHERE audit_record.CHANGED_DATE < SYSDATE - p_days_to_keep;

        v_deleted := SQL%ROWCOUNT;
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Purged ' || v_deleted || ' audit records older than ' ||
            p_days_to_keep || ' days');
    END purge_old_records;

    FUNCTION get_change_history(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_from_date  IN DATE DEFAULT NULL,
        p_to_date    IN DATE DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT audit_record.AUDIT_ID,
                   audit_record.TABLE_NAME,
                   audit_record.RECORD_ID,
                   audit_record.ACTION_TYPE,
                   audit_record.OLD_VALUES,
                   audit_record.NEW_VALUES,
                   audit_record.CHANGED_BY,
                   audit_record.CHANGED_DATE,
                   audit_record.IP_ADDRESS,
                   audit_record.SSO_SUBJECT,
                   audit_record.APEX_SESSION_ID,
                   audit_record.CLIENT_IP_ADDRESS
              FROM HRMS.AUDIT_LOG audit_record
             WHERE audit_record.TABLE_NAME = p_table_name
               AND audit_record.RECORD_ID = p_record_id
               AND (p_from_date IS NULL OR audit_record.CHANGED_DATE >= p_from_date)
               AND (p_to_date IS NULL OR audit_record.CHANGED_DATE <= p_to_date)
             ORDER BY audit_record.CHANGED_DATE DESC;

        RETURN v_cursor;
    END get_change_history;

END PKG_AUDIT;
/
