CREATE OR REPLACE PACKAGE HRMS.PKG_APP_ERRORS AS
    c_public_error_code CONSTANT PLS_INTEGER := -20999;

    FUNCTION get_error_code(
        in_oracle_error_code IN NUMBER
    ) RETURN VARCHAR2;

    FUNCTION get_user_message(
        in_oracle_error_code IN NUMBER,
        in_locale            IN VARCHAR2 DEFAULT 'en'
    ) RETURN VARCHAR2;

    PROCEDURE log_error(
        in_context_code        IN VARCHAR2,
        in_oracle_error_code   IN NUMBER,
        in_error_backtrace     IN VARCHAR2
    );

    PROCEDURE raise_user_error(
        in_oracle_error_code IN NUMBER,
        in_locale            IN VARCHAR2 DEFAULT 'en'
    );

    PROCEDURE handle_error(
        in_context_code IN VARCHAR2,
        in_oracle_error_code IN NUMBER,
        in_error_backtrace IN VARCHAR2,
        in_locale       IN VARCHAR2 DEFAULT 'en'
    );
END PKG_APP_ERRORS;
/
