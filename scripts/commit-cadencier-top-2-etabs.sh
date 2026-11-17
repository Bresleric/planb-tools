#!/bin/bash
set -e
cd ~/planb-tools
BR=$(git branch --show-current)
if [ "$BR" != "main" ]; then echo "STOP : pas sur main"; exit 1; fi
git pull --ff-only
git add docs/cadencier-noel-2026/outils/build_cadencier.py scripts/commit-cadencier-top-2-etabs.sh
git commit -m "Cadencier Noel 2026 : bloc Top ventes Solide des 2 etablissements reunis, libelles de plats apparies entre les deux caisses" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin "$BR"
