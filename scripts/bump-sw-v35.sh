#!/bin/bash
# Bump du CACHE_NAME du service worker en v35
# Contexte : commit 0c8f33d "Stock rattachement: show scanner identity (initials)"
# ajoute les badges scanneur dans Stock > Rattachement etiquettes. Sans ce bump,
# les iPads PWA continuent a servir l ancienne version de stock/index.html.
set -e

# Garde-fou : on doit etre sur main
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "main" ]; then
  echo "ERREUR : branche active = $BRANCH (attendu : main). Abandon."
  exit 1
fi

# Remplace integralement la ligne 15 de sw.js
sed -i.bak "15s|.*|const CACHE_NAME = 'planb-tools-v35';   // bump a chaque mise a jour du SW (v35 : stock rattachement badges scanneur 08/06/2026)|" sw.js

# Nettoyage du backup laisse par sed
rm -f sw.js.bak

echo "=== Ligne 15 apres modif ==="
sed -n '15p' sw.js

echo ""
echo "=== git diff sw.js ==="
git diff sw.js

# Commit + push
git add sw.js scripts/bump-sw-v35.sh
git commit -m "Bump SW cache to v35 for stock rattachement scanner badges"
git push origin main
