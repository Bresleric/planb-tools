#!/usr/bin/env bash
# UX briefing TAF : formulaire d'edition avec toutes les sections ouvertes d'emblee.
# Avant : il fallait cocher une case par section pour reveler le textarea.
# Apres : tous les textareas sont visibles directement (comme le brief de salle).
# bump SW cache v25
set -e
cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

echo "=== Fichiers a committer ==="
git add taf/index.html sw.js scripts/commit-briefing-form-ouvert.sh
git status --short

git commit -m "feat(taf): briefing formulaire toutes sections ouvertes

- supprime les cases a cocher qui revelaient les textareas
- toutes les sections sont visibles et editables directement
- bump SW cache v25

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

git push origin main
echo "Push OK"
