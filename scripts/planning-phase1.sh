#!/bin/bash
# =============================================================================
# Module Planning : grille semaine, vue jour, publication, signatures (05/11/2026)
# Usage : bash ~/planb-tools/scripts/planning-phase1.sh
# A lancer APRES avoir execute scripts/migration-planning.sql dans
# Supabase -> SQL Editor.
# =============================================================================
set -e
cd "$HOME/planb-tools"

BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"

git add planning/index.html index.html admin/index.html sw.js \
  scripts/migration-planning.sql scripts/planning-phase1.sh \
  scripts/copier-combo-contrats-import.sh

git status --short | grep -v '^??'
echo ""
echo "Continuer le commit et le push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi

git commit -F - <<'MSG'
Planning : nouveau module pour remplacer le planning Combo au 01/01/2027 - grille semaine par equipe, vue jour, horaires types, absences, copie de semaine PBT ou Combo, alertes HCR, publication versionnee, signature au code personnel, Mon planning, couverts reserves + tables planning avec RLS + alimentation du Briefing et du TAF a partir du 01/01/2027 seulement + bump SW v135

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine."
