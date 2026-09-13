#!/bin/bash
# Commit de la mise a jour du contrat INTERFACES.md en v1.1 (migration v4)
set -e
cd ~/planb-tools

git add INTERFACES.md
git commit -m "docs: contrat v1.1 - ajout combo_pointages + combo_user_mapping + vue pointages_unifies (migration v4)"
git push origin main

echo "---"
echo "Push OK sur main"
git log --oneline -1