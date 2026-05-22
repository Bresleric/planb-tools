#!/usr/bin/env bash
# Phase A — Affichage permanent des étiquettes scannées dans la modale fiche TAF
#
# Avant : les badges (lot/DLC/produit) ne s'affichent QUE quand opts.fromStart
# est vrai (démarrage du chrono) et UNIQUEMENT depuis localStorage pending.
# Dès que processAllPendingScans pousse les scans en DB et fait clearPendingScans,
# rouvrir la fiche n'affiche plus rien.
#
# Après :
# 1. openFicheConsultModal charge en async les stock_mouvements (source_table=tasks
#    OU production si la task a une production_id) joints à scan_tracabilite,
#    et les matche par article_id aux ingrédients principaux.
# 2. renderFiche reçoit opts.persistedScans en plus de pending, les fusionne
#    (priorité aux persistés s'ils existent) et affiche la section
#    "🎯 Étiquettes scannées" indépendamment de opts.fromStart.
# 3. Badge vert pour scan présent (avec lot/DLC/produit/fabricant/poids),
#    badge gris "Non scanné" pour les ingrédients principaux sans étiquette.
# 4. Bouton 📷 Scanner reste affiché uniquement en mode obligatoire (démarrage).

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Sync préventif iCloud → repo (lecture taf/index.html) ==="
ICLOUD_TAF="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools/taf/index.html"
if [ -f "$ICLOUD_TAF" ]; then
  if ! diff -q "$ICLOUD_TAF" taf/index.html > /dev/null 2>&1; then
    echo "⚠ taf/index.html iCloud ≠ repo. Diff bref :"
    diff "$ICLOUD_TAF" taf/index.html | head -40 || true
    echo "→ Je continue avec la version repo (plus récente présumée)."
  else
    echo "✓ iCloud et repo identiques."
  fi
fi

echo
echo "=== Application du patch Phase A ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# 1. openFicheConsultModal — charger les scans persistés avant renderFiche
# ============================================================
old_open = '''      if (error) throw error;

      renderFiche(fiche, ings || [], taskName, opts);
      // Affichage plein écran
      document.getElementById('fiche-overlay').classList.remove('minimized');'''

new_open = '''      if (error) throw error;

      // PHASE A — charger les scans persistés (stock_mouvements + scan_tracabilite)
      // pour la task courante (ou sa production_id si déjà créée)
      const __taskIdForScans = window.__currentTafContext?.task_id;
      const persistedScans = await loadPersistedScansForTask(__taskIdForScans);

      renderFiche(fiche, ings || [], taskName, { ...opts, persistedScans });
      // Affichage plein écran
      document.getElementById('fiche-overlay').classList.remove('minimized');'''

if old_open in content:
    content = content.replace(old_open, new_open)
    print("✓ openFicheConsultModal : chargement persistedScans avant renderFiche")
    changes += 1
elif "loadPersistedScansForTask" in content and "{ ...opts, persistedScans }" in content:
    print("• openFicheConsultModal : déjà patché")
else:
    print("⚠ Pattern openFicheConsultModal non trouvé")

# ============================================================
# 2. Ajout fonction loadPersistedScansForTask juste avant getPendingScans
# ============================================================
marker = "  // ====== SCAN-FEFO Phase 5 — Pending scans + traitement async ======"
new_fn = '''  // ====== PHASE A — Scans persistés (stock_mouvements + scan_tracabilite) ======
  // Retourne un dict { article_id: { lot, dlc, produit, fabricant, poids_net_kg, source } }
  // pour la task ou la production déjà liée. Permet d'afficher les étiquettes
  // après que processAllPendingScans a vidé le pending localStorage.
  async function loadPersistedScansForTask(taskId) {
    if (!taskId) return {};
    try {
      const task = tasks.find(t => t.id === taskId);
      const productionId = task?.production_id || null;
      // Construire la requête OR : source=tasks/source_id=taskId OU source=production/source_id=productionId
      let q = supabaseClient.from('stock_mouvements')
        .select(`id, article_id, scan_tracabilite_id, quantite, unite, source_table, source_id,
                 scan:scan_tracabilite_id ( id, lot, dlc, produit, fabricant, poids_net_kg )`)
        .eq('type', 'SORTIE');
      if (productionId) {
        q = q.or(`and(source_table.eq.tasks,source_id.eq.${taskId}),and(source_table.eq.production,source_id.eq.${productionId})`);
      } else {
        q = q.eq('source_table', 'tasks').eq('source_id', taskId);
      }
      const { data, error } = await q;
      if (error) {
        console.warn('[Phase A] loadPersistedScans:', error);
        return {};
      }
      const byArticle = {};
      (data || []).forEach(m => {
        if (!m.article_id || !m.scan) return;
        // En cas de doublon (tasks + production), on garde le plus récent (la 2e écrase)
        byArticle[m.article_id] = {
          lot: m.scan.lot,
          dlc: m.scan.dlc,
          produit: m.scan.produit,
          fabricant: m.scan.fabricant,
          poids_net_kg: m.scan.poids_net_kg,
          quantite_sortie: m.quantite,
          unite: m.unite,
          source: m.source_table,
          scan_tracabilite_id: m.scan_tracabilite_id,
        };
      });
      return byArticle;
    } catch (e) {
      console.warn('[Phase A] loadPersistedScansForTask:', e);
      return {};
    }
  }

'''

if "async function loadPersistedScansForTask" not in content:
    if marker in content:
        content = content.replace(marker, new_fn + marker)
        print("✓ Fonction loadPersistedScansForTask injectée")
        changes += 1
    else:
        print("⚠ Marker Phase 5 non trouvé pour injection fonction")
else:
    print("• loadPersistedScansForTask : déjà présente")

# ============================================================
# 3. renderFiche — fusionner pending + persistedScans et toujours afficher
# ============================================================
old_render = '''    // Ingrédients principaux à scanner (Scan-FEFO Phase 5 — mode obligatoire)
    const principaux = ings.filter(i => i.est_principal);
    const obligatoire = opts.fromStart === true;
    const taskId = window.__currentTafContext?.task_id;
    const pending = taskId ? getPendingScans(taskId) : {};
    let scanHTML = '';
    if (principaux.length > 0) {
      const allScanned = principaux.every(i => pending[i.id]);
      scanHTML = `
        <h3 style="color:#92400e">🎯 Ingrédients à scanner ${obligatoire ? '<span style="font-size:0.75rem;color:#dc2626;font-weight:400">(obligatoire)</span>' : ''}</h3>
        <div style="display:flex; flex-direction:column; gap:8px; margin-bottom:14px;">
          ${principaux.map(i => {
            const sc = pending[i.id];
            if (sc) {
              const dlcStr = sc.dlc ? new Date(sc.dlc).toLocaleDateString('fr-FR') : '?';
              return `<div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#dcfce7; border:1px solid #86efac; border-radius:8px;">
                <span style="font-size:1.3rem; line-height:1">✓</span>
                <span style="flex:1; color:#15803d; font-size:0.85rem;"><strong>${esc(i.nom)}</strong><br><span style="font-size:0.75rem; color:#166534;">${esc(sc.produit || '?')} · lot ${esc(sc.lot || '?')} · DLC ${dlcStr}</span></span>
                <button onclick="rescanIngredient('${i.id}')" style="font-size:0.72rem; padding:5px 9px; background:white; border:1px solid #86efac; border-radius:4px; color:#15803d; cursor:pointer;">↻</button>
              </div>`;
            }
            return `<div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#fffbeb; border:1px solid #fcd34d; border-radius:8px;">
              <span style="flex:1; font-weight:600; color:#78350f;">${esc(i.nom)} <span style="font-weight:400; color:#92400e; font-size:0.78rem;">(${esc(String(i.quantite))} ${esc(i.unite || '')})</span></span>
              <button class="btn-scan-camera" onclick="openScannerForIngredient('${i.id}')"><span class="scan-cam-emoji">📷</span><span>Scanner</span></button>
            </div>`;
          }).join('')}
        </div>'''

new_render = '''    // Ingrédients principaux à scanner (Scan-FEFO Phase 5 — mode obligatoire)
    // PHASE A : on fusionne pending (localStorage, non encore poussé en DB)
    // ET persistedScans (déjà en stock_mouvements). On affiche la section
    // dès qu'il y a au moins un ingrédient principal — pas seulement en démarrage.
    const principaux = ings.filter(i => i.est_principal);
    const obligatoire = opts.fromStart === true;
    const taskId = window.__currentTafContext?.task_id;
    const pending = taskId ? getPendingScans(taskId) : {};
    const persisted = opts.persistedScans || {};
    // Helper : récupère le scan pour un ingrédient (pending par ingredient_id, puis persisted par article_id)
    function getScanForIng(ing) {
      if (pending[ing.id]) return { ...pending[ing.id], _src: 'pending' };
      if (ing.article_id && persisted[ing.article_id]) return { ...persisted[ing.article_id], _src: 'persisted' };
      return null;
    }
    let scanHTML = '';
    if (principaux.length > 0) {
      const allScanned = principaux.every(i => getScanForIng(i));
      const nbScannes = principaux.filter(i => getScanForIng(i)).length;
      scanHTML = `
        <h3 style="color:#92400e">🎯 Étiquettes ingrédients (${nbScannes}/${principaux.length} scannées) ${obligatoire ? '<span style="font-size:0.75rem;color:#dc2626;font-weight:400">(obligatoire)</span>' : ''}</h3>
        <div style="display:flex; flex-direction:column; gap:8px; margin-bottom:14px;">
          ${principaux.map(i => {
            const sc = getScanForIng(i);
            if (sc) {
              const dlcStr = sc.dlc ? new Date(sc.dlc).toLocaleDateString('fr-FR') : '?';
              const fabStr = sc.fabricant ? ` · ${esc(sc.fabricant)}` : '';
              const poidsStr = sc.poids_net_kg ? ` · ${sc.poids_net_kg} kg` : '';
              const srcBadge = sc._src === 'persisted'
                ? '<span title="Persisté en base" style="font-size:0.65rem;background:#bbf7d0;color:#14532d;padding:1px 5px;border-radius:3px;margin-left:4px;">DB</span>'
                : '<span title="En attente" style="font-size:0.65rem;background:#fef3c7;color:#854d0e;padding:1px 5px;border-radius:3px;margin-left:4px;">pending</span>';
              const rescanBtn = obligatoire
                ? `<button onclick="rescanIngredient('${i.id}')" style="font-size:0.72rem; padding:5px 9px; background:white; border:1px solid #86efac; border-radius:4px; color:#15803d; cursor:pointer;">↻</button>`
                : '';
              return `<div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#dcfce7; border:1px solid #86efac; border-radius:8px;">
                <span style="font-size:1.3rem; line-height:1">✓</span>
                <span style="flex:1; color:#15803d; font-size:0.85rem;"><strong>${esc(i.nom)}</strong>${srcBadge}<br><span style="font-size:0.75rem; color:#166534;">${esc(sc.produit || '?')} · lot ${esc(sc.lot || '?')} · DLC ${dlcStr}${fabStr}${poidsStr}</span></span>
                ${rescanBtn}
              </div>`;
            }
            // Pas de scan : bouton Scanner si obligatoire, badge gris sinon
            if (obligatoire) {
              return `<div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#fffbeb; border:1px solid #fcd34d; border-radius:8px;">
                <span style="flex:1; font-weight:600; color:#78350f;">${esc(i.nom)} <span style="font-weight:400; color:#92400e; font-size:0.78rem;">(${esc(String(i.quantite))} ${esc(i.unite || '')})</span></span>
                <button class="btn-scan-camera" onclick="openScannerForIngredient('${i.id}')"><span class="scan-cam-emoji">📷</span><span>Scanner</span></button>
              </div>`;
            }
            return `<div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#f1f5f9; border:1px solid #cbd5e1; border-radius:8px;">
              <span style="font-size:1.1rem; line-height:1; color:#94a3b8">○</span>
              <span style="flex:1; color:#64748b; font-size:0.85rem;"><strong>${esc(i.nom)}</strong> <span style="font-size:0.72rem">(non scanné)</span></span>
            </div>`;
          }).join('')}
        </div>'''

if old_render in content:
    content = content.replace(old_render, new_render)
    print("✓ renderFiche : fusion pending + persistedScans, affichage permanent")
    changes += 1
elif "getScanForIng" in content:
    print("• renderFiche : déjà patché")
else:
    print("⚠ Pattern renderFiche/principaux non trouvé")

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
git commit -m "feat(scan-fefo phase A): badges étiquettes scannées permanents dans modale fiche TAF

Avant : les badges (lot/DLC/produit) n'apparaissaient qu'en mode obligatoire
(démarrage du chrono) et uniquement depuis localStorage.scan_fefo_pending.
Dès que processAllPendingScans poussait les scans en DB et faisait
clearPendingScans, rouvrir la fiche n'affichait plus rien.

Maintenant :

1. openFicheConsultModal charge en async les stock_mouvements (source_table=
   'tasks' pour les scans non encore poussés en production, OU source_table=
   'production' si la task a une production_id) joints à scan_tracabilite
   via la nouvelle fonction loadPersistedScansForTask(taskId).

2. renderFiche reçoit opts.persistedScans en plus du pending localStorage.
   Helper getScanForIng(ing) qui matche d'abord par ingredient_id (pending),
   puis par article_id (persisted).

3. La section '🎯 Étiquettes ingrédients (N/M scannées)' s'affiche dès qu'il
   y a au moins un ingrédient principal, peu importe opts.fromStart.

4. Chaque ingrédient principal a 3 états visuels :
   • Vert ✓ + détails (lot, DLC, produit, fabricant, poids) + badge DB/pending
   • Jaune avec bouton 📷 Scanner (seulement en mode obligatoire)
   • Gris 'non scanné' (en consultation hors démarrage)

5. Le bouton ↻ rescanner n'est plus affiché qu'en mode obligatoire (pour
   éviter de défaire un scan déjà persisté en base par erreur).

Côté technique :
- Pas de breaking change sur le pending workflow existant.
- Le matching persistedScans se fait par article_id, donc 1 article scanné
  une fois sert à tous les ingrédients qui le référencent."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
