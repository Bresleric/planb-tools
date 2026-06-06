#!/usr/bin/env bash
# Briefing Cuisine : nouvel onglet Briefing dans le module TAF.
# - Onglet Briefing (apres Taches) detecte le service courant par heure (soir / apres-midi)
# - 7 sections collaboratives, photo equipements en base64, finalisation pour equipe suivante
# - Table Supabase service_briefings (migration scripts/migration-service-briefings.sql, RLS + policy anon)
# - Helper escapeHtml ajoute (absent du fichier avant)
# - bump SW cache v22
set -e
cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

echo "=== Fichiers a committer ==="
git add taf/index.html sw.js scripts/migration-service-briefings.sql scripts/commit-briefing-cuisine.sh
git status --short

git commit -m "feat(taf): onglet Briefing cuisine + table service_briefings

- nouvel onglet Briefing dans le TAF apres Taches
- detection auto du service par heure (soir / apres-midi)
- 7 sections collaboratives, photo equipements base64, finalisation
- table service_briefings avec RLS + policy anon (migration SQL)
- helper escapeHtml ajoute
- bump SW cache v22

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

git push origin main
echo "Push OK"
