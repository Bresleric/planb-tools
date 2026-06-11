# Réorganisation Stock / Réception — feuille de route

> Document de pilotage. Décrit la **cible** (ce vers quoi on va), le **pourquoi**,
> l'**ordre d'exécution** (de la modif la moins risquée à la plus structurante) et
> les **risques**. Rien dans ce fichier n'est encore codé — c'est le plan de
> référence à suivre étape par étape.
>
> État du code de départ : 11/06/2026, vérifié fichier par fichier.
> Pour le parcours réel d'une étiquette aujourd'hui : voir `WORKFLOW-ETIQUETTES-MP.md`.
> Pour l'historique des modules qui se chevauchent : voir `CHANTIERS-ARCHIVES.md`.

---

## 1. Le problème qu'on règle

Au fil des chantiers, le couple **Réception / Stock / Scanner** a accumulé des
doublons et des frictions au quotidien pour l'équipe :

1. **Trois portes d'entrée du scanner** dont une redondante. Le **scan unitaire**
   (1 étiquette isolée) fait exactement ce que la **réception groupée** sait déjà
   faire — vérifié : la réception groupée a un bouton **« Valider sans BL (registre
   HACCP) »** actif dès **1 seule étiquette** extraite. Le scan unitaire ne sert
   donc plus qu'à scanner un **BL / une facture isolés**, ce qui n'a rien à voir
   avec une étiquette matière.

2. **Des scans inutiles imposés à l'équipe.** Le scan FEFO obligatoire en
   production est piloté par `fiche_ingredients.est_principal` seul. Rien ne
   distingue une viande (lot + DLC + traçabilité bovine = vraiment à tracer) d'un
   sac de farine (stable, pas de lot utile). On peut donc réclamer le scan d'un
   lot de farine — friction pure.

3. **Des libellés et des onglets qui se recouvrent** entre Stock et Réceptions
   (rattachement, corrections d'étiquettes, contrôle de stock, sorties), sans
   verbe clair pour l'utilisateur.

**Objectif** : 4 verbes simples, zéro doublon, et on ne trace par lot/DLC que ce
qui doit l'être pour l'HACCP.

---

## 2. La cible

```
📦 APPROVISIONNEMENT   →  ACHETER : Besoins · Commandes · Catalogue/Prix
                          └─ chaque article porte un flag « Scannable ? » ⭐ (nouveau)
                          (tables appro_commandes / appro_commande_lignes existantes)

📋 RÉCEPTION           →  RECEVOIR LA MARCHANDISE (flux unifié, cf. §2bis) :
                          ├─ ① Scan BL/Facture         → ouvre la session, l'IA lit les lignes
                          ├─ ② Scan étiquettes matières → uniquement les articles scannables (rafale)
                          ├─ ③ Check humain            → livré vs commandé
                          │     ⤷ async : Opus rapproche  Commande ↔ BL ↔ Étiquettes
                          ├─ Étiquettes (corrections) + Rattachement (fusionnés)
                          └─ ELIS (inchangé)
                          ✗ scan unitaire « étiquette » supprimé (redondant)

🛒 ACHATS / FACTURES   →  FACTURES COMPTABLES :
                          └─ Facture pure (sans marchandise / arrivée différée) ⭐
                          ⚠️ le scan BL/facture de réception RESTE dans Réception (c'est le pivot)

📦 STOCK               →  GÉRER LE STOCK :
                          ├─ État · Sorties du jour
                          ├─ Gérer les ingrédients (+ flag Scannable)
                          │     • scannable  → stock par lot/DLC
                          │     • non-scan.  → stock en quantité simple
                          ├─ Vérif lot (ex-« Inventaire » scanner)
                          ├─ Contrôle stock réel (renommé)
                          └─ Ajustement exceptionnel (ex-« Sortir matières »)
                          ✗ « Rattraper une production » → archivé
```

**Les 4 verbes : Acheter · Recevoir · Facturer · Gérer le stock.**

---

## 2bis. Le flux de réception cible (le « rêve »)

Une seule réception, une séquence claire pour l'équipe, et l'IA qui mouline **en
tâche de fond** pendant que l'humain fait son contrôle visuel :

```
1. 📄 Scan BL/Facture          → ouvre la session ; l'IA extrait les lignes du document
2. 🏷️  Scan des étiquettes       → en rafale, UNIQUEMENT les articles scannables
3. ✅ Check humain              → « ce qui est livré » vs « ce qu'on a commandé »
        ⤷ pendant ce temps, en async :
4. 🤖 Opus 4.8 rapproche le TRIANGLE :  Commande ↔ BL/Facture ↔ Étiquettes
        → écarts (manquant, sur-livré, prix, DLC), validation par PIN côté Réceptions
```

### Ce qui existe déjà (bonne nouvelle — c'est ~80 % en place)

| Brique | État | Où |
|---|---|---|
| Commandes en base | ✅ existe | `appro_commandes`, `appro_commande_lignes` |
| Session de réception groupée (N étiquettes + 1 BL) | ✅ existe | scanner mode `sburst` |
| Extraction IA des étiquettes + du BL | ✅ existe | edge function `extract-document` (Opus 4.8) |
| Rapprochement **asynchrone** Étiquettes ↔ BL | ✅ existe | edge function `reconcile-session` |
| Affichage écarts + validation PIN | ✅ existe | module Réceptions |

### Ce qui manque pour fermer le triangle

1. **Ajouter la Commande comme 3ᵉ source** de `reconcile-session` : aujourd'hui
   il rapproche Étiquettes ↔ BL ; il faut y injecter les lignes de
   `appro_commande_lignes` de la commande liée → écarts **vs commande** (manquant,
   sur-livré, article non commandé).
2. **Lier la session à une commande** : choisir la commande appro au démarrage de
   la réception (par fournisseur), pour donner à l'IA la 3ᵉ liste.
3. **Réordonner l'UI** : scanner le **BL en premier** (point ① du flux), puis les
   étiquettes — alors qu'aujourd'hui le BL peut venir en fin de session.

> 💡 Le flag `scannable` et ce flux se renforcent : `reconcile-session` sait déjà
> qu'une *« ligne BL sans étiquette est normale pour le sel, l'huile… »*. Le flag
> rend cette intuition **déterministe** : une ligne d'article `scannable=false`
> n'attend **aucune** étiquette → on la vérifie seulement en quantité (BL ↔
> commande), sans la signaler comme « étiquette orpheline ».

---

## 3. La pièce maîtresse : le flag « Scannable ? »

Une colonne booléenne `scannable` sur **`appro_ingredients`** (le catalogue
commun aux deux établissements). Elle dit : *« cet article a-t-il une étiquette
lot/DLC qu'on veut tracer ? »*

| Famille | `scannable` | Raison |
|---|---|---|
| Viande, volaille, poisson, charcuterie | `true` | lot + DLC + traçabilité = HACCP strict |
| Crèmerie, frais, œufs | `true` | DLC courte, à suivre |
| Épicerie sèche (farine, sucre, sel), conserves | `false` | stable, pas de lot utile |

### Ce que le flag change, concrètement

| Aujourd'hui | Avec le flag |
|---|---|
| Scan FEFO obligatoire = `est_principal` seul → peut réclamer le scan d'un lot de farine | Scan obligatoire = `est_principal` **ET** `article.scannable` → plus de scan absurde |
| L'écran Rattachement mélange tout | On ne propose au scan/rattachement que `scannable = true` |
| Stock par lot/DLC pour tout | Non-scannables → **stock en quantité simple** (pas de gestion lot/DLC) |
| `reconcile-session` devine au cas par cas qu'une ligne BL « peut » ne pas avoir d'étiquette | Ligne d'article `scannable=false` → **aucune** étiquette attendue, vérif quantité seule, pas d'anomalie « orpheline » |

### Articulation avec l'existant — à ne pas casser

- `fiche_ingredients.est_principal` **reste** le pilote du scan en production.
  Le flag `scannable` vient **en ET logique** par-dessus, il ne le remplace pas.
- La règle exacte à implémenter côté production (TAF/Production, mode burst) :
  > scan FEFO exigé pour un ingrédient **ssi** `est_principal = true`
  > **ET** l'article rattaché a `scannable = true`.
- Côté Stock, les non-scannables sortent du circuit `stock_par_lot` (qui reste
  une **vue** calculée sur `stock_mouvements`) et basculent sur un suivi quantité
  simple. **Décision à figer avant l'étape 4** (voir §6, point ouvert).

### Migration SQL (idempotente — à exécuter dans Supabase SQL Editor)

`appro_ingredients` a déjà RLS + policy `anon` (catalogue lu côté front). On
n'ajoute qu'une colonne, donc pas de nouvelle policy à créer — mais on garde le
réflexe de vérifier (règle PBT §8).

```sql
-- scripts/migration-scannable.sql (à créer)
ALTER TABLE appro_ingredients
  ADD COLUMN IF NOT EXISTS scannable BOOLEAN NOT NULL DEFAULT true;

-- Initialisation par famille : l'épicerie sèche passe en non-scannable.
-- ⚠️ À AJUSTER selon les vraies catégories de appro_ingredients
--    (lister d'abord : SELECT DISTINCT categorie FROM appro_ingredients;)
UPDATE appro_ingredients
   SET scannable = false
 WHERE categorie IN ('epicerie', 'epicerie_seche', 'sec', 'conserves');

-- Vérif post-migration
SELECT scannable, count(*) FROM appro_ingredients GROUP BY scannable;
```

> Default `true` volontairement : on ne « casse » aucun flux existant (tout reste
> scannable comme avant), puis on **désactive** explicitement les familles sèches.
> Plus sûr que l'inverse.

---

## 4. Ordre d'exécution (du moins risqué au plus structurant)

Chaque étape est **livrable seule, testable seule, réversible**. On ne passe à la
suivante qu'après validation d'Eric sur iPad.

### Étape 1 — Flag « Scannable » : BDD + affichage lecture seule  🟢 faible risque
- Migration `scripts/migration-scannable.sql` (colonne + init par famille).
- Dans **Stock → Gérer les ingrédients** : afficher une colonne / un toggle
  `Scannable Oui/Non`, **éditable**. Aucune logique branchée dessus encore.
- *Gain immédiat* : Eric paramètre son catalogue tranquillement.
- *Réversible* : la colonne ne fait rien tant que l'étape 2 n'est pas là.

### Étape 2 — Brancher le flag sur le scan FEFO production  🟡 moyen
- Production/TAF (mode burst) : n'exiger le scan que si `est_principal ET scannable`.
- ⚠️ Touche un composant à 2+ appelants (TAF *et* Production) → règle PBT §11 :
  test syntaxe JS obligatoire + test iPad sur les deux entrées avant push.
- *Gain* : fin des scans inutiles.

### Étape 3 — Supprimer le scan unitaire « étiquette »  🟡 moyen
- Réception groupée couvre déjà le cas 1 étiquette / sans BL (vérifié).
- Retirer l'entrée « scan unitaire » côté étiquettes matières.
- ⚠️ Le scanner gère `?return=taf` / `?return=production` (règle PBT §8) : vérifier
  qu'aucun appelant ne pointait vers le mode unitaire avant suppression.

### Étape 4 — Stock : suivi quantité simple pour les non-scannables  🟠 structurant
- Les articles `scannable = false` : stock en quantité, hors `stock_par_lot`.
- **Pré-requis** : trancher le point ouvert §6 (où vit la quantité simple).
- Plus gros morceau : à découper en sous-étapes au moment venu.

### Étape 5 — Fermer le triangle : Commande dans le rapprochement  🟠 structurant
> C'est le cœur du « rêve » (§2bis). Évolution, pas révolution : on enrichit
> l'existant plutôt que de repartir de zéro.
- **5a.** Lier la session de réception à une `appro_commandes` (choix de la
  commande/fournisseur au démarrage, point ① du flux).
- **5b.** Injecter les `appro_commande_lignes` comme **3ᵉ liste** dans le prompt de
  `reconcile-session` → écarts **vs commande** (manquant, sur-livré, non commandé,
  prix). Mettre à jour le JSON de sortie + l'affichage écarts côté Réceptions.
- **5c.** Réordonner l'UI scanner : **BL en premier**, étiquettes ensuite.
- ⚠️ Touche `reconcile-session` (edge function) + module Réceptions. À tester en
  live sur une vraie livraison. Profite du flag `scannable` (étape 1) pour ne pas
  signaler les lignes non-scannables comme « étiquette orpheline ».

> #### Le code article fournisseur = la clé d'or du pont BL ↔ Commande
> Le catalogue multi-fournisseur existe déjà : table **`appro_prix`** =
> (`article_id`, `fournisseur_id`, **`reference_fournisseur`**, `designation`,
> `pu_ht`…). Un même article PBT a **N lignes**, une par fournisseur, chacune avec
> **son** code. Ex. « Knack » : code `051619` chez Iller, `3315` chez Koch, etc.
>
> **Constat (vérifié au 11/06/2026)** : `reconcile-session` matche aujourd'hui par
> **désignation + poids** ; le `code_article` lu sur le BL est **transporté mais
> jamais comparé**, et `appro_prix`/la commande **ne sont pas lus**.
>
> **À faire en 5b** : utiliser `reference_fournisseur` comme **clé de match
> prioritaire** (fallback désignation/poids), distinctement sur les deux ponts :
> - **① BL ↔ Commande** : même fournisseur des deux côtés → `code = code`, match
>   **exact et non ambigu**. C'est ici que le code brille.
> - **② Étiquette (carton) ↔ Article** : l'étiquette porte le code **fabricant /
>   EAN**, pas la ref du distributeur → on reste sur désignation/poids (ou on
>   ajoute l'EAN plus tard). Ne PAS attendre la ref Iller sur l'étiquette.

### Étape 6 — Facture comptable pure → Achats  🟠 structurant
- **Pas** le BL de réception (qui reste le pivot de la Réception, étape 5).
- Seulement la **facture seule** (sans marchandise, ou arrivée en différé) →
  numérisation côté **Achats/Factures**, rapprochement avec la commande déjà reçue.
- À cadrer séparément (module Achats + réutilise `extract-document`).

### Étape 7 — Renommages / fusion d'onglets  🟢 faible risque (cosmétique)
- Fusion **Étiquettes (corrections) + Rattachement**, renommages (« Vérif lot »,
  « Contrôle stock réel », « Ajustement exceptionnel »), archivage « Rattraper une
  production ». Purement libellés/regroupement → à faire en dernier, sans risque.

---

## 5. Risques & points de vigilance (rappels PBT)

- **Service Worker** : toute étape user-visible (1, 3, 5, 7 surtout) → bumper
  `CACHE_NAME = 'planb-tools-vN'` dans `sw.js`, sinon les iPads PWA gardent
  l'ancienne version en cache. (règle §5 / §11)
- **Migrations** : toujours idempotentes (`IF NOT EXISTS`), jamais de schéma sans
  fichier `scripts/migration-*.sql`. Supabase MCP peut être read-only → si
  l'`apply_migration` échoue, Eric colle le SQL dans le SQL Editor. (§5 / §11)
- **Composants à 3+ utilisateurs** (scan FEFO rafale, `DB.getTasks`,
  `DB.createProduction`) : ne pas toucher sans accord explicite. L'étape 2 frôle
  ce périmètre → prudence. (§11)
- **Test syntaxe JS** avant chaque push HTML/JS (snippet `node -e ...` de §7).
- **Pas d'apostrophes** dans les messages de commit ; commits via `scripts/`. (§3)
- **Bonbao** : zéro occurrence ne doit apparaître ; c'est « Chez Tante Liesel ». (§4)

---

## 6. Points ouverts à trancher avec Eric

1. **Où vit la quantité simple des non-scannables ?** (avant étape 4)
   Options : (a) une colonne quantité sur `appro_ingredients`, (b) des
   `stock_mouvements` sans lot (lot = NULL) agrégés, (c) une petite table dédiée.
   Recommandation provisoire : (b), pour réutiliser le journal `stock_mouvements`
   déjà source de vérité.

2. **Init du flag `scannable`** : valider la liste réelle des catégories
   (`SELECT DISTINCT categorie FROM appro_ingredients;`) avant d'écrire le `UPDATE`.

3. **Lien session ↔ commande** (avant étape 5) : une réception = une seule
   commande, ou plusieurs commandes regroupées ? Et que faire si la livraison
   arrive **sans** commande enregistrée (achat direct) ?

4. **Facture comptable** (avant étape 6) : définir ce qu'on extrait (fournisseur,
   montant HT/TTC, lignes ?) et le rapprochement avec la commande déjà reçue.

---

## 7. Suivi d'avancement

| Étape | État | Notes |
|---|---|---|
| 1 — Flag Scannable (BDD + UI) | ⬜ à faire | |
| 2 — Flag branché sur scan FEFO | ⬜ à faire | |
| 3 — Suppression scan unitaire | ⬜ à faire | |
| 4 — Stock quantité simple | ⬜ à faire | dépend du point ouvert §6.1 |
| 5 — Triangle : Commande dans reconcile | ⬜ à faire | cœur du « rêve » ; dépend §6.3 |
| 6 — Facture comptable → Achats | ⬜ à faire | dépend §6.4 |
| 7 — Renommages / fusion onglets | ⬜ à faire | cosmétique, en dernier |
