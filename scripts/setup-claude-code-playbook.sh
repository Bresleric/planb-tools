#!/bin/bash
# ============================================================
# Bascule dev vers Claude Code — Etape 1 / 4
# Push du playbook CLAUDE.md (lu auto par Claude Code a chaque
# session) + du mode operatoire pour Eric.
# Ne change RIEN au code applicatif, c'est purement documentaire.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
git add CLAUDE.md MODE-OPERATOIRE-CLAUDE-CODE.md scripts/setup-claude-code-playbook.sh
git status --short
git commit -m "docs: playbook CLAUDE.md + mode operatoire bascule Claude Code

CLAUDE.md condense les regles non-negociables du projet PBT
(git via scripts/, jamais d'apostrophes, naming Liesel, supabase
MCP read-only, bump SW, etc.) pour que Claude Code demarre chaque
session avec le bon contexte au lieu de re-decouvrir les pieges.

MODE-OPERATOIRE est la 1-pager pour Eric : comment lancer/finir
une session Claude Code en toute securite (cd repo, git pull,
claude, validation des commits, git status final)."
git push
echo "=== Termine OK ==="
