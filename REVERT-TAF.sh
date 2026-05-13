#!/bin/bash
# Revert partiel : restaurer taf/index.html à la version d'avant
# le commit 6f4bf79 (qui avait écrasé des features récentes via cp iCloud).
# Températures et Production restent inchangés (OK).

set -e
cd ~/planb-tools

echo "=== 1. Étendue de ce qui a été perdu côté TAF (premier head -150) ==="
git diff 7974b6c..HEAD -- taf/index.html | head -150 || true
echo
echo "=== 1b. Stats globales du diff TAF ==="
git diff 7974b6c..HEAD --stat -- taf/index.html
echo
echo "=== 2. Restaurer taf/index.html à la version 7974b6c (avant mon commit) ==="
git checkout 7974b6c -- taf/index.html

echo
echo "=== 3. Vérifier l'index ==="
git status --short
echo
git diff --cached --stat -- taf/index.html

echo
echo "=== 4. Commit + push du revert ==="
git commit -m "Revert taf/index.html : restaurer version avant cp iCloud qui ecrasait des features"
git push origin main

echo
echo "✅ Revert fait. Reste à : (1) rapatrier git/taf -> iCloud, (2) re-appliquer le garde-fou switchTab"
