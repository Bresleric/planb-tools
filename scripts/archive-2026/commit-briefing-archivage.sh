#!/usr/bin/env bash
# Archivage d une info reprise dans le briefing par Manager/Admin :
# case a cocher pendant la redaction -> motif obligatoire -> info retiree,
# journalisee (briefing_archives) et source neutralisee (incident resolu /
# rappel desactive) pour stopper le retour.
set -e
cd ~/planb-tools

git add briefing/index.html sw.js scripts/migration-briefing-archives.sql scripts/commit-briefing-archivage.sh

git commit -m "feat(briefing): archivage info reprise par Manager/Admin avec motif

- case Archiver sur Incidents, Produits limites, Dates courtes, Rappels (creation)
- visible uniquement manager/admin
- motif obligatoire, journalise dans briefing_archives
- neutralise la source pour stopper le retour: incident resolu / rappel desactive
- produits: simple retrait suffit (le prochain briefing recopie celui-ci)
- migration SQL briefing_archives + RLS a executer dans Supabase
- bump SW cache v27

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

git push origin main
echo "Push OK"
