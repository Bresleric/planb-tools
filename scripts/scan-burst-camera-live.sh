#!/bin/bash
# ============================================================
# Commit + push — Caméra live « rafale » pour le scan des
# étiquettes matières premières depuis le module TAF.
#
# Les modifications de code sont DÉJÀ appliquées dans le repo
# par Cowork (scanner/index.html + taf/index.html). Ce script
# ne fait que committer et pousser.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add scanner/index.html taf/index.html scripts/scan-burst-camera-live.sh

echo ""
echo "=== Fichiers à committer ==="
git status --short scanner/index.html taf/index.html scripts/scan-burst-camera-live.sh
echo ""

git commit -m "feat(scan): camera live rafale — 1 SHOOT par etiquette MP dans le TAF

Scanner (scanner/index.html) :
- Nouvel ecran burst : apercu video getUserMedia en direct, cadre de
  capture, bouton SHOOT, boucle automatique sur tous les ingredients
  principaux a scanner.
- Extraction Claude Vision en tache de fond pendant le scan suivant.
- Repli sur l'appareil photo natif si getUserMedia indisponible.
- Ecran de validation (produit/lot/DLC) avec bouton Refaire par etiquette.

TAF (taf/index.html) :
- Bouton unique « Scanner les etiquettes (N) » dans la modale fiche.
- Lancement du scanner en mode burst, contexte = liste d'ingredients.
- Traitement du retour groupe : pending + persistance tasks.scans_lots."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
