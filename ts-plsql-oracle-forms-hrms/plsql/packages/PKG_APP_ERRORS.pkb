CREATE OR REPLACE PACKAGE BODY HRMS.PKG_APP_ERRORS AS

    FUNCTION get_error_code(
        in_oracle_error_code IN NUMBER
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE in_oracle_error_code
            WHEN -20001 THEN 'EMPLOYEE_NOT_FOUND'
            WHEN -20002 THEN 'DUPLICATE_EMPLOYEE'
            WHEN -20003 THEN 'INVALID_DEPARTMENT'
            WHEN -20004 THEN 'INVALID_MANAGER'
            WHEN -20005 THEN 'INVALID_EMPLOYMENT_STATE'
            WHEN -20010 THEN 'REQUIRED_EMPLOYEE_DATA'
            WHEN -20011 THEN 'INVALID_JOB'
            WHEN -20012 THEN 'INVALID_TRANSFER'
            WHEN -20013 THEN 'INVALID_SALARY'
            WHEN -20020 THEN 'INVALID_ORGANIZATION'
            WHEN -20091 THEN 'AUTHENTICATION_REQUIRED'
            WHEN -20092 THEN 'AUTHORIZATION_CONTEXT_UNAVAILABLE'
            WHEN -20093 THEN 'IDENTITY_NOT_MAPPED'
            WHEN -20094 THEN 'IDENTITY_MAPPING_AMBIGUOUS'
            WHEN -20095 THEN 'SECURITY_CONFIGURATION_UNAVAILABLE'
            WHEN -20096 THEN 'INVALID_EMPLOYEE_SCOPE_REQUEST'
            WHEN -20101 THEN 'INVALID_BATCH_PROGRESS'
            WHEN -20301 THEN 'INVALID_CREDENTIALS'
            WHEN -20302 THEN 'ACCOUNT_LOCKED'
            WHEN -20303 THEN 'SESSION_EXPIRED'
            WHEN -20304 THEN 'INSUFFICIENT_PRIVILEGES'
            ELSE 'UNEXPECTED_ERROR'
        END;
    END get_error_code;

    FUNCTION get_user_message(
        in_oracle_error_code IN NUMBER,
        in_locale            IN VARCHAR2 DEFAULT 'en'
    ) RETURN VARCHAR2 IS
        v_language VARCHAR2(2) := LOWER(SUBSTR(TRIM(in_locale), 1, 2));
        v_error_code VARCHAR2(60) := get_error_code(in_oracle_error_code);
    BEGIN
        IF v_language = 'fr' THEN
            RETURN CASE v_error_code
                WHEN 'EMPLOYEE_NOT_FOUND' THEN 'Employé introuvable.'
                WHEN 'DUPLICATE_EMPLOYEE' THEN 'Un employé avec ces informations existe déjà.'
                WHEN 'INVALID_DEPARTMENT' THEN 'Le département sélectionné est indisponible.'
                WHEN 'INVALID_MANAGER' THEN 'Le responsable sélectionné est invalide.'
                WHEN 'INVALID_EMPLOYMENT_STATE' THEN 'Cette opération n’est pas autorisée pour le statut actuel.'
                WHEN 'REQUIRED_EMPLOYEE_DATA' THEN 'Vérifiez les champs obligatoires de l’employé.'
                WHEN 'INVALID_JOB' THEN 'Le poste sélectionné est indisponible.'
                WHEN 'INVALID_TRANSFER' THEN 'Le transfert ne peut pas être effectué dans l’état actuel.'
                WHEN 'INVALID_SALARY' THEN 'Le salaire est en dehors de la fourchette autorisée pour le grade.'
                WHEN 'INVALID_ORGANIZATION' THEN 'Les données organisationnelles sélectionnées sont invalides.'
                WHEN 'AUTHENTICATION_REQUIRED' THEN 'Votre session a expiré. Connectez-vous à nouveau.'
                WHEN 'AUTHORIZATION_CONTEXT_UNAVAILABLE' THEN 'Votre session ne peut pas être vérifiée. Connectez-vous à nouveau.'
                WHEN 'IDENTITY_NOT_MAPPED' THEN 'Votre compte n’est pas autorisé à accéder à cette application.'
                WHEN 'IDENTITY_MAPPING_AMBIGUOUS' THEN 'Votre compte ne peut pas être vérifié. Contactez le support.'
                WHEN 'SECURITY_CONFIGURATION_UNAVAILABLE' THEN 'Le service est temporairement indisponible. Contactez le support.'
                WHEN 'INVALID_EMPLOYEE_SCOPE_REQUEST' THEN 'La demande d’accès à cet employé est invalide.'
                WHEN 'INVALID_BATCH_PROGRESS' THEN 'La progression du traitement est invalide.'
                WHEN 'INVALID_CREDENTIALS' THEN 'Nom d’utilisateur ou mot de passe invalide.'
                WHEN 'ACCOUNT_LOCKED' THEN 'Le compte est temporairement verrouillé.'
                WHEN 'SESSION_EXPIRED' THEN 'Votre session a expiré. Connectez-vous à nouveau.'
                WHEN 'INSUFFICIENT_PRIVILEGES' THEN 'Vous n’êtes pas autorisé à effectuer cette opération.'
                ELSE 'Une erreur est survenue. Réessayez ou contactez le support.'
            END;
        END IF;

        RETURN CASE v_error_code
            WHEN 'EMPLOYEE_NOT_FOUND' THEN 'The employee could not be found.'
            WHEN 'DUPLICATE_EMPLOYEE' THEN 'An employee with these details already exists.'
            WHEN 'INVALID_DEPARTMENT' THEN 'The selected department is unavailable.'
            WHEN 'INVALID_MANAGER' THEN 'The selected manager is invalid.'
            WHEN 'INVALID_EMPLOYMENT_STATE' THEN 'This action is not allowed for the current employment status.'
            WHEN 'REQUIRED_EMPLOYEE_DATA' THEN 'Check the required employee fields.'
            WHEN 'INVALID_JOB' THEN 'The selected job is unavailable.'
            WHEN 'INVALID_TRANSFER' THEN 'The transfer cannot be completed in the current state.'
            WHEN 'INVALID_SALARY' THEN 'The salary is outside the approved range for the grade.'
            WHEN 'INVALID_ORGANIZATION' THEN 'The selected organization data is invalid.'
            WHEN 'AUTHENTICATION_REQUIRED' THEN 'Your session has expired. Sign in again.'
            WHEN 'AUTHORIZATION_CONTEXT_UNAVAILABLE' THEN 'Your session cannot be verified. Sign in again.'
            WHEN 'IDENTITY_NOT_MAPPED' THEN 'Your account is not authorized to access this application.'
            WHEN 'IDENTITY_MAPPING_AMBIGUOUS' THEN 'Your account cannot be verified. Contact support.'
            WHEN 'SECURITY_CONFIGURATION_UNAVAILABLE' THEN 'The service is temporarily unavailable. Contact support.'
            WHEN 'INVALID_EMPLOYEE_SCOPE_REQUEST' THEN 'The employee access request is invalid.'
            WHEN 'INVALID_BATCH_PROGRESS' THEN 'The processing progress is invalid.'
            WHEN 'INVALID_CREDENTIALS' THEN 'The username or password is invalid.'
            WHEN 'ACCOUNT_LOCKED' THEN 'The account is temporarily locked.'
            WHEN 'SESSION_EXPIRED' THEN 'Your session has expired. Sign in again.'
            WHEN 'INSUFFICIENT_PRIVILEGES' THEN 'You are not authorized to perform this action.'
            ELSE 'An error occurred. Try again or contact support.'
        END;
    END get_user_message;

    PROCEDURE log_error(
        in_context_code      IN VARCHAR2,
        in_oracle_error_code IN NUMBER,
        in_error_backtrace   IN VARCHAR2
    ) IS
        v_error_code VARCHAR2(60);
        v_payload CLOB;
    BEGIN
        IF in_context_code IS NULL
           OR NOT REGEXP_LIKE(in_context_code, '^[A-Z][A-Z0-9_.]{0,59}$')
           OR in_oracle_error_code IS NULL
           OR in_oracle_error_code = 0
        THEN
            RAISE_APPLICATION_ERROR(-20998, 'Valid application error details are required.');
        END IF;

        v_error_code := get_error_code(in_oracle_error_code);

        SELECT JSON_OBJECT(
                   'error_code' VALUE v_error_code,
                   'oracle_error_code' VALUE in_oracle_error_code,
                   'context' VALUE in_context_code,
                   'backtrace' VALUE in_error_backtrace
                   NULL ON NULL
                   RETURNING CLOB
               )
          INTO v_payload
          FROM dual;

        HRMS.PKG_AUDIT.log_action(
            p_table_name => 'APPLICATION_ERRORS',
            p_record_id  => 0,
            p_action     => 'ERROR',
            p_new_values => v_payload
        );
    END log_error;

    PROCEDURE raise_user_error(
        in_oracle_error_code IN NUMBER,
        in_locale            IN VARCHAR2 DEFAULT 'en'
    ) IS
    BEGIN
        RAISE_APPLICATION_ERROR(
            c_public_error_code,
            get_user_message(in_oracle_error_code, in_locale)
        );
    END raise_user_error;

    PROCEDURE handle_error(
        in_context_code IN VARCHAR2,
        in_oracle_error_code IN NUMBER,
        in_error_backtrace IN VARCHAR2,
        in_locale       IN VARCHAR2 DEFAULT 'en'
    ) IS
    BEGIN
        log_error(
            in_context_code      => in_context_code,
            in_oracle_error_code => in_oracle_error_code,
            in_error_backtrace   => in_error_backtrace
        );
        raise_user_error(in_oracle_error_code, in_locale);
    END handle_error;

END PKG_APP_ERRORS;
/
