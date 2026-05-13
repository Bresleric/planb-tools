#!/usr/bin/env bash
# Versionne la migration v2 (fusion doublons + predefs orphelines).
# Application manuelle dans Supabase Studio (read-only depuis Cowork).

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add scripts/migrations/2026-05-09_v2_fusion_doublons_et_predefs_orphelines.sql
git commit -m "chore: migration v2 — fusion doublons + predefs orphelines

scripts/migrations/2026-05-09_v2_fusion_doublons_et_predefs_orphelines.sql

Effets attendus après application manuelle :
- 4 squelettes désactivés (doublons : Crème brûlée, Kässkuche,
  Tarte à l'oignon avec apostrophe droite, Fond de tarte). Les 4
  predefined_tasks correspondantes redirigées vers les fiches riches
  existantes (CRÈM, KASS, TART, FOTA).
- 2 predefined_tasks réparées (Galette de PDT → Galettes de Pommes de
  terre existante ; Tailler onglet → squelette créé maintenant).
- 19 nouvelles predefined_tasks créées pour les fiches orphelines
  (Babas au Rhum, Beurre Clarifié/d'escargot, Carottes - Tronçon,
  Cordons Bleus Finis/S/V Crus/S/V Cuits, Fonds Moule à Manqué,
  Garnitures Cordons bleus, Génoise chocolat/pour bûche, Onglet Parer
  et Portionner, Parfait Glacé Fleur de bière, Pâte à tarte, Sauce
  Bouchée/Munster/poisson, Saumon confit, Vinaigrette).

Idempotent : INSERT avec WHERE NOT EXISTS, UPDATE avec contraintes
sur l'état initial (fiche_id IS NULL, actif = true)."

git push origin "$BRANCH"

echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer dans Supabase Studio :"
echo "  Ouvre Supabase Studio (project dzrherfavgiuygnimtux), SQL Editor."
echo "  Copie-colle :"
echo "    ~/planb-tools/scripts/migrations/2026-05-09_v2_fusion_doublons_et_predefs_orphelines.sql"
echo "  Clique Run. Vérifie le résultat avec les requêtes de validation"
echo "  en fin de fichier."
