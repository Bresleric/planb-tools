#!/bin/bash
# Bump SW v4 -> v5 pour forcer les iPads PWA a recharger
# le restore production directe (commit c6e1b10).
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
git add sw.js scripts/bump-sw-v5.sh
git commit -m "chore(sw): bump CACHE_NAME v4 -> v5 (restore production directe)"
git push
echo "=== Termine OK ==="
