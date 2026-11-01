SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    TYPE t_names IS TABLE OF VARCHAR2(128);

    l_required_tables t_names := t_names(
        'DEPARTMENTS',
        'LOCATIONS',
        'JOB_GRADES',
        'JOB_TITLES',
        'EMPLOYEES',
        'EMPLOYEE_HISTORY',
        'EMPLOYEE_DEPENDENTS',
        'EMERGENCY_CONTACTS',
        'SALARY_RECORDS',
        'PAY_ELEMENTS',
        'EMPLOYEE_PAY_ELEMENTS',
        'PAY_PERIODS',
        'PAYROLL_RUNS',
        'PAYROLL_DETAILS',
        'TAX_BRACKETS',
        'EMPLOYEE_TAX_INFO',
        'EMPLOYEE_BANK_ACCOUNTS',
        'LEAVE_TYPES',
        'LEAVE_BALANCES',
        'LEAVE_REQUESTS',
        'LEAVE_ACCRUAL_LOG',
        'HOLIDAYS',
        'REVIEW_CYCLES',
        'PERFORMANCE_REVIEWS',
        'PERFORMANCE_GOALS',
        'AUDIT_LOG',
        'SYSTEM_PARAMETERS',
        'NOTIFICATION_QUEUE',
        'USER_SESSIONS',
        'LOOKUP_VALUES',
        'BATCH_EXECUTIONS',
        'MIGRATION_RECONCILIATIONS',
        'HRMS_USER_IDENTITIES',
        'HRMS_ROLES',
        'HRMS_ACTIONS',
        'HRMS_ROLE_ACTIONS',
        'HRMS_USER_ROLES',
        'HRMS_EMPLOYEE_SCOPE_DELEGATIONS'
    );
    l_required_sequences t_names := t_names(
        'SEQ_DEPARTMENT',
        'SEQ_LOCATION',
        'SEQ_JOB_GRADE',
        'SEQ_JOB_TITLE',
        'SEQ_EMPLOYEE',
        'SEQ_EMP_HISTORY',
        'SEQ_DEPENDENT',
        'SEQ_EMERGENCY_CONTACT',
        'SEQ_SALARY',
        'SEQ_PAY_ELEMENT',
        'SEQ_EMP_PAY_ELEMENT',
        'SEQ_PAY_PERIOD',
        'SEQ_PAYROLL_RUN',
        'SEQ_PAYROLL_DETAIL',
        'SEQ_TAX_BRACKET',
        'SEQ_LEAVE_TYPE',
        'SEQ_LEAVE_BALANCE',
        'SEQ_LEAVE_REQUEST',
        'SEQ_LEAVE_ACCRUAL',
        'SEQ_HOLIDAY',
        'SEQ_REVIEW_CYCLE',
        'SEQ_PERF_REVIEW',
        'SEQ_PERF_GOAL',
        'SEQ_AUDIT',
        'SEQ_NOTIFICATION',
        'SEQ_USER_SESSION',
        'SEQ_SYSTEM_PARAM',
        'SEQ_LOOKUP',
        'SEQ_BATCH_EXECUTION',
        'SEQ_MIGRATION_RECONCILIATION'
    );
    l_required_packages t_names := t_names(
        'PKG_COMMON',
        'PKG_AUDIT',
        'PKG_APP_ERRORS',
        'PKG_APP_CONTEXT',
        'PKG_BATCH',
        'PKG_EMPLOYEE',
        'PKG_ORGANIZATION',
        'PKG_INTEGRATION',
        'PKG_LEAVE',
        'PKG_NOTIFICATION',
        'PKG_PAYROLL',
        'PKG_PERFORMANCE',
        'PKG_REPORTING',
        'PKG_SECURITY',
        'PKG_VALIDATION'
    );
    l_required_views t_names := t_names(
        'VW_ACTIVE_EMPLOYEES',
        'VW_ORG_HIERARCHY',
        'VW_EMPLOYEE_COMPENSATION',
        'VW_LEAVE_SUMMARY',
        'VW_PAYROLL_LATEST',
        'VW_PENDING_APPROVALS',
        'VW_APP_USER_PERMISSIONS',
        'VW_APP_EMPLOYEE_SCOPE',
        'VW_APP_EMPLOYEES',
        'VW_APP_EMPLOYEE_ORGANIZATION',
        'VW_APP_EMPLOYEE_HIERARCHY',
        'VW_APP_EMPLOYEE_PROFILE',
        'VW_APP_EMPLOYEE_DEPENDENTS',
        'VW_APP_EMPLOYEE_CONTACTS',
        'VW_APP_EMPLOYEE_HISTORY',
        'VW_APP_EMPLOYEE_AUDIT',
        'VW_APP_ORG_DEPARTMENTS',
        'VW_APP_ORG_LOCATIONS',
        'VW_APP_ORG_JOB_GRADES',
        'VW_APP_ORG_JOB_TITLES'
    );
    l_required_constraints t_names := t_names(
        'CHK_AUDIT_ACTION',
        'BATCH_EXECUTIONS_PK',
        'BATCH_EXECUTIONS_IDEMP_KEY_UQ',
        'BATCH_EXECUTIONS_STATUS_CK',
        'MIG_RECONCILIATIONS_PK',
        'MIG_RECON_BATCH_OBJ_UQ',
        'MIG_RECON_BATCH_FK',
        'MIG_RECON_STATUS_CK'
    );
    l_object_count PLS_INTEGER;
    l_invalid_count PLS_INTEGER;

    PROCEDURE assert_present(
        in_object_type IN VARCHAR2,
        in_object_name IN VARCHAR2
    ) IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM USER_OBJECTS object_record
         WHERE object_record.OBJECT_TYPE = in_object_type
           AND object_record.OBJECT_NAME = in_object_name
           AND object_record.STATUS = 'VALID';

        IF v_count != 1 THEN
            RAISE_APPLICATION_ERROR(
                -20210,
                'Required valid ' || in_object_type || ' is missing: ' || in_object_name
            );
        END IF;
    END assert_present;
BEGIN
    IF SYS_CONTEXT('USERENV', 'SESSION_USER') != 'HRMS' THEN
        RAISE_APPLICATION_ERROR(-20211, 'Run foundation checks while connected as HRMS.');
    END IF;

    FOR i IN 1 .. l_required_tables.COUNT LOOP
        SELECT COUNT(*)
          INTO l_object_count
          FROM USER_TABLES table_record
         WHERE table_record.TABLE_NAME = l_required_tables(i);

        IF l_object_count != 1 THEN
            RAISE_APPLICATION_ERROR(
                -20212,
                'Required table is missing: ' || l_required_tables(i)
            );
        END IF;
    END LOOP;

    FOR i IN 1 .. l_required_sequences.COUNT LOOP
        SELECT COUNT(*)
          INTO l_object_count
          FROM USER_SEQUENCES sequence_record
         WHERE sequence_record.SEQUENCE_NAME = l_required_sequences(i);

        IF l_object_count != 1 THEN
            RAISE_APPLICATION_ERROR(
                -20213,
                'Required sequence is missing: ' || l_required_sequences(i)
            );
        END IF;
    END LOOP;

    FOR i IN 1 .. l_required_packages.COUNT LOOP
        assert_present('PACKAGE', l_required_packages(i));
        assert_present('PACKAGE BODY', l_required_packages(i));
    END LOOP;

    FOR i IN 1 .. l_required_views.COUNT LOOP
        assert_present('VIEW', l_required_views(i));
    END LOOP;

    SELECT COUNT(*)
      INTO l_invalid_count
      FROM USER_OBJECTS object_record
     WHERE object_record.STATUS = 'INVALID'
       AND object_record.OBJECT_TYPE IN (
           'FUNCTION',
           'PACKAGE',
           'PACKAGE BODY',
           'PROCEDURE',
           'TRIGGER',
           'VIEW'
       );

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20214, 'Invalid PL/SQL or view objects remain in the HRMS schema.');
    END IF;

    SELECT COUNT(*)
      INTO l_invalid_count
      FROM USER_ERRORS error_record;

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20215, 'Compilation errors remain in the HRMS schema.');
    END IF;

    SELECT COUNT(*)
      INTO l_invalid_count
      FROM USER_CONSTRAINTS constraint_record
     WHERE constraint_record.STATUS != 'ENABLED'
        OR constraint_record.VALIDATED != 'VALIDATED';

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20216, 'Disabled or unvalidated constraints remain in the HRMS schema.');
    END IF;

    FOR i IN 1 .. l_required_constraints.COUNT LOOP
        SELECT COUNT(*)
          INTO l_object_count
          FROM USER_CONSTRAINTS constraint_record
         WHERE constraint_record.CONSTRAINT_NAME = l_required_constraints(i)
           AND constraint_record.STATUS = 'ENABLED'
           AND constraint_record.VALIDATED = 'VALIDATED';

        IF l_object_count != 1 THEN
            RAISE_APPLICATION_ERROR(
                -20217,
                'Required enabled constraint is missing: ' || l_required_constraints(i)
            );
        END IF;
    END LOOP;

    SELECT COUNT(*)
      INTO l_object_count
      FROM USER_CONSTRAINTS audit_constraint
     WHERE audit_constraint.CONSTRAINT_NAME = 'CHK_AUDIT_ACTION'
       AND audit_constraint.SEARCH_CONDITION_VC LIKE '%ERROR%';

    IF l_object_count != 1 THEN
        RAISE_APPLICATION_ERROR(-20220, 'The audit action constraint does not permit normalized errors.');
    END IF;

    SELECT COUNT(*)
      INTO l_object_count
      FROM USER_TAB_COLUMNS view_column
     WHERE view_column.TABLE_NAME = 'VW_APP_EMPLOYEE_ORGANIZATION'
       AND view_column.COLUMN_NAME IN ('HIRE_DATE', 'LOCATION_CODE');

    IF l_object_count != 2 THEN
        RAISE_APPLICATION_ERROR(
            -20222,
            'The employee organization view must expose hire date and location for authorized search.'
        );
    END IF;

    SELECT COUNT(*)
      INTO l_object_count
      FROM USER_TAB_COLUMNS view_column
     WHERE view_column.TABLE_NAME = 'VW_APP_ORG_DEPARTMENTS'
       AND view_column.COLUMN_NAME = 'MANAGER_EMP_ID';

    IF l_object_count != 1 THEN
        RAISE_APPLICATION_ERROR(
            -20223,
            'The organization department view must expose the department manager reference.'
        );
    END IF;

    FOR actor_table IN (
        SELECT 'DEPARTMENTS' TABLE_NAME FROM DUAL
        UNION ALL SELECT 'LOCATIONS' FROM DUAL
        UNION ALL SELECT 'JOB_GRADES' FROM DUAL
        UNION ALL SELECT 'JOB_TITLES' FROM DUAL
        UNION ALL SELECT 'EMPLOYEES' FROM DUAL
        UNION ALL SELECT 'EMPLOYEE_HISTORY' FROM DUAL
        UNION ALL SELECT 'EMPLOYEE_DEPENDENTS' FROM DUAL
        UNION ALL SELECT 'EMERGENCY_CONTACTS' FROM DUAL
        UNION ALL SELECT 'SALARY_RECORDS' FROM DUAL
        UNION ALL SELECT 'EMPLOYEE_PAY_ELEMENTS' FROM DUAL
        UNION ALL SELECT 'LEAVE_REQUESTS' FROM DUAL
        UNION ALL SELECT 'NOTIFICATION_QUEUE' FROM DUAL
    ) LOOP
        SELECT COUNT(*)
          INTO l_object_count
          FROM USER_TAB_COLUMNS actor_column
         WHERE actor_column.TABLE_NAME = actor_table.TABLE_NAME
           AND actor_column.COLUMN_NAME IN ('CREATED_BY', 'MODIFIED_BY')
           AND actor_column.DATA_TYPE = 'VARCHAR2'
           AND actor_column.CHAR_LENGTH >= 255;

        IF l_object_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20221,
                'Actor columns do not support OIDC subjects on ' || actor_table.TABLE_NAME
            );
        END IF;
    END LOOP;

    SELECT COUNT(*)
      INTO l_invalid_count
      FROM USER_TAB_PRIVS_MADE privilege_record
     WHERE privilege_record.GRANTEE = 'PUBLIC';

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20218, 'The HRMS schema grants object privileges to PUBLIC.');
    END IF;

    SELECT COUNT(*)
      INTO l_invalid_count
      FROM USER_SYS_PRIVS privilege_record
     WHERE privilege_record.PRIVILEGE LIKE '%ANY%'
        OR privilege_record.PRIVILEGE IN (
            'ALTER SYSTEM',
            'CREATE USER',
            'ALTER USER',
            'DROP USER',
            'GRANT ANY PRIVILEGE'
        );

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20219, 'The HRMS schema has an administrative system privilege.');
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        'PASS: required schema objects, valid compilations, enabled constraints, and least-privilege checks.'
    );
END;
/

EXIT SUCCESS
