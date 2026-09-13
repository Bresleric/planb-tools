#!/usr/bin/env bash
# Phase 2 du projet Scan-FEFO : ajoute une checkbox 🎯 "Principal" sur
# chaque ligne ingrédient dans l'éditeur de fiche du module Production.
# Permet à l'admin de marquer quels ingrédients doivent être scannés au
# démarrage du TAF correspondant.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des 4 patchs ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('production/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# 1. CSS — style de la checkbox principal
# ============================================================
css_block = """    .ingredient-row .ing-principal-wrap {
      display: inline-flex; align-items: center; gap: 2px;
      cursor: pointer; padding: 4px 6px; border-radius: 6px;
      border: 1px solid #d1d5db; background: white;
      transition: background .15s;
    }
    .ingredient-row .ing-principal-wrap:has(input:checked) {
      background: #fef3c7; border-color: #f59e0b;
    }
    .ingredient-row .ing-principal { margin: 0; cursor: pointer; }
    .ingredient-row .ing-principal-icon {
      font-size: 0.95rem; opacity: .35; user-select: none;
    }
    .ingredient-row .ing-principal-wrap:has(input:checked) .ing-principal-icon {
      opacity: 1;
    }
"""
marker_css = "    .ingredient-row.no-article { background: #fff5e6; border-left: 3px solid #f59e0b; padding-left: 8px; }"
if marker_css in content and '.ing-principal-wrap' not in content:
    content = content.replace(marker_css, css_block + marker_css)
    print("✓ CSS .ing-principal-wrap ajouté")
    changes += 1
elif '.ing-principal-wrap' in content:
    print("• CSS .ing-principal-wrap : déjà présent")
else:
    print("⚠ CSS : marker .ingredient-row.no-article non trouvé")

# ============================================================
# 2. HTML — ajouter checkbox dans addIngredientRow
# ============================================================
old_html = '    <button type="button" class="btn-link-art" onclick="openArticlePicker(${id})" title="${linkBtnTitle}">${linkBtnLabel}</button>\n    <button class="btn-remove-ing" onclick="removeIngredientRow(${id})">×</button>'
new_html = '''    <button type="button" class="btn-link-art" onclick="openArticlePicker(${id})" title="${linkBtnTitle}">${linkBtnLabel}</button>
    <label class="ing-principal-wrap" title="🎯 Marquer comme ingrédient PRINCIPAL — à scanner obligatoirement au démarrage de la tâche (Scan-FEFO)">
      <input type="checkbox" class="ing-principal" ${data.est_principal ? 'checked' : ''}>
      <span class="ing-principal-icon">🎯</span>
    </label>
    <button class="btn-remove-ing" onclick="removeIngredientRow(${id})">×</button>'''

if old_html in content and 'class="ing-principal"' not in content:
    content = content.replace(old_html, new_html)
    print("✓ HTML : checkbox 🎯 ajoutée dans addIngredientRow")
    changes += 1
elif 'class="ing-principal"' in content:
    print("• HTML checkbox : déjà présente")
else:
    print("⚠ HTML : pattern btn-link-art + btn-remove-ing non trouvé")

# ============================================================
# 3. JS collecte — lire est_principal au moment du save
# ============================================================
old_collect = "    ingredients.push({ nom: ingNom, quantite: qty, unite, prix_unitaire: prix, article_id: articleId });"
new_collect = "    const estPrincipal = row.querySelector('.ing-principal')?.checked || false;\n    ingredients.push({ nom: ingNom, quantite: qty, unite, prix_unitaire: prix, article_id: articleId, est_principal: estPrincipal });"

if old_collect in content and 'est_principal: estPrincipal' not in content:
    content = content.replace(old_collect, new_collect)
    print("✓ JS collecte : est_principal lu et ajouté à ingredients.push")
    changes += 1
elif 'est_principal: estPrincipal' in content:
    print("• JS collecte : déjà à jour")
else:
    print("⚠ JS collecte : ingredients.push pattern non trouvé")

# ============================================================
# 4. DB.saveIngredients — persister est_principal
# ============================================================
old_save = """      const rows = ingredients.map((ing, i) => ({
        fiche_id: ficheId,
        nom: ing.nom,
        quantite: ing.quantite,
        unite: ing.unite,
        prix_unitaire: ing.prix_unitaire,
        cout_ligne: (ing.quantite || 0) * (ing.prix_unitaire || 0),
        ordre: i,
        article_id: ing.article_id || null,
      }));"""
new_save = """      const rows = ingredients.map((ing, i) => ({
        fiche_id: ficheId,
        nom: ing.nom,
        quantite: ing.quantite,
        unite: ing.unite,
        prix_unitaire: ing.prix_unitaire,
        cout_ligne: (ing.quantite || 0) * (ing.prix_unitaire || 0),
        ordre: i,
        article_id: ing.article_id || null,
        est_principal: !!ing.est_principal,
      }));"""

if old_save in content and 'est_principal: !!ing.est_principal' not in content:
    content = content.replace(old_save, new_save)
    print("✓ DB.saveIngredients : est_principal persisté en BDD")
    changes += 1
elif 'est_principal: !!ing.est_principal' in content:
    print("• DB.saveIngredients : déjà à jour")
else:
    print("⚠ DB.saveIngredients : mapping rows non trouvé")

if changes > 0:
    p.write_text(content, encoding='utf-8')
    print(f"\n✅ {changes} modifs écrites sur disque.")
else:
    print("\nAucun changement appliqué.")
PYEOF

echo
echo "=== git status ==="
git status --short

if git diff --quiet -- production/index.html; then
  echo
  echo "Rien à commiter — fichier déjà à jour."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add production/index.html
git commit -m "feat(production): scan-fefo phase 2 — checkbox 🎯 Principal sur ingrédients

UI Admin pour marquer les ingrédients à scanner au démarrage d'une
tâche TAF (workflow Scan-FEFO).

Module Production — éditeur de fiche technique :
- Chaque ligne ingrédient gagne une checkbox 🎯 (à droite, avant ✕)
- L'icône 🎯 reste grisée quand non cochée, jaune doré quand cochée
- Tooltip : 'Marquer comme ingrédient PRINCIPAL — à scanner obligatoirement
  au démarrage de la tâche'

4 patchs Python idempotents :
- CSS : .ing-principal-wrap (visuel)
- HTML : <label><input> ajouté entre btn-link-art et btn-remove-ing
- JS collecte (saveFiche) : lit la checkbox, push dans ingredients
- DB.saveIngredients : ajoute est_principal au mapping rows

Pré-requis : migration Phase 1 (fiche_ingredients.est_principal) doit
être appliquée dans Supabase avant que les saves ne fonctionnent."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/production" ] && cp production/index.html "$ICLOUD_DIR/production/index.html" && echo "✓ iCloud aligné (repo→iCloud)" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
