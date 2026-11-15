#!/bin/bash
# Service worker : fetch sans cache navigateur pour voir chaque nouvelle version tout de suite (SW v139)
set -e
cd ~/planb-tools
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git status --short sw.js scripts/sw-fetch-no-cache.sh
echo "Commit et push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git add sw.js scripts/sw-fetch-no-cache.sh
git commit -m "Service worker : chargement des pages avec cache no-cache pour que les iPads recoivent chaque nouvelle version immediatement au lieu de 10 minutes plus tard (cache GitHub Pages) + bump SW v139

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
echo "Pousse. Publication GitHub Pages en cours (1 a 2 minutes)."
