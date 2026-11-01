# Contract — Authentication and Identity Mapping

## Purpose

Définir le contrat entre le fournisseur SSO d’entreprise et l’application HRMS.

## Required identity claims

Le fournisseur doit fournir un identifiant stable correspondant à un employé HRMS, ainsi que le nom d’utilisateur et, lorsque disponible, les groupes ou rôles d’entreprise.

| Claim logique | Obligatoire | Utilisation |
|---|---:|---|
| Identifiant stable | Oui | Correspondance avec le compte ou `EMP_ID` HRMS. |
| Nom d’utilisateur | Oui | Audit et affichage. |
| Adresse email | Oui | Notifications et recherche de compte. |
| Groupes/roles | Recommandé | Pré-affectation d’un profil HRMS ; les permissions finales sont vérifiées côté serveur. |
| Nom complet | Recommandé | Affichage uniquement, jamais comme clé. |

## Rules

- Développement : utiliser temporairement un compte local APEX, sans fournisseur ni issuer SSO. Ces comptes sont réservés aux tests synthétiques et ne doivent pas accéder aux données de production.
- Préproduction et production : utiliser OIDC, avec un seul mécanisme d'authentification par environnement. Ne pas prévoir de compte local comme solution de repli.
- Le fournisseur OIDC, l’issuer/discovery URL de chaque environnement et les noms exacts des claims restent à confirmer avec l’équipe IAM avant l’activation d’OIDC; les candidats et les blocages sont suivis dans `apex/shared-components/authentication.md`.
- L’identifiant stable reçu après authentification doit correspondre à `HRMS_USER_IDENTITIES.SSO_SUBJECT`, relié à un employé HRMS. Le nom d’affichage ne sert jamais de clé.
- Une identité SSO sans correspondance HRMS est refusée avec un message générique et un événement de sécurité.
- La désactivation ou le départ d’un employé retire l’accès métier, même si le fournisseur SSO l’authentifie encore.
- Les rôles applicatifs sont résolus à partir d’une table de mapping administrée et auditée.
- Aucun token, assertion ou secret SSO n’est enregistré dans les tables métier.
- La déconnexion ferme la session APEX et, hors développement, applique la politique de déconnexion du fournisseur OIDC.

## Acceptance checks

- Connexion réussie avec identité valide et rôle attendu.
- Refus d’un utilisateur inconnu, inactif ou hors périmètre.
- Retrait d’un rôle effectif à la prochaine vérification de session ou reconnexion.
- Audit sans stockage de secret.
