#!/bin/bash
# Commit : Mode developpement admin - pas de deconnexion auto par inactivite.
# A la connexion, un compte admin choisit "Mode developpement" (pas de verrou) ou
# "Utilisation normale" (verrou apres inactivite). Drapeau sessionStorage.planb_dev_nolock.
# NB : briefing/index.html est volontairement EXCLU (travail "archivage" en cours non commite).
set -e
cd "$(dirname "$0")/.."

echo "Branche active :"
git branch --show-current

# Ajout explicite des seuls fichiers de cette feature
git add index.html
git add sw.js
git add scripts/patch-dev-mode-no-lock.js
git add admin/index.html
git add approvisionnement/index.html
git add caisse/index.html
git add cartons-jvr/index.html
git add checklist/index.html
git add dashboard/index.html
git add numerisations/index.html
git add objectifs/index.html
git add planb-tools-update/index.html
git add production/index.html
git add receptions/elis.html
git add taf/index.html
git add temperatures/index.html
git add ventes/index.html

echo
echo "=== Fichiers stages pour ce commit ==="
git status --short

git commit -m "feat(auth): mode developpement admin - desactive la deconnexion auto par inactivite

A la connexion dun compte admin, choix Mode developpement (pas de verrou) ou
Utilisation normale (verrou apres inactivite). Drapeau sessionStorage planb_dev_nolock,
efface a la deconnexion. Garde-fou ajoute dans les 14 modules avec inactivite. Bump SW v29.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

git push origin "$(git branch --show-current)"

echo
echo "Pousse. Pense a vider/recharger le cache PWA sur iPad (SW v29)."
