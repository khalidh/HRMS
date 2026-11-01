CREATE OR REPLACE PACKAGE HRMS.PKG_APP_CONTEXT AS
-- ============================================================================
-- PKG_APP_CONTEXT - Authenticated APEX identity and employee data scope
--
-- Call initialize_context from a Page 0 process on every authenticated
-- request. It reads the identity from the APEX engine; callers cannot supply
-- or override the user, session, or employee identity.
--
-- Employee resolution uses APEX APP_USER, which must be the stable OIDC
-- subject mapped by T010 in HRMS_USER_IDENTITIES (SSO_SUBJECT, EMP_ID,
-- ACTIVE_FLAG, VALID_FROM, VALID_TO) and the active HRMS.EMPLOYEES record.
-- Manager scope follows HRMS.EMPLOYEES; delegated scope uses
-- HRMS_EMPLOYEE_SCOPE_DELEGATIONS (DELEGATOR_EMP_ID, DELEGATE_EMP_ID,
-- ACTIVE_FLAG, VALID_FROM, VALID_TO), also created by T010.
-- ============================================================================

    e_not_authenticated EXCEPTION;
    e_context_not_initialized EXCEPTION;
    e_identity_not_mapped EXCEPTION;
    e_identity_mapping_invalid EXCEPTION;
    e_identity_mapping_unavailable EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_not_authenticated, -20091);
    PRAGMA EXCEPTION_INIT(e_context_not_initialized, -20092);
    PRAGMA EXCEPTION_INIT(e_identity_not_mapped, -20093);
    PRAGMA EXCEPTION_INIT(e_identity_mapping_invalid, -20094);
    PRAGMA EXCEPTION_INIT(e_identity_mapping_unavailable, -20095);

    PROCEDURE initialize_context;
    PROCEDURE clear_context;

    FUNCTION get_apex_username RETURN VARCHAR2;
    FUNCTION get_apex_session_id RETURN NUMBER;
    FUNCTION get_employee_id RETURN NUMBER;
    FUNCTION is_employee_in_scope (
        in_target_employee_id IN NUMBER
    ) RETURN BOOLEAN;

END PKG_APP_CONTEXT;
/
