# Migrations SQL — PlanB Tools

Migrations qui modifient la base Supabase.

## Workflow d'application

Cowork tourne en **read-only** sur Supabase, donc les UPDATE/INSERT manuels
doivent être appliqués par toi via **Supabase Studio → SQL Editor**.

### Étapes pour chaque migration

1. Ouvre le fichier `.sql` dans ton éditeur (ou avec `cat`).
2. Va sur https://supabase.com/dashboard/project/dzrherfavgiuygnimtux/sql/new
3. Copie le contenu du fichier, colle-le dans l'éditeur SQL.
4. Clique **Run**. Vérifie le résultat (nombre de lignes affectées).
5. Lance la requête de validation post-exécution (voir en fin de chaque fichier
   ou dans une note séparée) pour t'assurer que l'état attendu est atteint.

## Migrations existantes

| Date | Fichier | Effet |
|---|---|---|
| 2026-05-09 | `2026-05-09_link_predefined_tasks_to_fiches_squelettes.sql` | Crée 61 fiches squelettes (nom + categorie + etablissement freddy) et lie les 62 predefined_tasks au catalogue (61 nouvelles + 1 existante "Rieweleküche"). Idempotent : skip les tâches déjà liées. |
