# Stock PF/PI

Stock des **Produits Finis** et **Produits Intermédiaires** dans les meubles réfrigérés des restaurants.

## Branchements avec l'existant

| Concept Excel | Source dans la base |
|---|---|
| **Pièce** | `temp_frigos.categorie` (CUISINE / LABO / CAVE) — pas de nouvelle table |
| **Meuble** | `temp_frigos` étendu avec `nb_niveaux` (1–4) |
| **Niveau** | `stock_pf_pi.niveau` int 1–4 — convention **1 = bas, 4 = haut** |
| **Produit** | `fiches_techniques` (filtré sur `categorie ∈ produit_fini, produit_intermediaire, mise_en_place`) |
| **Contenant** | Nouvelle table `contenants` — nomenclature GN complète + bacs/sachets/seaux/boîtes/plaques |
| **Unité** | Nouvelle table `unites` — kg, g, L, mL, pièce, portion, %, plaque, sachet, etc. |

## Fichiers

| Fichier | Rôle | Ordre d'exécution |
|---|---|---|
| `schema.sql` | Tables `unites`, `contenants`, `stock_pf_pi` + `ALTER temp_frigos` + RLS + trigger | 1 |
| `seed_unites_contenants.sql` | Seed des 13 unités + 58 contenants (44 GN + 14 autres) | 2 |
| `init_meubles.sql` | UPDATE `nb_niveaux` pour les 17 meubles existants | 3 |
| `import_excel_initial.sql` | Import des 7 lignes saisies par Eric le 11/05/2026 | 4 (optionnel) |
| `frontend-spec.md` | Spec écran pour Claude Code | — |

## Exécution

Via **Supabase Studio → SQL Editor** dans cet ordre. Tous les scripts sont idempotents (`IF NOT EXISTS` / `ON CONFLICT DO NOTHING`).

Vérification finale :

```sql
SELECT COUNT(*) FROM public.unites;       -- 13
SELECT COUNT(*) FROM public.contenants;   -- 58
SELECT COUNT(*) FROM public.stock_pf_pi;  -- 7 après import_excel_initial
SELECT etablissement, nom, nb_niveaux FROM public.temp_frigos WHERE actif=true ORDER BY etablissement, ordre;
```

## Frontend

L'onglet "Stock PF/PI" est à intégrer dans le **Module Production** (à côté de Lots / Productions / Par personne). Voir `frontend-spec.md` pour le détail.
