#!/bin/bash
# Nouveau module Plan de nettoyage : suivi visuel du PMS (grille taches x jours, taux par zone, impression)
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add pms/index.html index.html admin/index.html sw.js scripts/module-plan-nettoyage.sh
git commit -m "Plan de nettoyage : nouveau module de suivi visuel du PMS (grille semaine et mois, taux par zone, impression) + bump SW v124

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
