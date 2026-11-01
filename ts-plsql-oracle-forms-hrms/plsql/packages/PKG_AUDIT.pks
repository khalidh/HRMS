CREATE OR REPLACE PACKAGE HRMS.PKG_AUDIT AS
-- ============================================================================
-- PKG_AUDIT - Audit Trail Package
-- Centralized audit logging for all DML operations
--
-- Dependencies: None (base package)
-- Called by: All other packages, database triggers
-- ============================================================================

    PROCEDURE log_action(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_action     IN VARCHAR2,
        p_user       IN VARCHAR2 DEFAULT USER,
        p_old_values IN CLOB DEFAULT NULL,
        p_new_values IN CLOB DEFAULT NULL
    );

    -- Log only code-based export metadata; never pass row values or sensitive filters.
    PROCEDURE log_export(
        in_module_code   IN VARCHAR2,
        in_report_code   IN VARCHAR2,
        in_export_format IN VARCHAR2,
        in_row_count     IN NUMBER,
        in_result        IN VARCHAR2,
        in_reason_code   IN VARCHAR2 DEFAULT NULL
    );

    PROCEDURE purge_old_records(
        p_days_to_keep IN NUMBER DEFAULT 365,
        p_user         IN VARCHAR2 DEFAULT USER
    );

    FUNCTION get_change_history(
        p_table_name IN VARCHAR2,
        p_record_id  IN NUMBER,
        p_from_date  IN DATE DEFAULT NULL,
        p_to_date    IN DATE DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

END PKG_AUDIT;
/
