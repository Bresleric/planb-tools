#!/usr/bin/env bash
# Fix : les patches Phase 5 ont injecté les APPELS aux fonctions
# (getPendingScans, confirmStartChronoFromScan...) dans renderFiche
# mais pas les DÉFINITIONS de ces fonctions. Résultat : 'function is
# not defined' au runtime → catch → 'Erreur chargement fiche'.
#
# Ce script injecte les 6 fonctions manquantes en remplaçant l'ancien
# listener Phase 3 (qui ne fait qu'un toast) par tout le bloc Phase 5.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Injection des fonctions Phase 5 manquantes ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')

old_listener = """  // Au retour du scanner : si un résultat est en localStorage, le traiter
  window.addEventListener('DOMContentLoaded', function checkScanReturn() {
    try {
      const raw = localStorage.getItem('scan_fefo_result');
      if (!raw) return;
      const result = JSON.parse(raw);
      // Consommer le résultat (1 seul affichage)
      localStorage.removeItem('scan_fefo_result');
      // Afficher un toast pour signaler que le scan a bien été reçu
      // (la logique FEFO + sortie stock viendra en Phase 4)
      const dlcStr = result.dlc ? ` — DLC ${new Date(result.dlc).toLocaleDateString('fr-FR')}` : '';
      showToast(`Scan reçu : ${result.produit || '?'}${dlcStr}`, 'success');
      console.log('[Scan-FEFO] Résultat reçu :', result);
      // TODO Phase 4 : vérif matching article + FEFO + INSERT stock_mouvements
    } catch (e) {
      console.error('[Scan-FEFO] checkScanReturn:', e);
    }
  });"""

new_block = """  // ====== SCAN-FEFO Phase 5 — Pending scans + traitement async ======
  function getPendingScans(taskId) {
    try {
      const raw = localStorage.getItem('scan_fefo_pending_' + taskId);
      return raw ? JSON.parse(raw) : {};
    } catch (e) { return {}; }
  }
  function setPendingScans(taskId, scans) {
    localStorage.setItem('scan_fefo_pending_' + taskId, JSON.stringify(scans));
  }
  function clearPendingScans(taskId) {
    localStorage.removeItem('scan_fefo_pending_' + taskId);
  }

  function rescanIngredient(ingredientId) {
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
  }

  async function confirmStartChronoFromScan(taskId) {
    const task = tasks.find(t => t.id === taskId);
    if (!task) return;
    const nowISO = new Date().toISOString();
    task.date_debut_execution = nowISO;
    task.debut_par_id = currentUser.id;
    task.debut_par_initiales = currentUser.initiales;
    task.duree_accumulee_secondes = task.duree_accumulee_secondes || 0;
    try {
      await DB.updateTask(taskId, {
        date_debut_execution: nowISO,
        debut_par_id: currentUser.id,
        debut_par_initiales: currentUser.initiales,
        duree_accumulee_secondes: task.duree_accumulee_secondes
      });
    } catch (e) {
      console.error('confirmStartChronoFromScan updateTask:', e);
      showToast('Erreur démarrage chrono', 'error');
      return;
    }
    closeFiche();
    renderFiltered();
    showToast('Chrono démarré ⏱', 'success');
    processAllPendingScans(taskId).catch(e => console.error('processAllPendingScans:', e));
  }

  async function processAllPendingScans(taskId) {
    const pending = getPendingScans(taskId);
    const task = tasks.find(t => t.id === taskId);
    if (!task) return;
    for (const [ingredientId, scan] of Object.entries(pending)) {
      try {
        if (scan.article_id_attendu && scan.article_id !== scan.article_id_attendu) {
          showToast(`⚠ Article ne correspond pas (${esc(scan.nom_attendu || '?')})`, 'error');
          continue;
        }
        let fefoViolation = null;
        try {
          const { data: lots } = await supabaseClient.from('stock_par_lot')
            .select('scan_tracabilite_id, lot, dlc, quantite_restante')
            .eq('article_id', scan.article_id)
            .eq('etablissement', currentEtablissement)
            .gt('quantite_restante', 0)
            .order('dlc', { ascending: true, nullsFirst: false });
          if (lots && lots.length > 0) {
            const meilleur = lots[0];
            if (meilleur.scan_tracabilite_id && meilleur.scan_tracabilite_id !== scan.scan_tracabilite_id) {
              const dlcM = meilleur.dlc ? new Date(meilleur.dlc).toLocaleDateString('fr-FR') : '?';
              fefoViolation = `Lot DLC ${dlcM} (lot ${meilleur.lot || '?'}) aurait dû être consommé d'abord`;
            }
          }
        } catch (e) { console.warn('FEFO check:', e); }
        let qte = 1, unite = 'kg', nomIng = scan.produit;
        try {
          const { data: ing } = await supabaseClient.from('fiche_ingredients')
            .select('quantite, unite, nom').eq('id', ingredientId).single();
          if (ing) {
            qte = Number(ing.quantite) || 1;
            unite = ing.unite || 'kg';
            nomIng = ing.nom || nomIng;
          }
        } catch (e) {}
        const motif = `TAF: ${task.tache}` + (fefoViolation ? ` [⚠ FEFO : ${fefoViolation}]` : '');
        const { error } = await supabaseClient.from('stock_mouvements').insert({
          type: 'sortie',
          article_id: scan.article_id,
          scan_tracabilite_id: scan.scan_tracabilite_id,
          quantite: qte,
          unite: unite,
          etablissement: currentEtablissement,
          motif: motif,
          source_table: 'tasks',
          source_id: taskId,
          created_by_id: currentUser.id,
          created_by_nom: currentUser.nom,
          created_by_initiales: currentUser.initiales || null
        });
        if (error) {
          showToast(`Erreur sortie stock ${nomIng}: ${error.message}`, 'error');
        } else if (fefoViolation) {
          showToast(`⚠ FEFO non respecté pour ${nomIng} — sortie enregistrée`, 'error');
        } else {
          showToast(`✓ ${qte} ${unite} de ${nomIng} sorti du stock`, 'success');
        }
      } catch (e) {
        console.error('processAllPendingScans iteration:', e);
      }
    }
    clearPendingScans(taskId);
  }

  // Au retour du scanner : stocker en pending au lieu d'INSERT direct
  window.addEventListener('DOMContentLoaded', function checkScanReturn() {
    setTimeout(() => processScanFefoResult(), 800);
  });

  async function processScanFefoResult() {
    let tries = 0;
    while (tries < 25 && (!currentUser || !currentEtablissement)) {
      await new Promise(r => setTimeout(r, 200));
      tries++;
    }
    const rawResult = localStorage.getItem('scan_fefo_result');
    const rawContext = localStorage.getItem('scan_fefo_context');
    if (!rawResult) return;
    if (!currentUser || !currentEtablissement) {
      console.warn('[Scan-FEFO] User non chargé, abandon.'); return;
    }
    let result, context = {};
    try {
      result = JSON.parse(rawResult);
      if (rawContext) context = JSON.parse(rawContext);
    } catch (e) {
      console.error('[Scan-FEFO] JSON parse:', e);
      localStorage.removeItem('scan_fefo_result');
      localStorage.removeItem('scan_fefo_context');
      return;
    }
    localStorage.removeItem('scan_fefo_result');
    localStorage.removeItem('scan_fefo_context');

    if (context.task_id && context.ingredient_id) {
      const pending = getPendingScans(context.task_id);
      pending[context.ingredient_id] = {
        scan_tracabilite_id: result.scan_tracabilite_id,
        article_id: result.article_id,
        article_id_attendu: context.article_id_attendu,
        nom_attendu: context.nom_attendu,
        produit: result.produit,
        lot: result.lot,
        dlc: result.dlc,
        timestamp: result.timestamp
      };
      setPendingScans(context.task_id, pending);
      showToast(`Scan enregistré : ${result.produit || '?'}`, 'success');
      setTimeout(() => {
        const task = tasks.find(t => t.id === context.task_id);
        if (task && task.fiche_id) {
          window.__currentTafContext = { task_id: task.id, fiche_id: task.fiche_id, tache: task.tache };
          openFicheConsultModal(task.fiche_id, task.tache, { fromStart: true });
        }
      }, 300);
    } else {
      showToast(`Scan reçu sans contexte : ${result.produit || '?'}`, 'success');
    }
  }"""

if old_listener in content:
    content = content.replace(old_listener, new_block)
    p.write_text(content, encoding='utf-8')
    print("✓ Ancien listener remplacé par bloc Phase 5 complet (6 fonctions)")
elif "function getPendingScans" in content and "function confirmStartChronoFromScan" in content:
    print("• Fonctions Phase 5 déjà présentes")
else:
    print("⚠ Pattern ancien listener non trouvé. Vérifier le fichier manuellement.")
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
git commit -m "fix(scan-fefo): injection des 6 fonctions Phase 5 manquantes

Le patch Phase 5 précédent (commit 53f4ff6) avait injecté les APPELS
aux fonctions dans renderFiche (getPendingScans, confirmStartChronoFromScan)
mais avait silencieusement échoué sur l'injection des DÉFINITIONS de
ces fonctions. Résultat : 'ReferenceError: getPendingScans is not
defined' → catch → toast 'Erreur chargement fiche'.

Fix : injection complète des 6 fonctions/blocs en remplaçant l'ancien
listener Phase 3 (qui ne faisait qu'un toast) par tout le bloc Phase 5 :
- getPendingScans / setPendingScans / clearPendingScans (localStorage)
- rescanIngredient (id-only, lookup via __currentFicheIngs)
- confirmStartChronoFromScan (chrono + processAllPendingScans async)
- processAllPendingScans (matching + FEFO + INSERT stock_mouvements)
- listener DOMContentLoaded + processScanFefoResult (stockage pending)

Maintenant le code est cohérent : les appels ont leurs définitions."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
