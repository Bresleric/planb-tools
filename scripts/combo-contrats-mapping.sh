#!/bin/bash
# =============================================================================
# Fonction combo-contrats : mapping final des champs Combo (04/11/2026)
# Usage : bash scripts/combo-contrats-mapping.sh   (depuis ~/planb-tools/)
# =============================================================================
set -e
cd "$HOME/planb-tools"
BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"
git add supabase/functions/combo-contrats/index.ts scripts/deploy-combo-contrats.sh scripts/combo-contrats-mapping.sh
git status --short | grep -v '^??' || true
echo ""
echo "Continuer le commit et le push sur $BRANCHE ? Taper o puis Entree"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git commit -F - <<'MSG'
Equipe : fonction combo-contrats alignee sur les vrais champs Combo (contract_time en heures par semaine, seasonal vers CDD, type vide ou heures hors limites mis de cote au lieu d etre devines, mode apercu sans noms)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine."
