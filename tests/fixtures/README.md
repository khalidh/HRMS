# Jeu de données de test anonymisé

## Principes

- Aucune donnée personnelle réelle : noms, emails, salaires, identifiants nationaux et coordonnées bancaires sont fictifs.
- Les identifiants de référence (`EMPLOYEE_ID`, `DEPARTMENT_ID`, etc.) sont conservés pour permettre le rapprochement Forms/APEX.
- Le jeu de données anonymisé et les clés de référence doivent être validés avant leur chargement. Les scripts actuellement présents dans `ts-plsql-oracle-forms-hrms/data/seed/` ne sont pas inclus par l'installation de test et doivent être vérifiés pour leur compatibilité avec le schéma et leur anonymisation.

## Identifiants de référence

À compléter avec le jeu anonymisé fourni (voir `specs/001-oracle-apex-migration/contracts/external-inputs.md`) :

| Cas de test | Identifiant | Usage |
|---|---|---|
| Employé standard | à définir | US1, US2 |
| Manager avec équipe | à définir | US2, périmètre manager |
| Utilisateur RH | à définir | US1, US3 |
| Auditeur | à définir | sécurité, audit |
| Employé hors périmètre | à définir | tests de refus |

## Export de référence Forms

Résultats Forms validés (effectifs, soldes de congés, paie) à déposer ici sous forme anonymisée pour les tests `*_forms_reconciliation.sql`.
