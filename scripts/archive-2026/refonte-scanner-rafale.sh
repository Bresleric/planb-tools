#!/usr/bin/env bash
# Refonte UX scanner rafale : liste cliquable non-bloquante + tri sous-produits.
# Deux commits (a: scanner+sw, b: flags appelants) puis un seul push.
# Usage : bash scripts/refonte-scanner-rafale.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

# --- Commit (a) : refonte UI scanner + async ---
git add scanner/index.html sw.js
git commit -m "feat(scanner): refonte rafale en liste cliquable non-bloquante

Le scanner rafale n imposait plus l ordre et bloquait l UI entre chaque shoot
pendant l analyse Claude Vision. Bascule sur un modele a liste cliquable.

- Liste verticale de toutes les MP avec badge de statut live
  (a scanner / analyse en cours / scanne N lots / a refaire)
- Clic sur une ligne arme la camera pour cette MP, retour immediat a la liste
- Analyses lancees en parallele en tache de fond, badge mis a jour live
- Re-clic sur une ligne verte ajoute un lot supplementaire
- Tri : les MP sources d un sous-produit remontent en haut (badge bleu)
- Bouton Terminer debloque des que les principaux ont une analyse non-rouge,
  avec attente si des principaux sont encore en analyse
- Format scan_fefo_result inchange (consommateurs TAF/production intacts)
- Bump service worker CACHE_NAME v7 -> v8"

# --- Commit (b) : flags sources sous-produits dans les appelants ---
git add taf/index.html production/index.html
git commit -m "feat(scan-fefo): propage est_principal et is_source_sous_produit au scanner

Les appelants du scanner construisent scan_fefo_context. Ils envoient desormais
TOUTE la liste des MP de la fiche (plus seulement les principaux) et marquent
chaque ingredient :

- est_principal : sert au gating du bouton Terminer cote scanner
- is_source_sous_produit : calcule via une requete fiches_techniques_sous_produits
  (set des source_article_id de la fiche), sert au tri et au badge bleu

Touche taf/index.html (launchBurstScanner async + scanAllPrincipaux envoie tout)
et production/index.html (pdLaunchScanner async). Degradation gracieuse si la
requete echoue : le scan fonctionne sans tri."

git push origin main

echo "=== Termine ==="
