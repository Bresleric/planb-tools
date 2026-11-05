#!/bin/bash
# =============================================================================
# Copie dans le presse-papiers la version PONCTUELLE de combo-contrats (import
# force). A lancer depuis le Terminal d Eric, juste avant de coller dans Supabase.
# Usage : bash ~/planb-tools/scripts/copier-combo-contrats-import.sh
# Apres import : remettre la version normale avec scripts/deploy-combo-contrats.sh
# =============================================================================
set -e
cd "$HOME/planb-tools"
sed 's|^  const mode = new URL.*$|  const mode = "import"; // VERSION PONCTUELLE : import force, a remplacer ensuite par la version du repo|' \
  supabase/functions/combo-contrats/index.ts | pbcopy

if [ "$(pbpaste | grep -c 'VERSION PONCTUELLE')" = "1" ]; then
  echo "==> OK : la version ponctuelle est dans le presse-papiers ($(pbpaste | wc -l | tr -d ' ') lignes)."
  echo "Ne copie plus rien avant de coller dans Supabase."
else
  echo "==> ERREUR : le presse-papiers ne contient pas la version ponctuelle. Previens Claude."
  exit 1
fi
