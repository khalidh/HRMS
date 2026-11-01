-- Install the HRMS schema in a dedicated, empty test database/schema only.
-- Invoke as HRMS with:
--   @00_install_test.sql INSTALL_EMPTY_HRMS_TEST_SCHEMA
-- DDL commits implicitly; this script is not a transactional rollback unit.

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON
SET DEFINE ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    c_confirmation CONSTANT VARCHAR2(40) := '&&1';
    v_object_count PLS_INTEGER;
BEGIN
    IF USER != 'HRMS' THEN
        RAISE_APPLICATION_ERROR(-20201, 'Connect as the HRMS schema owner in the isolated test database.');
    END IF;

    IF c_confirmation != 'INSTALL_EMPTY_HRMS_TEST_SCHEMA' THEN
        RAISE_APPLICATION_ERROR(-20202, 'Explicit test-schema installation confirmation is required.');
    END IF;

    SELECT COUNT(*)
      INTO v_object_count
      FROM USER_OBJECTS existing_object;

    IF v_object_count != 0 THEN
        RAISE_APPLICATION_ERROR(
            -20203,
            'Refusing installation: HRMS schema is not empty. Use a dedicated test database/schema.'
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('Preflight passed: empty HRMS schema in confirmed test environment.');
END;
/

SET DEFINE OFF

@@../schema/tables/01_core_tables.sql
@@../schema/tables/02_payroll_tables.sql
@@../schema/tables/03_leave_tables.sql
@@../schema/tables/04_performance_tables.sql
@@../schema/tables/05_operational_tables.sql
@@../schema/tables/06_security_tables.sql
@@../schema/tables/07_audit_context.sql
@@../schema/tables/08_batch_actor.sql

@@../schema/sequences/hrms_sequences.sql
@@../schema/sequences/hrms_operational_sequences.sql

@@../plsql/packages/PKG_COMMON.pks
@@../plsql/packages/PKG_AUDIT.pks
@@../plsql/packages/PKG_APP_CONTEXT.pks
@@../plsql/packages/PKG_BATCH.pks
@@../plsql/packages/PKG_EMPLOYEE.pks
@@../plsql/packages/PKG_INTEGRATION.pks
@@../plsql/packages/PKG_LEAVE.pks
@@../plsql/packages/PKG_NOTIFICATION.pks
@@../plsql/packages/PKG_PAYROLL.pks
@@../plsql/packages/PKG_PERFORMANCE.pks
@@../plsql/packages/PKG_REPORTING.pks
@@../plsql/packages/PKG_SECURITY.pks
@@../plsql/packages/PKG_VALIDATION.pks

@@../plsql/packages/PKG_APP_CONTEXT.pkb
@@../plsql/packages/PKG_AUDIT.pkb
@@../plsql/packages/PKG_BATCH.pkb
@@../plsql/packages/PKG_COMMON.pkb
@@../plsql/packages/PKG_EMPLOYEE.pkb
@@../plsql/packages/PKG_INTEGRATION.pkb
@@../plsql/packages/PKG_LEAVE.pkb
@@../plsql/packages/PKG_NOTIFICATION.pkb
@@../plsql/packages/PKG_PAYROLL.pkb
@@../plsql/packages/PKG_PERFORMANCE.pkb
@@../plsql/packages/PKG_REPORTING.pkb
@@../plsql/packages/PKG_SECURITY.pkb
@@../plsql/packages/PKG_VALIDATION.pkb

@@../schema/views/hrms_views.sql
@@../schema/views/hrms_security_views.sql
@@../plsql/triggers/trg_employees.sql
@@../plsql/triggers/trg_audit.sql

DECLARE
    v_invalid_count PLS_INTEGER;
    v_missing_count PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_invalid_count
      FROM USER_OBJECTS installed_object
     WHERE installed_object.STATUS = 'INVALID'
       AND installed_object.OBJECT_TYPE IN ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'TRIGGER');

    IF v_invalid_count > 0 THEN
        FOR invalid_object IN (
            SELECT installed_object.OBJECT_NAME, installed_object.OBJECT_TYPE
              FROM USER_OBJECTS installed_object
             WHERE installed_object.STATUS = 'INVALID'
               AND installed_object.OBJECT_TYPE IN ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'TRIGGER')
             ORDER BY installed_object.OBJECT_NAME, installed_object.OBJECT_TYPE
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                'INVALID ' || invalid_object.OBJECT_TYPE || ' ' || invalid_object.OBJECT_NAME
            );
        END LOOP;

        RAISE_APPLICATION_ERROR(-20204, 'One or more HRMS packages, views, or triggers are invalid.');
    END IF;

    SELECT COUNT(*)
      INTO v_missing_count
      FROM (
            SELECT 'BATCH_EXECUTIONS' OBJECT_NAME FROM DUAL
            UNION ALL SELECT 'MIGRATION_RECONCILIATIONS' FROM DUAL
            UNION ALL SELECT 'HRMS_USER_IDENTITIES' FROM DUAL
            UNION ALL SELECT 'HRMS_ROLES' FROM DUAL
            UNION ALL SELECT 'HRMS_ACTIONS' FROM DUAL
            UNION ALL SELECT 'HRMS_ROLE_ACTIONS' FROM DUAL
            UNION ALL SELECT 'HRMS_USER_ROLES' FROM DUAL
            UNION ALL SELECT 'HRMS_EMPLOYEE_SCOPE_DELEGATIONS' FROM DUAL
           ) expected_object
     WHERE NOT EXISTS (
           SELECT 1
             FROM USER_TABLES installed_table
            WHERE installed_table.TABLE_NAME = expected_object.OBJECT_NAME
       );

    IF v_missing_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20205, 'Required HRMS foundation tables are missing.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('PASS: HRMS test schema installation and object compilation.');
END;
/

EXIT SUCCESS
