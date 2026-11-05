#!/bin/bash
# Planning : onglet Pointages, recapitulatif hebdomadaire par salarie (05/11/2026)
# Usage : bash ~/planb-tools/scripts/planning-onglet-pointages.sh
set -e
cd "$HOME/planb-tools"
BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"
git add planning/index.html sw.js scripts/planning-onglet-pointages.sh
git status --short | grep -v '^??'
echo ""
echo "Continuer le commit et le push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git commit -F - <<'MSG'
Planning : nouvel onglet Pointages reserve a la gestion - recap hebdomadaire par salarie depuis combo_pointages (prevu, pointe, valide, ecart au prevu et au contrat), detail par jour, services a verifier, impression + bump SW v138

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine."
