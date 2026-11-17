#!/bin/bash
set -e
cd ~/planb-tools
BR=$(git branch --show-current)
if [ "$BR" != "main" ]; then echo "STOP : pas sur main"; exit 1; fi
git pull --ff-only
git add docs/cadencier-noel-2026/outils/build_cadencier.py scripts/commit-cadencier-top-ventes.sh
git commit -m "Cadencier Noel 2026 : budget a +3 % (coefficients 1,03) et nouvel onglet Top ventes Solide par etablissement (part cumulee, budget 2026, profil par jour de semaine)" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin "$BR"
