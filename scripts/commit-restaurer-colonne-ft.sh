#!/usr/bin/env bash
# Restaure la colonne FT (perdue par le commit 562e3f1 qui a écrasé via
# cp iCloud→repo). Inclut directement le onclick correct (sans JSON.stringify).

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "feat(taf): restaure colonne FT (écrasée par cp iCloud précédent)

Le commit 562e3f1 'Session inactivité' a involontairement écrasé deux
améliorations antérieures de taf/index.html :
- la colonne FT (📖) ajoutée par 00213a7
- le fix d'échappement onclick fait par 970856b

C'est l'incident classique d'un cp iCloud→repo qui prend la version
iCloud comme source de vérité alors que main avait des modifs plus
récentes (cf. mémoire 'Diff repo↔iCloud avant cp').

Réapplication complète :
- Grid template : 13 colonnes avec un 40px pour FT entre Tâche (2fr)
  et Note (1fr), en mode normal ET en mode sélection multiple
- Header : span 'FT' inséré entre les colonnes Tâche et Note
- Cellule : si t.fiche_id, bouton 📖 bleu qui appelle
  openFicheConsultModal('\${t.fiche_id}') — sans le 2e paramètre
  qui causait le bug d'échappement HTML
- Si pas de fiche : '—' grisé

Smoke tests 6/6, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné (repo→iCloud)" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
