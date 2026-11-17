#!/bin/bash
# Commit du chantier cadencier marche de Noel 2026
# Par defaut : outils + README seulement (le depot est public, les donnees restent hors git).
# Lancer avec  bash scripts/commit-cadencier-noel-2026.sh tout  pour inclure aussi le tableur et les CSV.
set -e
cd ~/planb-tools
BR=$(git branch --show-current)
echo "Branche active : $BR"
if [ "$BR" != "main" ]; then echo "STOP : pas sur main"; exit 1; fi
git pull --ff-only

if [ "$1" = "tout" ]; then
  git add docs/cadencier-noel-2026
  MSG="Cadencier marche de Noel 2026 : tableur, donnees de reference 2025 (ventes L Addition, lignes de factures) et outils de generation (pdf2lines.swift, parse_factures.py, build_cadencier.py)"
else
  git add docs/cadencier-noel-2026/outils
  MSG="Cadencier marche de Noel 2026 : outils de generation (pdf2lines.swift, parse_factures.py, build_cadencier.py) et README - tableur et donnees conserves hors git"
fi
git add scripts/commit-cadencier-noel-2026.sh
git status --short
git commit -m "$MSG" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin "$BR"
