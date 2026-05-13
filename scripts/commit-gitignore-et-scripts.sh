#!/usr/bin/env bash
# Ajoute le .gitignore et versionne les 5 scripts de commit existants.
# Nettoie le bruit visuel dans `git status`.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== git status avant ==="
git status --short

echo
echo "=== Add .gitignore + scripts ==="
git add .gitignore scripts/commit-*.sh

echo
echo "=== git status après add ==="
git status --short

echo
echo "=== Commit ==="
git commit -m "chore: .gitignore + versionnement des scripts de commit

Ajoute un .gitignore qui filtre :
- Bruit macOS (.DS_Store, ._*, .Spotlight, .Trashes)
- Lock files Office/LibreOffice (.~lock.*#, ~\$*.xlsx, ~\$*.docx)
- Éditeurs (.vscode/, .idea/, *.swp)
- Logs, node_modules/dist/cache, .env*

Garde volontairement scripts/commit-*.sh trackés : historique des
opérations + permet de relancer une commande à l'identique.

Versionne les 5 scripts de commit déjà créés en local :
- commit-taf-fiche.sh — Phase 1+2 fiche technique au démarrage TAF
- commit-fix-predeflist.sh — fallback fetch predefined_tasks
- commit-fix-equipe-autre.sh — Autre = super-rôle voit tout
- commit-edit-tache-production.sh — rattachement production dans modale édition
- commit-bouton-ajouter-tache.sh — masque tab Créer + ligne fin de liste"

git push origin "$BRANCH"

echo
echo "=== git status après push ==="
git status --short

echo
echo "=== Terminé ✓ ==="
echo "Le bruit (.DS_Store, lock files Excel) ne devrait plus apparaître."
