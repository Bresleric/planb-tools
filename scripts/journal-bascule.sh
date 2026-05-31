#!/usr/bin/env bash
set -euo pipefail

# Commit + push du journal de bascule Cowork -> Claude Code
# Fichiers concernes : MODE-OPERATOIRE-CLAUDE-CODE.md + ce script lui-meme

cd ~/planb-tools

git add MODE-OPERATOIRE-CLAUDE-CODE.md scripts/journal-bascule.sh

git commit -m "docs: journal des sessions - bascule officielle Cowork vers Claude Code (31/05/2026)"

git push origin main

echo "OK - journal de bascule commite et pousse."
