#!/bin/bash
# Planning : reprise du planning Combo sur la semaine affichee (05/11/2026)
# Usage : bash ~/planb-tools/scripts/planning-reprise-combo.sh
set -e
cd "$HOME/planb-tools"
BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"
git add planning/index.html sw.js scripts/planning-reprise-combo.sh
git status --short | grep -v '^??'
echo ""
echo "Continuer le commit et le push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git commit -F - <<'MSG'
Planning : reprise de Combo possible sur la semaine affichee, pour comparer aux vraies dates + bump SW v136

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine."
