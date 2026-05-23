#!/bin/bash
# ============================================================
# Commit + push — Multi-etiquettes par ingredient dans le
# scanner « rafale » du TAF (demarrage de production) :
#  - bouton « + Autre etiquette » pour scanner plusieurs lots
#    (plusieurs paquets) d'un meme ingredient
#  - tous les lots scannes sont memorises (tracabilite HACCP)
#  - la quantite theorique est repartie sur les lots scannes
#
# Les modifications sont DEJA appliquees dans le repo par
# Cowork (scanner/index.html + taf/index.html). Ce script ne
# fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add scanner/index.html taf/index.html scripts/scan-multi-etiquettes.sh

echo ""
echo "=== Fichiers a committer ==="
git status --short scanner/index.html taf/index.html scripts/scan-multi-etiquettes.sh
echo ""

git commit -m "feat(scan-fefo): plusieurs etiquettes (lots) par ingredient

- Scanner rafale : apres le SHOOT d'un ingredient, bouton
  « + Autre etiquette » pour scanner d'autres paquets du meme
  ingredient (lots differents). Bouton « Termine » pour revenir.
- Les lots supplementaires sont transportes via scan_fefo_result
  et persistes dans tasks.scans_lots (champ lots_supplementaires).
- Modale production : la quantite theorique est repartie a parts
  egales sur tous les lots scannes, chacun ajustable a la main.
  Chaque lot genere sa propre sortie de stock -> tracabilite
  complete sur l'etiquette de production (Phase C).
- Modale fiche TAF : badge « N lots » + detail des lots scannes.
- Le lot principal reste un objet simple : B-2 et le flux
  existant ne sont pas impactes (changement purement additif)."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
