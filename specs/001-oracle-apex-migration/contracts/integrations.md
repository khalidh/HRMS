# Contract — External Integrations

Les intégrations sont des contrats métier versionnés. Aucun consommateur externe ne reçoit un accès SQL générique.

## GL journal export

- **Direction** : HRMS → GL.
- **Entrée** : `run_id` d’une paie approuvée.
- **Sortie** : lignes équilibrées avec date, compte, débit, crédit, description et référence.
- **Idempotence** : une même paire `(run_id, integration_version)` ne peut être exportée avec succès deux fois.
- **Échec** : statut `FAILED`, message non sensible, reprise par `execution_id`.

## Benefits feed

- **Direction** : HRMS → fournisseur avantages.
- **Entrée** : date d’effet et périmètre validé.
- **Sortie** : employés, événements d’éligibilité et éléments nécessaires au format contractuel du fournisseur.
- **Contrôles** : schéma, encodage, volume, doublons, rapport de rejet et preuve d’envoi.

## Time and attendance import

- **Direction** : source temps/présence → HRMS.
- **Entrée** : fichier ou payload versionné avec identifiant d’import.
- **Contrôles** : employé connu, période ouverte, format, doublons, dates et totaux.
- **Résultat** : lignes acceptées/rejetées, statut de lot et rapport téléchargeable aux rôles autorisés.

## Organization synchronization

- **Direction** : source organisationnelle ↔ HRMS.
- **Contrôles** : codes uniques, parent existant, absence de cycle, statut actif et journal des changements.
- **Politique de conflit** : aucune suppression automatique ; les conflits sont placés en erreur pour revue RH.

## Common HTTP/processing rules

- Utiliser HTTPS et une authentification de service dédiée.
- Valider taille, type, encodage et version du payload.
- Retourner un identifiant de corrélation et un statut métier, sans stack trace ni secret.
- Supporter une reprise sûre via clé d’idempotence.
- Auditer appel, résultat, volume, erreur et utilisateur/service appelant.
