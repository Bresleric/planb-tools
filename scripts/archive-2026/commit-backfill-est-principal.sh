#!/usr/bin/env bash
# Versionne la migration de backfill bulk est_principal=true.
# La migration applique l'UPDATE en BDD une fois exécutée dans Supabase Studio.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add scripts/migrations/2026-05-14_backfill_est_principal_carnes_laitiers.sql
git commit -m "chore: scan-fefo backfill — est_principal=true pour carnés + laitiers

Marque en masse comme 'principaux' (à scanner au démarrage du TAF)
tous les fiche_ingredients qui pointent vers un article du catalogue :
- Catégorie 'Viande & charcuterie' (33 articles)
- Catégorie 'Poisson' (3)
- 'Frais' ou 'Surgelés' avec mot-clé carné : boeuf, veau, agneau, porc,
  canard, poulet, lapin, jambon, lard, knack, cervelas, paleron, onglet,
  rognon, jarret, filet, épaule, escalope, cuisse, saumon, foie gras (23)
- 'Frais' avec mot-clé laitier/œuf : beurre, crème, fromage, emmental,
  munster, mascarpone, tiramisu, lait, yaourt, brie, camembert, ricotta,
  feta, gouda, œuf, jaune (12)

Total ~71 articles → tous les fiche_ingredients qui pointent vers
ces articles passent est_principal=true. Idempotent (UPDATE WHERE
est_principal = false), peut être re-lancé sans dégât.

scripts/migrations/2026-05-14_backfill_est_principal_carnes_laitiers.sql

Pré-requis : la migration de Phase 1 (création de la colonne
est_principal) doit être appliquée d'abord."

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer la migration dans Supabase Studio :"
echo "  SQL Editor → New query → coller le contenu de :"
echo "    ~/planb-tools/scripts/migrations/2026-05-14_backfill_est_principal_carnes_laitiers.sql"
echo "  Run."
echo
echo "  Vérifier avec :"
echo "    SELECT COUNT(*) FROM fiche_ingredients WHERE est_principal = true;"
echo "  (devrait afficher un nombre significatif, vraisemblablement 40-80)"
