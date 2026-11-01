# Research — Migration HRMS vers Oracle APEX

## Decision 1 — Conserver une couche métier PL/SQL et faire d’APEX une couche d’expérience

**Decision**: conserver les packages métier `PKG_EMPLOYEE`, `PKG_PAYROLL`, `PKG_LEAVE`, `PKG_PERFORMANCE`, `PKG_SECURITY`, `PKG_AUDIT`, `PKG_NOTIFICATION`, `PKG_REPORTING`, `PKG_VALIDATION`, `PKG_COMMON` et `PKG_INTEGRATION` comme point de contrôle transactionnel. Les pages APEX appellent des procédures/fonctions contrôlées et ne dupliquent pas les règles métier.

**Rationale**: la spécification exige la conservation des résultats, de l’historique et de la coexistence Forms/APEX. Une couche métier commune permet de comparer les deux interfaces et limite la divergence des règles.

**Alternatives considered**: réécrire toute la logique dans les processus de page APEX ; rejeté car cela dupliquerait les règles et rendrait la comparaison avec Forms plus risquée.

## Decision 2 — Authentification fédérée et autorisations applicatives séparées

**Decision**: utiliser des comptes locaux APEX temporaires et synthétiques en développement, puis OIDC en préproduction et production. Le fournisseur, les issuers et les claims exacts restent à confirmer avec l’IAM. Mapper l’identité vers les profils et périmètres HRMS ; vérifier les autorisations côté serveur à chaque page, processus et opération métier.

**Rationale**: la décision utilisateur réserve les comptes locaux au développement et exige OIDC avant les environnements partagés. L’identité technique ne suffit pas à déterminer le périmètre RH, qui doit être résolu dans les données HRMS.

**Alternatives considered**: comptes locaux en préproduction/production ou SAML ; non retenus. Les comptes locaux restent réservés au développement et aucun fournisseur ou fallback n'est activé tant que l’IAM n’a pas confirmé le paramétrage OIDC.

**Source**: [APEX 26.2 Authentication Schemes](https://docs.oracle.com/en/database/oracle/apex/26.2/aeadm/about-configuring-authentication-schemes.html) et [APEX 26.2 Instance Authentication](https://docs.oracle.com/en/database/oracle/apex/26.2/aeadm/configuring-authentication-schemes-for-instance.html).

## Decision 3 — Utiliser Universal Theme et valider l’accessibilité dans le cycle de recette

**Decision**: utiliser Universal Theme comme base visuelle, avec contrôles clavier, libellés, focus, messages et contraste vérifiés sur les pages prioritaires.

**Rationale**: le périmètre inclut desktop/tablette et l’accessibilité. Oracle recommande Universal Theme pour les applications APEX accessibles et fournit un guide de validation.

**Alternatives considered**: thème entièrement personnalisé ; rejeté pour la première version afin de limiter la dette CSS et le risque d’accessibilité.

**Source**: [APEX 26.2 Accessibility Guide](https://docs.oracle.com/en/database/oracle/apex/26.2/aeacc/) et [Universal Theme Design System](https://docs.oracle.com/en/database/oracle/apex/26.1/apxdc/universal-theme-design-system.html).

## Decision 4 — Exécuter les traitements longs via des jobs suivis et idempotents

**Decision**: lancer paie, acquisition, report, expiration, notifications, rafraîchissement de rapports et intégrations dans des jobs contrôlés. Chaque exécution reçoit un identifiant, un statut, des dates, un compteur, un message d’erreur et une clé d’idempotence.

**Rationale**: les traitements peuvent durer plusieurs minutes et la spécification impose une consultation sans blocage du navigateur, une reprise contrôlée et l’absence de doublons.

**Alternatives considered**: exécuter tout le traitement dans la requête web APEX ; rejeté pour éviter les timeouts, les doubles soumissions et l’absence de suivi fiable.

## Decision 5 — N’exposer que des contrats ORDS explicites

**Decision**: utiliser les processus APEX et les packages Oracle pour le fonctionnement interne. N’exposer via ORDS que les endpoints nécessaires aux intégrations GL, avantages, temps/présence et synchronisation organisationnelle, avec authentification, validation, idempotence et audit.

**Rationale**: le service REST-enabled SQL d’ORDS permet l’exécution de SQL/PLSQL mais serait trop permissif pour une application RH ; les intégrations doivent avoir des contrats limités.

**Alternatives considered**: activer REST-enabled SQL pour les consommateurs externes ; rejeté car il élargit inutilement la surface d’attaque et ne fournit pas un contrat métier stable.

**Source**: [ORDS 26.3 Developer’s Guide](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/26.3/orddg/index.html) et [REST-Enabled SQL Service](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/26.2/orddg/rest-enabled-sql-service.html).

## Decision 6 — Migrer tout l’historique avec staging et rapprochement

**Decision**: migrer toutes les données historiques disponibles et valides via des étapes staging → validation → chargement → rapprochement. Les données non migrables sont isolées dans un rapport d’anomalies ; aucune correction silencieuse n’est autorisée.

**Rationale**: la clarification utilisateur demande tout l’historique et la spécification impose des contrôles de volumes, clés, statuts et agrégats.

**Alternatives considered**: migrer seulement les 3 ou 7 dernières années ; rejeté car cela casserait la traçabilité RH et les comparaisons historiques.

## Decision 7 — Traiter la conservation par catégorie

**Decision**: définir dans un catalogue de conformité la durée de conservation des données RH, paie, pièces jointes, notifications et audit par catégorie et juridiction. Les jobs d’archivage/anonymisation appliquent cette matrice après validation légale.

**Rationale**: la clarification a retenu une durée dépendant des obligations légales et de la politique interne, et non une durée uniforme.

**Alternatives considered**: conservation uniforme ou indéfinie ; rejetées car elles peuvent être insuffisantes ou excessives selon la catégorie de donnée.

## Unknowns resolved

- Authentification : comptes locaux APEX temporaires en développement et OIDC en préproduction/production ; fournisseur, issuers et claims à confirmer avec l’IAM.
- Coexistence : exécution parallèle Forms/APEX puis bascule progressive.
- Historique : tout l’historique disponible et valide.
- Continuité : RTO 4 heures, RPO 1 heure.
- Conservation : matrice par catégorie, validée avant production.
- Les contrats détaillés des systèmes GL, avantages et temps/présence restent une dépendance d’entrée pour la phase d’intégration, pas un choix d’architecture bloquant.
