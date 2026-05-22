#!/bin/bash
# ============================================================
# Commit + push — Phase B-2 : blocage strict de la validation
# d'une production tant que les etiquettes des ingredients
# principaux ne sont pas toutes scannees.
#
# Les modifications de code sont DEJA appliquees dans le repo
# par Cowork (taf/index.html). Ce script ne fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add taf/index.html scripts/scan-fefo-phase-b2.sh

echo ""
echo "=== Fichiers a committer ==="
git status --short taf/index.html scripts/scan-fefo-phase-b2.sh
echo ""

git commit -m "feat(scan-fefo phase B-2): blocage validation production sans scan

- Nouveau controle principauxNonScannesForTask() : relit tasks.scans_lots
  en base et liste les ingredients principaux non scannes.
- toggleTask : une tache de production ne peut plus etre validee si une
  etiquette principale manque -> toast + reouverture de la fiche en mode
  scan. C'est le trou par lequel la production d'EL etait passee le 18/05.
- Retour du scanner rafale : si on bloquait une validation et que tout
  est desormais scanne, ouverture directe de la modale de production.
- saveProductionFromTaf : garde-fou ceinture+bretelles avant enregistrement."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
