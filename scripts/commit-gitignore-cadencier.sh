#!/bin/bash
set -e
cd ~/planb-tools
BR=$(git branch --show-current)
if [ "$BR" != "main" ]; then echo "STOP : pas sur main"; exit 1; fi
git add .gitignore scripts/commit-gitignore-cadencier.sh
git commit -m "gitignore : exclusion des donnees du cadencier de Noel (CSV et tableur) pour ne pas publier prix fournisseurs et ventes sur le depot public" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin "$BR"
