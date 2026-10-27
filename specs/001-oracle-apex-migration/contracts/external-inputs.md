# Contract — External Integration Inputs

Ce document est le gate d’entrée des intégrations externes. Les endpoints ORDS ne doivent pas être implémentés avec des formats supposés.

## Required inputs before endpoint implementation

Pour chaque fournisseur GL, avantages et temps/présence, fournir et versionner :

- schéma de payload ou format de fichier ;
- dictionnaire de champs, types, longueurs, encodages et valeurs obligatoires ;
- règles de rejet et de correction ;
- méthode d’authentification et certificats hors dépôt ;
- limites de taille, fréquence, timeout et retry ;
- exemples anonymisés valides et invalides ;
- stratégie d’idempotence et identifiant métier ;
- procédure de rapprochement et de preuve de livraison.

## Gate

T077 est bloquée tant que ces éléments ne sont pas validés par le propriétaire de chaque système externe. En attendant, seuls des contrats simulés et des tests de schéma anonymisés peuvent être développés.
