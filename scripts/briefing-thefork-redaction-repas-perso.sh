#!/bin/bash
# Briefing : bloc TheFork en redaction + bloc Repas perso (16/10/2026)
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add briefing/index.html sw.js \
        scripts/migration-briefing-repas-perso.sql \
        scripts/briefing-thefork-redaction-repas-perso.sh

git commit -F - <<'MSG'
Briefing : bloc TheFork dans la redaction et bloc Repas perso

- Chantier 1 : les reservations TheFork du jour s affichent dans l onglet
  Redaction (lecture seule, non stockees dans le briefing) ; le chapitre
  compte dans le verrou de publication. Corps de la section extrait dans
  theForkBodyHtml pour servir a la consultation et a la redaction
- Chantier 2 : bloc Repas perso (plat, date de production, stock, unite)
  saisi en redaction, affiche en consultation, reporte de briefing en
  briefing et archivable avec motif comme les produits limites
- Migration : colonne briefings.repas_perso jsonb (appliquee)
- sw.js : bump v120

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
