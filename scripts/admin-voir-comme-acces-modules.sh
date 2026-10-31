#!/bin/bash
# Admin : le mode voir comme respecte la liste des modules autorises de la personne
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add admin/index.html sw.js scripts/migration-voir-comme-acces-modules.sql scripts/admin-voir-comme-acces-modules.sh
git commit -m "Admin : le mode voir comme reprend les modules autorises de la personne (avant il montrait les modules par defaut du role) + bump SW v129

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
