#!/usr/bin/env bash
# Versionne le fichier SQL de migration des fiches squelettes.
# La migration elle-même doit être appliquée manuellement par Eric
# via Supabase Studio (SQL Editor) — voir scripts/migrations/README.md.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add scripts/migrations/
git commit -m "chore: SQL migration fiches squelettes pour 62 predefined_tasks

Migration prête à appliquer dans Supabase Studio :
- scripts/migrations/2026-05-09_link_predefined_tasks_to_fiches_squelettes.sql
- scripts/migrations/README.md (workflow)

Effet attendu :
- 61 fiches squelettes créées (nom + categorie + etablissement freddy)
  avec note 'Squelette auto-créé le 2026-05-09 — à enrichir'
- 1 fiche existante 'Rieweleküche' réutilisée (rattachement uniquement)
- 62 predefined_tasks (toutes 'créer fiche' du mapping Excel) reçoivent
  un fiche_id

Migration idempotente : si Eric relance, skip les tâches déjà liées.
Les 13 'ignorer' du mapping ne sont pas touchées (toast 'Fiche à créer'
au démarrage, comportement choisi)."

git push origin "$BRANCH"

echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer la migration dans Supabase Studio :"
echo "  Ouvre Supabase Studio (project dzrherfavgiuygnimtux), SQL Editor."
echo "  Copie-colle le contenu de :"
echo "    ~/planb-tools/scripts/migrations/2026-05-09_link_predefined_tasks_to_fiches_squelettes.sql"
echo "  Clique Run."
