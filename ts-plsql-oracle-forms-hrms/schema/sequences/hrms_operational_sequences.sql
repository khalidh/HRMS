-- ============================================================================
-- HRMS Operational Sequences
-- Oracle Database 19c+
-- Schema: HRMS
-- Run after schema/tables/05_operational_tables.sql as HRMS or an installer
-- with the required privileges.
-- ============================================================================

DECLARE
BEGIN
    EXECUTE IMMEDIATE q'[
        CREATE SEQUENCE HRMS.SEQ_BATCH_EXECUTION
            START WITH 1
            INCREMENT BY 1
            MINVALUE 1
            MAXVALUE 999999999999999
            CACHE 100
            NOCYCLE
    ]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN
            RAISE;
        END IF;
END;
/

DECLARE
BEGIN
    EXECUTE IMMEDIATE q'[
        CREATE SEQUENCE HRMS.SEQ_MIGRATION_RECONCILIATION
            START WITH 1
            INCREMENT BY 1
            MINVALUE 1
            MAXVALUE 999999999999999
            CACHE 100
            NOCYCLE
    ]';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -955 THEN
            RAISE;
        END IF;
END;
/

DECLARE
    l_sequence_count PLS_INTEGER;
    l_invalid_count  PLS_INTEGER;
BEGIN
    SELECT COUNT(*),
           SUM(
               CASE
                   WHEN increment_by = 1
                    AND min_value = 1
                    AND max_value = 999999999999999
                    AND cache_size = 100
                    AND cycle_flag = 'N'
                   THEN 0
                   ELSE 1
               END
           )
      INTO l_sequence_count, l_invalid_count
      FROM user_sequences
     WHERE sequence_name IN (
         'SEQ_BATCH_EXECUTION',
         'SEQ_MIGRATION_RECONCILIATION'
     );

    IF l_sequence_count != 2 OR l_invalid_count != 0 THEN
        RAISE_APPLICATION_ERROR(
            -20081,
            'Operational sequences are missing or have unexpected settings.'
        );
    END IF;
END;
/

DECLARE
    l_expected_constraints SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'BATCH_EXECUTIONS_ID_NN',
        'BATCH_EXECUTIONS_TYPE_NN',
        'BATCH_EXECUTIONS_IDEMP_NN',
        'BATCH_EXECUTIONS_STATUS_NN',
        'BATCH_EXEC_REQUESTED_BY_NN',
        'BATCH_EXEC_REQUESTED_AT_NN',
        'BATCH_EXECUTIONS_RETRY_NN',
        'BATCH_EXECUTIONS_TOTAL_NN',
        'BATCH_EXECUTIONS_SUCCEEDED_NN',
        'BATCH_EXECUTIONS_FAILED_NN',
        'BATCH_EXECUTIONS_CREATED_BY_NN',
        'BATCH_EXECUTIONS_CREATED_AT_NN',
        'BATCH_EXECUTIONS_PK',
        'BATCH_EXECUTIONS_IDEMP_KEY_UQ',
        'BATCH_EXECUTIONS_STATUS_CK',
        'BATCH_EXECUTIONS_RETRY_CK',
        'BATCH_EXECUTIONS_TOTAL_CK',
        'BATCH_EXECUTIONS_DATES_CK',
        'MIG_RECON_ID_NN',
        'MIG_RECON_BATCH_ID_NN',
        'MIG_RECON_OBJECT_NN',
        'MIG_RECON_SOURCE_NN',
        'MIG_RECON_TARGET_NN',
        'MIG_RECON_MISSING_NN',
        'MIG_RECON_EXTRA_NN',
        'MIG_RECON_STATUS_NN',
        'MIG_RECON_CREATED_BY_NN',
        'MIG_RECON_CREATED_AT_NN',
        'MIG_RECONCILIATIONS_PK',
        'MIG_RECON_BATCH_OBJ_UQ',
        'MIG_RECON_BATCH_FK',
        'MIG_RECON_STATUS_CK',
        'MIG_RECON_COUNTS_CK',
        'MIG_RECON_AGG_JSON_CK'
    );
    l_constraint_count PLS_INTEGER;
BEGIN
    FOR i IN 1 .. l_expected_constraints.COUNT LOOP
        SELECT COUNT(*)
          INTO l_constraint_count
          FROM user_constraints
         WHERE constraint_name = l_expected_constraints(i)
           AND table_name IN (
               'BATCH_EXECUTIONS',
               'MIGRATION_RECONCILIATIONS'
           )
           AND status = 'ENABLED';

        IF l_constraint_count != 1 THEN
            RAISE_APPLICATION_ERROR(
                -20082,
                'Required operational constraint is missing or disabled: '
                    || l_expected_constraints(i)
            );
        END IF;
    END LOOP;
END;
/
