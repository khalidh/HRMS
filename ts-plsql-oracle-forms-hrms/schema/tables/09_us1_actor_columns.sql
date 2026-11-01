-- Widen audit actor columns used by employee lifecycle and organization flows.
-- Run after the core, payroll, leave, and performance table definitions.

DECLARE
    TYPE t_table_names IS TABLE OF VARCHAR2(30);
    l_tables t_table_names := t_table_names(
        'DEPARTMENTS',
        'LOCATIONS',
        'JOB_GRADES',
        'JOB_TITLES',
        'EMPLOYEES',
        'EMPLOYEE_HISTORY',
        'EMPLOYEE_DEPENDENTS',
        'EMERGENCY_CONTACTS',
        'SALARY_RECORDS',
        'EMPLOYEE_PAY_ELEMENTS',
        'LEAVE_REQUESTS',
        'NOTIFICATION_QUEUE'
    );
    v_table_count PLS_INTEGER;
    v_actor_count PLS_INTEGER;
BEGIN
    IF USER != 'HRMS' THEN
        RAISE_APPLICATION_ERROR(-20106, 'Run actor-column upgrades as the HRMS schema owner.');
    END IF;

    FOR i IN 1 .. l_tables.COUNT LOOP
        SELECT COUNT(*)
          INTO v_table_count
          FROM USER_TABLES table_record
         WHERE table_record.TABLE_NAME = l_tables(i);

        IF v_table_count != 1 THEN
            RAISE_APPLICATION_ERROR(
                -20107,
                'Required employee lifecycle table is missing: ' || l_tables(i)
            );
        END IF;

        SELECT COUNT(*)
          INTO v_actor_count
          FROM USER_TAB_COLUMNS actor_column
         WHERE actor_column.TABLE_NAME = l_tables(i)
           AND actor_column.COLUMN_NAME IN ('CREATED_BY', 'MODIFIED_BY');

        IF v_actor_count = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20108,
                'No actor columns were found on employee lifecycle table: ' || l_tables(i)
            );
        END IF;

        FOR actor_column IN (
            SELECT column_record.COLUMN_NAME,
                   column_record.DATA_TYPE,
                   column_record.CHAR_LENGTH
              FROM USER_TAB_COLUMNS column_record
             WHERE column_record.TABLE_NAME = l_tables(i)
               AND column_record.COLUMN_NAME IN ('CREATED_BY', 'MODIFIED_BY')
        ) LOOP
            IF actor_column.DATA_TYPE != 'VARCHAR2' THEN
                RAISE_APPLICATION_ERROR(
                    -20109,
                    'Unsupported actor-column type on ' || l_tables(i) || '.'
                        || actor_column.COLUMN_NAME
                );
            END IF;

            IF actor_column.CHAR_LENGTH < 255 THEN
                EXECUTE IMMEDIATE
                    'ALTER TABLE HRMS.'
                    || DBMS_ASSERT.SIMPLE_SQL_NAME(l_tables(i))
                    || ' MODIFY ('
                    || DBMS_ASSERT.SIMPLE_SQL_NAME(actor_column.COLUMN_NAME)
                    || ' VARCHAR2(255 CHAR))';
            END IF;
        END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('PASS: employee lifecycle actor columns support 255-character identities.');
END;
/
