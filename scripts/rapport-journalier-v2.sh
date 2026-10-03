#!/bin/bash
# ============================================================
# Rapport journalier v2 (demande Eric du 04/10/2026)
# - rapport : TAF du jour et du lendemain, productions, CA attendu,
#   progression du mois, temperatures (qui/quand), ecart de caisse,
#   besoins appro, cartons, receptions, lecture notes/informations
# - formules de caisse sorties dans js/caisse-calc.js (source unique
#   partagee entre le module Caisse et le rapport)
# - SW v60
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
git add rapport/index.html caisse/index.html js/caisse-calc.js sw.js docs/REPRISE-RAPPORT-JOURNALIER.md scripts/rapport-journalier-v2.sh
git status --short
git commit -m "Rapport journalier v2 : TAF, productions, CA attendu, mois, temperatures, ecart de caisse, appro, cartons, receptions, lectures

Formules du controle de caisse sorties dans js/caisse-calc.js, utilisees
par le module Caisse et par le rapport (une seule source de verite).
SW v60. Brief de reprise mis a jour."
git push
echo "=== Termine OK ==="
