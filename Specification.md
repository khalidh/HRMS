# Spécification produit — Migration HRMS Oracle Forms vers Oracle APEX

## 1. Objet

Moderniser l’application HRMS existante, actuellement basée sur Oracle Forms 12c et des packages PL/SQL, en une application web Oracle APEX accessible via ORDS.

La migration doit conserver les données, les règles métier et les contrôles fonctionnels existants tout en fournissant une interface responsive, sécurisée et adaptée aux profils RH, managers, employés et administrateurs paie.

Cette spécification est destinée à Speckit pour générer le plan d’implémentation, le modèle de données cible, les pages APEX, les composants PL/SQL et les tests.

## 2. Périmètre source

Le dépôt de référence est [`ts-plsql-oracle-forms-hrms/`](./ts-plsql-oracle-forms-hrms/). Les sources principales sont :

- schéma HRMS dans [`schema/`](./ts-plsql-oracle-forms-hrms/schema/) : tables, séquences et vues ;
- logique métier dans [`plsql/packages/`](./ts-plsql-oracle-forms-hrms/plsql/packages/) ;
- triggers dans [`plsql/triggers/`](./ts-plsql-oracle-forms-hrms/plsql/triggers/) ;
- exports Oracle Forms dans [`forms/xml-exports/`](./ts-plsql-oracle-forms-hrms/forms/xml-exports/) ;
- données de référence et données de démonstration dans [`data/seed/`](./ts-plsql-oracle-forms-hrms/data/seed/) ;
- bibliothèques et menu Forms dans [`forms/libraries/`](./ts-plsql-oracle-forms-hrms/forms/libraries/) et [`forms/menus/`](./ts-plsql-oracle-forms-hrms/forms/menus/).

Le système source comprend notamment les packages `PKG_EMPLOYEE`, `PKG_PAYROLL`, `PKG_LEAVE`, `PKG_PERFORMANCE`, `PKG_SECURITY`, `PKG_AUDIT`, `PKG_NOTIFICATION`, `PKG_REPORTING`, `PKG_VALIDATION`, `PKG_COMMON` et `PKG_INTEGRATION`.

## 3. Objectifs et résultats attendus

### Objectifs

1. Remplacer les écrans Forms par une application APEX responsive.
2. Réutiliser le schéma Oracle et les règles métier PL/SQL lorsque leur comportement est valide.
3. Déplacer la logique d’interface et de session Forms vers des composants APEX propres : pages, validations, processus, branches, autorisations et états de session.
4. Sécuriser l’authentification, les données sensibles et les accès par rôle.
5. Fournir des écrans de recherche, de saisie, d’approbation, de traitement batch et de reporting.
6. Disposer d’un déploiement versionné et reproductible dans Oracle APEX/ORDS.

### Hors périmètre initial

- Réécriture complète de l’ERP paie ou changement de fournisseur de paie.
- Remplacement immédiat des intégrations externes par des APIs si leurs contrats ne sont pas disponibles.
- Refonte fonctionnelle non demandée des règles de calcul existantes.
- Suppression des tables historiques, d’audit ou de compatibilité avant validation de la migration.

## 4. Contexte technique cible

- Base : Oracle Database avec le schéma applicatif `HRMS`.
- Interface : Oracle APEX 26.2 ou version compatible avec l’environnement installé.
- Accès web : ORDS 26.3 ou version compatible.
- Application : une application APEX exportable, installable et promotable entre environnements.
- Langue par défaut : français pour les libellés de navigation et messages ; prévoir l’anglais comme langue extensible.
- Fuseau horaire : utiliser le fuseau configuré par l’organisation et ne jamais dépendre implicitement du fuseau du navigateur pour les traitements métier.

Le nom du workspace, le numéro de l’application, les URLs, les secrets et les mots de passe doivent être fournis par la configuration de déploiement et ne doivent jamais être écrits dans le code ou dans cette spécification.

## 5. Profils et autorisations

Les autorisations doivent être contrôlées côté serveur, au niveau de la page, du composant et du traitement PL/SQL. Cacher un bouton ne constitue pas un contrôle de sécurité suffisant.

| Profil | Accès principal |
|---|---|
| Employé | Consulter son profil, ses soldes et demandes de congé, soumettre/annuler ses demandes, compléter et accuser réception de ses évaluations, consulter ses bulletins autorisés. |
| Manager | Consulter son équipe, approuver/rejeter les congés, consulter le calendrier d’équipe, renseigner les évaluations et objectifs de ses collaborateurs. |
| RH | Administrer les employés, départements, postes, grades, lieux, congés, cycles d’évaluation et rapports RH. |
| Gestionnaire paie | Gérer les salaires, périodes, éléments de paie et traitements de paie ; consulter les bulletins et registres. |
| Administrateur | Gérer les paramètres, utilisateurs/rôles, permissions, intégrations, notifications, audit et opérations techniques. |
| Auditeur | Consultation en lecture seule des historiques, journaux d’audit, rapports de conformité et exécutions de traitements. |

Les permissions doivent être exprimées au minimum par module et action : `VIEW`, `CREATE`, `UPDATE`, `DELETE`, `APPROVE`, `PROCESS`, `EXPORT`, `ADMIN`.

## 6. Navigation et expérience utilisateur

Créer un menu principal APEX avec les entrées suivantes :

1. Tableau de bord.
2. Employés et organisation.
3. Paie.
4. Congés.
5. Performance.
6. Rapports.
7. Administration.
8. Mon profil.

Exigences UX :

- interface utilisable sur écran desktop et tablette ;
- navigation cohérente, fil d’Ariane et retour explicite après chaque opération ;
- rapports interactifs avec recherche, filtres, tri, pagination, téléchargement contrôlé et colonnes configurables ;
- formulaires avec listes de valeurs dépendantes, masques, validations immédiates et messages compréhensibles ;
- confirmation obligatoire pour les opérations irréversibles ou sensibles ;
- affichage visible du statut des workflows ;
- aucune donnée sensible dans les URL, les messages de debug ou les logs applicatifs.

## 7. Modules fonctionnels

### 7.1 Tableau de bord

Le tableau de bord doit être personnalisé selon le profil connecté.

Indicateurs minimum :

- effectif actif et évolution ;
- effectif par département, lieu et statut ;
- demandes de congé en attente de l’utilisateur ;
- demandes à approuver par le manager ;
- statut de la période et de la dernière exécution de paie ;
- évaluations et objectifs à compléter ;
- notifications non lues ;
- alertes de validation, erreurs d’intégration et traitements en échec pour les profils autorisés.

### 7.2 Employés et organisation

#### Recherche et liste des employés

Fournir une page de rapport interactif avec filtres sur : matricule, nom, prénom, département, statut, lieu, type d’emploi et période d’embauche.

Actions selon permission : créer, modifier, consulter, transférer, promouvoir, terminer et réembaucher.

#### Fiche employé

La fiche doit présenter au minimum les onglets :

- identité et coordonnées ;
- emploi actuel : département, poste, manager, lieu, type et statut ;
- coordonnées d’urgence ;
- personnes à charge ;
- salaire et éléments de paie autorisés ;
- informations fiscales et bancaires, masquées selon le rôle ;
- historique d’emploi ;
- congés et soldes ;
- évaluations et objectifs ;
- historique d’audit.

Les champs sont issus notamment de `EMPLOYEES`, `EMPLOYEE_HISTORY`, `EMPLOYEE_DEPENDENTS`, `EMERGENCY_CONTACTS`, `SALARY_RECORDS` et des tables associées.

#### Organisation

Prévoir des pages d’administration pour les départements hiérarchiques, lieux, grades, postes et managers. Afficher la hiérarchie sous forme d’arbre ou de rapport hiérarchique. Empêcher les cycles dans la hiérarchie des départements et des managers.

#### Cycle de vie employé

Les opérations de transfert, promotion, termination et réembauche doivent :

- vérifier les droits de l’utilisateur ;
- valider les dates, la cohérence du poste, du grade, du salaire et du manager ;
- enregistrer une ligne dans `EMPLOYEE_HISTORY` ;
- mettre à jour les données courantes de façon transactionnelle ;
- créer l’audit et les notifications nécessaires ;
- afficher un résultat clair et rejouer proprement en cas d’erreur.

### 7.3 Paie

#### Référentiel et rémunération

Administrer les salaires, éléments de paie, éléments affectés aux employés, informations fiscales et comptes bancaires. Les numéros de sécurité sociale et de compte bancaire doivent rester chiffrés en base et masqués à l’écran, sauf permission explicite.

#### Périodes et exécutions

Fournir des pages pour :

- créer les périodes de paie ;
- afficher la période courante et son statut ;
- créer une exécution `REGULAR`, `SUPPLEMENTAL`, `BONUS` ou `FINAL` ;
- lancer le calcul ;
- suivre l’avancement et les erreurs par employé ;
- consulter les totaux brut, déductions, net, coût employeur et effectif ;
- approuver, clôturer ou inverser selon le workflow autorisé ;
- générer le registre et les bulletins.

Les transitions de statut et les contrôles doivent préserver les règles de `PKG_PAYROLL` : impossibilité de modifier une période clôturée, prévention du double paiement, validation des salaires et traçabilité de toute inversion.

Les traitements longs doivent être exécutés de manière asynchrone via `DBMS_SCHEDULER` ou un mécanisme APEX équivalent. La page doit permettre de consulter le statut, les erreurs et la date de dernière exécution sans bloquer le navigateur.

### 7.4 Congés

#### Espace employé

L’employé doit pouvoir :

- consulter ses soldes par type et année ;
- visualiser son calendrier ;
- soumettre une demande avec type, dates, demi-journée, motif et justificatif ;
- voir les conflits, jours ouvrés et solde disponible avant soumission ;
- annuler une demande selon son statut.

#### Espace manager/RH

Le manager ou RH doit pouvoir :

- lister les demandes en attente ;
- consulter le contexte employé et le calendrier d’équipe ;
- approuver ou rejeter avec commentaire ;
- ajuster les soldes avec justification ;
- administrer les types, règles d’acquisition et jours fériés ;
- lancer et suivre l’acquisition, le report et l’expiration.

Les règles de `PKG_LEAVE` doivent être conservées : détection de chevauchement, jours ouvrés et jours fériés par lieu, solde insuffisant, approbation requise, justificatif obligatoire, demi-journées et transitions `PENDING`, `APPROVED`, `REJECTED`, `CANCELLED`, `TAKEN`.

### 7.5 Performance

Fournir les pages suivantes :

- cycles d’évaluation : création, ouverture, suivi, calibration et clôture ;
- génération des évaluations pour un cycle ;
- liste des évaluations par employé, manager, département, cycle et statut ;
- auto-évaluation ;
- évaluation manager et notation de 1 à 5 ;
- objectifs avec catégorie, poids, cible, progression et statut ;
- commentaires, plan de développement et accusé de réception ;
- distribution des notes et vue de calibration pour les rôles autorisés.

Les transitions doivent respecter les statuts du schéma et empêcher qu’un employé modifie une évaluation après clôture ou qu’un manager évalue une personne hors de son périmètre.

### 7.6 Rapports

Créer des rapports interactifs et, lorsque nécessaire, des rapports imprimables/exportables pour :

- effectif ;
- synthèse de rémunération ;
- turnover ;
- nouvelles embauches ;
- utilisation des congés ;
- synthèse de paie ;
- conformité EEO.

Chaque rapport doit documenter ses filtres, sa date de référence, son niveau de fraîcheur et ses règles d’accès. Les exports doivent être journalisés et ne jamais exposer de colonnes sensibles sans autorisation.

### 7.7 Administration, audit et notifications

Prévoir des pages protégées pour :

- paramètres système et valeurs de référence ;
- utilisateurs, rôles et permissions ;
- file des notifications avec reprise des échecs ;
- état des intégrations ;
- journal d’audit avec recherche par table, identifiant, action, utilisateur et période ;
- sessions actives et historique de connexion ;
- supervision des traitements planifiés.

Les notifications email, in-app et SMS doivent utiliser `NOTIFICATION_QUEUE`, un traitement par lots, une politique de retry limitée et un état visible (`PENDING`, `SENT`, `FAILED`, `CANCELLED`). Les informations de connexion et secrets d’intégration doivent être externalisés de `SYSTEM_PARAMETERS` ou chiffrés et protégés.

## 8. Architecture APEX attendue

### Pages et composants

Utiliser les composants APEX adaptés :

- rapports interactifs pour les recherches et listes ;
- formulaires APEX ou grilles interactives pour les entités éditables ;
- régions de contenu statique, cartes et graphiques pour les tableaux de bord ;
- assistants pour les opérations multi-étapes comme la paie ou la réembauche ;
- calendrier APEX pour congés et échéances ;
- arbre hiérarchique pour l’organisation ;
- boîte de dialogue modale pour les actions ciblées et confirmations.

### Couche PL/SQL

- Conserver les packages métier stables et les appeler via des processus APEX sécurisés.
- Refactorer les variables globales Forms en contexte de session APEX, items de page contrôlés ou package context limité à la requête.
- Ne pas exposer directement de SQL dynamique alimenté par l’utilisateur.
- Remplacer `DBMS_OUTPUT` par un logging applicatif contrôlé et exploitable.
- Convertir les erreurs métier `-20000` à `-20999` en messages APEX compréhensibles sans divulguer la stack technique.
- Remplacer les appels Forms (`GO_BLOCK`, `EXECUTE_QUERY`, `VALIDATE`, triggers de navigation) par des validations, processus et branches APEX.
- Remplacer les LOV Forms par des LOV APEX avec filtres, valeurs retournées et affichées explicites.

### Vues et APIs internes

Créer des vues dédiées à l’interface lorsque cela améliore la lisibilité et la sécurité. Les requêtes de rapports doivent préférer les vues et fonctions SQL stables aux appels directs répétitifs de logique métier.

Si une API REST est nécessaire pour des intégrations externes, l’exposer via ORDS avec authentification, autorisation, validation de payload, idempotence et journalisation. Aucun endpoint ne doit permettre l’accès générique à toutes les tables HRMS.

## 9. Modèle de données et migration

### Conservation

Conserver les identifiants, contraintes, relations, statuts et dates historiques des tables existantes. Les séquences et triggers d’identifiants peuvent être remplacés par des identités ou séquences APEX uniquement après démonstration qu’aucune référence historique n’est rompue.

### Contrôles de migration

Avant migration :

- sauvegarder le schéma source et produire un inventaire des objets ;
- vérifier les doublons, clés orphelines, statuts invalides et dates incohérentes ;
- chiffrer ou exclure les données sensibles des environnements non productifs ;
- documenter les écarts entre les exports Forms et le schéma SQL réellement présent.

Après migration :

- comparer les volumes par table ;
- recalculer les agrégats de soldes et totaux de paie ;
- vérifier les contraintes, vues, packages, jobs et droits ;
- produire un rapport d’anomalies et une procédure de correction réexécutable.

La migration doit être idempotente autant que possible et fournir une stratégie de retour arrière basée sur sauvegarde, restauration ou tables de staging. Les données de démonstration ne doivent pas être confondues avec les données de production.

## 10. Sécurité et conformité

- Utiliser l’authentification d’entreprise disponible ; à défaut, utiliser un schéma APEX sécurisé avec politique de mot de passe, verrouillage après échecs, expiration et journalisation.
- Ne pas reconduire le hash MD5 ni les clés de chiffrement en dur identifiés dans l’ancien package de sécurité.
- Utiliser `APEX_AUTHORIZATION`, des schémas d’authentification configurés et des contrôles serveur.
- Appliquer le principe du moindre privilège aux schémas APEX, ORDS, jobs et comptes techniques.
- Masquer SSN, comptes bancaires, données fiscales et informations personnelles dans les rapports et exports.
- Protéger les pièces jointes et les BLOBs par contrôle d’accès au niveau de l’enregistrement.
- Journaliser les opérations sensibles : consultation de données protégées, export, modification, approbation, paie, changement de permissions et intégration.
- Activer la protection de session APEX, le checksum des pages/URL et les protections CSRF natives.
- Ne jamais committer secrets, mots de passe, certificats ou fichiers de configuration d’environnement.

## 11. Traitements planifiés et intégrations

Reproduire ou moderniser les traitements suivants :

- acquisition mensuelle des congés ;
- report et expiration des soldes ;
- traitement de la file de notifications ;
- rafraîchissement des données de reporting ;
- génération des journaux GL ;
- export du flux avantages ;
- import temps et présence ;
- synchronisation de la structure organisationnelle.

Chaque traitement doit avoir un identifiant d’exécution, une date de début/fin, un statut, un nombre de lignes traitées, un message d’erreur et une possibilité de reprise contrôlée. Les fichiers temporaires doivent être stockés dans un emplacement sécurisé avec durée de rétention définie.

## 12. Exigences non fonctionnelles

### Performance

- Supporter au moins 200 utilisateurs concurrents, correspondant au contexte existant.
- Les pages de recherche usuelles doivent répondre en moins de 3 secondes sur un jeu de données nominal, hors export ou traitement batch.
- Les traitements volumineux doivent être asynchrones et paginés.
- Ajouter les index nécessaires après mesure et vérifier les plans d’exécution.

### Disponibilité et exploitation

- Prévoir sauvegarde, restauration testée, supervision ORDS/APEX et suivi des jobs.
- Centraliser les erreurs applicatives sans exposer de détails techniques à l’utilisateur.
- Fournir une page de santé réservée aux administrateurs.

### Accessibilité

- Respecter les composants Universal Theme et les pratiques WCAG applicables.
- Garantir la navigation clavier, les libellés des contrôles, le contraste et les messages d’erreur accessibles.

### Maintenabilité

- Versionner l’export APEX, les scripts SQL, les packages, les jobs et les données de référence.
- Séparer les scripts d’installation, migration, configuration et rollback.
- Documenter les dépendances, variables d’environnement et prérequis.

## 13. Stratégie de livraison

### Phase 1 — Inventaire et socle

Produire l’inventaire des objets, valider le schéma, installer l’application APEX vide, configurer l’authentification, le thème, la navigation, les rôles et le logging.

### Phase 2 — Référentiel et employés

Implémenter le tableau de bord, la recherche employé, la fiche employé, l’organisation et le cycle de vie employé.

### Phase 3 — Congés et performance

Implémenter les soldes, demandes, approbations, calendriers, cycles d’évaluation, objectifs et notifications.

### Phase 4 — Paie

Implémenter référentiels, périodes, exécutions, calculs asynchrones, approbation, inversion, bulletins et registre.

### Phase 5 — Rapports, intégrations et administration

Implémenter rapports, exports, audit, paramètres, jobs, notifications et intégrations externes.

### Phase 6 — Migration et bascule

Réaliser une migration répétable, une recette parallèle Forms/APEX, la correction des écarts, la formation, la bascule et une période d’hypercare.

## 14. Tests et critères d’acceptation

### Tests requis

- tests unitaires PL/SQL pour validations, calculs, transitions et fonctions sensibles ;
- tests d’intégration pour packages, jobs, notifications et imports/exports ;
- tests APEX de permissions par profil ;
- tests de non-régression sur scénarios Forms existants ;
- tests de migration et rapprochement des données ;
- tests de performance sur recherches et traitements batch ;
- tests de sécurité : accès horizontal, accès vertical, injection, session, export et pièces jointes ;
- tests d’accessibilité et responsive.

### Critères d’acceptation globaux

1. Un utilisateur autorisé peut se connecter et ne voit que les modules correspondant à son profil.
2. Un employé peut consulter/modifier les données qui lui sont autorisées et soumettre une demande de congé complète.
3. Un manager peut approuver ou rejeter uniquement les demandes et évaluations de son périmètre.
4. RH peut gérer un employé de l’embauche à la termination ou réembauche, avec historique et audit.
5. La paie empêche les transitions invalides, calcule les totaux attendus et expose les erreurs par employé.
6. Les soldes de congés, chevauchements, jours ouvrés et approbations sont cohérents avec les règles métier existantes.
7. Les évaluations respectent les cycles, les rôles, les notations et les dates limites.
8. Les rapports retournent les mêmes résultats de référence que les requêtes source pour un même périmètre.
9. Toute opération sensible est auditée et toute donnée confidentielle est masquée ou refusée sans permission.
10. L’installation de l’application est reproductible depuis des scripts versionnés et ne dépend d’aucun secret commité.

## 15. Livrables attendus de Speckit

Speckit doit produire ou faire produire :

- une matrice de traçabilité Forms/PLSQL → pages, régions, processus, validations et autorisations APEX ;
- le modèle cible et les scripts SQL d’installation/migration/rollback ;
- l’application APEX exportable ;
- les packages PL/SQL refactorés et leurs tests ;
- les jobs `DBMS_SCHEDULER` et mécanismes de supervision ;
- les rapports et modèles d’export ;
- le catalogue des rôles, permissions et données sensibles ;
- les scénarios de recette et jeux de données anonymisés ;
- la procédure de déploiement, de bascule et de retour arrière ;
- la documentation utilisateur et administrateur.

## 16. Décisions à confirmer avant implémentation

1. Le fournisseur d’authentification cible : comptes APEX, LDAP, SSO/OIDC ou autre.
2. Le niveau de compatibilité requis avec les calculs de paie existants.
3. Les règles de conservation et de masquage des données personnelles et bancaires.
4. Les contrats des intégrations GL, avantages et temps/présence.
5. Le mécanisme d’envoi email/SMS en environnement cible.
6. La stratégie de coexistence et la date de bascule Forms/APEX.
7. Les exigences de disponibilité, sauvegarde, reprise après sinistre et rétention d’audit.

