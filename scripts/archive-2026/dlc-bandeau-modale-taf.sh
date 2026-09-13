#!/usr/bin/env bash
# Finition : bandeau vert "DLC calculee" a l ouverture de la modale production TAF,
# calque sur le pattern production directe. Champ manuel reste vide (override seulement).
# Usage : bash scripts/dlc-bandeau-modale-taf.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add taf/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "feat(taf): bandeau DLC calculee dans la modale production

Le champ DLC manuelle restait vide a l ouverture meme quand la fiche
definit une DLC, laissant croire que la DLC serait vide. Ajout d un bandeau
vert informatif calque sur la production directe.

- updateDlcAutoDisplayTaf : affiche DLC calculee depuis fiche (dlc_jours/heures)
  ou defaut +3 jours, au-dessus du champ manuel
- Appele a l ouverture de la modale, au choix de fiche et en mode Nouveau produit
- Le champ datetime-local reste vide : il ne sert qu a forcer une autre date
- Bandeau cache au reset de la modale
- Bump service worker CACHE_NAME v11 -> v12"

git push origin main

echo "=== Termine ==="
