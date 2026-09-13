#!/usr/bin/env bash
# Polish UX scanner + etiquette (test Choucroute Garnie) :
#  1. barre SHOOT fixe en bas du scanner
#  2. cadrage camera cape (fin de l etirement cinemascope en paysage iPad)
#  3. bouton PDF etiquette ne reste plus fige sur "Generation PDF..." au retour
#  4. safe-area iOS + liste scrollable
# Usage : bash scripts/polish-scanner-etiquette.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add scanner/index.html production/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "fix(ux): scanner barre SHOOT fixe + cadrage paysage + reset bouton PDF

Suite au test Choucroute Garnie (Eric) :
- Scanner : bouton SHOOT dans une barre position fixed en bas, toujours
  accessible sans scroller, avec env(safe-area-inset-bottom) pour ne pas
  passer sous la barre Safari ; bouton Liste a cote
- Scanner : .burst-cam-wrap cape a max-width 480px centre -> fin de
  l etirement cinemascope en paysage iPad (capture WYSIWYG preservee,
  pas de object-fit cover qui desynchroniserait le cadre et la photo)
- Etiquette : le bouton Generation PDF restait fige/desactive au retour
  du PDF (jamais reinitialise apres succes). Reset via pageshow sur les
  ecrans mono et multi -> bouton reutilisable, plus inutile
- Bump service worker CACHE_NAME v13 -> v14"

git push origin main

echo "=== Termine ==="
