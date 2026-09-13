#!/bin/bash
# Commit du fichier de setup des users pre-import Combo
set -e
cd ~/planb-tools

git add pointages/setup_combo_users.sql
git commit -m "setup: 8 nouveaux users + 2 corrections typos pour matching Combo"
git push origin main

echo "---"
echo "Push OK sur main"
