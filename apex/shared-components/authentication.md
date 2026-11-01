# HRMS SSO Configuration

## Decision

Use OIDC in development, preproduction, and production, with one OIDC configuration per environment.

The identity provider and its issuer/discovery URL have not yet been provided. Complete those values with the IAM team before configuring APEX; do not substitute a public or personal identity provider.

| Environment | Protocol | Identity provider | Issuer / discovery URL |
|---|---|---|---|
| Development | OIDC | To confirm with IAM | To confirm with IAM |
| Preproduction | OIDC | To confirm with IAM | To confirm with IAM |
| Production | OIDC | To confirm with IAM | To confirm with IAM |

## Claim mapping

| Logical claim | OIDC claim | Requirement |
|---|---|---|
| Stable identity | `sub` | Required; map to an existing HRMS identity, never use display name as a key. |
| Username | `preferred_username` | Required for audit and display. |
| Email | `email` | Required for notifications and account lookup. |
| Full name | `name` | Optional; display only. |
| Groups / roles | Provider-specific claim | Recommended for initial role mapping; HRMS authorization is still enforced server-side. |

Confirm the provider's actual claim names and whether `sub` remains stable for the application's client registration before enabling login.

## Secret handling and release gate

- Keep client IDs and issuer URLs in environment-specific deployment configuration.
- Store client secrets in the approved secret manager; never commit them or persist tokens in HRMS tables.
- Configure and validate redirect URIs, scopes, logout behavior, and identity-to-employee mapping separately in each environment.
- T014 remains open until the IAM provider, issuer, claim names, and APEX authentication settings are confirmed and tested.
