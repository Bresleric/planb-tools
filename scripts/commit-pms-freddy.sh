#!/bin/bash
# Commit du fichier SQL d import du PMS Freddy (44 recurrences de nettoyage, deja inserees en base le 30/10/2026)
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add scripts/migration-pms-freddy.sql scripts/commit-pms-freddy.sh
git commit -m "PMS Freddy : import des 44 taches de nettoyage du plan de maitrise sanitaire en recurrences TAF

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
