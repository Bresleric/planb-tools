# Stock PF/PI — Spec écran (onglet Module Production)

**Cible** : Claude Code, repo `~/planb-tools/` — implémentation de l'onglet "Stock PF/PI" dans le Module Production.

**Date** : 2026-05-11
**Auteur** : Cowork (PlanB Tools)

---

## 1. Vue d'ensemble

Le Module Production a actuellement les onglets : **Lots**, **Productions**, **Par personne** (récap collaborateur). On ajoute un 4e onglet : **Stock PF/PI**.

L'écran permet aux responsables et collaborateurs de :
- consulter l'état du stock courant des produits finis et intermédiaires, par établissement
- ajouter / éditer / supprimer une ligne de stock (relevé manuel)
- filtrer par pièce, meuble, niveau, catégorie produit
- voir les DLC qui approchent

À terme, ce stock sera auto-alimenté par les productions validées et décrémenté par les ventes — pour l'instant, **saisie manuelle uniquement**.

---

## 2. Modèle de données

Tables (voir `schema.sql`, `seed_unites_contenants.sql`) :

```
unites           — référentiel unités (kg, L, piece, pourcent, etc.)
contenants       — nomenclature GN + bacs + sachets + seaux + boîtes + plaques
temp_frigos      — meubles existants, étendu avec nb_niveaux (1-4)
fiches_techniques — produits existants (catégorie ∈ produit_fini / produit_intermediaire / mise_en_place)
stock_pf_pi      — lignes de stock (la table à exploiter)
```

### Colonnes `stock_pf_pi`

| Colonne | Type | Notes |
|---|---|---|
| id | uuid | PK |
| fiche_id | uuid? | FK fiches_techniques (nullable si produit hors fiche) |
| produit_nom | text | snapshot (toujours rempli) |
| produit_categorie | text? | snapshot |
| meuble_id | uuid? | FK temp_frigos |
| meuble_nom | text | snapshot |
| piece | text | CUISINE / LABO / CAVE / SALLE / BAR |
| emplacement | text? | libre (Porte, Étagère, Tiroir…) |
| niveau | int? | 1=bas, 4=haut, max selon temp_frigos.nb_niveaux |
| contenant_id | uuid? | FK contenants |
| contenant_libelle | text? | snapshot |
| unite | text? | FK unites.code |
| quantite | numeric | |
| observations | text? | |
| etablissement | text | freddy / liesel |
| production_id | uuid? | FK productions (optionnel, si stock issu d'une production) |
| dlc | date? | |
| date_releve | timestamptz | |
| releve_par_* | uuid+text+text | utilisateur PIN |

---

## 3. Routes / fichiers à créer

Suivre le pattern existant du module Production :

```
~/planb-tools/production/
  ├── index.html          (déjà existant — ajouter le 4e onglet)
  ├── stock-pf-pi.html    (NOUVEAU — page de l'onglet)
  └── stock-pf-pi.js      (NOUVEAU — logique JS)
```

Le fichier `production/index.html` charge déjà les sous-pages via les onglets. Suivre la même mécanique que pour l'onglet "Par personne".

---

## 4. UI / Interactions

### 4.1 En-tête

- Sélecteur établissement (freddy/liesel) — déjà global dans l'app, à respecter
- Bouton **+ Nouvelle ligne**
- Recherche libre (filtre sur `produit_nom`)
- Filtres : Pièce, Meuble, Catégorie produit (PF / PI / Mise en place)
- Indicateur "X lignes, total Y produits distincts"

### 4.2 Tableau principal

Colonnes :

| Pièce | Meuble | Empl. | Niveau | Produit | Catégorie | Qté | Unité | Contenant | DLC | Obs. | Actions |
|---|---|---|---|---|---|---|---|---|---|---|---|
| CUISINE | CUISINE GAUCHE | Porte | Haut (4) | Cervelas | mise_en_place | 24 | pcs | — | — | … | ✏️ 🗑️ |

- Tri par défaut : `piece, meuble_nom, niveau DESC, produit_nom`
- DLC < 48h affichée en rouge ; DLC < 24h en gras
- Clic sur ligne → ouvre modale d'édition

### 4.3 Modale Ajout / Édition

Formulaire avec :

1. **Produit** : combobox sur `fiches_techniques` filtrée par établissement + catégorie ∈ (produit_fini, produit_intermediaire, mise_en_place). Affichage `nom — catégorie`. Si non trouvé → champ libre.
2. **Pièce** : select sur les valeurs distinctes de `temp_frigos.categorie` pour l'établissement
3. **Meuble** : select sur `temp_frigos` filtré par établissement + pièce sélectionnée
4. **Niveau** : select 1..N où N = `temp_frigos.nb_niveaux` du meuble sélectionné. Libellé : `1 = Bas`, `nb_niveaux = Haut`, intermédiaires numérotés
5. **Emplacement** : champ libre avec autocomplete sur valeurs déjà saisies (Porte, Étagère, Tiroir)
6. **Contenant** : combobox sur `contenants WHERE actif=true`, groupé par `famille` (GN / Bac / Sachet / Seau / Boîte / Plaque / Autre)
7. **Quantité** : numeric
8. **Unité** : select sur `unites WHERE actif=true`, groupé par `type` (masse / volume / unitaire / pourcentage / autre)
9. **DLC** : date picker (optionnel)
10. **Observations** : textarea
11. **Boutons** : Enregistrer / Annuler / Supprimer (édition uniquement)

À l'enregistrement :
- toujours mettre à jour les snapshots (`produit_nom`, `meuble_nom`, `contenant_libelle`)
- `releve_par_*` rempli depuis la session PIN courante
- `date_releve` = `now()` à la création, conservée à l'édition

### 4.4 Vue groupée (optionnelle, v2)

Bouton "Vue par produit" qui regroupe les lignes par `produit_nom` et somme les `quantite` (par unité). Utile pour répondre vite à "combien de tartes oignons au total".

---

## 5. Requêtes Supabase

```js
// Lecture
const { data } = await supabase
  .from('stock_pf_pi')
  .select('*, fiche:fiches_techniques(nom, categorie), meuble:temp_frigos(nom, categorie, nb_niveaux), contenant:contenants(libelle, famille)')
  .eq('etablissement', etablissement)
  .order('piece').order('meuble_nom').order('niveau', { ascending: false }).order('produit_nom')

// Référentiels
const { data: meubles } = await supabase.from('temp_frigos').select('id, nom, categorie, nb_niveaux').eq('etablissement', etablissement).eq('actif', true).order('ordre')
const { data: contenants } = await supabase.from('contenants').select('*').eq('actif', true).order('famille').order('ordre')
const { data: unites } = await supabase.from('unites').select('*').eq('actif', true).order('type').order('ordre')
const { data: produits } = await supabase.from('fiches_techniques').select('id, nom, categorie').eq('etablissement', etablissement).eq('actif', true).in('categorie', ['produit_fini', 'produit_intermediaire', 'mise_en_place']).order('nom')
```

---

## 6. Permissions

- Lecture : tous les rôles
- Création/Édition : `collaborateur` et plus (PIN 4 chiffres)
- Suppression : `responsable` et plus (PIN 5 chiffres)

---

## 7. Migration / déploiement

Pas de script `DEPLOY-STOCK-PF-PI.sh` automatique au départ — Eric exécute les SQL via Supabase Studio dans cet ordre :

1. `schema.sql`
2. `seed_unites_contenants.sql`
3. `init_meubles.sql`
4. `import_excel_initial.sql` *(optionnel, données de démarrage)*

Puis Claude Code implémente le front et un script `DEPLOY-STOCK-PF-PI.sh` sera ajouté à `planb-tools-update/`.

---

## 8. Évolutions prévues (hors scope v1)

- Auto-alimentation depuis `productions` validées (création ligne stock_pf_pi avec `production_id`)
- Décrément automatique depuis ventes (lien fiches_techniques ↔ produits L'Addition)
- Vue chronologique : historique des relevés d'un produit donné
- Alertes DLC dans le module Information / dashboard
- Photo du contenant via Module Scanner
