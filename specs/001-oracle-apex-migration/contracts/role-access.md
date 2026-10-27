# Contract — Role and Data Access

## Roles

| Role | Read scope | Write/execute scope |
|---|---|---|
| EMPLOYEE | Soi-même et ses données autorisées | Profil autorisé, demandes, auto-évaluation, accusé de réception. |
| MANAGER | Équipe directe et périmètre délégué | Approbations de congé, évaluations et objectifs de l’équipe. |
| HR | Organisation et employés selon le périmètre RH | Cycle de vie employé, référentiels, congés, performance et rapports RH. |
| PAYROLL | Données nécessaires à la paie | Salaires, périodes, exécutions, approbations et registres. |
| ADMIN | Administration technique sans accès automatique aux secrets métier | Paramètres, rôles, jobs, intégrations et supervision autorisés. |
| AUDITOR | Lecture des données et audits autorisés | Aucun changement métier ; export uniquement si explicitement autorisé. |

## Enforcement

- Les contrôles sont appliqués dans les requêtes sécurisées, packages métier et processus APEX.
- Un contrôle d’interface masqué n’est jamais la seule protection.
- Le périmètre manager est calculé à partir de la hiérarchie courante et des délégations valides.
- Les colonnes SSN, bancaires, fiscales et pièces jointes ont une autorisation distincte de la fiche générale.
- Toute décision `ALLOW` ou `DENY` sur une action sensible doit être testable avec un utilisateur représentatif de chaque rôle.
