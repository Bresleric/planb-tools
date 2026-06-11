# Rapport de réconciliation `appro_prix` ↔ `appro_ingredients`

> Généré le 11/06/2026, en **lecture seule** (aucune donnée modifiée).
> Objectif : mesurer l'ampleur et la faisabilité du raccordement des tarifs
> fournisseurs au catalogue d'articles — prérequis « étape 0 » de la feuille de
> route `REORG-STOCK-RECEPTION.md` (§4).

## 1. Pourquoi ce rapport

Le rapprochement « par code article fournisseur » rêvé pour la réception repose
sur la table **`appro_prix`** (article ↔ fournisseur ↔ `reference_fournisseur` ↔
prix). Or **771 tarifs sur 771 sont déconnectés** du catalogue : leur `article_id`
ne pointe vers aucun `appro_ingredients`. Tant que ce lien n'est pas réparé, le
système ne peut pas savoir que « code `2821` chez Koch = mon article Knack ».

Ce rapport teste un **raccordement automatique** par ressemblance de désignation,
pour estimer combien de tarifs peuvent être réassociés sans saisie manuelle.

## 2. Chiffres clés

| Mesure | Valeur |
|---|---|
| Articles catalogue actifs (`appro_ingredients`) | 448 (455 au total) |
| Tarifs `appro_prix` | 771 |
| Fournisseurs avec tarifs | 13 |
| **Tarifs orphelins (lien cassé)** | **771 / 771 (100 %)** |
| Lignes de commande orphelines | 76 / 76 |

## 3. Méthode de matching automatique testée

`pg_trgm` (similarité trigramme) **n'est pas activé** sur la base. Faute de mieux
en lecture seule, heuristique par **inclusion de nom** : pour chaque tarif, on
retient l'article catalogue dont le `nom` (ou `nom_recherche`) est **contenu** dans
la désignation fournisseur, en privilégiant le nom **le plus long** (le plus
spécifique). Le « score de confiance » = longueur du nom matché.

## 4. Résultat

| | Tarifs | % |
|---|---|---|
| ✅ Proposition trouvée | **425** | 55 % |
| └─ confiance **haute** (nom ≥ 8 car.) | 265 | 34 % |
| └─ confiance moyenne (4–7 car.) | 160 | 21 % |
| ❌ Aucun match automatique | **346** | 45 % |

### Échantillon — confiance haute (fiable)

| Fournisseur | Réf | Désignation fournisseur | → Article proposé |
|---|---|---|---|
| Essentiel RHF | A00572 | CHAMPIGNONS PARIS 3KG | Champignons Paris |
| Essentiel RHF | A00797 | CHOCOLAT NOIR 44% PALETS 5KG | Chocolat Noir |
| Koch & Fils | P1210 | MASCARPONE AMBROSI 1 X 6 X 500 G | Mascarpone |
| Promocash | 837674 | ST 100G CIBOULETTE EQR IMP | Ciboulette |
| Zeyssolff | — | RIESLING AOC ALSACE 100cl | Riesling |

### Échantillon — confiance moyenne (corrects mais génériques, à valider)

| Fournisseur | Désignation | → Proposé |
|---|---|---|
| Sapam | CAROTTE HVE3 ALS SAC10K I | Carotte |
| Koch & Fils | JARRET BRAISE KOCH 1 X 10 X 700G+- | Jarret |
| Sapam | POIVRON ROUGE NL GG 5KG I | Poivron |
| Essentiel RHF | 500 PAILLES CARTON BLC | Pailles |

### Échantillon — sans match (pourquoi ça résiste)

| Désignation | Raison probable |
|---|---|
| TOM.RONDE HVE3 ALS 57-67 6KG | abréviation fournisseur (`TOM.` ≠ Tomate) |
| SL FEUI.CHE.BLO MIDI | abréviations cryptiques (salade feuille de chêne ?) |
| CH CHAMPIGNON P.C NL M 3KG | singulier/pluriel (`CHAMPIGNON` ≠ Champignons) |
| EMMENTAL RAPE STD VALMARTIN… | accents / article absent du catalogue |
| SAC POUBELLE 130L NOIR X20 | produit réellement absent du catalogue |
| METEOR IPA Litre Fût | bière, nom catalogue différent |

## 5. Cas « Knack » (le déclencheur)

- Article catalogue : **Knack** (`5d35396a`, Viande & charcuterie) ✅ existe.
- Tarif Koch `2821` « KNACK D'ALSACE EXTRA 20×50G » → article `2459f954` 👻 fantôme.
- Tarif Iller `062300` « SAUCISSE DE STRASBOURG 60GR » → article `92ea7c7a` 👻 fantôme.
- Aucun des deux n'est relié au vrai « Knack ». Seuls **2 fournisseurs** ont une
  ligne (ni Promocash, ni Metro — Metro n'est même pas dans `appro_fournisseurs`).
- Note : « SAUCISSE DE STRASBOURG » (Iller) ne contient pas le mot « Knack » → ce
  type de synonyme métier devra passer par `nom_recherche` ou une validation
  humaine, pas par la simple inclusion de nom.

## 6. Enseignements

1. **Un seul maillon à réparer** : `appro_prix.article_id`. Les commandes pointent
   déjà vers les tarifs (`appro_commande_lignes.prix_id`) → réparer les tarifs
   reconnecte automatiquement commande → prix → article → stock.
2. **~34 % réparables en quasi-automatique** (confiance haute, validation au survol).
3. **~21 % à valider rapidement** (noms génériques, peu de faux positifs).
4. **~45 % nécessitent un effort** : enrichir `nom_recherche` (synonymes,
   abréviations), activer `pg_trgm`, ou recourir à un matching IA (Opus, comme
   `reconcile-session`), ou de la saisie manuelle ciblée.

## 7. Plan de réparation proposé (étape 0)

1. **Outil de réconciliation** (UI Stock ou script) : liste les 771 tarifs avec la
   proposition pré-remplie + score ; Eric valide / corrige / écarte ligne par ligne,
   trié par fournisseur. Écrit `appro_prix.article_id`.
2. **Vague 1 — confiance haute (265)** : validation en masse (cocher tout, décocher
   les rares erreurs).
3. **Vague 2 — confiance moyenne (160)** : validation à l'œil.
4. **Vague 3 — sans match (346)** : matching IA + enrichissement `nom_recherche`,
   puis saisie manuelle du reste. Repérer ici les produits **absents du catalogue**
   à créer (ou à marquer hors-périmètre : consommables, bières, etc.).
5. **Garde-fou** : après réparation, ajouter une **FK** `appro_prix.article_id →
   appro_ingredients(id)` pour empêcher de recréer des orphelins.

> Décision attendue d'Eric avant de coder : valider cette approche par vagues, et
> choisir le support de l'outil (onglet dans Stock vs script one-shot assisté).
