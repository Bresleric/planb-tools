#!/usr/bin/env bash
# Fix : les apostrophes dans les noms d'ingrédients (ex: "Tarte à l'oignon")
# cassaient le parsing JS des onclick. Solution : ne passer que l'ID,
# les fonctions récupèrent le reste depuis window.__currentFicheIngs.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des patchs ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# 1. Stocker les ings en mémoire au début de renderFiche
# ============================================================
old_render_start = """  function renderFiche(fiche, ings, taskName, opts = {}) {
    const title = `📖 ${esc(fiche.nom)}`;
    document.getElementById('fiche-title').textContent = title;"""

new_render_start = """  function renderFiche(fiche, ings, taskName, opts = {}) {
    // Stocker pour que openScannerForIngredient/rescanIngredient retrouvent les infos
    window.__currentFicheIngs = ings;
    window.__currentFiche = fiche;
    const title = `📖 ${esc(fiche.nom)}`;
    document.getElementById('fiche-title').textContent = title;"""

if old_render_start in content:
    content = content.replace(old_render_start, new_render_start)
    print("✓ renderFiche : window.__currentFicheIngs stocké")
    changes += 1
elif "window.__currentFicheIngs = ings" in content:
    print("• renderFiche : déjà stocké")
else:
    print("⚠ renderFiche : pattern début non trouvé")

# ============================================================
# 2. Simplifier les onclick : ne passer que l'ID
# ============================================================
# Bouton rescan
old_rescan_btn = """<button onclick="rescanIngredient('${i.id}', ${i.article_id ? `'${i.article_id}'` : 'null'}, '${esc(i.nom).replace(/'/g, '\\\\\\'')}')" style="font-size:0.72rem; padding:5px 9px; background:white; border:1px solid #86efac; border-radius:4px; color:#15803d; cursor:pointer;">↻</button>"""
new_rescan_btn = """<button onclick="rescanIngredient('${i.id}')" style="font-size:0.72rem; padding:5px 9px; background:white; border:1px solid #86efac; border-radius:4px; color:#15803d; cursor:pointer;">↻</button>"""

if old_rescan_btn in content:
    content = content.replace(old_rescan_btn, new_rescan_btn)
    print("✓ Bouton ↻ rescan : onclick simplifié")
    changes += 1

# Bouton scanner (le bouton violet)
old_scan_btn = """<button class="btn-action" style="background:#7c3aed; color:white; padding:8px 14px; font-size:0.85rem;" onclick="openScannerForIngredient('${i.id}', ${i.article_id ? `'${i.article_id}'` : 'null'}, '${esc(i.nom).replace(/'/g, '\\\\\\'')}')">📷 Scanner</button>"""
new_scan_btn = """<button class="btn-action" style="background:#7c3aed; color:white; padding:8px 14px; font-size:0.85rem;" onclick="openScannerForIngredient('${i.id}')">📷 Scanner</button>"""

if old_scan_btn in content:
    content = content.replace(old_scan_btn, new_scan_btn)
    print("✓ Bouton 📷 Scanner : onclick simplifié")
    changes += 1

# ============================================================
# 3. Modifier openScannerForIngredient pour accepter juste un id
# ============================================================
old_open = """  function openScannerForIngredient(ingredientId, articleId, nomIngredient) {
    const ctx = window.__currentTafContext || {};
    if (!ctx.task_id) {
      showToast('Erreur : contexte TAF perdu', 'error');
      return;
    }"""

new_open = """  function openScannerForIngredient(ingredientId) {
    const ctx = window.__currentTafContext || {};
    if (!ctx.task_id) {
      showToast('Erreur : contexte TAF perdu', 'error');
      return;
    }
    // Récupérer article_id et nom depuis les ings stockés en mémoire
    const ings = window.__currentFicheIngs || [];
    const ing = ings.find(i => i.id === ingredientId);
    const articleId = ing?.article_id || null;
    const nomIngredient = ing?.nom || '';"""

if old_open in content:
    content = content.replace(old_open, new_open)
    print("✓ openScannerForIngredient : signature simplifiée, lookup ings")
    changes += 1
elif "function openScannerForIngredient(ingredientId)" in content and "ings.find" in content:
    print("• openScannerForIngredient : déjà simplifié")
else:
    print("⚠ openScannerForIngredient : pattern non trouvé")

# ============================================================
# 4. Modifier rescanIngredient pour accepter juste un id
# ============================================================
old_rescan = """  function rescanIngredient(ingredientId, articleId, nomIngredient) {
    if (!confirm(`Rescanner « ${nomIngredient} » ? L'ancien scan sera remplacé.`)) return;
    const taskId = window.__currentTafContext?.task_id;
    if (taskId) {
      const pending = getPendingScans(taskId);
      delete pending[ingredientId];
      setPendingScans(taskId, pending);
    }
    openScannerForIngredient(ingredientId, articleId, nomIngredient);
  }"""

new_rescan = """  function rescanIngredient(ingredientId) {
    const ings = window.__currentFicheIngs || [];
    const ing = ings.find(i => i.id === ingredientId);
    const nomIngredient = ing?.nom || 'cet ingrédient';
    if (!confirm(`Rescanner « ${nomIngredient} » ? L'ancien scan sera remplacé.`)) return;
    const taskId = window.__currentTafContext?.task_id;
    if (taskId) {
      const pending = getPendingScans(taskId);
      delete pending[ingredientId];
      setPendingScans(taskId, pending);
    }
    openScannerForIngredient(ingredientId);
  }"""

if old_rescan in content:
    content = content.replace(old_rescan, new_rescan)
    print("✓ rescanIngredient : signature simplifiée")
    changes += 1
elif "function rescanIngredient(ingredientId)" in content and "ings.find" in content:
    print("• rescanIngredient : déjà simplifié")
else:
    print("⚠ rescanIngredient : pattern non trouvé")

if changes > 0:
    p.write_text(content, encoding='utf-8')
    print(f"\n✅ {changes} modifs écrites.")
else:
    print("\nAucun changement.")
PYEOF

echo
git status --short

if git diff --quiet -- taf/index.html; then
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html
git commit -m "fix(scan-fefo): bug apostrophes dans onclick

Symptôme : toast 'Erreur chargement fiche' au clic ▶ Démarrer sur
n'importe quelle tâche production. Causé par les apostrophes dans
les noms d'ingrédients (ex: 'Tarte à l'oignon') qui cassaient le
parsing JS des attributs onclick='...' inline.

Le \`replace(/'/g, '\\\'')\` que j'avais bricolé en triple échappement
ne suffisait pas : la string générée par template literal contenait
un backslash + apostrophe qui terminait la string JS prématurément.

Fix : les onclick ne passent désormais que l'ID de l'ingrédient.
Les fonctions openScannerForIngredient(id) et rescanIngredient(id)
font un lookup dans window.__currentFicheIngs (stocké au début de
renderFiche) pour retrouver le nom et article_id.

Avantage : plus aucune apostrophe à échapper dans le HTML inline.
Plus robuste pour les ingrédients à noms exotiques."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
