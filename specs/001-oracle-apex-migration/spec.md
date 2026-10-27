# Feature Specification: Migration HRMS vers Oracle APEX

**Feature Branch**: `001-oracle-apex-migration`

**Created**: 2026-10-27

**Status**: Draft

**Input**: User description: `Specification.md`

## Clarifications

### Session 2026-10-27

- Q: Quel mode d’authentification doit être retenu pour les utilisateurs HRMS ? → A: SSO d’entreprise via OIDC ou SAML.
- Q: Quelle stratégie de bascule doit être utilisée entre Oracle Forms et la nouvelle application HRMS ? → A: Migration progressive avec coexistence et exécution parallèle.
- Q: Quelle profondeur d’historique doit être migrée vers la nouvelle application ? → A: Tout l’historique disponible.
- Q: Quel niveau de continuité de service et de reprise après incident doit être garanti pour HRMS ? → A: RTO ≤ 4 heures et RPO ≤ 1 heure.
- Q: Quelle règle de conservation doit s’appliquer aux données RH, à la paie et aux journaux d’audit ? → A: Durée définie par catégorie selon les obligations légales et la politique interne.

## User Scenarios & Testing

### User Story 1 - Administrer les employés et l’organisation (Priority: P1)

Un utilisateur RH recherche, consulte et met à jour les dossiers employés ainsi que la structure organisationnelle. Il peut gérer les étapes du cycle de vie d’un employé, avec validation des droits et conservation de l’historique.

**Why this priority**: Les employés et l’organisation constituent le référentiel central utilisé par la paie, les congés, la performance et les rapports.

**Independent Test**: Avec un jeu de données de référence, un utilisateur RH peut rechercher un employé, modifier un champ autorisé, effectuer un transfert et vérifier que l’historique, l’audit et les informations courantes sont cohérents.

**Acceptance Scenarios**:

1. **Given** un utilisateur RH autorisé et un employé actif, **When** il recherche par matricule, nom, département ou statut, **Then** seuls les employés correspondant aux filtres sont affichés.
2. **Given** un transfert valide, **When** l’utilisateur le confirme, **Then** le département, le poste, le manager ou le lieu sont mis à jour ensemble et une entrée d’historique est créée.
3. **Given** une tentative de cycle dans la hiérarchie des managers ou départements, **When** l’utilisateur enregistre la modification, **Then** l’opération est refusée avec un message explicite.
4. **Given** un utilisateur non autorisé, **When** il tente de modifier un dossier, **Then** la modification est refusée côté serveur et l’événement est journalisé.

### User Story 2 - Gérer les congés et les approbations (Priority: P1)

Un employé consulte ses soldes, soumet une demande de congé et suit son statut. Un manager ou un membre RH consulte les demandes de son périmètre, les approuve ou les rejette et peut administrer les soldes selon ses droits.

**Why this priority**: Les congés sont un processus quotidien et nécessitent un contrôle fiable des soldes, des conflits et des approbations.

**Independent Test**: Un employé peut soumettre une demande valide, un manager peut l’approuver ou la rejeter, et le solde ainsi que le calendrier d’équipe reflètent le résultat.

**Acceptance Scenarios**:

1. **Given** un solde suffisant et aucune demande en conflit, **When** l’employé soumet des dates valides, **Then** la demande est créée avec le statut `PENDING` et le responsable reçoit une notification.
2. **Given** une demande qui chevauche une demande existante ou dépasse le solde disponible, **When** l’employé la soumet, **Then** elle est refusée avant enregistrement et la raison est affichée.
3. **Given** une demande en attente appartenant à l’équipe du manager, **When** le manager l’approuve ou la rejette avec commentaire, **Then** le statut, le solde et l’historique de notification sont mis à jour.
4. **Given** un justificatif obligatoire manquant, **When** l’employé tente de soumettre la demande, **Then** la soumission est bloquée.

### User Story 3 - Exécuter et contrôler la paie (Priority: P1)

Un gestionnaire paie crée une période et une exécution, lance le calcul, consulte les erreurs et les totaux, puis soumet le résultat à approbation. Les états de période et d’exécution empêchent les opérations incompatibles.

**Why this priority**: La paie est un processus financier sensible dont les résultats doivent rester compatibles avec le système existant et auditables.

**Independent Test**: Sur un jeu de paie connu, le gestionnaire crée une exécution, obtient les totaux attendus, traite les erreurs, approuve le résultat et vérifie qu’une période clôturée ne peut plus être modifiée.

**Acceptance Scenarios**:

1. **Given** une période ouverte, **When** le gestionnaire crée une exécution valide, **Then** l’exécution est créée avec un état initial traçable.
2. **Given** une exécution calculable, **When** le gestionnaire lance le calcul, **Then** le traitement peut être suivi, les erreurs sont visibles par employé et les totaux sont calculés.
3. **Given** une exécution déjà payée ou une période clôturée, **When** un utilisateur tente de la recalculer ou de la modifier, **Then** l’opération est refusée.
4. **Given** une inversion autorisée, **When** elle est confirmée avec un motif, **Then** les résultats sont inversés, l’action est auditée et la justification est conservée.

### User Story 4 - Gérer les évaluations et les objectifs (Priority: P2)

Un responsable RH ouvre un cycle d’évaluation, génère les évaluations, puis les employés et managers complètent leurs parties. Les objectifs, notes, commentaires, plans de développement et accusés de réception sont suivis jusqu’à la clôture.

**Why this priority**: Le module structure le suivi annuel de la performance et doit respecter les rôles et les étapes du cycle.

**Independent Test**: Un cycle de test peut être ouvert, une évaluation générée, complétée par l’employé et le manager, puis accusée réception et clôturée.

**Acceptance Scenarios**:

1. **Given** un cycle ouvert, **When** RH génère les évaluations, **Then** une évaluation est créée pour chaque employé éligible avec un reviewer valide.
2. **Given** une évaluation au statut approprié, **When** l’employé ou le manager soumet sa partie, **Then** seuls les champs et transitions autorisés sont appliqués.
3. **Given** une évaluation clôturée, **When** un utilisateur tente de la modifier, **Then** la modification est refusée.
4. **Given** des évaluations d’un département, **When** un utilisateur autorisé consulte la distribution des notes, **Then** les résultats sont filtrés selon son périmètre.

### User Story 5 - Consulter les tableaux de bord, rapports et journaux (Priority: P2)

Un utilisateur consulte un tableau de bord adapté à son rôle. Les utilisateurs autorisés exécutent des rapports d’effectif, rémunération, turnover, nouvelles embauches, congés, paie et conformité, avec filtres et exports contrôlés.

**Why this priority**: Les indicateurs et rapports permettent aux équipes RH et à la direction de piloter l’activité et de vérifier la conformité.

**Independent Test**: Pour un périmètre et une date de référence donnés, un utilisateur autorisé obtient les mêmes résultats que les données de référence et ne peut pas exporter de colonnes sensibles sans permission.

**Acceptance Scenarios**:

1. **Given** un utilisateur connecté, **When** il ouvre le tableau de bord, **Then** les indicateurs et actions affichés correspondent à son rôle et à son périmètre.
2. **Given** un rapport avec filtres, **When** l’utilisateur l’exécute, **Then** les résultats indiquent la période de référence, le niveau de fraîcheur et les critères appliqués.
3. **Given** un export de données sensibles sans permission, **When** l’utilisateur le demande, **Then** l’export est refusé et l’événement est journalisé.

### User Story 6 - Exploiter l’administration et les traitements planifiés (Priority: P3)

Un administrateur gère les paramètres, rôles, permissions, notifications, intégrations et traitements planifiés. Il peut consulter les erreurs, relancer une opération autorisée et vérifier son résultat.

**Why this priority**: La supervision et l’administration sont nécessaires pour exploiter la solution, mais peuvent être livrées après les parcours RH prioritaires.

**Independent Test**: Un administrateur lance un traitement de test, consulte son statut et son erreur éventuelle, puis vérifie qu’une reprise ne crée pas de doublon.

**Acceptance Scenarios**:

1. **Given** un traitement planifié échoué, **When** un administrateur autorisé consulte la supervision, **Then** il voit l’identifiant, les dates, le statut, le volume traité et le message d’erreur.
2. **Given** une notification en échec sous la limite de reprise, **When** l’administrateur relance la file, **Then** la notification est retentée avec un compteur incrémenté.
3. **Given** un paramètre non modifiable, **When** un utilisateur tente de le changer, **Then** l’opération est refusée et aucun secret n’est exposé.

### Edge Cases

- Les dates de congé inversées, les jours non ouvrés, les jours fériés, les demi-journées et les demandes concurrentes doivent être traités explicitement.
- Une même opération de paie, d’acquisition ou de report relancée ne doit pas produire de doublon.
- Les employés sans salaire, sans manager, sans solde ou avec des données historiques incohérentes doivent être signalés sans interrompre silencieusement tout le traitement.
- Les fichiers d’import invalides, incomplets ou dupliqués doivent être rejetés avec un rapport d’erreurs exploitable.
- Une session expirée ou une modification concurrente doit demander une reconnexion ou un rechargement avant d’écraser des données.
- Les pièces jointes non autorisées, trop volumineuses ou malveillantes doivent être refusées.
- Les utilisateurs doivent recevoir un message métier compréhensible sans stack trace ni donnée confidentielle.

## Requirements

### Functional Requirements

- **FR-001**: Le système MUST permettre à un utilisateur autorisé de rechercher et consulter les employés, départements, postes, grades et lieux selon son périmètre.
- **FR-002**: Le système MUST permettre aux profils autorisés de créer, modifier, transférer, promouvoir, terminer et réembaucher un employé avec validations métier et historique.
- **FR-003**: Le système MUST empêcher les cycles dans les hiérarchies de départements et de managers.
- **FR-004**: Le système MUST appliquer des permissions distinctes par profil, module et action, côté serveur.
- **FR-005**: Le système MUST permettre à un employé de consulter ses soldes, son calendrier, ses demandes et ses évaluations autorisées.
- **FR-006**: Le système MUST valider les dates, jours ouvrés, jours fériés, chevauchements, soldes, demi-journées et justificatifs avant de soumettre une demande de congé.
- **FR-007**: Le système MUST permettre aux managers et RH d’approuver, rejeter, annuler ou ajuster les demandes et soldes conformément à leur périmètre.
- **FR-008**: Le système MUST supporter les états et transitions des périodes, exécutions et détails de paie, en empêchant les opérations incompatibles.
- **FR-009**: Le système MUST afficher l’avancement, les erreurs par employé et les totaux d’une exécution de paie sans exiger que l’utilisateur maintienne une page ouverte.
- **FR-010**: Le système MUST préserver les résultats métier de référence de la paie, des congés et des rapports lors de la migration.
- **FR-011**: Le système MUST permettre la création, l’ouverture, le suivi, la calibration, la clôture et l’accusé de réception des cycles d’évaluation.
- **FR-012**: Le système MUST gérer les objectifs, leurs poids, statuts, dates cibles, progressions, notes et commentaires selon le rôle.
- **FR-013**: Le système MUST fournir des tableaux de bord et rapports filtrables sur l’effectif, la rémunération, le turnover, les embauches, les congés, la paie et la conformité.
- **FR-014**: Le système MUST contrôler les exports et masquer les données personnelles, fiscales, sociales et bancaires selon les permissions.
- **FR-015**: Le système MUST journaliser les créations, modifications, suppressions, approbations, exports, consultations sensibles, traitements et changements d’autorisation.
- **FR-016**: Le système MUST fournir une file de notifications avec statuts, priorité, reprise limitée et historique d’erreur.
- **FR-017**: Le système MUST fournir la supervision des acquisitions, reports, expirations, notifications, rapports, intégrations et traitements d’import/export.
- **FR-018**: Le système MUST permettre une migration répétable avec contrôles de volumes, clés, statuts, agrégats, données sensibles et anomalies.
- **FR-019**: Le système MUST fournir des messages d’erreur orientés utilisateur et conserver les détails techniques uniquement dans des journaux protégés.
- **FR-020**: Le système MUST être utilisable sur desktop et tablette, avec navigation clavier, libellés accessibles, contraste suffisant et messages d’erreur compréhensibles.
- **FR-021**: Le système MUST permettre l’installation, la configuration, la migration et le retour arrière à partir d’artefacts versionnés sans secret commité.

### Key Entities

- **Employé**: identité, coordonnées, emploi, statut, manager, département, lieu, historique, personnes à charge et contacts d’urgence.
- **Organisation**: départements hiérarchiques, lieux, postes, grades, centres de coûts et relations de management.
- **Rémunération**: salaires, éléments de paie, informations fiscales, comptes bancaires, périodes, exécutions et détails de paie.
- **Congé**: types, règles d’acquisition, soldes, demandes, calendrier, justificatifs et journal d’acquisition.
- **Évaluation**: cycles, évaluations, reviewer, auto-évaluation, évaluation manager, notes, objectifs et accusé de réception.
- **Autorisation**: utilisateur, profil, module, action, périmètre et statut d’accès.
- **Notification**: destinataire, type, contenu, priorité, référence métier, statut, reprises et erreur.
- **Audit**: table ou domaine concerné, identifiant, action, valeurs avant/après, utilisateur, date, session et adresse réseau.
- **Traitement**: type, identifiant d’exécution, statut, dates, volumes, erreurs, reprise et résultat.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Au moins 95 % des utilisateurs de recette réussissent les parcours prioritaires employés, congés et approbation sans assistance lors de leur première tentative.
- **SC-002**: Au moins 99 % des résultats de paie, soldes de congés et rapports de référence correspondent aux résultats du système source sur le jeu de comparaison validé.
- **SC-003**: Au moins 95 % des recherches usuelles affichent un résultat en moins de 3 secondes dans les conditions nominales.
- **SC-004**: Le système supporte au moins 200 utilisateurs concurrents sans perte de données ni dégradation fonctionnelle des parcours usuels.
- **SC-005**: 100 % des opérations sensibles de recette sont retrouvables dans l’audit avec utilisateur, date, action et objet concernés.
- **SC-006**: 100 % des tests de contrôle d’accès empêchent un accès horizontal ou vertical non autorisé aux données et actions protégées.
- **SC-007**: 100 % des traitements planifiés de recette exposent un statut, un identifiant, des dates, un volume et un message d’erreur en cas d’échec.
- **SC-008**: Une migration complète peut être répétée dans un environnement de test et produit un rapport de rapprochement sans doublon non expliqué.
- **SC-009**: Aucun secret, mot de passe, certificat ou donnée de production sensible n’est présent dans les artefacts versionnés de l’application.
- **SC-010**: Les utilisateurs de recette peuvent terminer les parcours principaux sur desktop et tablette avec navigation clavier et messages accessibles.
- **SC-011**: Après un incident couvert par le plan de reprise, le service est restauré en quatre heures maximum et les données perdues ne dépassent pas une heure de production.

## Assumptions

- Le schéma Oracle HRMS et les données historiques restent disponibles pendant la phase de migration et de comparaison.
- Les règles métier valides du système source constituent la référence fonctionnelle, sous réserve de correction des anomalies explicitement acceptées.
- L’authentification des utilisateurs sera assurée par le SSO d’entreprise via OIDC ou SAML ; les règles de mapping des identités vers les rôles et périmètres HRMS seront définies avant l’implémentation.
- Oracle Forms et la nouvelle application pourront fonctionner en coexistence pendant une période de comparaison contrôlée avant la bascule progressive.
- Toutes les données historiques disponibles et valides seront migrées ; les données invalides ou techniquement non migrables feront l’objet d’un rapport d’anomalies et d’une décision documentée.
- Les sauvegardes, la supervision et les procédures de reprise seront conçues et testées pour un RTO maximal de quatre heures et un RPO maximal d’une heure.
- Les traitements de paie, d’acquisition et d’intégration peuvent durer plusieurs minutes et doivent donc rester consultables sans bloquer l’utilisateur.
- Les données personnelles et bancaires des environnements non productifs seront anonymisées ou remplacées par des données synthétiques.
- Les contrats et accès aux systèmes GL, avantages et temps/présence seront fournis avant l’implémentation des intégrations correspondantes.
- Les exports Forms incomplets ou divergents du schéma SQL seront traités comme des sources à analyser, sans inventer de fonctionnalité absente du modèle validé.
- Les applications desktop et tablette sont dans le périmètre ; une application mobile native est hors périmètre initial.
- La conservation des données RH, de la paie, des pièces jointes et des journaux d’audit sera définie par catégorie selon les obligations légales et la politique interne, puis configurée et testée avant la mise en production.
