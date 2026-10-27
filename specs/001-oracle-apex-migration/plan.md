# Implementation Plan: Migration HRMS vers Oracle APEX

**Branch**: `001-oracle-apex-migration` | **Date**: 2026-10-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from [spec.md](./spec.md)

## Summary

Migrer l’application RH Oracle Forms vers une application web Oracle APEX en conservant le schéma HRMS, l’historique complet, les règles métier validées et les résultats de référence. L’implémentation adopte une approche progressive : les packages PL/SQL restent la couche métier transactionnelle, APEX fournit les parcours web, les contrôles d’accès et les rapports, et les traitements longs sont suivis de façon asynchrone. Forms et APEX fonctionneront en parallèle pendant la comparaison et la bascule.

## Technical Context

**Language/Version**: SQL et PL/SQL Oracle ; cible Oracle Database 26ai, compatibilité à vérifier avec les scripts source Oracle 19c ; APEX 26.2 ; ORDS 26.3.

**Primary Dependencies**: Oracle APEX, ORDS, Universal Theme, `DBMS_SCHEDULER`, packages métier HRMS existants, fournisseur SSO OIDC ou SAML, SQL*Plus/SQLcl pour les déploiements.

**Storage**: Schéma Oracle `HRMS` existant, incluant les tables core, paie, congés, performance, audit, notifications, vues et séquences ; tables auxiliaires de suivi de traitements et de migration à ajouter si nécessaire.

**Testing**: SQLcl et utPLSQL lorsque disponibles pour les validations SQL/PLSQL, tests d’intégration base/jobs/imports, Playwright pour les parcours navigateur, contrôle APEX Advisor/accessibilité, tests de sécurité par rôle et périmètre, et rapprochement Forms/APEX.

**Target Platform**: Application web Oracle APEX servie par ORDS, accessible sur desktop et tablette, avec SSO d’entreprise et déploiement versionné entre environnements.

**Project Type**: Application web métier et migration de données Oracle.

**Performance Goals**: Au moins 200 utilisateurs concurrents ; 95 % des recherches usuelles en moins de 3 secondes ; traitements de paie et batch suivis sans bloquer le navigateur ; RTO maximal de 4 heures et RPO maximal d’une heure.

**Constraints**: Préserver les identifiants, l’historique et les résultats validés ; migrer tout l’historique disponible ; ne pas exposer de SQL générique ; ne pas committer de secrets ; masquer les données sensibles ; assurer la coexistence Forms/APEX ; contrôler les accès côté serveur.

**Scale/Scope**: 6 parcours prioritaires, 200 utilisateurs concurrents, environ 42 tables et 15 vues annoncées dans la documentation source, 12 packages PL/SQL métier, données d’employés, paie, congés, performance, audit, notifications et intégrations.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

La constitution actuelle est encore le template non ratifié et ne définit donc aucune règle contraignante applicable au projet. Les garde-fous de la spécification sont appliqués comme règles de travail provisoires, mais la mise en production reste conditionnée à la ratification de la constitution.

- **Gate sécurité** : PASS — SSO fédéré, autorisations serveur, masquage des données sensibles et audit inclus.
- **Gate données** : PASS — conservation des identifiants et de l’historique, migration répétable et rapprochement obligatoire.
- **Gate qualité** : PASS — tests unitaires, intégration, sécurité, performance, accessibilité et comparaison Forms/APEX prévus.
- **Gate exploitation** : PASS — traitements suivis, reprise contrôlée, RTO/RPO mesurables et procédure de rollback.
- **Point de gouvernance** : CONDITIONAL — la constitution doit être ratifiée avant la mise en production ; T088 est un gate de release et non une autorisation de contourner la gouvernance.

## Project Structure

### Documentation (this feature)

```text
specs/001-oracle-apex-migration/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── authentication.md
│   ├── integrations.md
│   ├── role-access.md
│   └── external-inputs.md
├── checklists/requirements.md
└── tasks.md                 # généré par $speckit-tasks
```

### Source Code (repository root)

```text
ts-plsql-oracle-forms-hrms/
├── schema/
│   ├── tables/              # schéma conservé et extensions ciblées
│   ├── views/               # vues sécurisées et rapports
│   └── sequences/           # séquences et identifiants
├── plsql/
│   ├── packages/            # logique métier refactorée et APIs transactionnelles
│   └── triggers/            # audit et invariants de données
├── data/
│   ├── seed/                # référentiels et données de démonstration
│   └── migration/           # staging, contrôles, rapprochement et rollback
├── apex/
│   ├── application/         # export APEX versionné
│   └── shared-components/   # LOV, navigation, autorisations, thème
├── ords/
│   └── modules/             # endpoints d’intégration explicitement contractuels
├── jobs/
│   └── scheduler/           # traitements planifiés et supervision
└── tests/
    ├── sql/                 # validations, contraintes et rapprochements
    ├── plsql/               # packages et règles métier
    ├── integration/         # jobs, imports, notifications et intégrations
    ├── security/            # matrice rôles/périmètres
    └── browser/             # parcours APEX et accessibilité
```

**Structure Decision**: conserver le dépôt SQL/PLSQL source comme socle de données et de métier, versionner un export APEX installable ainsi que des descripteurs page par page sous `apex/application/pages/`, et isoler les scripts de migration, jobs, endpoints et tests. Les exports Forms restent en lecture pour la traçabilité et la comparaison, mais ne sont plus la couche d’interface cible.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Coexistence Forms/APEX | La paie et les congés exigent une comparaison progressive et une bascule contrôlée. | Une bascule unique ne permet pas de comparer les résultats ni de réduire le risque opérationnel. |
| Tables auxiliaires de suivi de traitements | Les exécutions asynchrones et les reprises doivent être observables et idempotentes. | Réutiliser uniquement les tables métier ne permet pas de distinguer les tentatives, erreurs et reprises techniques. |
