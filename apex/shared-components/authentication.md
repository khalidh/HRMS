# HRMS Authentication Configuration

## Decision by environment

Use exactly one authentication scheme in each environment:

| Environment | Authentication | Identity provider / issuer | Status |
|---|---|---|---|
| Development | Temporary APEX local accounts; not SSO | None | Approved for development only |
| Preproduction | OIDC | Provider and issuer/discovery URL to be confirmed with IAM | Blocked on IAM details |
| Production | OIDC | Provider and issuer/discovery URL to be confirmed with IAM | Blocked on IAM details |

Do not enable local accounts as a fallback in preproduction or production. Development accounts must be synthetic and must not access production data. Do not copy development credentials or authentication configuration into another environment.

## Claim mapping

The following OIDC claim names are candidates only. IAM must confirm the exact names and the stability of the subject before either OIDC environment is configured.

| Logical claim | Candidate OIDC claim | Requirement |
|---|---|---|
| Stable identity | `sub` | Required; resolve to an active `HRMS_USER_IDENTITIES.SSO_SUBJECT`. Never use display name as a key. |
| Username | `preferred_username` | Required for audit and display; confirm availability with IAM. |
| Email | `email` | Required for notifications and account lookup; confirm availability with IAM. |
| Full name | `name` | Optional; display only. |
| Groups / roles | Provider-specific, possibly `groups` | Recommended as an input to role mapping; HRMS authorization is still enforced server-side. |

For development, provision only synthetic APEX local accounts and explicitly map each test account to an approved synthetic HRMS identity. The identity lookup and authorization checks remain mandatory regardless of the authentication scheme.

## Security and release gates

- Configure one scheme only per environment; never combine OIDC and local accounts as alternate login paths.
- Confirm the OIDC provider, issuer/discovery URL, exact claim names, redirect URIs, scopes, and logout behavior with IAM for preproduction and production.
- Keep client IDs and secrets in environment-specific deployment configuration and the approved secret manager; never commit secrets or persist tokens in HRMS tables.
- An authenticated identity without an active `HRMS_USER_IDENTITIES` mapping is denied with a generic message and a security audit event.
- Deactivation or departure of an employee removes business access even if the identity provider still authenticates them.
- Resolve application roles from the administered and audited HRMS mapping tables; do not treat external groups as final authorization.
- Close the APEX session on logout and apply the configured OIDC provider logout policy outside development.
- Initialize `HRMS.PKG_APP_CONTEXT` for authenticated APEX requests; protected packages must fail closed when no valid application context exists.

T014 remains open until IAM confirms the OIDC provider, per-environment issuers, and claim mapping, and the OIDC flow is tested in preproduction.
