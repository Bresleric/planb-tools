# Architecture des données — Ingrédients / Matières premières / Produits

> Note de référence. Cartographie les tables qui définissent et référencent les
> articles, pour éviter les confusions et les doublons. Établi le 12/06/2026 après
> investigation complète de la base.
>
> ⚠️ **Le piège à connaître** : il existe **deux** tables qui ressemblent à un
> catalogue (`appro_ingredients` ET `appro_catalogue`). Ce ne sont PAS des
> doublons : ce sont **deux niveaux** d'une même chaîne. Confondre les deux mène à
> de fausses conclusions (ex. croire le catalogue de prix « déconnecté »).

## 1. La chaîne à deux niveaux (le cœur)

```
  ACHAT / RÉCEPTION                              PRODUCTION / STOCK / SCAN
  ─────────────────                              ─────────────────────────

  appro_prix ───────────┐
  (codes + prix par      │ article_id
   fournisseur, 771)     ▼
  appro_commande_lignes  appro_catalogue ───────────► appro_ingredients
  (lignes de commande) ──┘ (771 "articles tels       (455 ingrédients /
                            que livrés/facturés        matières premières
       article_id          par un fournisseur")        CANONIQUES)
                              │  ingredient_id              ▲
                              └─────────────────────────────┤
                                                            │ article_id
                          fiche_ingredients ────────────────┤ (production)
                          stock_mouvements ─────────────────┤ (stock)
                          scan_tracabilite ─────────────────┘ (scanner)
```

- **`appro_catalogue`** = « le produit **tel que ce fournisseur** le vend » (sa
  désignation, son unité, son établissement). Plusieurs lignes catalogue (un par
  fournisseur) pointent vers **un seul** ingrédient.
- **`appro_ingredients`** = « **mon** ingrédient / matière première », indépendant
  du fournisseur. C'est lui qu'utilisent la production, le stock et le scan.
- `appro_prix` et `appro_commande_lignes` pointent vers `appro_catalogue`
  (`article_id`), **pas** directement vers `appro_ingredients`.

> Pour relier un **code fournisseur** (ex. Knack Koch `2821`) à **mon ingrédient**
> (« Knack »), le chemin est : `appro_prix → appro_catalogue → appro_ingredients`.

## 2. Les référentiels (tables qui DÉFINISSENT un produit)

| Table | Définit | Modules |
|---|---|---|
| **`appro_ingredients`** (455) | l'ingrédient / MP canonique | achats · approvisionnement · **production** · **stock** |
| **`appro_catalogue`** (771) | l'article vu par un fournisseur → 1 ingrédient | approvisionnement · stock |
| `fiches_techniques` | produits finis / recettes (PF-PI) | production · stock · taf |
| `produits_vendus` · `ventes_produits` | produits de la carte / caisse | produits · ventes |
| `produits_signatures` | référentiel scan (produit ↔ code attendu) | receptions |
| `elis_articles` | articles blanchisserie ELIS (à part) | receptions |
| `stock_pf_pi` | stock produits finis / intermédiaires | production |

## 3. Les consommateurs (tables qui RÉFÉRENCENT un article)

Pointent vers `appro_ingredients` (`article_id`) ou `appro_catalogue` :

`appro_prix`, `appro_commande_lignes`, `appro_besoins`, `appro_inventaire_lignes`,
`appro_reception_articles`, `factures_achats_lignes`, `fiche_ingredients`,
`prelevements`, `stock_mouvements`, `stock_controle_lignes`, `scan_tracabilite`,
`etiquettes_prelevement`, `rapprochement_apprentissage`.

## 4. Risques de doublons — et règles PBT

| Risque | État 12/06/2026 | Règle |
|---|---|---|
| Doublons exacts dans `appro_ingredients` | 3 (*Farine*, *Fromage blanc*, *PDT Épluchées*) | fusionner ; voir §5 |
| Pas d'unicité sur le nom | aucune contrainte | ajouter `UNIQUE` sur nom normalisé |
| Quasi-doublons | *Echalotes/Echalottes*, *Pdt/Pommes de terre*, *Salade/…* | vérifier avant de créer |
| Colonnes `_nom` figées (snapshots) | `article_nom`, `ingredient_nom` dans 5 tables | ne jamais s'y fier comme source ; `appro_ingredients.nom` fait foi |
| Lignes `appro_catalogue` sans ingrédient | 8 → traités (5 raccrochés, 3 en attente) | `ingredient_id` doit toujours être rempli |

**Règle d'or** : avant de **créer** un ingrédient, chercher s'il existe déjà
(nom normalisé : minuscules, sans accent). Avant de conclure qu'un tarif est
« orphelin », **suivre la chaîne via `appro_catalogue`**, pas seulement
`appro_ingredients`.

## 5. Plan d'assainissement (en cours)

1. ✅ Raccrocher les lignes `appro_catalogue` sans ingrédient (5/8 faits, dont Knack).
2. ⬜ Trancher les 3 derniers orphelins (épaule d'agneau roulé, tablette
   lave-vaisselle, frais d'éco-participation).
3. ⬜ Fusionner les 3 doublons (re-pointer les références vers l'exemplaire gardé,
   puis désactiver le perdant) — migration soignée, touche `stock_mouvements`.
4. ⬜ Ajouter la contrainte d'unicité sur le nom (après fusion).
