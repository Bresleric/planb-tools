#!/usr/bin/env bash
# Fix: onglet Briefing TAF restait bloque sur "Chargement..." + toast "Erreur chargement briefing".
# Cause: le code Cowork appelait .catch() directement sur le builder supabase-js, qui n'est
# pas une vraie Promise (il a .then mais pas .catch) -> TypeError leve avant tout reseau.
# Correctif: try/catch propre + maybeSingle() (0 ligne = pas d'erreur). Degrade proprement
# si la table service_briefings n'existe pas encore (affiche etat vide au lieu de planter).
# bump SW cache v24
set -e
cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

echo "=== Fichiers a committer ==="
git add taf/index.html sw.js scripts/commit-fix-briefing-chargement.sh
git status --short

git commit -m "fix(taf): briefing reste bloque au chargement (.catch sur builder supabase)

- remplace .single().catch() et .limit().catch() par try/catch + maybeSingle()
- le builder supabase-js n'est pas une vraie Promise (pas de .catch)
- degrade proprement si la table service_briefings est absente
- bump SW cache v24

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

git push origin main
echo "Push OK"
