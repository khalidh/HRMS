-- ============================================================================
-- Secure employee and organization views for APEX User Story 1.
-- Requires hrms_security_views.sql and the corresponding explicit grants.
-- ============================================================================

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_ORGANIZATION AS
SELECT employee.EMP_ID,
       employee.EMP_NUMBER,
employee.FIRST_NAME,
employee.LAST_NAME,
employee.FULL_NAME,
employee.HIRE_DATE,
employee.EMPLOYMENT_STATUS,
       employee.DEPT_ID,
       department.DEPT_CODE,
       department.DEPT_NAME,
       department.PARENT_DEPT_ID,
       employee.JOB_ID,
       job_title.JOB_CODE,
       job_title.JOB_TITLE,
       job_title.GRADE_ID,
       job_grade.GRADE_CODE,
       job_grade.GRADE_NAME,
       employee.MANAGER_EMP_ID,
       manager.FULL_NAME AS MANAGER_NAME,
       employee.LOCATION_CODE,
       location.LOCATION_NAME
  FROM HRMS.VW_APP_EMPLOYEES employee
  JOIN HRMS.DEPARTMENTS department
    ON department.DEPT_ID = employee.DEPT_ID
  JOIN HRMS.JOB_TITLES job_title
    ON job_title.JOB_ID = employee.JOB_ID
  JOIN HRMS.JOB_GRADES job_grade
    ON job_grade.GRADE_ID = job_title.GRADE_ID
  LEFT JOIN HRMS.VW_APP_EMPLOYEES manager
    ON manager.EMP_ID = employee.MANAGER_EMP_ID
  LEFT JOIN HRMS.LOCATIONS location
    ON location.LOCATION_CODE = employee.LOCATION_CODE
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_ORGANIZATION IS
    'Authorized employee organization details; rows inherit the employee-view scope and expose no pay or personal contact fields.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_HIERARCHY AS
SELECT employee.EMP_ID,
       employee.EMP_NUMBER,
       employee.FULL_NAME,
       employee.DEPT_ID,
       employee.JOB_ID,
       employee.MANAGER_EMP_ID,
       LEVEL AS ORG_LEVEL,
       CONNECT_BY_ROOT employee.EMP_ID AS ROOT_EMP_ID,
       SYS_CONNECT_BY_PATH(TO_CHAR(employee.EMP_ID), '/') AS EMPLOYEE_PATH,
       CONNECT_BY_ISLEAF AS IS_LEAF
  FROM (
        SELECT scoped_employee.*,
               CASE
                   WHEN scoped_employee.MANAGER_EMP_ID IS NULL
                    AND EXISTS (
                        SELECT 1
                          FROM HRMS.VW_APP_USER_PERMISSIONS permission
                         WHERE permission.ROLE_CODE IN ('HR', 'AUDITOR')
                           AND permission.MODULE_CODE = 'EMPLOYEE'
                           AND permission.ACTION_CODE = 'VIEW'
                    )
                   THEN 1
                   ELSE 0
               END AS AUTHORIZED_ROOT
          FROM HRMS.VW_APP_EMPLOYEES scoped_employee
       ) employee
 START WITH employee.EMP_ID = HRMS.PKG_APP_CONTEXT.GET_EMPLOYEE_ID()
        OR employee.AUTHORIZED_ROOT = 1
CONNECT BY NOCYCLE PRIOR employee.EMP_ID = employee.MANAGER_EMP_ID;

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_HIERARCHY IS
    'Employee hierarchy rooted at the authenticated employee or authorized organization roots; every row is scope-filtered.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_PROFILE AS
SELECT employee.EMP_ID,
       employee.EMP_NUMBER,
       employee.FIRST_NAME,
       employee.MIDDLE_NAME,
       employee.LAST_NAME,
       employee.EMAIL,
       employee.PHONE_WORK,
       employee.PHONE_MOBILE,
       employee.ADDRESS_LINE1,
       employee.ADDRESS_LINE2,
       employee.CITY,
       employee.STATE_PROVINCE,
       employee.POSTAL_CODE,
       employee.COUNTRY_CODE
  FROM HRMS.EMPLOYEES employee
  JOIN HRMS.VW_APP_EMPLOYEES scoped_employee
    ON scoped_employee.EMP_ID = employee.EMP_ID
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'PROFILE_VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_PROFILE IS
    'Authorized profile and contact fields; excludes date of birth, national identifiers, and encrypted values.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_DEPENDENTS AS
SELECT dependent.DEPENDENT_ID,
       dependent.EMP_ID,
       dependent.FIRST_NAME,
       dependent.LAST_NAME,
       dependent.RELATIONSHIP,
       dependent.BENEFITS_ENROLLED,
       dependent.ACTIVE_FLAG
  FROM HRMS.EMPLOYEE_DEPENDENTS dependent
  JOIN HRMS.VW_APP_EMPLOYEES scoped_employee
    ON scoped_employee.EMP_ID = dependent.EMP_ID
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'DEPENDENTS_VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_DEPENDENTS IS
    'Authorized dependent details; excludes dates of birth and encrypted national identifiers.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_CONTACTS AS
SELECT contact.CONTACT_ID,
       contact.EMP_ID,
       contact.CONTACT_NAME,
       contact.RELATIONSHIP,
       contact.PHONE_PRIMARY,
       contact.PHONE_SECONDARY,
       contact.EMAIL,
       contact.PRIORITY_ORDER,
       contact.ACTIVE_FLAG
  FROM HRMS.EMERGENCY_CONTACTS contact
  JOIN HRMS.VW_APP_EMPLOYEES scoped_employee
    ON scoped_employee.EMP_ID = contact.EMP_ID
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'CONTACTS_VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_CONTACTS IS
    'Authorized emergency contacts, filtered by employee scope and an explicit contact-view grant.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_HISTORY AS
SELECT history.HIST_ID,
       history.EMP_ID,
       history.CHANGE_TYPE,
       history.EFFECTIVE_DATE,
       history.OLD_DEPT_ID,
       history.NEW_DEPT_ID,
       history.OLD_JOB_ID,
       history.NEW_JOB_ID,
       history.OLD_MANAGER_ID,
       history.NEW_MANAGER_ID,
       history.OLD_LOCATION,
       history.NEW_LOCATION,
       history.REASON_CODE,
       history.CREATED_BY,
       history.CREATED_DATE
  FROM HRMS.EMPLOYEE_HISTORY history
  JOIN HRMS.VW_APP_EMPLOYEES scoped_employee
    ON scoped_employee.EMP_ID = history.EMP_ID
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'EMPLOYEE'
          AND permission.ACTION_CODE = 'HISTORY_VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_HISTORY IS
    'Authorized lifecycle history; excludes salary values and free-text comments.';

CREATE OR REPLACE VIEW HRMS.VW_APP_EMPLOYEE_AUDIT AS
SELECT audit_record.AUDIT_ID,
       audit_record.RECORD_ID AS EMP_ID,
       audit_record.ACTION_TYPE,
       audit_record.CHANGED_BY,
       audit_record.CHANGED_DATE,
       audit_record.SSO_SUBJECT,
       audit_record.APEX_SESSION_ID,
       audit_record.CLIENT_IP_ADDRESS
  FROM HRMS.AUDIT_LOG audit_record
  JOIN HRMS.VW_APP_EMPLOYEES scoped_employee
    ON scoped_employee.EMP_ID = audit_record.RECORD_ID
 WHERE audit_record.TABLE_NAME = 'EMPLOYEES'
   AND EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'AUDIT'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_EMPLOYEE_AUDIT IS
    'Employee audit metadata limited to the authorized employee scope; old and new values are not exposed.';

CREATE OR REPLACE VIEW HRMS.VW_APP_ORG_DEPARTMENTS AS
SELECT department.DEPT_ID,
       department.DEPT_CODE,
       department.DEPT_NAME,
       department.PARENT_DEPT_ID,
       department.COST_CENTER,
       department.MANAGER_EMP_ID,
       department.LOCATION_CODE,
       department.ACTIVE_FLAG
  FROM HRMS.DEPARTMENTS department
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'ORGANIZATION'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_ORG_DEPARTMENTS IS
    'Organization departments available only to authenticated users with ORGANIZATION.VIEW.';

CREATE OR REPLACE VIEW HRMS.VW_APP_ORG_LOCATIONS AS
SELECT location.LOCATION_CODE,
       location.LOCATION_NAME,
       location.CITY,
       location.STATE_PROVINCE,
       location.COUNTRY_CODE,
       location.ACTIVE_FLAG
  FROM HRMS.LOCATIONS location
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'ORGANIZATION'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_ORG_LOCATIONS IS
    'Organization locations available only to authenticated users with ORGANIZATION.VIEW.';

CREATE OR REPLACE VIEW HRMS.VW_APP_ORG_JOB_GRADES AS
SELECT job_grade.GRADE_ID,
       job_grade.GRADE_CODE,
       job_grade.GRADE_NAME,
       job_grade.MIN_SALARY,
       job_grade.MAX_SALARY,
       job_grade.ACTIVE_FLAG
  FROM HRMS.JOB_GRADES job_grade
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'ORGANIZATION'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_ORG_JOB_GRADES IS
    'Authorized job-grade reference data, including approved grade ranges for HR administration.';

CREATE OR REPLACE VIEW HRMS.VW_APP_ORG_JOB_TITLES AS
SELECT job_title.JOB_ID,
       job_title.JOB_CODE,
       job_title.JOB_TITLE,
       job_title.JOB_FAMILY,
       job_title.GRADE_ID,
       job_grade.GRADE_CODE,
       job_grade.GRADE_NAME,
       job_title.ACTIVE_FLAG
  FROM HRMS.JOB_TITLES job_title
  JOIN HRMS.JOB_GRADES job_grade
    ON job_grade.GRADE_ID = job_title.GRADE_ID
 WHERE EXISTS (
       SELECT 1
         FROM HRMS.VW_APP_USER_PERMISSIONS permission
        WHERE permission.MODULE_CODE = 'ORGANIZATION'
          AND permission.ACTION_CODE = 'VIEW'
   );

COMMENT ON TABLE HRMS.VW_APP_ORG_JOB_TITLES IS
    'Authorized job-title reference data, filtered by an explicit ORGANIZATION.VIEW grant.';
