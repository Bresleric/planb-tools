#!/bin/bash
# Déploie les modifs de droits d'accès aux onglets :
# - TAF / Températures : garde-fou switchTab (Admin déjà masqué via isAdmin)
# - Production : Fiches et Rattachement masqués aux non-admins
# Puis rapatrie la version git d'Approvisionnement vers iCloud
# (iCloud est obsolète, manque l'onglet Ingrédients).

set -e
cd ~/planb-tools

ICLOUD="/Users/eric/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"

echo "=== diff TAF (iCloud vs repo) ==="
diff "$ICLOUD/taf/index.html" taf/index.html | head -60 || true
echo
echo "=== diff Températures (iCloud vs repo) ==="
diff "$ICLOUD/temperatures/index.html" temperatures/index.html | head -60 || true
echo
echo "=== diff Production (iCloud vs repo) ==="
diff "$ICLOUD/production/index.html" production/index.html | head -60 || true
echo

echo "=== cp iCloud -> repo ==="
cp "$ICLOUD/taf/index.html" taf/index.html
cp "$ICLOUD/temperatures/index.html" temperatures/index.html
cp "$ICLOUD/production/index.html" production/index.html

echo "=== git status ==="
git status --short

echo "=== commit + push ==="
git add taf/index.html temperatures/index.html production/index.html
git commit -m "Restreindre droits onglets : Admin (TAF, Temperatures), Fiches + Rattachement (Production), aux admins uniquement"
git push origin main

echo
echo "=== Rapatriement git -> iCloud pour Approvisionnement ==="
cp approvisionnement/index.html "$ICLOUD/planb-tools-update/approvisionnement/index.html"
ls -la "$ICLOUD/planb-tools-update/approvisionnement/index.html"

echo
echo "✅ Terminé. Relance Cowork pour le batch Approvisionnement."
