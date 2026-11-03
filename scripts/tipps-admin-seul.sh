#!/bin/bash
# Tipps reserve a l admin (portail, ecran Admin, page du module, base)
# A lancer depuis ~/planb-tools : bash scripts/tipps-admin-seul.sh
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add tipps/index.html index.html admin/index.html sw.js \
  scripts/migration-tipps-admin-seul.sql scripts/tipps-admin-seul.sh

git commit -m "Tipps : module reserve a l admin (masque du portail pour tous les autres roles, non accordable dans Admin, page fermee aux non-admins, tables tipps protegees par une policy admin) + bump SW v133

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"

git push origin "$BRANCHE"
echo "Pousse sur $BRANCHE."
