#!/usr/bin/env bash
# Fix : DLC vide sur l etiquette quand une production est validee depuis le TAF
# sans fiche liee. Aligne taf/index.html sur la production directe.
# Usage : bash scripts/fix-dlc-vide-etiquette-taf.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add taf/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "fix(taf): DLC jamais vide sur etiquette production

Depuis le TAF, une production sans fiche liee laissait dlc a NULL et
l etiquette affichait une DLC vide. Aligne sur la production directe.

- saveProductionFromTaf : priorite saisie manuelle > fiche (dlc_jours/heures)
  > defaut +3 jours. dlc n est plus jamais null (corrige aussi le code lot MMJJ)
- Ajout d un champ DLC manuelle dans la modale TAF de validation production
  (datetime-local), reset a l ouverture de la modale
- Bump service worker CACHE_NAME v10 -> v11"

git push origin main

echo "=== Termine ==="
