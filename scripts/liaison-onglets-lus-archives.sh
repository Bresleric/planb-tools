#!/bin/bash
# Cahier de liaison : 4 onglets Messages / Lus / Archives / Non lus par personne (15/10/2026)
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add liaison/index.html sw.js \
        scripts/migration-liaison-archive-par.sql \
        scripts/liaison-onglets-lus-archives.sh

git commit -F - <<'MSG'
Cahier de liaison : onglets Messages, Lus, Archives et Non lus par personne

- Messages : les fils pas encore lus par la personne connectee (meme regle
  que la pastille du portail) ; les epingles restent en haut ; une nouvelle
  reponse non lue fait revenir le fil
- Lus : les fils entierement lus, 14 jours + epingles exclus ; apres un Lu
  signe par la personne connectee, le fil y passe tout seul
- Archives : chargees a la demande (200 max), mention Archive par X le JJ/MM,
  bouton Desarchiver ; archivage reserve a l admin, la question et ses
  reponses partent ensemble
- Mention Fil de X en haut et verrou d inactivite 3 min identique au portail
  (iPad partage : le fil suit la personne reellement connectee)
- Compteurs sur les onglets, dernier onglet memorise pour la session
- Lectures chargees par pages (plafond de 1000 lignes de la base)
- Migration archive_par_id, archive_par_nom, archive_le (appliquee)
- sw.js : bump v119

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
