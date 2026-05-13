#!/usr/bin/env bash
# Refonte vue Admin/Tâches prédéfinies en table éditable type base de données.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "feat(taf/admin): table éditable des predefined_tasks

Refonte de la section 'Tâches prédéfinies' dans l'onglet Admin :
ancienne liste plate → vraie table type base de données.

Colonnes affichées :
- Nom (avec badge 🏭 si is_production)
- Catégorie
- Équipe
- Créneau
- Fiche liée (badge code_court + nom, ou ⚠ Fiche manquante en rouge si production sans fiche)
- Type production (chip coloré : Mise en place / Intermédiaire / Produit fini)
- Actions (Modifier ✏️ / Désactiver ✕)

Fonctionnalités :
- Recherche texte (nom, catégorie, équipe, créneau, fiche, code_court)
- Tri sur toutes les colonnes (clic sur l'en-tête, asc/desc)
- Compteur de lignes (filtré + total)
- Modale d'édition complète au clic sur ✏️ : nom, catégorie, équipe,
  créneau, toggle production, type prod, sélecteur fiche avec auto-complete
- Action ✕ existante préservée (deletePredefined fait un soft delete actif=false)

L'ajout passe toujours par showAddPredefinedModal (bouton + Ajouter)
inchangé pour l'instant.

Smoke tests 14/14 ✓, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
