# Assainissement du stock matières premières — liste à valider (02/11/2026)

> Étape 0 du chantier « Contrôle permanent du stock ». Rien n'est exécuté tant
> qu'Eric n'a pas validé cette liste. L'opération est **réversible** : chaque lot
> soldé reçoit un mouvement `AJUSTEMENT` daté et motivé dans `stock_mouvements`
> (`source_table = 'assainissement'`) ; supprimer ces lignes restaure l'état d'avant.

## 1. Ce qui sera soldé (mis à zéro)

| Cas | Freddy | Liesel | Règle |
|---|---|---|---|
| A. Lots à DLC dépassée avec quantité restante > 0 | 333 | 38 | ajustement = − quantité restante |
| B. Lots sans DLC lisible, scannés il y a plus de 45 jours | 44 | 19 | ajustement = − quantité restante |
| C. Lots en négatif (sorties supérieures aux entrées) | 48 | 1 | ajustement = + quantité manquante (retour à zéro) |
| **Total** | **425** | **58** | **483 lots** |

Ne sont **pas** touchés : les 21 lots de Freddy encore valides (DLC à venir).

## 2. Détail du cas A — Freddy (333 lots, par article)

| Article | Catégorie | Lots | Qté restante | DLC de … à | Dernier scan |
|---|---|---|---|---|---|
| Cervelas | Viande & charcuterie | 36 | 45,92 kg | 03/2025 → 06/2026 | 10/06 |
| Blanc de poulet | Viande & charcuterie | 27 | 107,69 kg | 05/2025 → 06/2026 | 05/06 |
| Jambon Forêt Noire | Viande & charcuterie | 23 | 4,60 kg | 07/2023 → 07/2026 | 08/06 |
| Jarret | Viande & charcuterie | 22 | 19,47 kg | 04/2025 → 06/2026 | 18/05 |
| Knack MEP ⚠️ PI | Alimentaire | 16 | 297 pce | 12/10 → 31/10/2026 | 28/10 |
| Kassler fumé cru | Viande & charcuterie | 14 | 27,82 kg | 03/2025 → 06/2026 | 02/06 |
| Saumon fumé | Frais | 14 | 14 pce | 05/2026 → 06/2026 | 04/06 |
| Knack | Viande & charcuterie | 13 | 15,25 kg | 05/2025 → 09/2026 | 10/06 |
| Lard salé | Viande & charcuterie | 12 | 52,06 kg | 06/2020 → 06/2026 | 02/06 |
| Paleron | Frais | 11 | 32,56 kg | 06/2024 → 07/2026 | 08/06 |
| Pièce du boucher | Viande & charcuterie | 11 | 21,51 kg | 08/2025 → 06/2026 | 10/06 |
| Gendarmes | Frais | 10 | 9,84 pce | 08/2025 → 06/2026 | 11/06 |
| Lard fumé | Viande & charcuterie | 10 | 19,43 kg | 02/2025 → 06/2026 | 01/06 |
| Emmental râpé Valmartin | Alimentaire | 9 | 9 pce | 06/2025 → 08/2026 | 04/06 |
| Jambon cuit en tranches | Viande & charcuterie | 9 | 4,64 kg | 06/2025 → 06/2026 | 23/05 |
| Magret de canard | Alimentaire | 7 | 2,97 pce | 05/2026 → 06/2026 | 02/06 |
| Pièce du boucher : PAC ⚠️ PI | Alimentaire | 7 | 36 pce | 13/10 → 01/11/2026 | 29/10 |
| Tranches fines de poitrine crue fumée | Viande & charcuterie | 7 | 5,70 kg | 06/2025 → 05/2026 | 06/05 |
| Rieweleküche (PI) ⚠️ PI | PI/MEP | 5 | 8 kg | 12/10 → 01/11/2026 | 29/10 |
| Bavette aloyau bœuf | Viande & charcuterie | 4 | 8,25 kg | 05/2026 → 06/2026 | 21/05 |
| Carton jarret de porc cuit ×10 | Viande & charcuterie | 4 | 28 pce | 07/2025 → 07/2026 | 02/06 |
| Farce bœuf préparée | Viande & charcuterie | 4 | 5 kg | 05/2026 | 06/05 |
| Salade lavée ⚠️ PI | Alimentaire | 4 | 12 pce | 10/10 → 01/11/2026 | 29/10 |
| Soupe à l'oignon (PI) ⚠️ PI | PI/MEP | 4 | 23 kg | 16/10 → 24/10/2026 | 21/10 |
| Spaetzele (PI) ⚠️ PI | PI/MEP | 4 | 64 kg | 18/10 → 30/10/2026 | 24/10 |
| Haché tradition | Viande & charcuterie | 3 | 4,50 kg | 01/2025 → 06/2026 | 02/06 |
| Onglet | Frais | 3 | 5,10 kg | 05/2026 → 06/2026 | 07/05 |
| Sauce Munster ⚠️ PI | Alimentaire | 3 | 15 pce | 18/10 → 31/10/2026 | 26/10 |
| Bibeleskaes (PI) ⚠️ PI | PI/MEP | 2 | 2 kg | 09/10 → 21/10/2026 | 18/10 |
| Bœuf bourguignon (PI) ⚠️ PI | PI/MEP | 2 | 14 kg | 27/10 → 28/10/2026 | 25/10 |
| Cordons bleus S/V crus ⚠️ PI | Alimentaire | 2 | 11 pce | 18/10 → 19/10/2026 | 16/10 |
| Jambon sel sec Espagne | Viande & charcuterie | 2 | 2 kg | 07/2026 | 14/05 |
| Jarrets de porc cuits supérieur ×3 | Viande & charcuterie | 2 | 3,88 kg | 06/2026 | 14/05 |
| Munster blanc | Frais | 2 | 2,31 kg | 05/2026 → 06/2026 | 23/05 |
| Munsterflette poche S/V (PI) ⚠️ PI | PI/MEP | 2 | 11 kg | 10/10 → 25/10/2026 | 22/10 |
| Oignons tombés pour soupe (PI) ⚠️ PI | PI/MEP | 2 | 30 kg | 16/10 → 18/10/2026 | 15/10 |
| Onglet de veau | Frais | 2 | 3,46 kg | 05/2026 | 11/05 |
| Pommes de terre épluchées d'Alsace | Fruits & légumes | 2 | 5,50 kg | 06/2026 | 29/05 |
| Préparer cervelas (PI) ⚠️ PI | PI/MEP | 2 | 12 kg | 11/10 → 27/10/2026 | 24/10 |
| Saumon fumé MEP ⚠️ PI | Alimentaire | 2 | 3 pce | 09/10 → 18/10/2026 | 10/10 |
| 10 brochettes de poulet cajun | Viande & charcuterie | 1 | 2,21 kg | 05/2026 | 21/05 |
| Beurre campagne | Frais | 1 | 0,50 kg | 08/2026 | 04/05 |
| Blancs d'œufs | Frais | 1 | 0,60 kg | 06/2024 | 14/05 |
| Cordons bleus S/V cuits ⚠️ PI | Alimentaire | 1 | 6 pce | 15/10/2026 | 12/10 |
| Kassküche (PI) ⚠️ PI | PI/MEP | 1 | 2 kg | 27/10/2026 | 21/10 |
| Knack fromage à griller | Viande & charcuterie | 1 | 1,31 kg | 05/2025 | 14/05 |
| Magret de canard fumé | Viande & charcuterie | 1 | 0,30 kg | 07/2026 | 01/05 |
| Mascarpone | Alimentaire | 1 | 0,50 pce | 08/2026 | 04/05 |
| Noix de veau cuite ⚠️ PI | Alimentaire | 1 | 2,27 pce | 15/10/2026 | 12/10 |
| Oignons confits S/V (PI) ⚠️ PI | PI/MEP | 1 | 1 pce | 09/10/2026 | 06/10 |
| Salade coleslaw | Alimentaire | 1 | 3 kg | 06/2026 | 05/06 |
| Sauce bouchée (PI) ⚠️ PI | PI/MEP | 1 | 3 kg | 17/10/2026 | 11/10 |
| Saucisse de viande émincée | Viande & charcuterie | 1 | 1,21 kg | 05/2026 | 14/05 |

⚠️ PI = produit intermédiaire fabriqué en cuisine (entré en stock par le module
Production depuis le 10/10) : **jamais sorti du stock car aucune sortie n'existe
pour les PI**. Voir §5.

## 3. Détail du cas A — Liesel (38 lots, par article)

| Article | Catégorie | Lots | Qté restante | DLC de … à | Dernier scan |
|---|---|---|---|---|---|
| Munster | Alimentaire | 7 | 4,53 pce | 05/2021 → 05/2026 | 29/05 |
| Jambon Forêt Noire | Viande & charcuterie | 6 | 1,20 kg | 05/2025 → 06/2026 | 06/05 |
| Cervelas | Viande & charcuterie | 4 | 5 kg | 05/2026 → 08/2026 | 29/05 |
| Onglet | Frais | 4 | 8,53 kg | 05/2026 | 06/05 |
| Pièce du boucher | Viande & charcuterie | 3 | 7,26 kg | 06/2025 → 06/2026 | 30/05 |
| Emmental râpé Valmartin | Alimentaire | 2 | 2 pce | 07/2026 | 06/05 |
| Lard fumé | Viande & charcuterie | 2 | 3,55 kg | 05/2025 → 09/2025 | 05/05 |
| Paleron | Frais | 2 | 6,61 kg | 05/2026 | 05/05 |
| Gendarmes | Frais | 1 | 1,20 pce | 09/2026 | 06/05 |
| Jarret | Viande & charcuterie | 1 | 7 kg | 06/2026 | 06/05 |
| Kassler fumé cru | Viande & charcuterie | 1 | 1,53 kg | 05/2026 | 05/05 |
| Knack | Viande & charcuterie | 1 | 1,11 kg | 07/2026 | 06/05 |
| Lard salé | Viande & charcuterie | 1 | 2,30 kg | 05/2026 | 05/05 |
| Lardons fumés | Viande & charcuterie | 1 | 1 kg | 02/2025 | 06/05 |
| Œufs frais | Œufs | 1 | 0,18 pce | 05/2026 | 06/05 |
| Tiramisu | Frais | 1 | 1 L | 09/2025 | 06/05 |

## 4. Détail du cas C — lots en négatif (49 lots)

Ces lots ont plus de sorties que d'entrées. Les montants aberrants (plusieurs
**tonnes** d'épaule d'agneau ou de porc) montrent une **erreur d'unité dans les
sorties de production** (grammes de la recette comptés comme des kilos). À
corriger dans l'étape 2, sinon le phénomène se reproduira.

| Établ. | Article | Lots | Quantité en négatif | Étiquettes (entrées) |
|---|---|---|---|---|
| Freddy | Épaule d'agneau coupée sauté | 3 | −13 479,82 kg | 21,01 kg |
| Freddy | Porc pour Baeckeoffe | 4 | −9 631,02 kg | 10,85 kg |
| Freddy | Bœuf bourguignon | 4 | −7 126,97 kg | 10,75 kg |
| Freddy | Pommes de terre lamelles | 1 | −1 419,40 kg | 5 kg |
| Freddy | Crème liquide 5 L | 1 | −739,50 kg | 0,50 kg |
| Freddy | Beurre | 1 | −499,80 pce | 0,20 pce |
| Freddy | Poivre grains | 1 | −99 | 1 |
| Freddy | Œufs frais | 10 | −64,42 pce | 180 pce |
| Freddy | Jaunes d'œufs liquide brique | 1 | −43,44 kg | 1 kg |
| Freddy | Pommes de terre épluchées d'Alsace | 4 | −20 kg | 20 kg |
| Freddy | Œufs entiers liquide brique | 3 | −19,84 pce | 2,60 pce |
| Freddy | Lait entier | 1 | −19,33 L | 1 L |
| Freddy | Munster | 3 | −11,33 pce | 2,12 pce |
| Freddy | Oignons émincés (PI) | 1 | −6 kg | 1 kg |
| Freddy | Blanc de poulet | 1 | −5 kg | 5 kg |
| Freddy | Oignons émincés frais | 1 | −2,67 pce | 0,50 pce |
| Freddy | Cervelas | 1 | −1,27 kg | 1,27 kg |
| Freddy | Crème liquide brique | 1 | −1 L | 6 L |
| Freddy | Fonds de tarte | 1 | −1 pce | — |
| Freddy | Noix de veau blanche | 1 | −0,87 kg | 3,63 kg |
| Freddy | Poitrine fumée tranche fine | 1 | −0,80 pce | 0,80 pce |
| Freddy | Huile tournesol | 1 | −0,50 pce | 1,50 pce |
| Freddy | Cuisses de canard confites | 1 | −0,50 kg | 1 kg |
| Freddy | Lardons fumés | 1 | −0,33 kg | 1 kg |
| Liesel | Beurre | 1 | −49 pce | 0,50 pce |

## 5. Ce que cette liste nous apprend (pour la suite du chantier)

1. **Les matières premières scannées avant juillet** (cervelas, poulet, jarret,
   lards…) n'ont jamais été sorties : la consommation hors production n'est pas
   enregistrée. → Étape 2 : consommation théorique par les recettes + comptage.
2. **Les produits intermédiaires** entrés depuis le 10/10 (Knack MEP, Spaetzele,
   Soupe à l'oignon…) ressortent en « stock fantôme » **une semaine après leur
   fabrication**, faute de sortie. → Étape 2 : prévoir leur sortie (consommation
   en service, ou sortie automatique à la DLC).
3. **Les sorties de production ont un bug d'unité** (tonnes au lieu de kilos). →
   Étape 2, à corriger **avant** de recalculer quoi que ce soit.
4. **Les DLC absurdes** (2020, 2021, 2023) sont des erreurs de lecture d'étiquette
   par l'IA : à surveiller à l'étape 1 (rattachement express), avec un contrôle de
   vraisemblance (DLC entre aujourd'hui − 7 j et + 2 ans).

## 7. Résultat de l'exécution (02/11/2026, validé par Eric : cas A, B et C)

| | Freddy | Liesel |
|---|---|---|
| Cas A | 333 | 38 |
| Cas B | 44 | 19 |
| Cas C | 48 | 1 |
| **Ajustements créés** | **425** | **58** |

Vérification après coup : **0 lot** restant à DLC dépassée, en négatif ou sans DLC
ancien. Script exécuté : `scripts/assainissement-stock-2026-11.sql`.

**Reste en stock** : 21 lots, tous chez Freddy. 11 sont des produits intermédiaires
fabriqués ces derniers jours (DLC du 02 au 07/11) et 10 sont des **lots scannés en
mai-juin avec une DLC lue en 2028** (jambon Forêt-Noire 0,20 kg × 6, onglet, pièce
du boucher, pommes de terre…) : DLC mal lue, à solder dans un second temps (cas D
proposé : scanné il y a plus de 45 jours et DLC à plus d'un an).

## 6. Exécution prévue (après OK)

Un seul script SQL, idempotent, qui insère pour chaque lot concerné une ligne
`stock_mouvements` de type `AJUSTEMENT` :
- quantité = l'opposé de la quantité restante (ramène le lot à zéro) ;
- `motif` = « Assainissement stock 11/2026 valide par Eric — cas A/B/C … » ;
- `source_table` = `assainissement`, `source_id` = l'identifiant du lot ;
- `created_by` = Eric.

Vérification après coup : `SELECT count(*) FROM stock_par_lot WHERE quantite_restante
<> 0 AND (dlc < current_date OR quantite_restante < 0)` doit renvoyer 0.
Retour arrière : `DELETE FROM stock_mouvements WHERE source_table = 'assainissement'`.
