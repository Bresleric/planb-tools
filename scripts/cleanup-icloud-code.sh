#!/bin/bash
# ============================================================
# Nettoyage iCloud — supprime les artefacts code dormants pour
# que ~/planb-tools/ devienne la SEULE source de verite du code.
#
# Strategie :
#  - Les 6 dossiers a 0 octet (PlanB_*_Update, PlanbCompta-db,
#    PlanB_QuickFix_Exit_Tasks_Equipment) : suppression directe,
#    rien a sauvegarder.
#  - Les 4 depots git inactifs (Kuizine, Fiches techniques,
#    Kouizine, KitchenTAF) + PlanBistro.swiftpm : ARCHIVE
#    (tar.gz dans ~/iCloud-Archive-PBT-2026-05-31/) puis
#    suppression. Tu peux toujours recuperer si besoin.
#  - Le reste (BAL_PlanB, Goodnotes, Pages, Numbers,
#    Cowork-Artifacts, ...) n'est PAS touche.
#
# Demande confirmation 'oui' avant toute action destructive.
# ============================================================
set -e

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
PLAYGROUNDS="$HOME/Library/Mobile Documents/iCloud~com~apple~Playgrounds/Documents"
ARCHIVE="$HOME/iCloud-Archive-PBT-2026-05-31"

EMPTY_FOLDERS=(
  "PlanB_Dashboard_Update"
  "PlanB_Features_Update"
  "PlanB_ModulesWithSubmenus"
  "PlanbCompta-db"
  "Downloads/PlanB_LoginAndMenu_Update"
  "PlanB_QuickFix_Exit_Tasks_Equipment"
)

DEAD_REPOS=(
  "Kuizine"
  "Fiches techniques"
  "Kouizine"
  "KitchenTAF"
)

echo ""
echo "=========================================================="
echo "  NETTOYAGE iCloud — Plan d'action"
echo "=========================================================="
echo ""
echo "GARDE intact :"
echo "  - BAL_PlanB/ (factures, relances, DSN)"
echo "  - Goodnotes, Pages, Numbers, Cowork-Artifacts"
echo ""
echo "SUPPRIME directement (dossiers 0 octet, vides) :"
for f in "${EMPTY_FOLDERS[@]}"; do
  if [ -e "$ICLOUD/$f" ]; then
    echo "  - $f"
  fi
done
echo ""
echo "ARCHIVE (tar.gz dans $ARCHIVE) puis SUPPRIME :"
for f in "${DEAD_REPOS[@]}"; do
  if [ -e "$ICLOUD/$f" ]; then
    echo "  - $f  (depot git inactif)"
  fi
done
if [ -e "$PLAYGROUNDS/PlanBistro.swiftpm" ]; then
  echo "  - PlanBistro.swiftpm  (Swift Playground inactif)"
fi
echo ""
echo "=========================================================="
echo ""
echo "Confirmer en tapant : oui"
echo "(toute autre reponse = annulation, rien n'est touche)"
echo -n "> "
read -r REPLY

if [ "$REPLY" != "oui" ]; then
  echo ""
  echo "Annule. Aucun fichier touche."
  exit 0
fi

echo ""
echo "=== ARCHIVAGE en cours... ==="
mkdir -p "$ARCHIVE"

for f in "${DEAD_REPOS[@]}"; do
  if [ -d "$ICLOUD/$f" ]; then
    safe="${f// /_}"
    echo "  tar $f -> $ARCHIVE/${safe}.tar.gz"
    (cd "$ICLOUD" && tar -czf "$ARCHIVE/${safe}.tar.gz" "$f")
  fi
done

if [ -d "$PLAYGROUNDS/PlanBistro.swiftpm" ]; then
  echo "  tar PlanBistro.swiftpm"
  (cd "$PLAYGROUNDS" && tar -czf "$ARCHIVE/PlanBistro.swiftpm.tar.gz" "PlanBistro.swiftpm")
fi

echo ""
echo "=== SUPPRESSION en cours... ==="

for f in "${EMPTY_FOLDERS[@]}"; do
  if [ -e "$ICLOUD/$f" ]; then
    echo "  rm $f"
    rm -rf "$ICLOUD/$f"
  fi
done

for f in "${DEAD_REPOS[@]}"; do
  if [ -e "$ICLOUD/$f" ]; then
    echo "  rm $f"
    rm -rf "$ICLOUD/$f"
  fi
done

if [ -e "$PLAYGROUNDS/PlanBistro.swiftpm" ]; then
  echo "  rm PlanBistro.swiftpm"
  rm -rf "$PLAYGROUNDS/PlanBistro.swiftpm"
fi

echo ""
echo "=========================================================="
echo "  TERMINE"
echo "=========================================================="
echo ""
echo "Archive de securite : $ARCHIVE"
ls -lh "$ARCHIVE" 2>/dev/null
echo ""
echo "Pour recuperer un projet si besoin :"
echo "  tar -xzf $ARCHIVE/<nom>.tar.gz"
echo ""
echo "Si dans 1 mois tout fonctionne sans regret, tu peux"
echo "supprimer aussi l'archive :"
echo "  rm -rf $ARCHIVE"
echo ""
