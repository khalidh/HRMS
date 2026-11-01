-- ============================================================================
-- Upgrade existing AUDIT_LOG tables for authenticated APEX auditing.
-- Run after 04_performance_tables.sql when upgrading an existing schema.
-- ============================================================================

DECLARE
    v_column_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_column_count
      FROM ALL_TABLES audit_table
     WHERE audit_table.OWNER = 'HRMS'
       AND audit_table.TABLE_NAME = 'AUDIT_LOG';

    IF v_column_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20082, 'HRMS.AUDIT_LOG must exist before applying audit context upgrades.');
    END IF;

    EXECUTE IMMEDIATE 'ALTER TABLE HRMS.AUDIT_LOG MODIFY (ACTION_TYPE VARCHAR2(20))';
    EXECUTE IMMEDIATE 'ALTER TABLE HRMS.AUDIT_LOG MODIFY (CHANGED_BY VARCHAR2(255))';

    SELECT COUNT(*)
      INTO v_column_count
      FROM ALL_TAB_COLUMNS audit_column
     WHERE audit_column.OWNER = 'HRMS'
       AND audit_column.TABLE_NAME = 'AUDIT_LOG'
       AND audit_column.COLUMN_NAME = 'SSO_SUBJECT';

    IF v_column_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE HRMS.AUDIT_LOG ADD (SSO_SUBJECT VARCHAR2(255))';
    END IF;

    SELECT COUNT(*)
      INTO v_column_count
      FROM ALL_TAB_COLUMNS audit_column
     WHERE audit_column.OWNER = 'HRMS'
       AND audit_column.TABLE_NAME = 'AUDIT_LOG'
       AND audit_column.COLUMN_NAME = 'APEX_SESSION_ID';

    IF v_column_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE HRMS.AUDIT_LOG ADD (APEX_SESSION_ID NUMBER(20))';
    END IF;

    SELECT COUNT(*)
      INTO v_column_count
      FROM ALL_TAB_COLUMNS audit_column
     WHERE audit_column.OWNER = 'HRMS'
       AND audit_column.TABLE_NAME = 'AUDIT_LOG'
       AND audit_column.COLUMN_NAME = 'CLIENT_IP_ADDRESS';

    IF v_column_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE HRMS.AUDIT_LOG ADD (CLIENT_IP_ADDRESS VARCHAR2(50))';
    END IF;

    BEGIN
        EXECUTE IMMEDIATE 'ALTER TABLE HRMS.AUDIT_LOG DROP CONSTRAINT CHK_AUDIT_ACTION';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -2443 THEN
                RAISE;
            END IF;
    END;

    EXECUTE IMMEDIATE q'[
        ALTER TABLE HRMS.AUDIT_LOG ADD CONSTRAINT CHK_AUDIT_ACTION
        CHECK (ACTION_TYPE IN (
            'INSERT', 'UPDATE', 'DELETE', 'STATUS_CHANGE', 'EXPORT',
            'EXPORT_DENIED', 'EXPORT_FAILED', 'SENSITIVE_READ', 'AUTHZ_CHANGE',
            'LOGIN', 'LOGOUT', 'PURGE'
        ))
    ]';
END;
/

COMMENT ON COLUMN HRMS.AUDIT_LOG.SSO_SUBJECT IS
    'Authenticated OIDC subject from the initialized APEX context; null for legacy non-APEX calls.';
COMMENT ON COLUMN HRMS.AUDIT_LOG.APEX_SESSION_ID IS
    'Authenticated APEX session ID; SESSION_ID continues to store the database session identifier.';
COMMENT ON COLUMN HRMS.AUDIT_LOG.CLIENT_IP_ADDRESS IS
    'Client address observed by the web gateway; forwarded headers are not trusted by the audit package.';
