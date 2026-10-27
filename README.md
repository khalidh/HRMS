# HRMS — Migration Oracle Forms vers Oracle APEX

## Vue générale

Ce projet concerne la modernisation d’un système de gestion des ressources humaines (HRMS) historiquement développé avec Oracle Forms et PL/SQL.

L’application couvre les processus RH principaux d’une organisation : gestion des employés, organisation, congés, paie, évaluations de performance, reporting, audit, notifications et intégrations externes.

L’objectif est de migrer progressivement l’application vers une application web Oracle APEX, servie par ORDS, tout en conservant les données historiques, les règles métier validées et la traçabilité existante.

## Objectif du projet

La cible est une application Oracle APEX moderne, sécurisée et responsive qui :

- remplace les écrans Oracle Forms ;
- réutilise les packages métier PL/SQL lorsque leur comportement est valide ;
- permet un accès desktop et tablette ;
- applique des permissions côté serveur selon les profils ;
- protège les données personnelles, fiscales et bancaires ;
- conserve tout l’historique disponible ;
- permet une coexistence Forms/APEX pendant la migration ;
- fournit des rapports, des traitements batch suivis et des mécanismes de reprise ;
- est déployable à partir d’artefacts versionnés sans secrets dans le dépôt.

## Fonctionnalités couvertes

### Employés et organisation

- recherche par matricule, nom, département, statut, lieu et période d’embauche ;
- fiche employé avec identité, coordonnées, emploi, manager et lieu ;
- gestion des départements, postes, grades et lieux ;
- gestion des dépendants et contacts d’urgence ;
- embauche, transfert, promotion, termination et réembauche ;
- historique des changements et audit ;
- contrôle des cycles dans les hiérarchies.

### Congés

- consultation des soldes et du calendrier ;
- soumission, modification et annulation des demandes ;
- gestion des demi-journées et justificatifs ;
- calcul des jours ouvrés et prise en compte des jours fériés ;
- détection des chevauchements et des soldes insuffisants ;
- approbation ou rejet par manager/RH ;
- acquisition, report et expiration automatisés.

### Paie

- gestion des salaires, éléments de paie et informations fiscales ;
- gestion des comptes bancaires avec masquage des données sensibles ;
- création des périodes et exécutions de paie ;
- calcul asynchrone et suivi des erreurs par employé ;
- totaux brut, déductions, net et coût employeur ;
- approbation, paiement et inversion contrôlée ;
- bulletins, registres et export GL.

### Performance

- création et suivi des cycles d’évaluation ;
- auto-évaluation et évaluation manager ;
- objectifs, pondération, progression et dates cibles ;
- notation, commentaires et plan de développement ;
- accusé de réception ;
- calibration et distribution des notes.

### Reporting et administration

- tableau de bord personnalisé par rôle ;
- rapports d’effectif, rémunération, turnover et nouvelles embauches ;
- rapports d’utilisation des congés, paie et conformité ;
- exports contrôlés et journalisés ;
- gestion des rôles, permissions et paramètres ;
- file de notifications et reprise des échecs ;
- supervision des jobs et intégrations ;
- audit des opérations sensibles.

## Profils utilisateurs

| Profil | Responsabilités principales |
|---|---|
| Employé | Profil personnel, congés, évaluations et données autorisées. |
| Manager | Équipe, approbations de congés, évaluations et objectifs. |
| RH | Employés, organisation, congés, performance et rapports RH. |
| Gestionnaire paie | Salaires, périodes, calculs, approbations et bulletins. |
| Administrateur | Paramètres, rôles, jobs, intégrations et supervision. |
| Auditeur | Consultation des historiques, audits et rapports autorisés. |

L’authentification cible est un SSO d’entreprise via OIDC ou SAML. Un seul protocole doit être sélectionné par environnement et ses claims doivent être mappés vers les rôles et périmètres HRMS.

## Architecture cible

```text
Utilisateur
    │
    ▼
Oracle APEX ─── SSO OIDC/SAML
    │
    ▼
ORDS
    │
    ▼
Schéma Oracle HRMS
    ├── Tables et vues métier
    ├── Packages PL/SQL
    ├── Jobs DBMS_SCHEDULER
    ├── Audit et notifications
    └── Intégrations contractuelles
```

Les traitements longs, comme la paie et les acquisitions de congés, doivent être exécutés de façon asynchrone et suivis par identifiant, statut, volume, erreur et clé d’idempotence.

## Organisation du dépôt

```text
.
├── Specification.md                         # spécification métier initiale
├── Installation md                         # notes d’installation Oracle/APEX/ORDS
├── specs/001-oracle-apex-migration/         # artefacts Spec Kit
│   ├── spec.md                              # spécification structurée
│   ├── plan.md                              # plan d’architecture et d’implémentation
│   ├── research.md                          # décisions et recherches techniques
│   ├── data-model.md                         # modèle de données cible
│   ├── quickstart.md                         # guide de validation
│   ├── contracts/                            # contrats SSO, rôles et intégrations
│   ├── checklists/                           # checklist qualité
│   └── tasks.md                              # tâches d’implémentation
├── .specify/                                 # configuration Spec Kit
├── .agents/skills/                           # skills Spec Kit pour Codex
└── ts-plsql-oracle-forms-hrms/              # application Oracle Forms source
    ├── forms/                                # exports Forms, menus et bibliothèques
    ├── plsql/                               # packages et triggers PL/SQL
    ├── schema/                              # tables, séquences et vues
    └── data/                                # données de référence et de démonstration
```

## Stratégie de migration

La migration suit une approche progressive :

1. inventorier et valider le schéma, les packages, les Forms et les données ;
2. préparer les fondations APEX : SSO, rôles, audit, erreurs et jobs ;
3. livrer le module Employés/Organisation comme MVP ;
4. ajouter les congés et les approbations ;
5. ajouter la paie avec rapprochement parallèle des résultats ;
6. ajouter performance, reporting et administration ;
7. migrer tout l’historique disponible avec staging et rapprochement ;
8. faire fonctionner Forms et APEX en parallèle ;
9. effectuer une bascule progressive suivie d’une période d’hypercare.

Les objectifs d’exploitation retenus sont un RTO maximal de 4 heures et un RPO maximal d’une heure. La conservation des données est définie par catégorie selon les obligations légales et la politique interne.

## Workflow Spec Kit

Spec Kit est installé dans ce projet et configuré pour Codex. Les commandes se lancent dans la conversation Codex avec le préfixe `$`.

### 1. Constitution

Définir les principes, règles de qualité, contraintes de sécurité et règles de gouvernance du projet :

```text
$speckit-constitution
```

La constitution actuelle est encore un template. Elle doit être ratifiée avant la mise en production.

### 2. Spécification

Créer ou mettre à jour la spécification d’une fonctionnalité :

```text
$speckit-specify
```

Dans ce projet, la spécification de migration est disponible dans [spec.md](./specs/001-oracle-apex-migration/spec.md).

### 3. Clarification

Identifier les décisions manquantes et les enregistrer dans la spécification :

```text
$speckit-clarify
```

Les décisions déjà prises concernent le SSO, la coexistence Forms/APEX, l’historique à migrer, le RTO/RPO et la conservation des données.

### 4. Planification

Générer l’architecture, les recherches, le modèle de données, les contrats et le guide de validation :

```text
$speckit-plan
```

Voir [plan.md](./specs/001-oracle-apex-migration/plan.md), [data-model.md](./specs/001-oracle-apex-migration/data-model.md) et [quickstart.md](./specs/001-oracle-apex-migration/quickstart.md).

### 5. Tâches

Générer les tâches ordonnées et dépendantes par user story :

```text
$speckit-tasks
```

Les tâches actuelles sont dans [tasks.md](./specs/001-oracle-apex-migration/tasks.md). Elles couvrent le setup, les fondations, les six user stories et la phase de finalisation.

### 6. Analyse

Vérifier la cohérence entre spécification, plan et tâches :

```text
$speckit-analyze
```

Cette étape est en lecture seule et doit être relancée après toute modification importante des artefacts.

### 7. Implémentation

Exécuter les tâches validées :

```text
$speckit-implement
```

L’implémentation doit commencer par le MVP Employés/Organisation, puis progresser vers les congés, la paie, la performance, le reporting et l’administration.

## Commandes Spec Kit complémentaires

```text
$speckit-checklist     # générer une checklist ciblée
$speckit-converge      # comparer le code aux artefacts et compléter les tâches
```

## État actuel

- Spécification métier initiale créée dans [Specification.md](./Specification.md).
- Spécification structurée créée dans [spec.md](./specs/001-oracle-apex-migration/spec.md).
- Clarifications réalisées et intégrées.
- Plan, recherche, modèle de données et contrats générés.
- 90 tâches d’implémentation générées, dont 40 parallélisables.
- Analyse de cohérence exécutée après corrections.
- Prochaine étape : `$speckit-implement`.

## Sécurité

Ne jamais versionner de mots de passe, tokens SSO, certificats privés, chaînes de connexion ou données de production. Les paramètres d’environnement doivent être fournis par un gestionnaire de secrets ou par la configuration du workspace APEX.

Voir également [INSTALLATION.md](./INSTALLATION.md) pour les prérequis Oracle, APEX et ORDS. Les notes d’installation locales contenant des secrets restent volontairement hors du dépôt.
