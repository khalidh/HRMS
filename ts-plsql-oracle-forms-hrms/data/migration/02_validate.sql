-- Validate staged JSON rows and advance progress for one RUNNING execution.
-- Invoke after loading rows:
--   @02_validate.sql <BATCH_EXECUTION_ID>

SET SERVEROUTPUT ON
SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    c_batch_execution_id CONSTANT NUMBER := TO_NUMBER('&&1');
    v_execution_status HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE;
    v_staged_count PLS_INTEGER;
    v_pending_count PLS_INTEGER;
    v_rejected_count PLS_INTEGER;
BEGIN
    IF c_batch_execution_id <= 0 OR c_batch_execution_id != TRUNC(c_batch_execution_id) THEN
        RAISE_APPLICATION_ERROR(-20221, 'A positive integer batch execution ID is required.');
    END IF;

    SELECT batch_execution.EXECUTION_STATUS
      INTO v_execution_status
      FROM HRMS.BATCH_EXECUTIONS batch_execution
     WHERE batch_execution.BATCH_EXECUTION_ID = c_batch_execution_id
       FOR UPDATE;

    IF v_execution_status != 'RUNNING' THEN
        RAISE_APPLICATION_ERROR(-20222, 'Only a RUNNING batch execution can be validated.');
    END IF;

    SELECT COUNT(*),
           SUM(CASE WHEN staging_row.STAGING_STATUS = 'PENDING' THEN 1 ELSE 0 END),
           SUM(CASE WHEN staging_row.STAGING_STATUS = 'REJECTED' THEN 1 ELSE 0 END)
      INTO v_staged_count, v_pending_count, v_rejected_count
      FROM HRMS.MIGRATION_STAGING_ROWS staging_row
     WHERE staging_row.BATCH_EXECUTION_ID = c_batch_execution_id;

    IF v_staged_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20223, 'No staging rows were loaded for this batch.');
    END IF;

    IF v_rejected_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20224, 'Rejected staging rows must be resolved before validation.');
    END IF;

    UPDATE HRMS.MIGRATION_STAGING_ROWS staging_row
       SET staging_row.STAGING_STATUS = 'VALID',
           staging_row.VALIDATED_AT = SYSTIMESTAMP
     WHERE staging_row.BATCH_EXECUTION_ID = c_batch_execution_id
       AND staging_row.STAGING_STATUS = 'PENDING'
       AND staging_row.SOURCE_PAYLOAD IS JSON;

    SELECT COUNT(*)
      INTO v_pending_count
      FROM HRMS.MIGRATION_STAGING_ROWS staging_row
     WHERE staging_row.BATCH_EXECUTION_ID = c_batch_execution_id
       AND staging_row.STAGING_STATUS != 'VALID';

    IF v_pending_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20225, 'Some staged rows did not pass JSON validation.');
    END IF;

    HRMS.PKG_BATCH.update_progress(
        in_batch_execution_id => c_batch_execution_id,
        in_items_total        => v_staged_count,
        in_items_succeeded    => v_staged_count,
        in_items_failed       => 0
    );

    DBMS_OUTPUT.PUT_LINE(
        'PASS: ' || v_staged_count || ' staging rows passed generic JSON validation.'
    );
    DBMS_OUTPUT.PUT_LINE(
        'Note: this does not replace target-specific business validation or reconciliation.'
    );
END;
/

COMMIT

EXIT SUCCESS
