-- ============================================================================
-- Upgrade existing BATCH_EXECUTIONS actor columns for OIDC subjects.
-- Run after 05_operational_tables.sql when upgrading an existing schema.
-- ============================================================================

DECLARE
    v_table_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_table_count
      FROM ALL_TABLES batch_table
     WHERE batch_table.OWNER = 'HRMS'
       AND batch_table.TABLE_NAME = 'BATCH_EXECUTIONS';

    IF v_table_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20105, 'HRMS.BATCH_EXECUTIONS must exist before applying actor column upgrades.');
    END IF;

    EXECUTE IMMEDIATE 'ALTER TABLE HRMS.BATCH_EXECUTIONS MODIFY (REQUESTED_BY VARCHAR2(255))';
    EXECUTE IMMEDIATE 'ALTER TABLE HRMS.BATCH_EXECUTIONS MODIFY (CREATED_BY VARCHAR2(255))';
    EXECUTE IMMEDIATE 'ALTER TABLE HRMS.BATCH_EXECUTIONS MODIFY (UPDATED_BY VARCHAR2(255))';
END;
/
