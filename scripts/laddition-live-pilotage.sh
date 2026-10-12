#!/bin/bash
# Pilotage : vues CA live et Stock alimentees par L Addition Live (12/10/2026)
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add pilotage/index.html sw.js \
        supabase/functions/laddition-live/index.ts \
        scripts/migration-laddition-live.sql \
        scripts/laddition-live-pilotage.sh

git commit -F - <<'MSG'
Pilotage : vues CA live et Stock alimentees par L Addition Live

- Edge function laddition-live : lit live.laddition.com toutes les 30 min
  (pg_cron), etat courant par restaurant, historique des ventes du jour,
  ruptures horodatees
- Pilotage : onglet CA live (chiffres du service, courbe CA/encaisse,
  principaux plats et boissons, menus, serveurs, salles)
- Pilotage : onglet Stock (solides / liquides via le catalogue L Addition,
  ruptures du service, stock bas, Top 20 des ventes avec stock restant)
- Migration : tables laddition_live, laddition_ventes_jour,
  laddition_ruptures + RLS pbt_session + cron laddition-live-30min
- SW v112

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
