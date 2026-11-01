# Quickstart — Validation de la migration HRMS APEX

Ce guide valide le socle et les parcours principaux sans contenir les scripts d’implémentation complets.

## Prérequis

- Oracle Database cible et PDB accessibles.
- APEX 26.2 et ORDS 26.3 installés.
- Workspace/application APEX configurables.
- Schéma HRMS et droits de déploiement disponibles.
- Accès au fournisseur SSO de test.
- Jeu de données anonymisé et export de référence Forms.
- Variables d’environnement fournies hors dépôt : `HRMS_DB_CONNECT`, `HRMS_SCHEMA`, `APEX_WORKSPACE`, `APEX_APP_ID`.

## 1. Vérifier le dépôt et les artefacts

```bash
test -f specs/001-oracle-apex-migration/spec.md
test -f specs/001-oracle-apex-migration/plan.md
test -f specs/001-oracle-apex-migration/data-model.md
test -d specs/001-oracle-apex-migration/contracts
```

Résultat attendu : tous les artefacts de conception sont présents et aucun secret n’est requis dans le dépôt.

## 2. Installer le schéma et les données de test

Utiliser la procédure de déploiement versionnée avec un compte de service limité. Dans l’environnement local fourni par le projet, la connexion peut être exécutée depuis le conteneur Oracle ; ne pas recopier de mot de passe dans une commande ou un fichier versionné.

```bash
sql -S "$HRMS_DB_CONNECT" \
  @ts-plsql-oracle-forms-hrms/data/migration/00_install_test.sql \
  INSTALL_EMPTY_HRMS_TEST_SCHEMA
```

`HRMS_DB_CONNECT` doit être fourni par le gestionnaire de secrets ou la session locale et ne doit pas être écrit dans le dépôt. Utiliser une base de test isolée avec un schéma HRMS vide : le script refuse un schéma déjà peuplé et ne charge pas les anciens scripts de seed. Résultats attendus : contraintes valides, packages compilés, vues accessibles et jobs désactivés par défaut en test. Les fixtures anonymisées ne seront chargées qu'après vérification de leur provenance et de leur compatibilité avec le schéma.

## 3. Déployer l’application APEX

Importer l’export APEX installable, puis appliquer les descripteurs page par page selon `apex/application/README.md`. Utiliser l’authentification locale APEX temporaire en développement et OIDC en préproduction/production, selon `apex/shared-components/authentication.md`. Configurer les rôles, les LOV et les paramètres. Vérifier que les URLs et secrets proviennent de la configuration du workspace, pas du code.

## 4. Parcours de recette prioritaires

1. Se connecter avec les comptes locaux synthétiques en développement, puis via OIDC en préproduction/production, avec un utilisateur employé, manager, RH, paie, administrateur et auditeur.
2. Vérifier que chaque rôle ne voit que son menu et son périmètre.
3. Rechercher un employé, effectuer un transfert de test et contrôler l’historique/audit.
4. Soumettre un congé valide, tenter un chevauchement, puis approuver/rejeter avec un manager.
5. Créer une paie de test, lancer le traitement, consulter une erreur, vérifier les totaux et approuver.
6. Ouvrir un cycle de performance, générer une évaluation, renseigner un objectif et clôturer le cycle.
7. Exécuter les rapports et vérifier les filtres, l’export et le masquage des colonnes sensibles.
8. Simuler un job échoué, le reprendre avec la même clé d’idempotence et vérifier l’absence de doublon.

## 5. Rapprochement Forms/APEX

Pour un même jeu de données et une même date de référence, comparer les effectifs, soldes et demandes de congé, totaux de paie, rapports, audits et notifications. Le rapprochement est accepté uniquement si les écarts sont nuls ou documentés et approuvés.

## 6. Contrôles non fonctionnels

- Mesurer 95 % des recherches sous 3 secondes avec 200 utilisateurs concurrents simulés.
- Exécuter un test de restauration visant RTO ≤ 4 heures et RPO ≤ 1 heure.
- Exécuter l’analyse d’accessibilité APEX et une navigation clavier sur les pages prioritaires.
- Vérifier qu’aucun accès direct à une donnée hors périmètre n’est possible en modifiant URL, paramètres ou items.
- Vérifier que les logs et exports ne contiennent pas de secret, SSN ou compte bancaire en clair.

## 7. Sortie attendue

Publier un rapport de recette contenant version de l’application, jeux de données, résultats par scénario, écarts, anomalies, décision de bascule et preuve de restauration.
