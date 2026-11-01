-- ============================================================================
-- Generic audit triggers
-- APEX actor, session, and client address are resolved by PKG_AUDIT from the
-- authenticated server-side context; caller-supplied usernames are not trusted.
-- ============================================================================

CREATE OR REPLACE TRIGGER HRMS.TRG_SALARY_AUDIT
AFTER INSERT OR UPDATE OR DELETE ON HRMS.SALARY_RECORDS
FOR EACH ROW
DECLARE
    v_action   VARCHAR2(20);
    v_old_json CLOB;
    v_new_json CLOB;
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        SELECT JSON_OBJECT(
                   'employee_id' VALUE :NEW.EMP_ID,
                   'salary' VALUE :NEW.BASE_SALARY,
                   'effective_date' VALUE :NEW.EFFECTIVE_DATE
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_new_json
          FROM dual;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        SELECT JSON_OBJECT(
                   'employee_id' VALUE :OLD.EMP_ID,
                   'salary' VALUE :OLD.BASE_SALARY,
                   'active' VALUE :OLD.ACTIVE_FLAG,
                   'effective_date' VALUE :OLD.EFFECTIVE_DATE
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_old_json
          FROM dual;
        SELECT JSON_OBJECT(
                   'employee_id' VALUE :NEW.EMP_ID,
                   'salary' VALUE :NEW.BASE_SALARY,
                   'active' VALUE :NEW.ACTIVE_FLAG,
                   'effective_date' VALUE :NEW.EFFECTIVE_DATE
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_new_json
          FROM dual;
    ELSE
        v_action := 'DELETE';
        SELECT JSON_OBJECT(
                   'employee_id' VALUE :OLD.EMP_ID,
                   'salary' VALUE :OLD.BASE_SALARY,
                   'effective_date' VALUE :OLD.EFFECTIVE_DATE
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_old_json
          FROM dual;
    END IF;

    HRMS.PKG_AUDIT.log_action(
        p_table_name => 'SALARY_RECORDS',
        p_record_id  => NVL(:NEW.SALARY_ID, :OLD.SALARY_ID),
        p_action     => v_action,
        p_user       => NVL(:NEW.MODIFIED_BY, NVL(:OLD.MODIFIED_BY, USER)),
        p_old_values => v_old_json,
        p_new_values => v_new_json
    );
END TRG_SALARY_AUDIT;
/

CREATE OR REPLACE TRIGGER HRMS.TRG_LEAVE_REQUEST_AUDIT
AFTER UPDATE OF STATUS ON HRMS.LEAVE_REQUESTS
FOR EACH ROW
DECLARE
    v_old_json CLOB;
    v_new_json CLOB;
BEGIN
    SELECT JSON_OBJECT(
               'status' VALUE :OLD.STATUS
               NULL ON NULL RETURNING CLOB
           )
      INTO v_old_json
      FROM dual;
    SELECT JSON_OBJECT(
               'status' VALUE :NEW.STATUS
               NULL ON NULL RETURNING CLOB
           )
      INTO v_new_json
      FROM dual;

    HRMS.PKG_AUDIT.log_action(
        p_table_name => 'LEAVE_REQUESTS',
        p_record_id  => :NEW.REQUEST_ID,
        p_action     => 'STATUS_CHANGE',
        p_user       => NVL(:NEW.MODIFIED_BY, USER),
        p_old_values => v_old_json,
        p_new_values => v_new_json
    );
END TRG_LEAVE_REQUEST_AUDIT;
/

CREATE OR REPLACE TRIGGER HRMS.TRG_DEPARTMENT_AUDIT
AFTER INSERT OR UPDATE OR DELETE ON HRMS.DEPARTMENTS
FOR EACH ROW
DECLARE
    v_action   VARCHAR2(20);
    v_old_json CLOB;
    v_new_json CLOB;
BEGIN
    IF INSERTING THEN
        v_action := 'INSERT';
        SELECT JSON_OBJECT(
                   'department_code' VALUE :NEW.DEPT_CODE,
                   'department_name' VALUE :NEW.DEPT_NAME,
                   'parent_department_id' VALUE :NEW.PARENT_DEPT_ID,
                   'manager_employee_id' VALUE :NEW.MANAGER_EMP_ID
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_new_json
          FROM dual;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        SELECT JSON_OBJECT(
                   'department_code' VALUE :OLD.DEPT_CODE,
                   'department_name' VALUE :OLD.DEPT_NAME,
                   'parent_department_id' VALUE :OLD.PARENT_DEPT_ID,
                   'manager_employee_id' VALUE :OLD.MANAGER_EMP_ID
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_old_json
          FROM dual;
        SELECT JSON_OBJECT(
                   'department_code' VALUE :NEW.DEPT_CODE,
                   'department_name' VALUE :NEW.DEPT_NAME,
                   'parent_department_id' VALUE :NEW.PARENT_DEPT_ID,
                   'manager_employee_id' VALUE :NEW.MANAGER_EMP_ID
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_new_json
          FROM dual;
    ELSE
        v_action := 'DELETE';
        SELECT JSON_OBJECT(
                   'department_code' VALUE :OLD.DEPT_CODE,
                   'department_name' VALUE :OLD.DEPT_NAME,
                   'parent_department_id' VALUE :OLD.PARENT_DEPT_ID,
                   'manager_employee_id' VALUE :OLD.MANAGER_EMP_ID
                   NULL ON NULL RETURNING CLOB
               )
          INTO v_old_json
          FROM dual;
    END IF;

    HRMS.PKG_AUDIT.log_action(
        p_table_name => 'DEPARTMENTS',
        p_record_id  => NVL(:NEW.DEPT_ID, :OLD.DEPT_ID),
        p_action     => v_action,
        p_user       => NVL(:NEW.MODIFIED_BY, NVL(:OLD.MODIFIED_BY, USER)),
        p_old_values => v_old_json,
        p_new_values => v_new_json
    );
END TRG_DEPARTMENT_AUDIT;
/
