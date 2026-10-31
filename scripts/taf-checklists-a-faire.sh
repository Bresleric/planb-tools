#!/bin/bash
# TAF : bandeau des check-lists a faire avec lien direct (31/10/2026)
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add taf/index.html checklist/index.html sw.js scripts/taf-checklists-a-faire.sh

git commit -F - <<'MSG'
TAF : bandeau des check-lists a faire avec lien direct vers chaque check-list

- TAF : en tete de la liste (date du jour), les check-lists du service en
  cours pas encore terminees, avec leur avancement ; un tap ouvre la
  check-list, un lien ouvre toutes les check-lists. Meme regle que l onglet
  Validation du module Check-lists (equipe, service, jour, periode)
- Check-lists : lien direct ?id=...&service=...&return=taf, la check-list est
  mise en evidence et depliee ; le bouton retour ramene a TAF
- sw.js : bump v130

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
