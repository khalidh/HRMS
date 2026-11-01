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
sql -S "$HRMS_DB_CONNECT" @ts-plsql-oracle-forms-hrms/data/migration/00_install_test.sql INSTALL_EMPTY_HRMS_TEST_SCHEMA

# Contrôles de schéma
sql -S "$HRMS_DB_CONNECT" @tests/sql/foundation_schema.sql

# Tests utPLSQL
sql -S "$HRMS_DB_CONNECT" <<'SQL'
exec ut.run('HRMS');
SQL
```

`00_install_test.sql` crée et compile le schéma, mais ne charge pas les scripts existants de `data/seed/`. Avant d'utiliser ces données, vérifiez leur anonymisation et leur compatibilité avec le DDL; le jeu de fixtures de référence reste à fournir.

## Organisation

- `sql/` : contraintes, compilation, rapprochements.
- `plsql/` : tests unitaires des packages.
- `integration/` : règles métier, jobs, imports, notifications.
- `security/` : matrice rôles et périmètres.
- `browser/` : scénarios APEX et accessibilité.
- `fixtures/` : données anonymisées et identifiants de référence.

Les tests d'une story s'écrivent d'abord et doivent échouer avant l'implémentation.
