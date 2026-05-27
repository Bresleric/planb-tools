#!/bin/bash
# ============================================================
# Bouton "✏️ Modifier la fiche" depuis le TAF
# Cote TAF : dans le header de la modale fiche, un bouton ✏️
# visible aux admins ouvre la production module en mode edition
# de la fiche courante (?edit_fiche=<id>).
# Cote production : loadFiches detecte ?edit_fiche=, nettoie
# l'URL et enchaine sur editFiche(id) apres le chargement.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
echo ""

git add taf/index.html production/index.html scripts/btn-modifier-fiche-depuis-taf.sh

echo "=== Fichiers a committer ==="
git status --short taf/index.html production/index.html scripts/btn-modifier-fiche-depuis-taf.sh
echo ""

git commit -m "feat(taf+production): bouton modifier fiche depuis TAF

- TAF : bouton ✏️ dans le header de la modale fiche, visible aux
  admins uniquement. Au clic, redirige vers
  ../production/?edit_fiche=<fiche_id>.
- Production : loadFiches detecte le parametre edit_fiche, nettoie
  l'URL et enchaine sur editFiche(id) apres chargement de la liste.

Permet aux admins de cocher rapidement les ingredients principaux
🎯 sans naviguer via Production -> Fiches -> chercher -> editer."

echo ""
echo "=== Push ==="
git push

echo "=== Termine OK ==="
