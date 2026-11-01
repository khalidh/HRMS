CREATE OR REPLACE PACKAGE BODY HRMS.PKG_BATCH AS

    FUNCTION get_actor RETURN VARCHAR2 IS
    BEGIN
        IF APEX_AUTHENTICATION.IS_AUTHENTICATED THEN
            RETURN HRMS.PKG_APP_CONTEXT.get_apex_username;
        END IF;

        RETURN USER;
    END get_actor;

    PROCEDURE start_execution(
        in_execution_type       IN HRMS.BATCH_EXECUTIONS.EXECUTION_TYPE%TYPE,
        in_idempotency_key      IN HRMS.BATCH_EXECUTIONS.IDEMPOTENCY_KEY%TYPE,
        out_batch_execution_id  OUT HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE,
        out_should_execute      OUT BOOLEAN,
        in_reference_key        IN HRMS.BATCH_EXECUTIONS.REFERENCE_KEY%TYPE DEFAULT NULL
    ) IS
        v_execution HRMS.BATCH_EXECUTIONS%ROWTYPE;
        v_actor HRMS.BATCH_EXECUTIONS.REQUESTED_BY%TYPE := get_actor;
        v_execution_type HRMS.BATCH_EXECUTIONS.EXECUTION_TYPE%TYPE;
        v_idempotency_key HRMS.BATCH_EXECUTIONS.IDEMPOTENCY_KEY%TYPE;
        v_reference_key HRMS.BATCH_EXECUTIONS.REFERENCE_KEY%TYPE;
    BEGIN
        v_execution_type := UPPER(TRIM(in_execution_type));
        v_idempotency_key := TRIM(in_idempotency_key);
        v_reference_key := TRIM(in_reference_key);

        IF v_execution_type IS NULL OR v_idempotency_key IS NULL THEN
            RAISE_APPLICATION_ERROR(-20101, 'Execution type and idempotency key are required.');
        END IF;

        BEGIN
            INSERT INTO HRMS.BATCH_EXECUTIONS (
                BATCH_EXECUTION_ID,
                EXECUTION_TYPE,
                REFERENCE_KEY,
                IDEMPOTENCY_KEY,
                EXECUTION_STATUS,
                REQUESTED_BY,
                REQUESTED_AT,
                STARTED_AT,
                CREATED_BY,
                CREATED_AT
            ) VALUES (
                HRMS.SEQ_BATCH_EXECUTION.NEXTVAL,
                v_execution_type,
                v_reference_key,
                v_idempotency_key,
                'RUNNING',
                v_actor,
                SYSTIMESTAMP,
                SYSTIMESTAMP,
                v_actor,
                SYSTIMESTAMP
            )
            RETURNING BATCH_EXECUTION_ID INTO out_batch_execution_id;

            out_should_execute := TRUE;
            RETURN;
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
        END;

        BEGIN
            SELECT batch_execution.*
              INTO v_execution
              FROM HRMS.BATCH_EXECUTIONS batch_execution
             WHERE batch_execution.IDEMPOTENCY_KEY = v_idempotency_key
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20102, 'Batch execution key conflict could not be resolved.');
        END;

        IF v_execution.EXECUTION_TYPE != v_execution_type
           OR (v_execution.REFERENCE_KEY IS NULL AND v_reference_key IS NOT NULL)
           OR (v_execution.REFERENCE_KEY IS NOT NULL AND v_reference_key IS NULL)
           OR (v_execution.REFERENCE_KEY IS NOT NULL
               AND v_reference_key IS NOT NULL
               AND v_execution.REFERENCE_KEY != v_reference_key)
        THEN
            RAISE_APPLICATION_ERROR(-20102, 'Idempotency key was already used for a different execution.');
        END IF;

        out_batch_execution_id := v_execution.BATCH_EXECUTION_ID;
        out_should_execute := FALSE;

        IF v_execution.EXECUTION_STATUS = 'PENDING'
           OR v_execution.EXECUTION_STATUS = 'FAILED'
        THEN
            UPDATE HRMS.BATCH_EXECUTIONS batch_execution
               SET batch_execution.EXECUTION_STATUS = 'RUNNING',
                   batch_execution.RETRY_COUNT =
                       batch_execution.RETRY_COUNT
                       + CASE WHEN v_execution.EXECUTION_STATUS = 'FAILED' THEN 1 ELSE 0 END,
                   batch_execution.STARTED_AT = SYSTIMESTAMP,
                   batch_execution.COMPLETED_AT = NULL,
                   batch_execution.ITEMS_TOTAL = 0,
                   batch_execution.ITEMS_SUCCEEDED = 0,
                   batch_execution.ITEMS_FAILED = 0,
                   batch_execution.ERROR_CODE = NULL,
                   batch_execution.ERROR_SUMMARY = NULL,
                   batch_execution.UPDATED_BY = v_actor,
                   batch_execution.UPDATED_AT = SYSTIMESTAMP
             WHERE batch_execution.BATCH_EXECUTION_ID = v_execution.BATCH_EXECUTION_ID;

            out_should_execute := TRUE;
        END IF;
    END start_execution;

    PROCEDURE update_progress(
        in_batch_execution_id IN HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE,
        in_items_total        IN HRMS.BATCH_EXECUTIONS.ITEMS_TOTAL%TYPE,
        in_items_succeeded    IN HRMS.BATCH_EXECUTIONS.ITEMS_SUCCEEDED%TYPE,
        in_items_failed       IN HRMS.BATCH_EXECUTIONS.ITEMS_FAILED%TYPE
    ) IS
        v_execution HRMS.BATCH_EXECUTIONS%ROWTYPE;
        v_actor HRMS.BATCH_EXECUTIONS.UPDATED_BY%TYPE := get_actor;
    BEGIN
        IF in_items_total IS NULL
           OR in_items_succeeded IS NULL
           OR in_items_failed IS NULL
           OR in_items_total < 0
           OR in_items_succeeded < 0
           OR in_items_failed < 0
           OR in_items_total != TRUNC(in_items_total)
           OR in_items_succeeded != TRUNC(in_items_succeeded)
           OR in_items_failed != TRUNC(in_items_failed)
           OR in_items_succeeded + in_items_failed > in_items_total
        THEN
            RAISE_APPLICATION_ERROR(-20101, 'Batch progress counters are invalid.');
        END IF;

        SELECT batch_execution.*
          INTO v_execution
          FROM HRMS.BATCH_EXECUTIONS batch_execution
         WHERE batch_execution.BATCH_EXECUTION_ID = in_batch_execution_id
           FOR UPDATE;

        IF v_execution.EXECUTION_STATUS != 'RUNNING' THEN
            RAISE_APPLICATION_ERROR(-20103, 'Progress can only be recorded for a running execution.');
        END IF;

        IF in_items_total < v_execution.ITEMS_TOTAL
           OR in_items_succeeded < v_execution.ITEMS_SUCCEEDED
           OR in_items_failed < v_execution.ITEMS_FAILED
        THEN
            RAISE_APPLICATION_ERROR(-20101, 'Batch progress counters cannot decrease.');
        END IF;

        UPDATE HRMS.BATCH_EXECUTIONS batch_execution
           SET batch_execution.ITEMS_TOTAL = in_items_total,
               batch_execution.ITEMS_SUCCEEDED = in_items_succeeded,
               batch_execution.ITEMS_FAILED = in_items_failed,
               batch_execution.UPDATED_BY = v_actor,
               batch_execution.UPDATED_AT = SYSTIMESTAMP
         WHERE batch_execution.BATCH_EXECUTION_ID = in_batch_execution_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20104, 'Batch execution does not exist.');
    END update_progress;

    PROCEDURE complete_execution(
        in_batch_execution_id IN HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE,
        in_execution_status   IN HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE,
        in_items_total        IN HRMS.BATCH_EXECUTIONS.ITEMS_TOTAL%TYPE,
        in_items_succeeded    IN HRMS.BATCH_EXECUTIONS.ITEMS_SUCCEEDED%TYPE,
        in_items_failed       IN HRMS.BATCH_EXECUTIONS.ITEMS_FAILED%TYPE,
        in_error_code         IN HRMS.BATCH_EXECUTIONS.ERROR_CODE%TYPE DEFAULT NULL,
        in_error_summary      IN HRMS.BATCH_EXECUTIONS.ERROR_SUMMARY%TYPE DEFAULT NULL
    ) IS
        v_execution HRMS.BATCH_EXECUTIONS%ROWTYPE;
        v_actor HRMS.BATCH_EXECUTIONS.UPDATED_BY%TYPE := get_actor;
        v_status HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE;
    BEGIN
        v_status := UPPER(TRIM(in_execution_status));

        IF v_status IS NULL
           OR v_status NOT IN ('SUCCEEDED', 'FAILED', 'CANCELLED')
           OR in_items_total IS NULL
           OR in_items_succeeded IS NULL
           OR in_items_failed IS NULL
           OR in_items_total < 0
           OR in_items_succeeded < 0
           OR in_items_failed < 0
           OR in_items_total != TRUNC(in_items_total)
           OR in_items_succeeded != TRUNC(in_items_succeeded)
           OR in_items_failed != TRUNC(in_items_failed)
           OR in_items_succeeded + in_items_failed > in_items_total
        THEN
            RAISE_APPLICATION_ERROR(-20101, 'Final batch status or counters are invalid.');
        END IF;

        SELECT batch_execution.*
          INTO v_execution
          FROM HRMS.BATCH_EXECUTIONS batch_execution
         WHERE batch_execution.BATCH_EXECUTION_ID = in_batch_execution_id
           FOR UPDATE;

        IF v_execution.EXECUTION_STATUS != 'RUNNING' THEN
            RAISE_APPLICATION_ERROR(-20103, 'Only a running execution can be completed.');
        END IF;

        IF in_items_total < v_execution.ITEMS_TOTAL
           OR in_items_succeeded < v_execution.ITEMS_SUCCEEDED
           OR in_items_failed < v_execution.ITEMS_FAILED
        THEN
            RAISE_APPLICATION_ERROR(-20101, 'Final batch counters cannot be less than recorded progress.');
        END IF;

        UPDATE HRMS.BATCH_EXECUTIONS batch_execution
           SET batch_execution.EXECUTION_STATUS = v_status,
               batch_execution.ITEMS_TOTAL = in_items_total,
               batch_execution.ITEMS_SUCCEEDED = in_items_succeeded,
               batch_execution.ITEMS_FAILED = in_items_failed,
               batch_execution.ERROR_CODE = SUBSTR(in_error_code, 1, 100),
               batch_execution.ERROR_SUMMARY =
                   SUBSTR(
                       REPLACE(REPLACE(in_error_summary, CHR(10), ' '), CHR(13), ' '),
                       1,
                       2000
                   ),
               batch_execution.COMPLETED_AT = SYSTIMESTAMP,
               batch_execution.UPDATED_BY = v_actor,
               batch_execution.UPDATED_AT = SYSTIMESTAMP
         WHERE batch_execution.BATCH_EXECUTION_ID = in_batch_execution_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20104, 'Batch execution does not exist.');
    END complete_execution;

    FUNCTION get_status(
        in_batch_execution_id IN HRMS.BATCH_EXECUTIONS.BATCH_EXECUTION_ID%TYPE
    ) RETURN HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE IS
        v_status HRMS.BATCH_EXECUTIONS.EXECUTION_STATUS%TYPE;
    BEGIN
        SELECT batch_execution.EXECUTION_STATUS
          INTO v_status
          FROM HRMS.BATCH_EXECUTIONS batch_execution
         WHERE batch_execution.BATCH_EXECUTION_ID = in_batch_execution_id;

        RETURN v_status;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20104, 'Batch execution does not exist.');
    END get_status;

END PKG_BATCH;
/
