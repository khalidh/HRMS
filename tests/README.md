# Tests HRMS

## Outillage

| Outil | Usage |
|---|---|
| SQLcl | exécution des scripts, compilation, export APEX |
| utPLSQL v3 | tests unitaires des packages (`tests/plsql/`) |
| Playwright | parcours navigateur et accessibilité (`tests/browser/`) |

## Prérequis locaux

- Base Oracle accessible via `HRMS_DB_CONNECT` (voir `ts-plsql-oracle-forms-hrms/data/migration/env.example`), avec un compte de service aux droits limités.
- utPLSQL installé dans la base de test.
- Node.js pour Playwright.
- Aucun mot de passe dans les commandes ni dans les fichiers versionnés.

## Commandes

```bash
# Installer dans un schéma HRMS neuf et isolé (refus si le schéma contient déjà un objet)
HRMS_INSTALL_CONFIRMATION=INSTALL_EMPTY_HRMS_TEST_SCHEMA \
  scripts/deploy-hrms.sh --install-test-schema

# Contrôles de schéma
scripts/deploy-hrms.sh --check-schema

# Tests utPLSQL
sql -S "$HRMS_DB_CONNECT" <<'SQL'
exec ut.run('HRMS');
SQL
```

`00_install_test.sql` crée et compile le schéma, mais ne charge pas les scripts existants de `data/seed/`. Avant d'utiliser ces données, vérifiez leur anonymisation et leur compatibilité avec le DDL; le jeu de fixtures de référence reste à fournir.

Les scripts `scripts/deploy-hrms.sh` et `scripts/rollback-hrms.sh` attendent SQLcl (`SQLCL_BIN`, par défaut `sql`). L'installation complète est réservée à un schéma HRMS de test vide. Un export applicatif versionné sous `apex/application/` s'importe avec `--import-apex`; la connexion APEX (`APEX_DB_CONNECT`) doit appartenir au workspace cible. Le rollback de staging est limité à un lot `RUNNING`; la restauration APEX réimporte un export connu comme valide et ne restaure ni le schéma ni les données métier. Aucun déploiement de mise à niveau en production n'est activé tant que des migrations réversibles et ordonnées ne sont pas définies.

Les contrôles `--check-schema` exécutent le contrôle structurel, les tests du package d'erreurs et les validations US1. Le test `tests/plsql/test_pkg_app_errors.sql` écrit temporairement une ligne de journal d'audit, vérifie son contenu puis la supprime. Exécutez-le uniquement dans un schéma de test isolé.

Les scripts `tests/security/us1_employee_access.sql` et `tests/integration/us1_employee_lifecycle.sql` s'exécutent depuis une session APEX authentifiée avec les items de test documentés dans leur en-tête. Le rapprochement Forms/APEX requiert des tables de référence anonymisées non présentes dans le dépôt et un rôle HR explicitement autorisé.

## Organisation

- `sql/` : contraintes, compilation, rapprochements.
- `plsql/` : tests unitaires des packages.
- `integration/` : règles métier, jobs, imports, notifications.
- `security/` : matrice rôles et périmètres.
- `browser/` : scénarios APEX et accessibilité.
- `fixtures/` : données anonymisées et identifiants de référence.

Les tests d'une story s'écrivent d'abord et doivent échouer avant l'implémentation.
