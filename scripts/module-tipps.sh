#!/bin/bash
# Module Tipps : partage du pot commun des pourboires + champ dans la caisse
# A lancer depuis ~/planb-tools : bash scripts/module-tipps.sh
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

echo ""
echo "IMPORTANT : la migration scripts/migration-tipps.sql doit etre executee"
echo "dans Supabase (SQL Editor) AVANT ce push, sinon la caisse ne pourra plus enregistrer."
echo "Migration executee ? (oui/non)"
read -r REPLY
if [ "$REPLY" != "oui" ]; then
  echo "Arret : executer la migration puis relancer ce script."
  exit 1
fi

git add tipps/index.html caisse/index.html index.html admin/index.html sw.js \
  scripts/migration-tipps.sql scripts/module-tipps.sh

git commit -m "Tipps : nouveau module de partage du pot commun des pourboires (jour par jour au prorata des heures Combo validees, salle 100 / cuisine 75 / plonge 30, minoration hebdo redistribuee a la meme equipe, cloture de semaine) + champ Tipps pot commun dans le controle de caisse + bump SW v132

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

git push origin "$BRANCHE"
echo "Pousse sur $BRANCHE."
