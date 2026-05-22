#!/usr/bin/env bash
# Phase B-1 — Continuité TAF → Production : persistance des scans + pré-remplissage
#
# PRÉREQUIS : la migration 2026-05-21_tasks_scans_lots.sql doit être exécutée
# (colonne tasks.scans_lots jsonb).
#
# Constat : le workflow "scan au démarrage du chrono" (processAllPendingScans)
# insérait type:'sortie' en minuscule → rejeté par la contrainte CHECK
# (type IN 'ENTREE','SORTIE') → aucun scan TAF n'a jamais été persisté en base.
#
# Cette phase :
# 1. processScanFefoResult : à chaque scan, on persiste l'étiquette dans
#    tasks.scans_lots (JSONB) en plus du pending localStorage.
# 2. Nouvelle fonction persistScanToTask (enrichit fabricant/poids puis UPDATE).
# 3. confirmStartChronoFromScan : on retire l'appel à processAllPendingScans
#    (INSERT cassé + doublon potentiel). Le scan ne crée plus de sortie stock ;
#    la sortie unique se fait à la validation de la production.
# 4. loadPersistedScansForTask : lit désormais tasks.scans_lots (et non plus
#    les stock_mouvements 'tasks' qui n'existent pas).
# 5. loadProductionMatieres : charge est_principal + reçoit les scans, et
#    pré-remplit les lots avec l'étiquette réellement scannée (pas le FEFO
#    théorique).
# 6. renderMatieresList : badge '✓ étiquette scannée' / '⚠ non scanné'.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Sync préventif iCloud → repo ==="
ICLOUD_TAF="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools/taf/index.html"
if [ -f "$ICLOUD_TAF" ]; then
  if ! diff -q "$ICLOUD_TAF" taf/index.html > /dev/null 2>&1; then
    echo "⚠ taf/index.html iCloud ≠ repo — on continue avec la version repo."
  else
    echo "✓ iCloud et repo identiques."
  fi
fi

echo
echo "=== Application du patch Phase B-1 ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# PATCH 1 — processScanFefoResult : persister le scan en base
# ============================================================
old1 = """      setPendingScans(context.task_id, pending);
      showToast(`Scan enregistré : ${result.produit || '?'}`, 'success');"""
new1 = """      setPendingScans(context.task_id, pending);
      // PHASE B — persister aussi en base (tasks.scans_lots) pour survivre
      // au changement d'iPad jusqu'à la validation de la production
      await persistScanToTask(context.task_id, context.ingredient_id, pending[context.ingredient_id]);
      showToast(`Scan enregistré : ${result.produit || '?'}`, 'success');"""
if old1 in content:
    content = content.replace(old1, new1)
    print("[1/6] ✓ processScanFefoResult : persistScanToTask ajouté")
    changes += 1
elif "persistScanToTask(context.task_id" in content:
    print("[1/6] • déjà patché")
else:
    print("[1/6] ⚠ pattern processScanFefoResult non trouvé")

# ============================================================
# PATCH 2 — Injecter persistScanToTask après clearPendingScans
# ============================================================
old2 = """  function clearPendingScans(taskId) {
    localStorage.removeItem('scan_fefo_pending_' + taskId);
  }"""
new2 = """  function clearPendingScans(taskId) {
    localStorage.removeItem('scan_fefo_pending_' + taskId);
  }

  // ====== PHASE B — Persistance des scans dans tasks.scans_lots ======
  // Mémorise l'étiquette scannée pour un ingrédient, en base, afin qu'elle
  // survive jusqu'à la validation de la production (multi-iPads).
  async function persistScanToTask(taskId, ingredientId, scanData) {
    if (!taskId || !ingredientId || !scanData) return;
    try {
      let enriched = { ...scanData };
      // Enrichir avec fabricant + poids depuis scan_tracabilite (best-effort)
      if (scanData.scan_tracabilite_id) {
        try {
          const { data: st } = await supabaseClient.from('scan_tracabilite')
            .select('fabricant, poids_net_kg, produit, lot, dlc')
            .eq('id', scanData.scan_tracabilite_id).single();
          if (st) {
            enriched.fabricant = st.fabricant ?? null;
            enriched.poids_net_kg = st.poids_net_kg ?? null;
            if (!enriched.produit) enriched.produit = st.produit;
            if (!enriched.lot) enriched.lot = st.lot;
            if (!enriched.dlc) enriched.dlc = st.dlc;
          }
        } catch (e) { /* enrichissement non bloquant */ }
      }
      // Relire scans_lots en base pour ne pas écraser un scan concurrent
      let scansLots = {};
      try {
        const { data: fresh } = await supabaseClient.from('tasks')
          .select('scans_lots').eq('id', taskId).single();
        if (fresh && fresh.scans_lots) scansLots = { ...fresh.scans_lots };
      } catch (e) { /* colonne absente ? on repart de {} */ }
      scansLots[ingredientId] = enriched;
      const task = tasks.find(t => t.id === taskId);
      if (task) task.scans_lots = scansLots;
      await DB.updateTask(taskId, { scans_lots: scansLots });
    } catch (e) {
      console.warn('[Phase B] persistScanToTask:', e);
    }
  }"""
if "async function persistScanToTask" not in content:
    if old2 in content:
        content = content.replace(old2, new2)
        print("[2/6] ✓ persistScanToTask injectée")
        changes += 1
    else:
        print("[2/6] ⚠ pattern clearPendingScans non trouvé")
else:
    print("[2/6] • persistScanToTask déjà présente")

# ============================================================
# PATCH 3 — confirmStartChronoFromScan : retirer processAllPendingScans
# ============================================================
old3 = """    showToast('Chrono démarré ⏱', 'success');
    processAllPendingScans(taskId).catch(e => console.error('processAllPendingScans:', e));
  }"""
new3 = """    showToast('Chrono démarré ⏱', 'success');
    // PHASE B : le scan ne crée plus de sortie stock ici (INSERT cassé +
    // doublon). Les scans sont déjà persistés dans tasks.scans_lots ;
    // la sortie stock unique se fait à la validation de la production.
  }"""
if old3 in content:
    content = content.replace(old3, new3)
    print("[3/6] ✓ confirmStartChronoFromScan : processAllPendingScans retiré")
    changes += 1
elif "le scan ne crée plus de sortie stock ici" in content:
    print("[3/6] • déjà patché")
else:
    print("[3/6] ⚠ pattern confirmStartChronoFromScan non trouvé")

# ============================================================
# PATCH 4 — loadPersistedScansForTask : lire tasks.scans_lots
# ============================================================
old4 = """  // ====== PHASE A — Scans persistés (stock_mouvements + scan_tracabilite) ======
  async function loadPersistedScansForTask(taskId) {
    if (!taskId) return {};
    try {
      const task = tasks.find(t => t.id === taskId);
      const productionId = task?.production_id || null;
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
    }"""
new4 = """  // ====== PHASE A/B — Scans persistés (lus depuis tasks.scans_lots) ======
  // Retourne un dict indexé par article_id pour le matching dans renderFiche.
  async function loadPersistedScansForTask(taskId) {
    if (!taskId) return {};
    try {
      const { data: t, error } = await supabaseClient.from('tasks')
        .select('scans_lots').eq('id', taskId).single();
      if (error) {
        console.warn('[Phase B] loadPersistedScans:', error);
        return {};
      }
      const scansLots = (t && t.scans_lots) ? t.scans_lots : {};
      const byArticle = {};
      Object.values(scansLots).forEach(sc => {
        if (!sc || !sc.article_id) return;
        byArticle[sc.article_id] = {
          lot: sc.lot,
          dlc: sc.dlc,
          produit: sc.produit,
          fabricant: sc.fabricant,
          poids_net_kg: sc.poids_net_kg,
          source: 'scans_lots',
          scan_tracabilite_id: sc.scan_tracabilite_id,
        };
      });
      return byArticle;
    } catch (e) {
      console.warn('[Phase B] loadPersistedScansForTask:', e);
      return {};
    }"""
if old4 in content:
    content = content.replace(old4, new4)
    print("[4/6] ✓ loadPersistedScansForTask : lit tasks.scans_lots")
    changes += 1
elif "Scans persistés (lus depuis tasks.scans_lots)" in content:
    print("[4/6] • déjà patché")
else:
    print("[4/6] ⚠ pattern loadPersistedScansForTask non trouvé")

# ============================================================
# PATCH 5 — loadProductionMatieres + recalcMatieresFefo + applyScannedLots
# ============================================================
# 5a. signature + est_principal + prodScannedLots
old5a = """  async function loadProductionMatieres(ficheId) {
    try {
      // 1. Ingrédients de la fiche AVEC article_id rattaché
      const { data: ings, error: e1 } = await sb.from('fiche_ingredients')
        .select('id, nom, quantite, unite, article_id, ordre')
        .eq('fiche_id', ficheId)
        .not('article_id', 'is', null)
        .order('ordre');"""
new5a = """  async function loadProductionMatieres(ficheId, scansLots) {
    try {
      // PHASE B : mémoriser les scans reçus pour pré-remplir les lots
      prodScannedLots = scansLots || {};
      // 1. Ingrédients de la fiche AVEC article_id rattaché
      const { data: ings, error: e1 } = await sb.from('fiche_ingredients')
        .select('id, nom, quantite, unite, article_id, ordre, est_principal')
        .eq('fiche_id', ficheId)
        .not('article_id', 'is', null)
        .order('ordre');"""
if old5a in content:
    content = content.replace(old5a, new5a)
    print("[5a/6] ✓ loadProductionMatieres : signature + est_principal")
    changes += 1
elif "prodScannedLots = scansLots || {}" in content:
    print("[5a/6] • déjà patché")
else:
    print("[5a/6] ⚠ pattern loadProductionMatieres non trouvé")

# 5b. prodMatieres.map : ajouter est_principal
old5b = """      prodMatieres = ings.map(ing => ({
        ingredient_id: ing.id,
        ingredient_nom: ing.nom,
        article_id: ing.article_id,
        qty_fiche: ing.quantite,
        unite_fiche: ing.unite,
        lots: (lots || []).filter(l => l.article_id === ing.article_id),
        selections: {}, // { lot_id: qty }
      }));"""
new5b = """      prodMatieres = ings.map(ing => ({
        ingredient_id: ing.id,
        ingredient_nom: ing.nom,
        article_id: ing.article_id,
        est_principal: ing.est_principal === true,
        qty_fiche: ing.quantite,
        unite_fiche: ing.unite,
        lots: (lots || []).filter(l => l.article_id === ing.article_id),
        selections: {}, // { lot_id: qty }
      }));"""
if old5b in content:
    content = content.replace(old5b, new5b)
    print("[5b/6] ✓ prodMatieres : flag est_principal")
    changes += 1
elif "est_principal: ing.est_principal === true" in content:
    print("[5b/6] • déjà patché")
else:
    print("[5b/6] ⚠ pattern prodMatieres.map non trouvé")

# 5c. recalcMatieresFefo : appeler applyScannedLotsToMatieres en fin
old5c = """      m.qty_manque = restant > 0.001 ? restant : 0;
    });
  }"""
new5c = """      m.qty_manque = restant > 0.001 ? restant : 0;
    });
    // PHASE B : forcer les lots réellement scannés par-dessus le FEFO théorique
    applyScannedLotsToMatieres();
  }

  // Force la sélection sur l'étiquette réellement scannée dans le TAF.
  function applyScannedLotsToMatieres() {
    const scans = Object.values(prodScannedLots || {});
    prodMatieres.forEach(m => { m.scanne = false; m.scan_info = null; });
    if (!scans.length) return;
    prodMatieres.forEach(m => {
      const scan = scans.find(s => s && s.article_id === m.article_id && s.scan_tracabilite_id);
      if (!scan) return;
      const scanLotId = scan.scan_tracabilite_id;
      // S'assurer que le lot scanné apparaît dans la liste (même si épuisé en stock)
      if (!m.lots.find(l => l.scan_tracabilite_id === scanLotId)) {
        m.lots.unshift({
          scan_tracabilite_id: scanLotId,
          article_id: m.article_id,
          article_nom: scan.produit || m.ingredient_nom,
          lot: scan.lot || '?',
          dlc: scan.dlc || null,
          quantite_restante: Number(scan.poids_net_kg) || Number(m.qty_theorique) || 0,
          fabricant: scan.fabricant || null,
        });
      }
      // Forcer la sélection sur le seul lot scanné
      m.selections = {};
      m.selections[scanLotId] = Number((m.qty_theorique || 0).toFixed(3));
      m.scanne = true;
      m.scan_info = scan;
    });
  }"""
if old5c in content and "applyScannedLotsToMatieres" not in content:
    content = content.replace(old5c, new5c, 1)
    print("[5c/6] ✓ recalcMatieresFefo + applyScannedLotsToMatieres")
    changes += 1
elif "applyScannedLotsToMatieres" in content:
    print("[5c/6] • déjà patché")
else:
    print("[5c/6] ⚠ pattern recalcMatieresFefo non trouvé")

# 5d. openProductionModal : passer task.scans_lots
old5d = "        await loadProductionMatieres(task.fiche_id);"
new5d = "        await loadProductionMatieres(task.fiche_id, task.scans_lots || {});"
if old5d in content:
    content = content.replace(old5d, new5d)
    print("[5d/6] ✓ openProductionModal : passe task.scans_lots")
    changes += 1
elif "loadProductionMatieres(task.fiche_id, task.scans_lots" in content:
    print("[5d/6] • déjà patché")
else:
    print("[5d/6] ⚠ pattern appel loadProductionMatieres non trouvé")

# 5e. déclaration de prodScannedLots près de prodMatieres
old5e = "  let prodMatieres = []; // [{ ingredient_id, article_id, article_nom, qty_theorique, lots: [...], selections: { lot_id: qty } }]"
new5e = """  let prodMatieres = []; // [{ ingredient_id, article_id, article_nom, qty_theorique, lots: [...], selections: { lot_id: qty } }]
  let prodScannedLots = {}; // PHASE B : scans_lots de la tâche en cours de validation"""
if old5e in content and "let prodScannedLots" not in content:
    content = content.replace(old5e, new5e)
    print("[5e/6] ✓ déclaration prodScannedLots")
    changes += 1
elif "let prodScannedLots" in content:
    print("[5e/6] • déjà patché")
else:
    print("[5e/6] ⚠ pattern déclaration prodMatieres non trouvé")

# ============================================================
# PATCH 6 — renderMatieresList : badge scannée / non scanné
# ============================================================
old6 = """            <div style="font-size:13px; font-weight:600; color:#111827;">${_esc(m.ingredient_nom)}</div>"""
new6 = """            <div style="font-size:13px; font-weight:600; color:#111827;">${_esc(m.ingredient_nom)}${m.scanne ? ' <span style="font-size:9px;background:#bbf7d0;color:#14532d;padding:1px 6px;border-radius:3px;font-weight:700;">✓ ÉTIQUETTE SCANNÉE</span>' : (m.est_principal ? ' <span style="font-size:9px;background:#fee2e2;color:#991b1b;padding:1px 6px;border-radius:3px;font-weight:700;">⚠ NON SCANNÉ</span>' : '')}</div>"""
if old6 in content:
    content = content.replace(old6, new6)
    print("[6/6] ✓ renderMatieresList : badge scannée/non scanné")
    changes += 1
elif "✓ ÉTIQUETTE SCANNÉE" in content:
    print("[6/6] • déjà patché")
else:
    print("[6/6] ⚠ pattern renderMatieresList non trouvé")

if changes > 0:
    p.write_text(content, encoding='utf-8')
    print(f"\n✅ {changes} modifs écrites.")
else:
    print("\nAucun changement.")
PYEOF

echo
git status --short

if git diff --quiet -- taf/index.html && git diff --cached --quiet -- taf/index.html; then
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html scripts/phaseB1-continuite-scans-production.sh scripts/migrations/2026-05-21_tasks_scans_lots.sql
git commit -m "feat(scan-fefo phase B-1): continuité TAF→Production — persistance scans + pré-remplissage

PRÉREQUIS : migration 2026-05-21_tasks_scans_lots.sql (colonne tasks.scans_lots).

Constat : processAllPendingScans insérait type:'sortie' minuscule, rejeté
par la contrainte CHECK (type IN 'ENTREE','SORTIE'). Aucun scan TAF n'a
jamais été persisté en base — ils restaient en localStorage et étaient
perdus. Seul saveProductionFromTaf créait de vraies sorties stock.

Phase B-1 :
1. processScanFefoResult appelle persistScanToTask : chaque scan est
   écrit dans tasks.scans_lots (JSONB, clé = fiche_ingredients.id),
   en plus du pending localStorage.
2. persistScanToTask : enrichit fabricant/poids depuis scan_tracabilite,
   relit scans_lots en base (anti-écrasement concurrent), UPDATE.
3. confirmStartChronoFromScan : suppression de l'appel processAllPendingScans
   (INSERT cassé + doublon). Le scan ne crée plus de sortie stock ; la
   sortie unique se fait à la validation de la production.
4. loadPersistedScansForTask : lit désormais tasks.scans_lots au lieu des
   stock_mouvements 'tasks' inexistants.
5. loadProductionMatieres(ficheId, scansLots) : charge est_principal et
   reçoit les scans. Nouvelle applyScannedLotsToMatieres() appelée en fin
   de recalcMatieresFefo : force la sélection sur l'étiquette réellement
   scannée (au lieu du FEFO théorique), et l'ajoute à la liste des lots
   même si le lot est épuisé en stock.
6. renderMatieresList : badge vert '✓ étiquette scannée' ou badge rouge
   '⚠ non scanné' (ingrédients principaux) sur chaque matière.

Résultat : les étiquettes scannées dans le TAF se retrouvent
automatiquement pré-sélectionnées dans la modale de production, et
survivent au changement d'iPad.

Phase B-2 (blocage strict de la validation sans scan) à suivre."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
