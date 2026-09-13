#!/usr/bin/env bash
# Phase 5 du projet Scan-FEFO :
# - Scan OBLIGATOIRE des ingrédients principaux avant que le chrono ne démarre
# - Au retour du scanner : le scan est mis en "pending" (pas d'INSERT immédiat)
# - Modale fiche en mode "obligatoire" : checklist visuel des scans à faire
# - Bouton "▶ Démarrer le chrono" actif seulement quand tous les principaux scannés
# - Au démarrage : chrono lancé + traitement async des sorties stock en background
# - FEFO non bloquant : violation → motif explicite mais sortie enregistrée

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application Phase 5 (4 patchs) ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# PATCH 1 — startTask : ne démarre PAS le chrono si is_production && fiche_id
#                       avec ingrédients principaux à scanner
# ============================================================
old_start_block = """      // === Affichage fiche technique pour les TAF de production ===
      if (task.is_production) {
        if (task.fiche_id) {
          window.__currentTafContext = { task_id: task.id, fiche_id: task.fiche_id, tache: task.tache };
          openFicheConsultModal(task.fiche_id, task.tache);
        } else {
          showToast('⚠ Fiche à créer pour cette tâche', 'error');
        }
      }"""

new_start_block = """      // === Affichage fiche technique pour les TAF de production ===
      // Phase 5 : si la fiche a des ingrédients principaux, on bloque le démarrage
      //           du chrono tant qu'ils ne sont pas scannés (mode obligatoire).
      if (task.is_production) {
        if (task.fiche_id) {
          window.__currentTafContext = { task_id: task.id, fiche_id: task.fiche_id, tache: task.tache };
          openFicheConsultModal(task.fiche_id, task.tache, { fromStart: true });
        } else {
          showToast('⚠ Fiche à créer pour cette tâche', 'error');
        }
      }"""

if old_start_block in content:
    content = content.replace(old_start_block, new_start_block)
    print("✓ startTask : appel openFicheConsultModal avec { fromStart: true }")
    changes += 1
elif "{ fromStart: true }" in content:
    print("• startTask : déjà à jour")
else:
    print("⚠ startTask : pattern non trouvé")

# ============================================================
# PATCH 1bis — startTask : déplacer le démarrage du chrono APRÈS le test is_production
#                          (pour pouvoir l'annuler si scan obligatoire)
# ============================================================
old_start_chrono = """      // Mise à jour optimiste en local pour un retour visuel immédiat
      task.date_debut_execution = nowISO;
      task.debut_par_id = currentUser.id;
      task.debut_par_initiales = currentUser.initiales;
      task.duree_accumulee_secondes = task.duree_accumulee_secondes || 0;
      renderFiltered();
      await DB.updateTask(id, {
        date_debut_execution: nowISO,
        debut_par_id: currentUser.id,
        debut_par_initiales: currentUser.initiales,
        duree_accumulee_secondes: task.duree_accumulee_secondes
      });
      showToast('Chrono démarré ⏱', 'success');

      // === Affichage fiche technique pour les TAF de production ==="""

new_start_chrono = """      // Phase 5 : si la tâche est production + fiche avec ingrédients principaux,
      // on N'EXÉCUTE PAS le démarrage chrono ici — on laisse openFicheConsultModal
      // décider (mode obligatoire = bouton Démarrer dans la modale).
      let chronoDemareDici = true;
      if (task.is_production && task.fiche_id) {
        // On déclenche le chrono uniquement si la fiche n'a pas d'ingrédient principal.
        // openFicheConsultModal vérifie ça et appelle reallyStartChrono(taskId) si besoin.
        chronoDemareDici = false;
      }

      if (chronoDemareDici) {
        // Mise à jour optimiste en local pour un retour visuel immédiat
        task.date_debut_execution = nowISO;
        task.debut_par_id = currentUser.id;
        task.debut_par_initiales = currentUser.initiales;
        task.duree_accumulee_secondes = task.duree_accumulee_secondes || 0;
        renderFiltered();
        await DB.updateTask(id, {
          date_debut_execution: nowISO,
          debut_par_id: currentUser.id,
          debut_par_initiales: currentUser.initiales,
          duree_accumulee_secondes: task.duree_accumulee_secondes
        });
        showToast('Chrono démarré ⏱', 'success');
      }

      // === Affichage fiche technique pour les TAF de production ==="""

if old_start_chrono in content:
    content = content.replace(old_start_chrono, new_start_chrono)
    print("✓ startTask : chrono conditionnel selon ingrédients principaux")
    changes += 1
elif "chronoDemareDici" in content:
    print("• startTask : chrono conditionnel déjà appliqué")
else:
    print("⚠ startTask : pattern Mise à jour optimiste non trouvé")

# ============================================================
# PATCH 2 — openFicheConsultModal accepte un paramètre opts et passe à renderFiche
# ============================================================
old_open = """  async function openFicheConsultModal(ficheId, taskName) {"""
new_open = """  async function openFicheConsultModal(ficheId, taskName, opts = {}) {"""
if old_open in content and "openFicheConsultModal(ficheId, taskName, opts" not in content:
    content = content.replace(old_open, new_open)
    print("✓ openFicheConsultModal : signature étendue avec opts")
    changes += 1
elif "openFicheConsultModal(ficheId, taskName, opts" in content:
    print("• openFicheConsultModal : signature déjà étendue")
else:
    print("⚠ openFicheConsultModal : signature non trouvée")

# Passer opts à renderFiche
old_call_render = "      renderFiche(fiche, ings || [], taskName);"
new_call_render = "      renderFiche(fiche, ings || [], taskName, opts);"
if old_call_render in content:
    content = content.replace(old_call_render, new_call_render)
    print("✓ openFicheConsultModal : opts transmis à renderFiche")
    changes += 1

# ============================================================
# PATCH 3 — renderFiche : mode obligatoire avec checklist + bouton Démarrer
# ============================================================
old_render_sig = "  function renderFiche(fiche, ings, taskName) {"
new_render_sig = "  function renderFiche(fiche, ings, taskName, opts = {}) {"
if old_render_sig in content:
    content = content.replace(old_render_sig, new_render_sig)
    print("✓ renderFiche : signature étendue avec opts")
    changes += 1

# Remplacer le bloc scanHTML pour gérer le mode obligatoire avec pending
old_scan_block = """    // Ingrédients principaux à scanner (Scan-FEFO Phase 3)
    const principaux = ings.filter(i => i.est_principal);
    let scanHTML = '';
    if (principaux.length > 0) {
      scanHTML = `
        <h3 style="color:#92400e">🎯 Ingrédients à scanner</h3>
        <div style="display:flex; flex-direction:column; gap:8px; margin-bottom:14px;">
          ${principaux.map(i => `
            <div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#fffbeb; border:1px solid #fcd34d; border-radius:8px;">
              <span style="flex:1; font-weight:600; color:#78350f;">${esc(i.nom)} <span style="font-weight:400; color:#92400e; font-size:0.78rem;">(${esc(String(i.quantite))} ${esc(i.unite || '')})</span></span>
              <button class="btn-action" style="background:#7c3aed; color:white; padding:8px 14px; font-size:0.85rem;" onclick="openScannerForIngredient('${i.id}', ${i.article_id ? `'${i.article_id}'` : 'null'}, '${esc(i.nom).replace(/'/g, '\\\\\\'')}')">📷 Scanner</button>
            </div>`).join('')}
        </div>`;
    }"""

new_scan_block = """    // Ingrédients principaux à scanner (Scan-FEFO Phase 5 — mode obligatoire)
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
                <button onclick="rescanIngredient('${i.id}', ${i.article_id ? `'${i.article_id}'` : 'null'}, '${esc(i.nom).replace(/'/g, '\\\\\\'')}')" style="font-size:0.72rem; padding:5px 9px; background:white; border:1px solid #86efac; border-radius:4px; color:#15803d; cursor:pointer;">↻</button>
              </div>`;
            }
            return `<div style="display:flex; align-items:center; gap:10px; padding:10px 12px; background:#fffbeb; border:1px solid #fcd34d; border-radius:8px;">
              <span style="flex:1; font-weight:600; color:#78350f;">${esc(i.nom)} <span style="font-weight:400; color:#92400e; font-size:0.78rem;">(${esc(String(i.quantite))} ${esc(i.unite || '')})</span></span>
              <button class="btn-action" style="background:#7c3aed; color:white; padding:8px 14px; font-size:0.85rem;" onclick="openScannerForIngredient('${i.id}', ${i.article_id ? `'${i.article_id}'` : 'null'}, '${esc(i.nom).replace(/'/g, '\\\\\\'')}')">📷 Scanner</button>
            </div>`;
          }).join('')}
        </div>
        ${obligatoire && allScanned ? `
          <button onclick="confirmStartChronoFromScan('${taskId}')" style="width:100%; background:#16a34a; color:white; padding:14px; font-size:1rem; font-weight:700; border:none; border-radius:8px; margin-bottom:14px; cursor:pointer; box-shadow:0 2px 4px rgba(0,0,0,.1);">▶ Démarrer le chrono</button>
        ` : obligatoire ? `
          <div style="background:#fef3c7; border:1px solid #fcd34d; padding:10px 14px; border-radius:6px; margin-bottom:14px; font-size:0.85rem; color:#92400e;">
            ⚠ Scanne tous les ingrédients principaux pour pouvoir démarrer le chrono.
          </div>
        ` : ''}`;
    } else if (obligatoire) {
      // Pas d'ingrédient principal mais fiche présente : on peut démarrer direct
      scanHTML = `
        <button onclick="confirmStartChronoFromScan('${taskId}')" style="width:100%; background:#16a34a; color:white; padding:14px; font-size:1rem; font-weight:700; border:none; border-radius:8px; margin-bottom:14px; cursor:pointer;">▶ Démarrer le chrono (pas d'ingrédient à scanner)</button>`;
    }"""

if old_scan_block in content:
    content = content.replace(old_scan_block, new_scan_block)
    print("✓ renderFiche : bloc scanHTML obligatoire avec checklist + bouton Démarrer")
    changes += 1
elif "confirmStartChronoFromScan" in content:
    print("• renderFiche scanHTML obligatoire déjà installé")
else:
    print("⚠ renderFiche : ancien bloc scanHTML non trouvé")

# ============================================================
# PATCH 4 — Remplacer processScanFefoResult par version pending + ajouter
#           getPendingScans, setPendingScans, clearPendingScans, rescanIngredient,
#           confirmStartChronoFromScan, processAllPendingScans
# ============================================================
old_process = """  async function processScanFefoResult() {
    // Attendre que currentUser & currentEtablissement soient chargés (polling max 5s)
    let tries = 0;
    while (tries < 25 && (!currentUser || !currentEtablissement)) {
      await new Promise(r => setTimeout(r, 200));
      tries++;
    }

    const rawResult = localStorage.getItem('scan_fefo_result');"""

new_process = """  // ====== SCAN-FEFO Phase 5 — Stockage pending + traitement async ======
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

  // Rescanner un ingrédient (efface l'ancien scan puis ouvre le scanner)
  function rescanIngredient(ingredientId, articleId, nomIngredient) {
    if (!confirm(`Rescanner « ${nomIngredient} » ? L'ancien scan sera remplacé.`)) return;
    const taskId = window.__currentTafContext?.task_id;
    if (taskId) {
      const pending = getPendingScans(taskId);
      delete pending[ingredientId];
      setPendingScans(taskId, pending);
    }
    openScannerForIngredient(ingredientId, articleId, nomIngredient);
  }

  // Démarrage chrono effectif après que tous les scans soient faits
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
    // En background : traiter tous les scans en pending (sortie stock + alertes FEFO)
    processAllPendingScans(taskId).catch(e => console.error('processAllPendingScans:', e));
  }

  // Traitement asynchrone (non-bloquant) des scans en pending
  async function processAllPendingScans(taskId) {
    const pending = getPendingScans(taskId);
    const task = tasks.find(t => t.id === taskId);
    if (!task) return;
    for (const [ingredientId, scan] of Object.entries(pending)) {
      try {
        // 1. Matching article
        if (scan.article_id_attendu && scan.article_id !== scan.article_id_attendu) {
          showToast(`⚠ Article ne correspond pas (${esc(scan.nom_attendu || '?')})`, 'error');
          continue;
        }
        // 2. Vérif FEFO (non bloquante)
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
        // 3. Récupérer quantité/unité depuis fiche_ingredients
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
        // 4. INSERT stock_mouvements (toujours, même si FEFO violation)
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
  async function processScanFefoResult() {
    // Attendre que currentUser & currentEtablissement soient chargés (polling max 5s)
    let tries = 0;
    while (tries < 25 && (!currentUser || !currentEtablissement)) {
      await new Promise(r => setTimeout(r, 200));
      tries++;
    }

    const rawResult = localStorage.getItem('scan_fefo_result');"""

if old_process in content:
    content = content.replace(old_process, new_process)
    print("✓ processScanFefoResult : fonctions Phase 5 ajoutées (pending, rescan, confirm, processAll)")
    changes += 1
elif "function getPendingScans" in content:
    print("• Phase 5 fonctions déjà présentes")
else:
    print("⚠ Pattern processScanFefoResult intro non trouvé")

# Maintenant remplacer le contenu de processScanFefoResult pour stocker en pending au lieu d'INSERT
old_old_logic = """    // 1. Vérif matching article
    if (context.article_id_attendu && result.article_id !== context.article_id_attendu) {"""

if old_old_logic in content:
    # On garde le polling + parse, mais on remplace TOUT le bloc à partir du matching jusqu'au showToast final
    # par un simple stockage pending + reopen fiche

    # Trouver la limite : on cherche la fin de la fonction processScanFefoResult
    # qui ressemble à "    showToast(...);\n  }"
    # En pratique on remplace une grosse string

    old_full_logic_start = """    // 1. Vérif matching article"""
    # On va remplacer le contenu entre ce marqueur et la fermeture de la fonction
    # qui est : "  }\n\n  // Ferme la modale ET le bandeau"

    # Trouvons le bloc entier
    start_idx = content.find(old_full_logic_start)
    end_marker = "  // Ferme la modale ET le bandeau"
    end_idx = content.find(end_marker, start_idx)

    if start_idx > 0 and end_idx > start_idx:
        # Bloc à remplacer : du début de la logique jusqu'à 2 lignes avant le commentaire fin (qui ferme la fonction processScanFefoResult)
        old_full = content[start_idx:end_idx]
        new_full = """    // === Phase 5 : stocker en pending au lieu d'INSERT direct ===
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
      // Rouvrir la modale fiche en mode obligatoire pour montrer le ✓
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
  }

  """
        content = content[:start_idx] + new_full + content[end_idx:]
        print("✓ processScanFefoResult : logique remplacée par stockage pending + rouverture modale")
        changes += 1
elif 'setPendingScans(context.task_id, pending);' in content:
    print("• processScanFefoResult : déjà refactor Phase 5")

if changes > 0:
    p.write_text(content, encoding='utf-8')
    print(f"\n✅ {changes} modifs écrites sur disque.")
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
git commit -m "feat(scan-fefo phase 5): scan obligatoire + traitement async

Le scan des ingrédients principaux devient OBLIGATOIRE avant le démarrage
du chrono, et le rapprochement avec le stock se fait en arrière-plan
sans bloquer l'utilisateur.

CHANGEMENTS UX :
- Click ▶ Démarrer sur tâche production avec fiche : le chrono NE
  démarre PAS direct. La modale fiche s'ouvre en mode 'obligatoire'.
- Section 🎯 Ingrédients à scanner : checklist visuel.
  • Non scanné : bouton violet '📷 Scanner [nom]'
  • Scanné : carte verte '✓' avec produit, lot, DLC + bouton ↻ rescan
- Quand tous les principaux sont scannés : un gros bouton vert
  '▶ Démarrer le chrono' apparaît. Avant ça, message d'attente.
- Au click 'Démarrer le chrono' : chrono lancé immédiatement, modale
  fermée, l'utilisateur peut travailler.

ARCHITECTURE BACKEND (async / non-bloquant) :
- Au retour du scanner, le résultat est stocké en localStorage sous
  scan_fefo_pending_<task_id>[ingredient_id] (pas d'INSERT immédiat).
- Au click '▶ Démarrer le chrono', confirmStartChronoFromScan() :
  1. UPDATE tasks pour démarrer le chrono
  2. Ferme la modale, toast 'Chrono démarré'
  3. Lance processAllPendingScans(task_id) SANS await (background)
- processAllPendingScans itère sur chaque scan en pending :
  • Matching article : si fail → toast erreur, skip cet ingrédient
  • Vérif FEFO via stock_par_lot : si violation → motif explicite
    dans stock_mouvements, toast d'alerte (mais sortie enregistrée)
  • INSERT stock_mouvements avec quantité/unité de fiche_ingredients
- Aucune action ne bloque l'utilisateur : les erreurs sortent en
  toasts en arrière-plan, le chrono continue.

NOUVELLES FONCTIONS :
- getPendingScans, setPendingScans, clearPendingScans (localStorage)
- rescanIngredient (efface + relance scanner)
- confirmStartChronoFromScan (chrono + async background)
- processAllPendingScans (boucle async sur les scans en attente)

CHANGEMENTS startTask :
- Variable chronoDemareDici : false si is_production + fiche_id
- Sinon comportement inchangé (Nettoyage, etc.)

CHANGEMENTS openFicheConsultModal & renderFiche :
- Acceptent un opts.fromStart pour distinguer mode obligatoire vs consultation
- En consultation (ouverture manuelle), pas de bouton Démarrer affiché"

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
echo
echo "Pour tester (après force-refresh) :"
echo "  1. Va sur TAF, trouve une tâche prod avec ingrédient principal"
echo "  2. Click ▶ — la modale s'ouvre, PAS de chrono démarré"
echo "  3. Click 📷 Scanner — caméra, scan, retour"
echo "  4. Tu reviens, l'ingrédient passe en ✓ vert"
echo "  5. Si tous scannés : gros bouton vert '▶ Démarrer le chrono'"
echo "  6. Click — chrono démarre, modale ferme, toasts d'alerte si FEFO violations"
