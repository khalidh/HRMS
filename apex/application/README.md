# Application APEX HRMS

## Convention d'export

- L'export installable (`f<APP_ID>.sql`) est versionné dans ce dossier, généré avec SQLcl : `apex export -applicationid <APP_ID> -split`.
- Chaque page possède un descripteur lisible dans `pages/` nommé `<story>_<sujet>.sql` ou `.md` (ex. `us1_employee_search.sql`) : région, source de données, items, validations, processus, Dynamic Actions et autorisations.
- Les composants partagés (authentification, autorisations, navigation, thème, LOV) sont décrits dans `../shared-components/`.

## Procédure d'assemblage

1. Appliquer les scripts de schéma et de packages (`scripts/deploy-hrms.sh`).
2. Importer l'export APEX dans le workspace cible (`APEX_WORKSPACE`, `APEX_APP_ID`).
3. Configurer le schéma d'authentification SSO de l'environnement.
4. Lancer les tests (`tests/README.md`).

## Règles

- Aucun secret dans l'export : les identifiants SSO sont injectés par environnement.
- Les accès sont contrôlés côté serveur par des schémas d'autorisation, pas seulement par masquage d'interface.
- Les pages appellent les packages `PKG_*` plutôt que d'embarquer la logique métier.
