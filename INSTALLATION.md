# Installation de l’environnement Oracle APEX

Ce document décrit les prérequis généraux pour exécuter HRMS avec Oracle APEX. Les mots de passe, tokens, certificats et chaînes de connexion ne doivent jamais être stockés dans GitHub.

## Composants

- Oracle Database avec un PDB dédié à l’application ;
- Oracle APEX compatible avec la version cible ;
- Oracle ORDS compatible avec APEX ;
- Java adapté à la version d’ORDS ;
- Docker, si la base Oracle est exécutée en conteneur ;
- un fournisseur SSO OIDC ou SAML pour l’authentification HRMS.

## Configuration locale

Fournir les paramètres suivants via un gestionnaire de secrets ou un fichier local non versionné :

```text
HRMS_DB_CONNECT
HRMS_SCHEMA
APEX_WORKSPACE
APEX_APP_ID
HRMS_CONNECT_STRING
SSO_ISSUER_OR_METADATA
```

Les fichiers de configuration ORDS et les journaux locaux doivent rester hors du dépôt.

## Déploiement du schéma

1. Créer ou sélectionner le schéma Oracle `HRMS`.
2. Exécuter les scripts du répertoire [`ts-plsql-oracle-forms-hrms/schema/`](./ts-plsql-oracle-forms-hrms/schema/).
3. Compiler les packages et triggers du répertoire [`ts-plsql-oracle-forms-hrms/plsql/`](./ts-plsql-oracle-forms-hrms/plsql/).
4. Charger les données de référence depuis [`ts-plsql-oracle-forms-hrms/data/seed/`](./ts-plsql-oracle-forms-hrms/data/seed/).
5. Exécuter les contrôles de migration et de rapprochement décrits dans [`specs/001-oracle-apex-migration/quickstart.md`](./specs/001-oracle-apex-migration/quickstart.md).

## Déploiement APEX/ORDS

1. Installer ou configurer APEX et ORDS dans l’environnement cible.
2. Importer l’export APEX versionné de l’application.
3. Configurer le SSO, les rôles, les LOV et les paramètres d’environnement.
4. Vérifier que les secrets proviennent de la configuration de l’environnement.
5. Exécuter les tests de sécurité, de performance, d’accessibilité et de rapprochement Forms/APEX.

## Sécurité

Ne jamais publier les informations d’administration de la base, d’APEX, d’ORDS ou du registre Oracle. En cas de fuite, révoquer et renouveler immédiatement les identifiants concernés.
