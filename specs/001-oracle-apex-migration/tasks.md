---

description: "Tâches d’implémentation de la migration HRMS vers Oracle APEX"
---

# Tasks: Migration HRMS vers Oracle APEX

**Input**: Design documents from `/specs/001-oracle-apex-migration/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Les tests sont inclus car la spécification exige des tests unitaires, d’intégration, de sécurité, de performance, d’accessibilité et de non-régression.

**Path conventions**: SQL/PLSQL sous `ts-plsql-oracle-forms-hrms/`, artefacts APEX sous `apex/`, jobs sous `jobs/`, intégrations ORDS sous `ords/`, tests sous `tests/`.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: préparer l’arborescence, les conventions de déploiement et les jeux de données de test.

- [x] T001 Créer l’arborescence cible `apex/`, `jobs/`, `ords/`, `tests/` et `ts-plsql-oracle-forms-hrms/data/migration/` selon [plan.md](./plan.md).
- [x] T002 [P] Documenter l’inventaire des objets source, les versions Oracle/APEX/ORDS et les écarts connus dans `ts-plsql-oracle-forms-hrms/data/migration/README.md`.
- [x] T003 [P] Créer la configuration d’environnement sans secrets dans `ts-plsql-oracle-forms-hrms/data/migration/env.example` avec les variables de connexion, workspace, application et SSO.
- [x] T004 [P] Préparer le jeu de données anonymisé et les identifiants de référence dans `tests/fixtures/README.md`.
- [x] T005 [P] Ajouter la convention d’export APEX installable, les descripteurs page par page et la procédure d’assemblage dans `apex/application/README.md`.
- [x] T006 [P] Documenter l’outillage SQLcl/utPLSQL/Playwright, les commandes de compilation et les prérequis locaux dans `tests/README.md`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: construire les fondations communes qui bloquent toutes les user stories.

**⚠️ CRITICAL**: aucune user story ne doit commencer avant la fin de cette phase.

- [x] T007 Créer le DDL des tables techniques `BATCH_EXECUTIONS` et `MIGRATION_RECONCILIATIONS` dans `ts-plsql-oracle-forms-hrms/schema/tables/05_operational_tables.sql` avec clés, statuts, unicité d’idempotence et colonnes d’audit. — [GitHub #1](https://github.com/khalidh/HRMS/issues/1)
- [x] T008 [P] Créer les séquences et contraintes des tables techniques dans `ts-plsql-oracle-forms-hrms/schema/sequences/hrms_operational_sequences.sql`. — [GitHub #2](https://github.com/khalidh/HRMS/issues/2)
- [x] T009 [P] Créer le package de contexte utilisateur et périmètre dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_APP_CONTEXT.pks` et `PKG_APP_CONTEXT.pkb`. — [GitHub #3](https://github.com/khalidh/HRMS/issues/3)
- [x] T010 Créer les vues sécurisées de base et le mapping rôles/actions dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_security_views.sql` et `ts-plsql-oracle-forms-hrms/schema/tables/06_security_tables.sql`. — [GitHub #4](https://github.com/khalidh/HRMS/issues/4)
- [x] T011 [P] Adapter le package et les déclencheurs d’audit pour l’identité SSO, la session APEX, l’adresse réseau et les exports; étendre `AUDIT_LOG` via `schema/tables/07_audit_context.sql`. — [GitHub #5](https://github.com/khalidh/HRMS/issues/5)
- [x] T012 [P] Créer le package de suivi des jobs, transitions et idempotence dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_BATCH.pks` et `PKG_BATCH.pkb`; étendre les colonnes demandeur/auteur pour les sujets SSO dans `schema/tables/08_batch_actor.sql`. — [GitHub #6](https://github.com/khalidh/HRMS/issues/6)
- [ ] T013 [P] Créer le script d’installation de test, puis les scripts de staging, validation et rollback dans `ts-plsql-oracle-forms-hrms/data/migration/00_install_test.sql`, `01_staging.sql`, `02_validate.sql` et `03_rollback.sql`. — [GitHub #7](https://github.com/khalidh/HRMS/issues/7)
- [ ] T014 Configurer exactement un protocole SSO par environnement (`OIDC` ou `SAML`), documenter le fournisseur et mapper les claims dans `apex/shared-components/authentication.md` conformément à [contracts/authentication.md](./contracts/authentication.md). — [GitHub #8](https://github.com/khalidh/HRMS/issues/8)
- [ ] T015 [P] Configurer les rôles, autorisations, navigation commune, LOV partagées et thème Universal Theme dans `apex/shared-components/authorization.md`, `navigation.md` et `theme.md`. — [GitHub #9](https://github.com/khalidh/HRMS/issues/9)
- [ ] T016 [P] Créer le package de normalisation des erreurs métier et messages utilisateur dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_APP_ERRORS.pks` et `PKG_APP_ERRORS.pkb`. — [GitHub #10](https://github.com/khalidh/HRMS/issues/10)
- [ ] T017 Configurer la chaîne de déploiement versionnée des scripts SQL et de l’export APEX dans `scripts/deploy-hrms.sh` et `scripts/rollback-hrms.sh`. — [GitHub #11](https://github.com/khalidh/HRMS/issues/11)
- [ ] T018 Vérifier les contraintes, compilations, droits minimaux et tables techniques avec `tests/sql/foundation_schema.sql` avant d’ouvrir les phases métier. — [GitHub #12](https://github.com/khalidh/HRMS/issues/12)

**Checkpoint**: fondation disponible ; les user stories peuvent être développées en parallèle.

---

## Phase 3: User Story 1 - Administrer les employés et l’organisation (Priority: P1) 🎯 MVP

**Goal**: offrir le référentiel employé et organisationnel avec cycle de vie, historique, audit et périmètre sécurisé.

**Independent Test**: un utilisateur RH recherche un employé, modifie une donnée autorisée, réalise un transfert de test et vérifie l’état courant, l’historique et l’audit ; un utilisateur hors périmètre est refusé.

### Tests for User Story 1

- [ ] T019 [P] [US1] Écrire les tests de permissions employé/RH/manager/auditeur dans `tests/security/us1_employee_access.sql` et vérifier qu’ils échouent avant les vues sécurisées. — [GitHub #13](https://github.com/khalidh/HRMS/issues/13)
- [ ] T020 [P] [US1] Écrire les tests de recherche, hiérarchie et cycle de vie dans `tests/integration/us1_employee_lifecycle.sql` et vérifier qu’ils échouent avant l’implémentation. — [GitHub #14](https://github.com/khalidh/HRMS/issues/14)
- [ ] T021 [P] [US1] Écrire le test de non-régression Forms/APEX pour effectif et organisation dans `tests/integration/us1_forms_reconciliation.sql`. — [GitHub #15](https://github.com/khalidh/HRMS/issues/15)

### Implementation for User Story 1

- [ ] T022 [P] [US1] Créer les vues de recherche employé, organisation, hiérarchie et historique dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_employee_views.sql`. — [GitHub #16](https://github.com/khalidh/HRMS/issues/16)
- [ ] T023 [P] [US1] Ajouter les validations de matricule, email, dates, statut, type d’emploi, département, poste, lieu, manager et cycles hiérarchiques dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_VALIDATION.pkb`. — [GitHub #17](https://github.com/khalidh/HRMS/issues/17)
- [ ] T024 [US1] Refactorer les opérations d’embauche, transfert, promotion, termination et réembauche dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_EMPLOYEE.pkb` pour utiliser le contexte applicatif et l’audit. — [GitHub #18](https://github.com/khalidh/HRMS/issues/18)
- [ ] T025 [US1] Créer la page APEX de recherche et liste des employés dans `apex/application/pages/us1_employee_search.sql` avec filtres, pagination, actions autorisées et masquage. — [GitHub #19](https://github.com/khalidh/HRMS/issues/19)
- [ ] T026 [US1] Créer la page APEX de fiche employé et ses onglets dans `apex/application/pages/us1_employee_form.sql` pour identité, emploi, dépendants, contacts, historique et audit. — [GitHub #20](https://github.com/khalidh/HRMS/issues/20)
- [ ] T027 [US1] Créer les pages d’administration départements, lieux, grades, postes et managers dans `apex/application/pages/us1_organization.sql`. — [GitHub #21](https://github.com/khalidh/HRMS/issues/21)
- [ ] T028 [US1] Créer les dialogues de transfert, promotion, termination et réembauche dans `apex/application/pages/us1_employee_actions.sql` avec confirmation, motif et branchement après succès. — [GitHub #22](https://github.com/khalidh/HRMS/issues/22)
- [ ] T029 [US1] Ajouter les tests d’acceptation et le scénario indépendant US1 dans `tests/browser/us1_employee_journey.md`. — [GitHub #23](https://github.com/khalidh/HRMS/issues/23)

**Checkpoint**: US1 est démontrable indépendamment et constitue le MVP.

---

## Phase 4: User Story 2 - Gérer les congés et les approbations (Priority: P1)

**Goal**: permettre la soumission, la validation, l’approbation et le suivi des congés avec soldes et calendrier fiables.

**Independent Test**: un employé soumet une demande valide, un conflit est refusé, puis un manager approuve ou rejette une demande de son équipe et le solde est mis à jour.

### Tests for User Story 2

- [ ] T030 [P] [US2] Écrire les tests de solde, chevauchement, jours ouvrés, demi-journée et justificatif dans `tests/integration/us2_leave_rules.sql`. — [GitHub #24](https://github.com/khalidh/HRMS/issues/24)
- [ ] T031 [P] [US2] Écrire les tests de périmètre employé/manager/RH pour les demandes dans `tests/security/us2_leave_access.sql`. — [GitHub #25](https://github.com/khalidh/HRMS/issues/25)
- [ ] T032 [P] [US2] Écrire le test Forms/APEX des soldes et demandes dans `tests/integration/us2_forms_reconciliation.sql`. — [GitHub #26](https://github.com/khalidh/HRMS/issues/26)

### Implementation for User Story 2

- [ ] T033 [P] [US2] Créer les vues sécurisées des soldes, demandes, calendrier d’équipe et approbations dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_leave_views.sql`. — [GitHub #27](https://github.com/khalidh/HRMS/issues/27)
- [ ] T034 [US2] Corriger et centraliser les règles de chevauchement, demi-journée, jours fériés, solde et justificatif dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_LEAVE.pkb`. — [GitHub #28](https://github.com/khalidh/HRMS/issues/28)
- [ ] T035 [US2] Créer la page APEX de consultation des soldes et calendrier employé dans `apex/application/pages/us2_leave_self_service.sql`. — [GitHub #29](https://github.com/khalidh/HRMS/issues/29)
- [ ] T036 [US2] Créer la page APEX de soumission et annulation de demande dans `apex/application/pages/us2_leave_request.sql` avec upload contrôlé et validations. — [GitHub #30](https://github.com/khalidh/HRMS/issues/30)
- [ ] T037 [US2] Créer la page APEX de file d’approbation et calendrier manager dans `apex/application/pages/us2_leave_approval.sql`. — [GitHub #31](https://github.com/khalidh/HRMS/issues/31)
- [ ] T038 [US2] Créer les pages RH de types de congé, jours fériés et ajustements de solde dans `apex/application/pages/us2_leave_admin.sql`. — [GitHub #32](https://github.com/khalidh/HRMS/issues/32)
- [ ] T039 [US2] Implémenter les jobs d’acquisition, report et expiration dans `jobs/scheduler/leave_accrual.sql` en utilisant `PKG_BATCH` et une clé d’idempotence. — [GitHub #33](https://github.com/khalidh/HRMS/issues/33)
- [ ] T040 [US2] Ajouter les notifications de soumission, approbation, rejet et erreur dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_NOTIFICATION.pkb` et `apex/application/pages/us2_leave_notifications.sql`. — [GitHub #34](https://github.com/khalidh/HRMS/issues/34)
- [ ] T041 [US2] Ajouter le parcours indépendant et les cas limites US2 dans `tests/browser/us2_leave_journey.md`. — [GitHub #35](https://github.com/khalidh/HRMS/issues/35)

**Checkpoint**: US1 et US2 sont testables séparément avec un jeu de données RH valide.

---

## Phase 5: User Story 3 - Exécuter et contrôler la paie (Priority: P1)

**Goal**: gérer les périodes, exécutions, calculs, erreurs, approbations, bulletins et inversions avec compatibilité des résultats.

**Independent Test**: un gestionnaire paie traite un jeu de référence, retrouve les totaux attendus, consulte une erreur et ne peut pas modifier une période clôturée.

### Tests for User Story 3

- [ ] T042 [P] [US3] Écrire les tests de transitions période/exécution, double paiement, inversion et erreurs dans `tests/integration/us3_payroll_states.sql`. — [GitHub #36](https://github.com/khalidh/HRMS/issues/36)
- [ ] T043 [P] [US3] Écrire les tests de masquage et permissions paie, fiscalité et banque dans `tests/security/us3_payroll_access.sql`. — [GitHub #37](https://github.com/khalidh/HRMS/issues/37)
- [ ] T044 [P] [US3] Écrire le rapprochement des totaux brut, déductions, net et coût employeur dans `tests/integration/us3_payroll_reconciliation.sql`. — [GitHub #38](https://github.com/khalidh/HRMS/issues/38)

### Implementation for User Story 3

- [ ] T045 [P] [US3] Créer les vues sécurisées des salaires, éléments, périodes, exécutions, détails et bulletins dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_payroll_views.sql`. — [GitHub #39](https://github.com/khalidh/HRMS/issues/39)
- [ ] T046 [US3] Refactorer les validations de salaire, périodes, calcul, approbation et inversion dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_PAYROLL.pkb` sans changer les résultats de référence. — [GitHub #40](https://github.com/khalidh/HRMS/issues/40)
- [ ] T047 [US3] Créer la page APEX de rémunération, éléments, fiscalité et comptes bancaires masqués dans `apex/application/pages/us3_payroll_setup.sql`. — [GitHub #41](https://github.com/khalidh/HRMS/issues/41)
- [ ] T048 [US3] Créer la page APEX de périodes et exécutions dans `apex/application/pages/us3_payroll_runs.sql` avec transitions autorisées et confirmation des actions sensibles. — [GitHub #42](https://github.com/khalidh/HRMS/issues/42)
- [ ] T049 [US3] Implémenter le job de calcul asynchrone et le suivi par employé dans `jobs/scheduler/payroll_calculation.sql` et `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_BATCH.pkb`. — [GitHub #43](https://github.com/khalidh/HRMS/issues/43)
- [ ] T050 [US3] Créer la page APEX de suivi, erreurs, totaux et approbation dans `apex/application/pages/us3_payroll_monitoring.sql`. — [GitHub #44](https://github.com/khalidh/HRMS/issues/44)
- [ ] T051 [US3] Créer les vues et pages de bulletin et registre de paie dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_payslip_views.sql` et `apex/application/pages/us3_payroll_reports.sql`. — [GitHub #45](https://github.com/khalidh/HRMS/issues/45)
- [ ] T052 [US3] Ajouter l’export GL contrôlé et idempotent dans `ords/modules/gl_journal.sql` conformément à [contracts/integrations.md](./contracts/integrations.md). — [GitHub #46](https://github.com/khalidh/HRMS/issues/46)
- [ ] T053 [US3] Ajouter le parcours indépendant, le rapprochement Forms/APEX et les cas d’inversion dans `tests/browser/us3_payroll_journey.md`. — [GitHub #47](https://github.com/khalidh/HRMS/issues/47)

**Checkpoint**: US3 peut être exécutée sur un jeu de référence sans modifier les données de production.

---

## Phase 6: User Story 4 - Gérer les évaluations et les objectifs (Priority: P2)

**Goal**: gérer les cycles, évaluations, objectifs, notes, calibration et accusés de réception.

**Independent Test**: un cycle de test est ouvert, une évaluation est générée, complétée par l’employé et le manager, puis accusée réception et clôturée.

### Tests for User Story 4

- [ ] T054 [P] [US4] Écrire les tests de transitions de cycle et d’évaluation dans `tests/integration/us4_performance_states.sql`. — [GitHub #48](https://github.com/khalidh/HRMS/issues/48)
- [ ] T055 [P] [US4] Écrire les tests d’accès employé/manager/RH et de notation dans `tests/security/us4_performance_access.sql`. — [GitHub #49](https://github.com/khalidh/HRMS/issues/49)

### Implementation for User Story 4

- [ ] T056 [P] [US4] Créer les vues sécurisées cycles, évaluations, objectifs et distribution des notes dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_performance_views.sql`. — [GitHub #50](https://github.com/khalidh/HRMS/issues/50)
- [ ] T057 [US4] Compléter les transitions et validations de `PKG_PERFORMANCE` dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_PERFORMANCE.pkb`. — [GitHub #51](https://github.com/khalidh/HRMS/issues/51)
- [ ] T058 [US4] Créer les pages APEX cycles et génération des évaluations dans `apex/application/pages/us4_review_cycles.sql`. — [GitHub #52](https://github.com/khalidh/HRMS/issues/52)
- [ ] T059 [US4] Créer les pages APEX auto-évaluation, évaluation manager et accusé de réception dans `apex/application/pages/us4_reviews.sql`. — [GitHub #53](https://github.com/khalidh/HRMS/issues/53)
- [ ] T060 [US4] Créer les pages APEX objectifs, progression, calibration et distribution des notes dans `apex/application/pages/us4_goals_calibration.sql`. — [GitHub #54](https://github.com/khalidh/HRMS/issues/54)
- [ ] T061 [US4] Ajouter les notifications d’échéance et de changement de statut dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_NOTIFICATION.pkb`. — [GitHub #55](https://github.com/khalidh/HRMS/issues/55)
- [ ] T062 [US4] Ajouter le scénario indépendant de recette dans `tests/browser/us4_performance_journey.md`. — [GitHub #56](https://github.com/khalidh/HRMS/issues/56)

**Checkpoint**: le cycle d’évaluation complet est indépendant et respecte les rôles.

---

## Phase 7: User Story 5 - Consulter les tableaux de bord, rapports et journaux (Priority: P2)

**Goal**: fournir les indicateurs, rapports, exports contrôlés et recherches d’audit adaptés au profil.

**Independent Test**: un utilisateur autorisé filtre un rapport, vérifie la date de référence et obtient un export sans colonnes sensibles non autorisées.

### Tests for User Story 5

- [ ] T063 [P] [US5] Écrire les tests de résultats des rapports et dates de référence dans `tests/integration/us5_reporting_reconciliation.sql`. — [GitHub #57](https://github.com/khalidh/HRMS/issues/57)
- [ ] T064 [P] [US5] Écrire les tests d’export et de masquage des colonnes sensibles dans `tests/security/us5_reporting_access.sql`. — [GitHub #58](https://github.com/khalidh/HRMS/issues/58)

### Implementation for User Story 5

- [ ] T065 [P] [US5] Créer ou compléter les vues de reporting effectif, rémunération, turnover, embauches, congés, paie et conformité dans `ts-plsql-oracle-forms-hrms/schema/views/hrms_reporting_views.sql`. — [GitHub #59](https://github.com/khalidh/HRMS/issues/59)
- [ ] T066 [US5] Refactorer les requêtes de `PKG_REPORTING` pour accepter date de référence, périmètre et fraîcheur affichée dans `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_REPORTING.pkb`. — [GitHub #60](https://github.com/khalidh/HRMS/issues/60)
- [ ] T067 [US5] Créer le tableau de bord personnalisé par rôle dans `apex/application/pages/us5_dashboard.sql`. — [GitHub #61](https://github.com/khalidh/HRMS/issues/61)
- [ ] T068 [US5] Créer les pages de rapports interactifs et imprimables dans `apex/application/pages/us5_reports.sql`. — [GitHub #62](https://github.com/khalidh/HRMS/issues/62)
- [ ] T069 [US5] Implémenter les contrôles d’export, journalisation et masquage dans `apex/shared-components/export-security.md` et `ts-plsql-oracle-forms-hrms/plsql/packages/PKG_AUDIT.pkb`. — [GitHub #63](https://github.com/khalidh/HRMS/issues/63)
- [ ] T070 [US5] Créer la page de recherche d’audit et d’historique dans `apex/application/pages/us5_audit_search.sql`. — [GitHub #64](https://github.com/khalidh/HRMS/issues/64)
- [ ] T071 [US5] Ajouter le scénario indépendant de recette dans `tests/browser/us5_reporting_journey.md`. — [GitHub #65](https://github.com/khalidh/HRMS/issues/65)

**Checkpoint**: les rapports prioritaires sont comparables aux résultats source et protégés par rôle.

---

## Phase 8: User Story 6 - Exploiter l’administration et les traitements planifiés (Priority: P3)

**Goal**: administrer les paramètres, rôles, intégrations, notifications, jobs, rétention et supervision.

**Independent Test**: un administrateur autorisé consulte un job échoué, le relance avec sa clé d’idempotence et vérifie son résultat sans doublon.

### Tests for User Story 6

- [ ] T072 [P] [US6] Écrire les tests de jobs, reprise, idempotence et erreurs dans `tests/integration/us6_operations.sql`. — [GitHub #66](https://github.com/khalidh/HRMS/issues/66)
- [ ] T073 [P] [US6] Écrire les tests de rôles, paramètres, intégrations et accès auditeur dans `tests/security/us6_admin_access.sql`. — [GitHub #67](https://github.com/khalidh/HRMS/issues/67)

### Implementation for User Story 6

- [ ] T074 [P] [US6] Créer les pages APEX paramètres, lookups, rôles et mapping SSO dans `apex/application/pages/us6_admin_configuration.sql`. — [GitHub #68](https://github.com/khalidh/HRMS/issues/68)
- [ ] T075 [P] [US6] Créer la page APEX de supervision des jobs et traitements dans `apex/application/pages/us6_batch_monitoring.sql`. — [GitHub #69](https://github.com/khalidh/HRMS/issues/69)
- [ ] T076 [US6] Implémenter la file notification, retry limité et annulation dans `jobs/scheduler/notification_queue.sql` et `apex/application/pages/us6_notifications.sql`. — [GitHub #70](https://github.com/khalidh/HRMS/issues/70)
- [ ] T077 [US6] Obtenir, versionner et valider les schémas réels des fournisseurs avant d’ajouter les contrats ORDS avantages, temps/présence et synchronisation organisationnelle dans `specs/001-oracle-apex-migration/contracts/external-inputs.md`, `ords/modules/benefits_feed.sql`, `time_attendance_import.sql` et `org_sync.sql`. — [GitHub #71](https://github.com/khalidh/HRMS/issues/71)
- [ ] T078 [US6] Implémenter l’archivage/anonymisation par catégorie de conservation dans `jobs/scheduler/retention.sql` et `ts-plsql-oracle-forms-hrms/schema/tables/07_retention_catalog.sql`. — [GitHub #72](https://github.com/khalidh/HRMS/issues/72)
- [ ] T079 [US6] Documenter et automatiser la sauvegarde, restauration, RTO 4 heures et RPO 1 heure dans `jobs/operations/disaster-recovery.md`. — [GitHub #73](https://github.com/khalidh/HRMS/issues/73)
- [ ] T080 [US6] Ajouter le scénario indépendant de supervision et reprise dans `tests/browser/us6_operations_journey.md`. — [GitHub #74](https://github.com/khalidh/HRMS/issues/74)

**Checkpoint**: les fonctions d’exploitation, d’intégration et de reprise sont observables et contrôlées.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: finaliser la migration, la qualité, l’accessibilité et la bascule progressive.

- [ ] T081 [P] Exécuter la recette complète multi-rôles et corriger les écarts dans `tests/browser/regression-suite.md`. — [GitHub #75](https://github.com/khalidh/HRMS/issues/75)
- [ ] T082 [P] Exécuter le rapprochement complet Forms/APEX et produire le rapport dans `ts-plsql-oracle-forms-hrms/data/migration/reconciliation-report.sql`. — [GitHub #76](https://github.com/khalidh/HRMS/issues/76)
- [ ] T083 [P] Exécuter le test de charge 200 utilisateurs et optimiser les requêtes lentes dans `tests/performance/load-test.md` et `ts-plsql-oracle-forms-hrms/schema/views/`. — [GitHub #77](https://github.com/khalidh/HRMS/issues/77)
- [ ] T084 [P] Exécuter l’analyse d’accessibilité et la navigation clavier sur les pages prioritaires dans `tests/accessibility/apex-accessibility.md`. — [GitHub #78](https://github.com/khalidh/HRMS/issues/78)
- [ ] T085 [P] Exécuter les tests d’accès horizontal/vertical, injection, session, upload et export dans `tests/security/security-regression.md`. — [GitHub #79](https://github.com/khalidh/HRMS/issues/79)
- [ ] T086 Répéter la migration complète sur un environnement de préproduction et archiver les écarts dans `ts-plsql-oracle-forms-hrms/data/migration/rehearsal-report.md`. — [GitHub #80](https://github.com/khalidh/HRMS/issues/80)
- [ ] T087 Finaliser la documentation utilisateur, administrateur et exploitation dans `docs/hrms-apex-user-guide.md`, `docs/hrms-apex-admin-guide.md` et `docs/hrms-apex-operations.md`. — [GitHub #81](https://github.com/khalidh/HRMS/issues/81)
- [ ] T088 Ratifier la constitution du projet et remplacer les placeholders dans `.specify/memory/constitution.md` avant toute mise en production ; bloquer la release si cette tâche n’est pas validée. — [GitHub #82](https://github.com/khalidh/HRMS/issues/82)
- [ ] T089 Exécuter toutes les étapes de [quickstart.md](./quickstart.md) et archiver la preuve de recette dans `tests/acceptance/release-readiness.md`. — [GitHub #83](https://github.com/khalidh/HRMS/issues/83)
- [ ] T090 Préparer la bascule progressive, les critères d’arrêt Forms/APEX et l’hypercare dans `docs/cutover-runbook.md`. — [GitHub #84](https://github.com/khalidh/HRMS/issues/84)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: aucune dépendance ; T002–T006 peuvent être parallélisées après T001.
- **Phase 2 Foundational**: dépend de T001–T003 et bloque toutes les user stories.
- **Phases 3–5 P1**: dépendent de la fondation ; US1, US2 et US3 peuvent être développées en parallèle après T018, avec intégration des employés nécessaire avant les jeux de données complets de congés et paie.
- **Phases 6–7 P2**: dépendent des fondations et peuvent démarrer en parallèle de US2/US3 si leurs données de test sont disponibles.
- **Phase 8 P3**: dépend des contrats et des composants produits par les stories métier.
- **Phase 9 Polish**: dépend des stories livrées et de la disponibilité d’un environnement de préproduction.

### User Story Dependencies

- **US1**: aucune dépendance métier après la fondation ; c’est le MVP.
- **US2**: dépend des données Employé/Organisation de US1 pour le périmètre manager, mais son moteur de règles peut être développé en parallèle.
- **US3**: dépend des données Employé/Organisation de US1 et des données de référence paie ; calcul et écrans peuvent être parallélisés.
- **US4**: dépend de la hiérarchie Employé/Manager de US1.
- **US5**: dépend des vues et données produites par US1–US4 pour les rapports complets ; le dashboard shell peut démarrer en parallèle.
- **US6**: dépend du framework de jobs de la fondation et des contrats consommés par US2, US3 et US5.

### Within Each User Story

- Les tests marqués comme préalables doivent être écrits et échouer avant l’implémentation correspondante.
- Les vues et packages métier précèdent les pages APEX.
- Les contrats d’intégration précèdent les endpoints ORDS.
- Une story est validée par son critère de test indépendant avant de passer à la suivante.

## Parallel Execution Examples

### User Story 1

```text
Parallèle après T018 :
- T019 permissions
- T020 cycle de vie
- T021 rapprochement Forms/APEX

Parallèle après les tests :
- T022 vues employé
- T023 validations
```

### User Story 2

```text
Parallèle après T018 :
- T030 règles congés
- T031 permissions congés
- T032 rapprochement congés

Parallèle après les vues/règles :
- T035 self-service
- T037 approbation
- T038 administration congés
```

### User Stories 4 et 5

```text
Après la fondation :
- US4 : T054/T055 puis T056/T058
- US5 : T063/T064 puis T065/T067
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Compléter Phase 1 et Phase 2.
2. Implémenter US1 avec recherche, fiche, organisation, cycle de vie, audit et permissions.
3. Exécuter `tests/browser/us1_employee_journey.md` et les contrôles de sécurité.
4. Démontrer le MVP sur des données anonymisées avant d’ouvrir la paie ou les congés.

### Incremental Delivery

1. Ajouter US2 et valider les demandes/approbations de congé.
2. Ajouter US3 et valider le rapprochement paie en parallèle avec Forms.
3. Ajouter US4 et US5 pour performance et pilotage.
4. Ajouter US6 pour l’exploitation, les intégrations et la rétention.
5. Répéter la migration et les tests de reprise avant la bascule progressive.

### Parallel Team Strategy

Après la fondation :

- Équipe A : US1 Employés/Organisation.
- Équipe B : US2 Congés.
- Équipe C : US3 Paie.
- Équipe D : US4 Performance et US5 Reporting.
- Équipe plateforme : US6 Jobs, ORDS, SSO et exploitation.

Les modifications communes de `PKG_AUDIT`, `PKG_APP_CONTEXT`, `PKG_BATCH` et des vues de sécurité doivent être intégrées par une seule équipe responsable afin d’éviter les conflits.
