#!/bin/bash
# Commits des 3 livrables Combo : migration v4 + script Python + README
set -e
cd ~/planb-tools

# Commit 1 : migration SQL (avec bloc RLS ajoute par Claude Code)
git add pointages/migration_v4_combo_pointages.sql
git commit -m "feat(combo): migration v4 - tables combo_pointages + combo_user_mapping + vue pointages_unifies + RLS"

# Commit 2 : script Python + README
git add pointages/scripts/combo_import.py pointages/scripts/README.md
git commit -m "feat(combo): script Python import et README"

git push origin main

echo "---"
echo "2 commits pousses sur main"
git log --oneline -3