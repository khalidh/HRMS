-- Remove staging rows for one RUNNING batch and mark that execution CANCELLED.
-- This does not drop tables or delete business data.
-- Explicit confirmation is required:
--   @03_rollback.sql <BATCH_EXECUTION_ID> CONFIRM_STAGING_ROLLBACK

SET SERVEROUTPUT ON
SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    c_batch_execution_id CONSTANT NUMBER := TO_NUMBER('&&1');
    c_confirmation CONSTANT VARCHAR2(40) := '&&2';
    v_execution HRMS.BATCH_EXECUTIONS%ROWTYPE;
    v_deleted_count PLS_INTEGER;
BEGIN
    IF c_batch_execution_id <= 0 OR c_batch_execution_id != TRUNC(c_batch_execution_id) THEN
        RAISE_APPLICATION_ERROR(-20231, 'A positive integer batch execution ID is required.');
    END IF;

    IF c_confirmation != 'CONFIRM_STAGING_ROLLBACK' THEN
        RAISE_APPLICATION_ERROR(-20232, 'Explicit staging rollback confirmation is required.');
    END IF;

    SELECT batch_execution.*
      INTO v_execution
      FROM HRMS.BATCH_EXECUTIONS batch_execution
     WHERE batch_execution.BATCH_EXECUTION_ID = c_batch_execution_id
       FOR UPDATE;

    IF v_execution.EXECUTION_STATUS != 'RUNNING' THEN
        RAISE_APPLICATION_ERROR(-20233, 'Only a RUNNING batch can be rolled back.');
    END IF;

    HRMS.PKG_BATCH.complete_execution(
        in_batch_execution_id => c_batch_execution_id,
        in_execution_status   => 'CANCELLED',
        in_items_total        => v_execution.ITEMS_TOTAL,
        in_items_succeeded    => v_execution.ITEMS_SUCCEEDED,
        in_items_failed       => v_execution.ITEMS_FAILED
    );

    DELETE FROM HRMS.MIGRATION_STAGING_ROWS staging_row
     WHERE staging_row.BATCH_EXECUTION_ID = c_batch_execution_id;

    v_deleted_count := SQL%ROWCOUNT;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'PASS: batch ' || c_batch_execution_id || ' cancelled; '
        || v_deleted_count || ' staging rows removed.'
    );
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20234, 'Batch execution does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

EXIT SUCCESS
