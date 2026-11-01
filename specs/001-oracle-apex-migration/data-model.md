# Data Model — HRMS APEX

## Principes de modélisation

- Conserver les clés, relations, statuts et colonnes d’audit du schéma HRMS existant.
- Exposer les données à APEX par des vues et APIs métier qui filtrent le périmètre de l’utilisateur côté serveur.
- Ne pas afficher les valeurs chiffrées de SSN et de comptes bancaires ; les opérations de déchiffrement restent limitées et auditées.
- Utiliser les tables existantes comme source de vérité pendant la coexistence ; les extensions de suivi technique ne doivent pas modifier les résultats métier.

## Entités et relations

| Entité | Source principale | Relations et rôle cible |
|---|---|---|
| Département | `DEPARTMENTS` | Hiérarchie via `PARENT_DEPT_ID`, manager, lieu et centre de coûts. |
| Lieu | `LOCATIONS` | Référencé par les employés, jours fériés et calculs de jours ouvrés. |
| Grade / poste | `JOB_GRADES`, `JOB_TITLES` | Un poste appartient à un grade ; les salaires sont validés par rapport au grade. |
| Employé | `EMPLOYEES` | Référence centrale ; liens vers département, poste, manager, lieu et domaines RH. |
| Historique employé | `EMPLOYEE_HISTORY` | Une ligne par embauche, transfert, promotion, changement de salaire, statut ou départ. |
| Dépendant / contact | `EMPLOYEE_DEPENDENTS`, `EMERGENCY_CONTACTS` | Enfants de l’employé, avec accès et masquage par profil. |
| Salaire | `SALARY_RECORDS` | Historique effectif-daté d’une rémunération et approbation associée. |
| Élément de paie | `PAY_ELEMENTS`, `EMPLOYEE_PAY_ELEMENTS` | Référentiel et affectation individuelle des gains, déductions, taxes et avantages. |
| Période / exécution | `PAY_PERIODS`, `PAYROLL_RUNS` | Une période possède plusieurs exécutions ; les transitions contrôlent calcul, approbation, paiement et inversion. |
| Détail paie | `PAYROLL_DETAILS` | Détail par employé et élément, avec erreur et statut de calcul. |
| Fiscalité / banque | `EMPLOYEE_TAX_INFO`, `TAX_BRACKETS`, `EMPLOYEE_BANK_ACCOUNTS` | Données sensibles avec accès restreint et journalisé. |
| Type / solde / demande de congé | `LEAVE_TYPES`, `LEAVE_BALANCES`, `LEAVE_REQUESTS` | Un employé possède des soldes annuels et des demandes soumises à workflow. |
| Acquisition / jours fériés | `LEAVE_ACCRUAL_LOG`, `HOLIDAYS` | Sert aux calculs de jours ouvrés, acquisition, report et expiration. |
| Cycle / évaluation / objectif | `REVIEW_CYCLES`, `PERFORMANCE_REVIEWS`, `PERFORMANCE_GOALS` | Workflow de performance avec employé, reviewer, notes et objectifs pondérés. |
| Audit | `AUDIT_LOG` | Trace les opérations et valeurs avant/après. |
| Paramètre / lookup | `SYSTEM_PARAMETERS`, `LOOKUP_VALUES` | Configuration contrôlée et données de référence. |
| Notification | `NOTIFICATION_QUEUE` | File de notifications avec reprise et statut. |
| Session utilisateur | `USER_SESSIONS` | Historique de connexion et support d’audit, sans remplacer la session APEX. |

## Extensions de données proposées

### `HRMS.BATCH_EXECUTIONS`

Table technique pour suivre les traitements longs et idempotents : `BATCH_EXECUTION_ID`, `EXECUTION_TYPE`, `REFERENCE_KEY`, `IDEMPOTENCY_KEY`, `EXECUTION_STATUS`, dates de début/fin, compteurs, résumé d’erreur, demandeur et dates d’audit. La clé d’idempotence est unique ; une reprise réutilise la même ligne et incrémente le compteur de tentatives. Les statuts sont `PENDING`, `RUNNING`, `SUCCEEDED`, `FAILED` et `CANCELLED`.

Les séquences `SEQ_BATCH_EXECUTION` et `SEQ_MIGRATION_RECONCILIATION` génèrent les clés primaires dans `hrms_operational_sequences.sql`. Le script vérifie aussi que les contraintes créées avec les tables sont présentes et activées.

Règles : une clé d’idempotence ne peut être consommée deux fois avec succès ; les transitions sont monotones sauf reprise explicitement autorisée ; chaque échec conserve son code et un résumé assaini, sans secret ni donnée RH sensible.

### `HRMS.MIGRATION_RECONCILIATIONS`

Table de contrôle par objet et lot de migration, liée à `BATCH_EXECUTIONS` : source, cible, volumes, écarts de clés, comparaisons d’agrégats JSON, statut, anomalie assainie et validation. L’unicité du lot et de l’objet rend l’écriture idempotente ; les données sensibles ne doivent pas être recopiées dans les résumés.

### Identity and delegated employee scope

`HRMS_USER_IDENTITIES` maps one stable OIDC subject (`SSO_SUBJECT`, configured as the APEX username) to an `EMP_ID`, with `ACTIVE_FLAG`, `VALID_FROM` and `VALID_TO`. `HRMS_EMPLOYEE_SCOPE_DELEGATIONS` stores time-bounded manager scope with `DELEGATOR_EMP_ID`, `DELEGATE_EMP_ID`, `ACTIVE_FLAG`, `VALID_FROM` and `VALID_TO`. T010 creates these security tables; `PKG_APP_CONTEXT` fails closed when the identity mapping is absent or ambiguous.

`HRMS_ROLES`, `HRMS_ACTIONS`, `HRMS_ROLE_ACTIONS` and `HRMS_USER_ROLES` define effective, time-bounded grants. The installation seeds role and action catalogs only: it creates no employee-role assignments or permission grants, so access is denied until an administrator configures them. The base employee view limits employees to the caller's role-specific scope and requires an explicit `EMPLOYEE.VIEW` grant; it omits sensitive personal, payroll, tax and bank columns.

## États métier à préserver

- Employé : `ACTIVE`, `ON_LEAVE`, `SUSPENDED`, `TERMINATED`.
- Demande de congé : `PENDING` → `APPROVED` ou `REJECTED`, avec `CANCELLED` ou `TAKEN` selon le cycle.
- Période : `OPEN` → `PROCESSING` → `CLOSED`, avec `REVERSED` lorsque prévu.
- Exécution paie : `PENDING` → `CALCULATING` → `CALCULATED` → `APPROVED` → `PAID`, ou `ERROR`/`REVERSED` selon les droits.
- Cycle d’évaluation : `DRAFT` → `OPEN` → `IN_PROGRESS` → `CALIBRATION` → `CLOSED`.
- Notification : `PENDING` → `SENT` ou `FAILED`, avec `CANCELLED` possible.

## Règles de validation principales

1. Les clés et codes uniques existants restent uniques après migration.
2. Les références employé, département, poste, lieu, période et élément de paie doivent être résolues avant chargement.
3. Les dates effectives ne peuvent créer deux enregistrements courants incompatibles.
4. Les droits de lecture et d’écriture sont appliqués selon l’utilisateur connecté et son périmètre, indépendamment des items APEX affichés.
5. Toute modification sensible doit renseigner l’utilisateur, la date, l’objet et le résultat de l’opération.
6. Les agrégats de paie et de congés sont recalculés et comparés au système source.
