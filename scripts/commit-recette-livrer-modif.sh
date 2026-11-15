#!/bin/bash
# Recette Claude Code livrer-modif-pbt : procedure de livraison partagee entre les deux Mac (pas de bump SW, rien de visible dans app)
set -e
cd ~/planb-tools
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git status --short .gitignore .claude/skills/livrer-modif-pbt/SKILL.md scripts/commit-recette-livrer-modif.sh
echo "Commit et push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git add .gitignore .claude/skills/livrer-modif-pbt/SKILL.md scripts/commit-recette-livrer-modif.sh
git commit -m "Claude Code : recette livrer-modif-pbt (branche et pull, test syntaxe JS, bump SW, script de commit sans apostrophe, diff montre avant push, etapes de test iPad) + gitignore laisse passer .claude/skills et .claude/agents

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
echo "Pousse. La recette sera disponible sur le MacBook Air apres un git pull."
