#!/usr/bin/env bash
# Commit + push des changements TAF (fiche technique au démarrage).
# Généré par Cowork le 2026-05-09.
#
# ATTENTION : le repo a déjà été modifié DIRECTEMENT par Cowork
# (pas via la copie iCloud). Ne PAS faire de cp iCloud→repo cette fois,
# ce serait écraser le travail. C'est l'inverse qu'il faudrait faire :
# cp repo→iCloud pour aligner le workspace Cowork. Voir bloc final.

set -euo pipefail
cd ~/planb-tools

echo "=== 1. Vérification branche active ==="
BRANCH=$(git branch --show-current)
echo "Branche : $BRANCH"
if [ "$BRANCH" != "main" ]; then
  echo "⚠ Branche inattendue ($BRANCH) — vérifier avant de continuer."
  read -p "Continuer quand même ? (y/N) " ok
  [ "$ok" = "y" ] || exit 1
fi

echo
echo "=== 2. Nettoyage lock résiduel ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== 3. État avant commit ==="
git status --short

echo
echo "=== 4. Add ==="
git add taf/index.html Mapping_TAF_Fiches.xlsx
git status --short

echo
echo "=== 5. Commit ==="
git commit -m "TAF: fiche technique au démarrage + rappel à la validation

Phase 1 — Modale fiche technique minimisable au clic ▶ Démarrer un TAF de production:
- Si task.is_production && task.fiche_id : openFicheConsultModal() affiche meta
  (rendement, temps prépa/cuisson/repos, DLC, stockage), ingrédients (TOUS,
  pas filtrés par article_id), instructions et notes.
- Bouton ▾ minimise la modale en bandeau persistant (cliquable pour rouvrir).
- Si is_production sans fiche_id : toast 'Fiche à créer pour cette tâche'
  (le chrono démarre quand même).

Phase 2 — Rappel fiche dans la modale de saisie production (à la validation):
- Section <details> repliable 'Rappel fiche technique' affichant temps, DLC,
  stockage et instructions. Aide à vérifier la conformité avant validation.

Outil mapping (séparé):
- Mapping_TAF_Fiches.xlsx : 75 predefined_tasks production sans fiche +
  catalogue 28 fiches existantes pour rattachement manuel.

Schema/BDD inchangé : tous les champs nécessaires (tasks.fiche_id,
predefined_tasks.fiche_id, productions.tache_id) existaient déjà."

echo
echo "=== 6. Push origin $BRANCH ==="
git push origin "$BRANCH"

echo
echo "=== 7. Aligner le workspace Cowork (iCloud) ==="
echo "On copie depuis le repo VERS iCloud (pas l'inverse) pour rattraper l'écart."
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
if [ -d "$ICLOUD_DIR" ]; then
  cp taf/index.html "$ICLOUD_DIR/taf/index.html"
  cp Mapping_TAF_Fiches.xlsx "$ICLOUD_DIR/Mapping_TAF_Fiches.xlsx"
  echo "✓ iCloud aligné."
else
  echo "⚠ Dossier iCloud Cowork introuvable : $ICLOUD_DIR"
  echo "  Aligne manuellement si besoin."
fi

echo
echo "=== Terminé ✓ ==="
