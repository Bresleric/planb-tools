#!/bin/bash
# =============================================================================
# Module Equipe - Phase 1 : validation des heures + contrats (03/11/2026)
# Usage : bash scripts/equipe-phase1.sh   (depuis ~/planb-tools/)
# A lancer APRES avoir execute scripts/migration-equipe-phase1.sql dans
# Supabase -> SQL Editor.
# =============================================================================
set -e
cd "$HOME/planb-tools"

BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"

git add equipe/index.html index.html admin/index.html sw.js \
  scripts/migration-equipe-phase1.sql scripts/equipe-phase1.sh scripts/deploy-combo-contrats.sh \
  supabase/functions/combo-contrats/index.ts

git status --short
echo ""
echo "Continuer le commit et le push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi

git commit -F - <<'MSG'
Equipe : nouveau module de gestion des heures (phase 1 de la sortie de Combo au 01/01/2027) - onglet Validation des heures (prevu Combo / badge iPad / retenu, alertes oubli de badge, ecarts, plus de 11 h, sans pause, validation en un clic ou groupee, correction avec commentaire obligatoire, recap hebdo vs contrat) + onglet Contrats (type, heures hebdo, dates, matricule Payfit, avenants, modifiable par admin seulement) + table rh_contrats et niveau valide sur pointage_periodes_travail + fonction combo-contrats de reprise des contrats + bump SW v134

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine."
