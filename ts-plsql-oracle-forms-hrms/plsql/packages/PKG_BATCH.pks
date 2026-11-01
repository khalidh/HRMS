CREATE OR REPLACE PACKAGE HRMS.PKG_BATCH AS
-- Idempotent job execution tracking. Callers own the transaction and commit
-- the job state and associated work atomically where the workload permits.

    PROCEDURE start_execution(
        in_execution_type       IN HRMS.BATCH_EXECUTIONS.EXECUTION_TYPE%TYPE,
        in_idempotency_key      IN HRMS.BATCH_EXECUTIONS.IDEMPOTENCY_KEY%TYPE,
        out_batch_execution_id  OUT HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE,
        out_should_execute      OUT BOOLEAN,
        in_reference_key        IN HRMS.BATCH_EXECUTIONS.REFERENCE_KEY%TYPE DEFAULT NULL
    );

    PROCEDURE update_progress(
        in_batch_execution_id IN HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE,
        in_items_total        IN HRMS.BATCH_EXECUTIONS.ITEMS_TOTAL%TYPE,
        in_items_succeeded    IN HRMS.BATCH_EXECUTIONS.ITEMS_SUCCEEDED%TYPE,
        in_items_failed       IN HRMS.BATCH_EXECUTIONS.ITEMS_FAILED%TYPE
    );

    PROCEDURE complete_execution(
        in_batch_execution_id IN HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE,
        in_execution_status   IN HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE,
        in_items_total        IN HRMS.BATCH_EXECUTIONS.ITEMS_TOTAL%TYPE,
        in_items_succeeded    IN HRMS.BATCH_EXECUTIONS.ITEMS_SUCCEEDED%TYPE,
        in_items_failed       IN HRMS.BATCH_EXECUTIONS.ITEMS_FAILED%TYPE,
        in_error_code         IN HRMS.BATCH_EXECUTIONS.ERROR_CODE%TYPE DEFAULT NULL,
        in_error_summary      IN HRMS.BATCH_EXECUTIONS.ERROR_SUMMARY%TYPE DEFAULT NULL
    );

    FUNCTION get_status(
        in_batch_execution_id IN HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE
    ) RETURN HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE;

END PKG_BATCH;
/
