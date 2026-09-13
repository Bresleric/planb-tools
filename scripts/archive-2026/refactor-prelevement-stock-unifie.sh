#!/usr/bin/env bash
# Realigne le sous-module rapprochement Production sur la primitive unifiee
# "Prelevement de stock" (table prelevements, motif polymorphe) et remplace
# l'ancienne migration_rapprochement_lots.sql (obsolete).
#
# Migration migration_prelevement_stock.sql deja appliquee via MCP le 05/06/2026
# (tables prelevements + etiquettes_prelevement, RLS anon FOR ALL, index).

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche active : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

# Code refactore + nouvelle trace de migration ; suppression de l'obsolete.
git add production/index.html sw.js migration_prelevement_stock.sql
git rm --quiet migration_rapprochement_lots.sql

echo "=== Fichiers a committer ==="
git status --short -- production/index.html sw.js migration_prelevement_stock.sql migration_rapprochement_lots.sql
echo

git commit -m "refactor(production): rapprochement aligne sur table unifiee prelevements

Le sous-module Lots et rapprochement stock ecrit desormais dans la table
unifiee prelevements (motif_type=production, motif_ref=production_id) au lieu
de production_rapprochements. Prepare la primitive Prelevement reutilisable
(production, sortie manuelle, repas personnel, mise en place).

- production_rapprochements -> prelevements (quantite_sortie -> quantite,
  ajout motif_type / motif_ref / motif_libelle / prend_tout / article_id).
- Annulation reouverture et suppression etiquette : meme logique ENTREE inverse,
  article_id repris directement depuis la ligne prelevement.
- Onglet Lots : comptage des valides via motif_type=production / motif_ref.
- Bump service worker cache v18 -> v19.
- Ajoute migration_prelevement_stock.sql, supprime migration_rapprochement_lots.sql
  (obsolete, remplace).

Migration appliquee via MCP : tables prelevements + etiquettes_prelevement
(etiquette enfant reconditionnement, non encore utilisee) + rapprochement_apprentissage,
RLS anon FOR ALL + index, idempotente."

git push origin "$BRANCH"
echo
echo "=== Push effectue sur $BRANCH ==="
