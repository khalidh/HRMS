-- ============================================================================
-- HRMS context-aware security views
-- Requires 01_core_tables.sql, 06_security_tables.sql, and PKG_APP_CONTEXT.
-- These views fail closed when no authenticated APEX context is initialized.
-- ============================================================================

CREATE OR REPLACE VIEW HRMS.VW_APP_USER_PERMISSIONS AS
SELECT DISTINCT role_action.ROLE_CODE,
                role_action.MODULE_CODE,
                role_action.ACTION_CODE
  FROM HRMS.HRMS_USER_ROLES user_role
  JOIN HRMS.HRMS_ROLES app_role
    ON app_role.ROLE_CODE = user_role.ROLE_CODE
  JOIN HRMS.HRMS_ROLE_ACTIONS role_action
    ON role_action.ROLE_CODE = app_role.ROLE_CODE
  JOIN HRMS.HRMS_ACTIONS app_action
    ON app_action.MODULE_CODE = role_action.MODULE_CODE
   AND app_action.ACTION_CODE = role_action.ACTION_CODE
 WHERE user_role.EMP_ID = HRMS.PKG_APP_CONTEXT.GET_EMPLOYEE_ID()
   AND user_role.ACTIVE_FLAG = 'Y'
   AND user_role.VALID_FROM <= SYSDATE
   AND (user_role.VALID_TO IS NULL OR user_role.VALID_TO > SYSDATE)
   AND app_role.ACTIVE_FLAG = 'Y'
   AND role_action.ACTIVE_FLAG = 'Y'
   AND role_action.VALID_FROM <= SYSDATE
   AND (role_action.VALID_TO IS NULL OR role_action.VALID_TO > SYSDATE)
   AND app_action.ACTIVE_FLAG = 'Y';

COMMENT ON TABLE HRMS.VW_APP_USER_PERMISSIONS IS
    'Effective module/action grants for the authenticated APEX employee; no implicit role grants.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_SCOPE AS
SELECT DISTINCT scoped.EMP_ID
  FROM (
        SELECT HRMS.PKG_APP_CONTEXT.GET_EMPLOYEE_ID() AS EMP_ID
          FROM dual
        UNION
        SELECT employee.EMP_ID
          FROM HRMS.EMPLOYEES employee
         WHERE EXISTS (
               SELECT 1
                 FROM HRMS.VW_APP_USER_PERMISSIONS permission
                WHERE permission.ROLE_CODE = 'MANAGER'
                  AND permission.MODULE_CODE = 'EMPLOYEE'
                  AND permission.ACTION_CODE = 'VIEW'
           )
         START WITH employee.EMP_ID = HRMS.PKG_APP_CONTEXT.GET_EMPLOYEE_ID()
       CONNECT BY NOCYCLE PRIOR employee.EMP_ID = employee.MANAGER_EMP_ID
        UNION
        SELECT employee.EMP_ID
          FROM HRMS.EMPLOYEES employee
         WHERE EXISTS (
               SELECT 1
                 FROM HRMS.VW_APP_USER_PERMISSIONS permission
                WHERE permission.ROLE_CODE = 'MANAGER'
                  AND permission.MODULE_CODE = 'EMPLOYEE'
                  AND permission.ACTION_CODE = 'VIEW'
           )
         START WITH employee.EMP_ID IN (
               SELECT delegation.DELEGATOR_EMP_ID
                 FROM HRMS.HRMS_EMPLOYEE_SCOPE_DELEGATIONS delegation
                 JOIN HRMS.EMPLOYEES delegator
                   ON delegator.EMP_ID = delegation.DELEGATOR_EMP_ID
                WHERE delegation.DELEGATE_EMP_ID = HRMS.PKG_APP_CONTEXT.GET_EMPLOYEE_ID()
                  AND delegation.ACTIVE_FLAG = 'Y'
                  AND delegation.VALID_FROM <= SYSDATE
                  AND (delegation.VALID_TO IS NULL OR delegation.VALID_TO > SYSDATE)
                  AND delegator.EMPLOYMENT_STATUS = 'ACTIVE'
                  AND delegator.ACTIVE_FLAG = 'Y'
           )
       CONNECT BY NOCYCLE PRIOR employee.EMP_ID = employee.MANAGER_EMP_ID
        UNION
        SELECT employee.EMP_ID
          FROM HRMS.EMPLOYEES employee
         WHERE EXISTS (
               SELECT 1
                 FROM HRMS.VW_APP_USER_PERMISSIONS permission
                WHERE permission.ROLE_CODE IN ('HR', 'AUDITOR')
                  AND permission.MODULE_CODE = 'EMPLOYEE'
                  AND permission.ACTION_CODE = 'VIEW'
           )
       ) scoped
  JOIN HRMS.EMPLOYEES target
    ON target.EMP_ID = scoped.EMP_ID
 WHERE (target.EMPLOYMENT_STATUS = 'ACTIVE' AND target.ACTIVE_FLAG = 'Y')
    OR EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.ROLE_CODE IN ('HR', 'AUDITOR')
          AND permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_SCOPE IS
    'Employee scope: self, active manager/delegated hierarchy, or HR/auditor records when EMPLOYEE.VIEW is explicitly granted.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEES AS
SELECT employee.EMP_ID,
       employee.EMP_NUMBER,
       employee.FIRST_NAME,
       employee.MIDDLE_NAME,
       employee.LAST_NAME,
       employee.FIRST_NAME || ' ' || employee.LAST_NAME AS FULL_NAME,
       employee.HIRE_DATE,
       employee.EMPLOYMENT_TYPE,
       employee.EMPLOYMENT_STATUS,
       employee.DEPT_ID,
       employee.JOB_ID,
       employee.MANAGER_EMP_ID,
       employee.LOCATION_CODE
  FROM HRMS.EMPLOYEES employee
  JOIN HRMS.VW_APP_EMPLOYEE_SCOPE scope
    ON scope.EMP_ID = employee.EMP_ID
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEES IS
    'Employee list limited to the authenticated user scope and explicit EMPLOYEE.VIEW authorization; excludes sensitive columns.';
