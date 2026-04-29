# Module Scanner — Roadmap

**PlanB Tools** | Décision actée le 29 avril 2026
**Auteur** : Eric Bresler (PLANB SARL) avec Cowork

---

## Contexte

Le module `receptions/` actuel utilise Tesseract.js + photos base64 stockées dans Postgres. Audit du 29/04/2026 sur 41 documents : OCR illisible sur la majorité des photos prises au smartphone, aucune base interrogeable, registre HACCP impossible. Décision : **abandonner cette chaîne et bâtir un nouveau module `scanner/` selon la reco architecture de mars 2026** (`docs/recommandation-numerisation.md`), avec un ajustement issu d'un POC réussi : la chaîne hybride à 2 voies (option D).

## Architecture cible — Option D hybride

Deux voies d'entrée alimentant le **même** pipeline d'extraction :

```
┌──────────────────────────────────────────────────────────────────┐
│  Voie 1 — Capture caméra in-app                                  │
│  <input type="file" accept="image/*" capture="environment">      │
│  → étiquette à scanner sur le moment, en chambre froide          │
│                                                                  │
│  Voie 2 — Import PDF Scanner Pro                                 │
│  Upload formulaire / partage iOS / email vers boîte dédiée       │
│  → batchs de qualité maximale (perspective redressée, multipage) │
└─────────────────────────────────┬────────────────────────────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │  Supabase Storage `scans`   │  (privé, signed URLs)
                    └─────────────────┬───────────┘
                                      ▼
                    ┌─────────────────────────────┐
                    │  Edge Function              │
                    │  `extract-document`         │
                    │  - reçoit (file_url, type)  │
                    │  - split PDF si multipage   │
                    │  - appelle Claude Vision    │
                    │  - retourne JSON structuré  │
                    └─────────────────┬───────────┘
                                      ▼
                    ┌─────────────────────────────┐
                    │  Anthropic API              │
                    │  Claude Haiku 4.5 Vision    │
                    │  Prompt selon type document │
                    └─────────────────┬───────────┘
                                      ▼
                    ┌─────────────────────────────┐
                    │  Validation humaine         │
                    │  Tables `scans`,            │
                    │  `scan_lignes`,             │
                    │  `scan_tracabilite`         │
                    └─────────────────────────────┘
```

## Pourquoi pas un seul des deux modes ?

| | Capture in-app seule | Scanner Pro seul | Hybride (D) |
|---|---|---|---|
| Qualité photo | Correcte | Excellente (perspective redressée) | Le meilleur des 2 |
| Workflow rapide chambre froide | ✅ | ❌ | ✅ |
| Sessions batch (factures du jour) | Pénible (1 par 1) | ✅ | ✅ |
| Multipages | À développer | Natif | Hérite des 2 |
| Dépendance app externe | Aucune | iOS uniquement | iOS pour la voie 2 |
| Effort dev | Élevé (auto-bords, multipage) | Aucun | Modéré |

## Modes d'extraction prioritaires

| Mode | Description | Priorité | Intégration aval |
|------|-------------|----------|------------------|
| `bl_facture` | BL et factures fournisseurs : fournisseur, n°, date, lignes (désignation/qté/PU/HT), TVA par taux, TTC | Haute | Skill `traitement-comptable` → écritures Cegid |
| `etiquette_produit` | Étiquettes carnés / BOF : dénomination, espèce, origine, lot, DLC/DDM, poids, agrément CE, T° | Haute (HACCP critique) | Registre HACCP automatique + alerte DLC |
| `ticket_caisse` | Tickets de dépenses caisse | Phase ultérieure | Module Contrôle Caisse existant |

## POC validé (29 avril 2026)

Test sur un PDF Scanner Pro de 52 étiquettes chambre froide (33 Mo). 13 pages réparties représentativement (1, 4, 7, 13, 19, 22, 25, 31, 37, 40, 43, 49, 52) ont été lues par Claude Vision.

**Résultat** : 13/13 étiquettes lues intégralement.

Cas piégeux gérés :
- Étiquette photographiée tournée à 90° (page 19)
- Étiquette multilingue partiellement déchirée — traçabilité bovine 5 colonnes intacte (pages 22, 25)
- Texte minuscule sur sachet sous-vide froissé (page 1)
- Étiquette en 4 langues avec instructions de cuisson (page 52)

Cas limite identifié : étiquette face avant qui mentionne "voir sur l'emballage" pour le lot/DLC (page 49). Le pipeline doit demander une 2ᵉ photo dans ce cas.

Doublons détectables automatiquement (3 photos du même jambon Schwarzwaldhaus pages 37, 40, 43 — même lot, même DLC).

Rapport détaillé : `poc-scanner/resultats.html`.

## Phasage

### Phase 0 — Infrastructure (préalable, ~1 h)
1. Créer le compte API Anthropic et générer une clé (action Eric, accompagnée pas-à-pas)
2. Stocker la clé comme secret `ANTHROPIC_API_KEY` dans Supabase
3. Créer le bucket Storage `scans` (privé, accès via signed URLs uniquement)
4. Créer les tables `scans`, `scan_lignes`, `scan_tracabilite` (cf. schema dans `docs/recommandation-numerisation.md`)
5. Purger les 41 entrées des tables `receptions_documents` et `receptions_pages` (`DELETE`, pas `DROP`)

### Phase 1 — Edge Function `extract-document` (~2 h)
1. Créer la function en TypeScript (Deno runtime Supabase)
2. Reçoit `(file_url, type_document, etablissement)`
3. Si le fichier est un PDF multipage : extraire chaque page en image (lib pdf-lib ou similaire)
4. Pour chaque image : appel Claude Haiku 4.5 Vision avec prompt système adapté au `type_document`
5. Retourne un JSON structuré (1 entrée par page si multipage)
6. Tester sur les 4 PDF déjà en base (Alsabret, Malt et Houblon, Ruhlmann-Schutz, Distribution Iller 02/04) + le PDF de 52 étiquettes du POC

### Phase 2 — Module `scanner/index.html` (~4-6 h)
1. Page unique avec choix de mode en haut (BL/facture vs étiquette)
2. **Voie 1 — Capture caméra** : bouton "📷 Scanner maintenant" → `<input capture="environment">`, prévisualisation, possibilité multi-pages, compression côté client (canvas → JPEG 80%, max 1500×1500)
3. **Voie 2 — Import PDF** : bouton "📄 Importer PDF Scanner Pro" → drag-drop ou sélection fichier, support multi-pages
4. Vue de validation : photos affichées + champs extraits éditables + bouton "Enregistrer"
5. Liste historique des scans (filtres établissement / type / date / statut)

### Phase 3 — Intégrations (~3 h pour BL, ~2 h pour HACCP)
1. **BL/factures** : à la validation, préparer une écriture pré-remplie pour le skill `traitement-comptable`
2. **Étiquettes** : registre HACCP consultable (page liste avec recherche par lot / DLC / fournisseur), export Excel pour archivage 5 ans, alerte DLC J-3
3. Détection de doublons automatique (hash lot + DLC + poids)

### Phase 4 — Décommissionnement Réceptions (~30 min)
1. Retirer le bouton Réceptions de la nav (ou le rediriger vers `scanner/`)
2. Garder l'URL `receptions/` accessible 30 jours en lecture seule
3. Conserver le sous-module ELIS (lui n'a pas le problème OCR — saisie manuelle structurée)

## Coût récurrent estimé

| Volume / jour (2 restos combinés) | API Anthropic |
|-----------------------------------|---------------|
| 30 docs/jour (900/mois) | ~3,90 €/mois |
| 50 docs/jour (1 500/mois) | ~6,50 €/mois |
| 100 docs/jour (3 000/mois) | ~12,90 €/mois |
| 200 docs/jour (6 000/mois) | ~25,80 €/mois |

Estimation conservatrice mode standard, validée par le POC. Plafond CB conseillé : **50 €/mois** pour sécuriser. Aucun autre coût (Storage et Edge Functions sont inclus dans l'abonnement Supabase Pro existant).

## Décisions structurantes

- **Scanner Pro reste l'outil de capture** quand la qualité prime ou en mode batch. Le module web ne cherche pas à le remplacer.
- **Ne pas stocker les images en base64 dans Postgres** (erreur du module Réceptions actuel) — toutes les images vont dans Storage avec signed URLs.
- **Clé API Anthropic jamais côté client** — elle reste secret Edge Function uniquement.
- **Purge mais pas suppression** des tables Réceptions actuelles, pour pouvoir y revenir si besoin pendant la transition.
- **Conservation HACCP 5 ans** : les étiquettes scannées doivent être archivées, le registre HACCP doit être exportable au format demandé par l'inspection.

## État au 29 avril 2026

- ✅ Audit module Réceptions actuel (galerie `receptions-audit.html`)
- ✅ POC Claude Vision sur étiquettes (`poc-scanner/resultats.html`)
- ✅ Roadmap figée (ce document)
- ⏳ Création compte API Anthropic — prochaine action Eric
- ⏳ Phase 0 — bloquée tant que la clé n'est pas créée

## Liens

- Reco architecture mars 2026 : [`docs/recommandation-numerisation.md`](recommandation-numerisation.md)
- Audit Réceptions actuel : [`receptions-audit.html`](../receptions-audit.html)
- POC Claude Vision : [`poc-scanner/resultats.html`](../poc-scanner/resultats.html)
