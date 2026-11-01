# Inventaire de migration HRMS (Forms vers APEX)

## Versions

| Composant | Source | Cible |
|---|---|---|
| Oracle Forms | 12c (historique 6i puis 11g) | remplacé par APEX |
| Oracle Database | 19c | 26ai (compatibilité à vérifier) |
| Oracle APEX | non applicable | 26.2 |
| ORDS | non applicable | 26.3 |

Sources : `ts-plsql-oracle-forms-hrms/README.md` et `specs/001-oracle-apex-migration/plan.md`.

## Objets source relevés dans le dépôt

| Type | Nombre | Emplacement |
|---|---|---|
| Tables | 30 | `schema/tables/01..04_*.sql` |
| Séquences | 29 | `schema/sequences/hrms_sequences.sql` |
| Vues | 6 | `schema/views/hrms_views.sql` |
| Triggers | 6 | `plsql/triggers/` |
| Packages PL/SQL | 11 (spec + body) | `plsql/packages/` |
| Modules Forms (XML) | 6 | `forms/xml-exports/` |
| Bibliothèques PL/SQL Forms | 2 | `forms/libraries/` |
| Menu Forms | 1 | `forms/menus/` |
| Données de départ | 2 scripts | `data/seed/` |

Vues : `VW_ACTIVE_EMPLOYEES`, `VW_ORG_HIERARCHY`, `VW_EMPLOYEE_COMPENSATION`, `VW_LEAVE_SUMMARY`, `VW_PAYROLL_LATEST`, `VW_PENDING_APPROVALS`.

Triggers : `TRG_SALARY_AUDIT`, `TRG_LEAVE_REQUEST_AUDIT`, `TRG_DEPARTMENT_AUDIT`, `TRG_EMP_BEFORE_INSERT`, `TRG_EMP_BEFORE_UPDATE`, `TRG_EMP_INSTEAD_OF_DELETE`.

Packages : `PKG_AUDIT`, `PKG_COMMON`, `PKG_EMPLOYEE`, `PKG_INTEGRATION`, `PKG_LEAVE`, `PKG_NOTIFICATION`, `PKG_PAYROLL`, `PKG_PERFORMANCE`, `PKG_REPORTING`, `PKG_SECURITY`, `PKG_VALIDATION`.

Modules Forms : `HRMS_LOGIN`, `HRMS_MENU`, `HRMS_EMPLOYEE`, `HRMS_LEAVE`, `HRMS_PAYROLL`, `HRMS_PERFORMANCE`.

## Écarts connus

- La documentation annonce environ 42 tables, 15 vues et 12 packages ; le dépôt en contient 30, 6 et 11. Les objets manquants sont à retrouver auprès de l'équipe source ou à confirmer comme inexistants avant la phase de rapprochement.
- Les scripts source ciblent Oracle 19c : valider la compilation sur 26ai (T018).
- Les exports Forms sont en lecture seule et servent à la traçabilité et à la comparaison.
- La constitution du projet n'est pas ratifiée (gate de release, voir `plan.md`).

## Installation et staging

Les scripts `00_install_test.sql` à `03_rollback.sql` ciblent un schéma Oracle **HRMS isolé**. Le schéma est codé en dur dans les DDL historiques. Ne lancez pas `00_install_test.sql` sur la base de développement partagée ou en production : il exige l'argument `INSTALL_EMPTY_HRMS_TEST_SCHEMA` et refuse tout schéma HRMS contenant déjà un objet.

Exécuter depuis le répertoire du dépôt avec SQLcl et une connexion gérée hors dépôt :

```text
sql -S "$HRMS_DB_CONNECT" @ts-plsql-oracle-forms-hrms/data/migration/00_install_test.sql INSTALL_EMPTY_HRMS_TEST_SCHEMA
```

Cette installation crée le schéma et compile les packages, vues et triggers, mais ne charge aucune donnée métier. Le contenu actuel de `data/seed/` n'est pas utilisé comme fixture d'installation : le jeu de données anonymisé et les clés de référence doivent être vérifiés avant chargement (voir `tests/fixtures/README.md`).

Pour migrer un lot :

1. Démarrer `PKG_BATCH.start_execution` avec une clé d'idempotence stable et conserver son `BATCH_EXECUTION_ID`.
2. Créer la table de staging et vérifier que le lot est `RUNNING` :
   `@ts-plsql-oracle-forms-hrms/data/migration/01_staging.sql <BATCH_EXECUTION_ID>`.
3. Charger les enregistrements JSON dans `MIGRATION_STAGING_ROWS`, avec la séquence `SEQ_MIGRATION_STAGING_ROW`; l'unicité `(BATCH_EXECUTION_ID, SOURCE_OBJECT_NAME, SOURCE_RECORD_KEY)` empêche les doublons.
4. Exécuter `@ts-plsql-oracle-forms-hrms/data/migration/02_validate.sql <BATCH_EXECUTION_ID>`. Ce contrôle valide uniquement le JSON, la présence du lot, les doublons et les états de staging; les règles métier par table et le rapprochement restent requis.
5. Si le staging doit être annulé, exécuter `@ts-plsql-oracle-forms-hrms/data/migration/03_rollback.sql <BATCH_EXECUTION_ID> CONFIRM_STAGING_ROLLBACK`. Cette opération annule le lot `RUNNING` et supprime uniquement ses lignes de staging. Elle ne supprime pas le schéma ni les données métier.

Les scripts de validation et de rollback valident et commitent les modifications DML du lot ciblé. Ne partagez pas un même `BATCH_EXECUTION_ID` entre chargements concurrents.
