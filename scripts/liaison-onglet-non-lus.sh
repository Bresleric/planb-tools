#!/bin/bash
# Cahier de liaison : onglet Non lus par personne (14/10/2026)
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add liaison/index.html sw.js scripts/liaison-onglet-non-lus.sh

git commit -F - <<'MSG'
Cahier de liaison : onglet Non lus par personne (responsable et plus)

- Deux onglets : Messages (le fil, par defaut) et Non lus par personne,
  ce dernier visible seulement pour responsable, manager et admin
- Meme regle que la pastille du portail : 14 jours glissants + epingles,
  pas ses propres messages, messages a toute l equipe, messages adresses,
  reponses dans les fils dont la personne est destinataire ou auteur
- Les messages a toute l equipe publies avant l arrivee de la personne
  ne lui sont pas comptes ; un Lu pose par un non concerne ne compte pas
- Tableau trie par nombre de non lus, anciennete du plus vieux non lu,
  pastille rouge au-dela de 48 h, detail des messages au tap
- sw.js : bump v118

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
