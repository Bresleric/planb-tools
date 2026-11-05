#!/bin/bash
# Planning : reflet automatique du planning Combo (05/11/2026)
# Usage : bash ~/planb-tools/scripts/planning-reflet-combo.sh
# A lancer APRES migration-planning-combo.sql et le deploiement de combo-planning.
set -e
cd "$HOME/planb-tools"
BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"
git add planning/index.html sw.js supabase/functions/combo-planning/index.ts \
  scripts/migration-planning-combo.sql scripts/planning-reflet-combo.sh
git status --short | grep -v '^??'
echo ""
echo "Continuer le commit et le push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git commit -F - <<'MSG'
Planning : reflet automatique du planning Combo - fonction combo-planning et table planning_combo, 2 semaines en arriere a 8 semaines en avant sans depasser le 31/12/2026, vue Planning Combo en lecture seule et vue Mon brouillon separee, copie depuis le reflet avec les notes + bump SW v137

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine."
