#!/bin/bash
# Briefing : reservations TheFork visibles dans la redaction + pave Repas du perso
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add briefing/index.html sw.js scripts/briefing-resas-repas-perso.sh
git commit -m "Briefing : reservations TheFork dans la redaction + pave Repas du perso (fab, DLC, quantites en stock)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
