#!/usr/bin/env bash
# Phase 3 du projet Scan-FEFO :
# - Côté TAF : modale fiche affiche les ingrédients principaux avec un
#   bouton "📷 Scanner [nom]". Au clic, on stocke le contexte en
#   localStorage et on navigue vers /scanner/?return=taf&...
# - Côté Scanner : à l'arrivée avec return=taf, mode 'unit' forcé.
#   Après validation, on stocke le résultat (scan_tracabilite_id +
#   article_id détecté) en localStorage et on redirige vers /taf/.
# - Côté TAF (retour) : au chargement, on lit le résultat et on affiche
#   un toast "Scan reçu". La logique FEFO + sortie stock viendra en Phase 4.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des patchs ==="
python3 << 'PYEOF'
from pathlib import Path

# ============================================================
# PATCH côté TAF (taf/index.html)
# ============================================================
taf_path = Path('taf/index.html')
taf = taf_path.read_text(encoding='utf-8')
taf_changes = 0

# 1. Élargir le SELECT des ingrédients dans openFicheConsultModal pour récupérer est_principal et article_id
old_select = """      const { data: ings, error } = await sb.from('fiche_ingredients')
        .select('id, nom, quantite, unite, ordre')
        .eq('fiche_id', ficheId)
        .order('ordre');"""
new_select = """      const { data: ings, error } = await sb.from('fiche_ingredients')
        .select('id, nom, quantite, unite, ordre, est_principal, article_id')
        .eq('fiche_id', ficheId)
        .order('ordre');"""
if old_select in taf:
    taf = taf.replace(old_select, new_select)
    print("[TAF] ✓ SELECT élargi (est_principal + article_id)")
    taf_changes += 1
elif new_select in taf:
    print("[TAF] • SELECT déjà élargi")
else:
    print("[TAF] ⚠ SELECT fiche_ingredients non trouvé")

# 2. Modifier openFicheConsultModal pour stocker la task_id (utile pour le retour de scan)
# On va passer task_id dans la signature, mais on peut aussi la lire depuis le contexte de startTask
# Stratégie simple : utiliser une variable globale window.__currentTafContext = { task_id, fiche_id }
# Au démarrage du chrono, on remplit ce contexte juste avant openFicheConsultModal

old_start = """      // === Affichage fiche technique pour les TAF de production ===
      if (task.is_production) {
        if (task.fiche_id) {
          openFicheConsultModal(task.fiche_id, task.tache);"""
new_start = """      // === Affichage fiche technique pour les TAF de production ===
      if (task.is_production) {
        if (task.fiche_id) {
          window.__currentTafContext = { task_id: task.id, fiche_id: task.fiche_id, tache: task.tache };
          openFicheConsultModal(task.fiche_id, task.tache);"""
if old_start in taf and 'window.__currentTafContext = ' not in taf:
    taf = taf.replace(old_start, new_start)
    print("[TAF] ✓ Contexte TAF stocké avant ouverture fiche")
    taf_changes += 1
elif 'window.__currentTafContext = ' in taf:
    print("[TAF] • Contexte TAF déjà stocké")
else:
    print("[TAF] ⚠ Pattern startTask 'is_production' non trouvé")

# 3. Modifier renderFiche pour afficher les ingrédients PRINCIPAUX avec un bouton 📷
# La signature actuelle de renderFiche : (fiche, ings, taskName)
# On trouve le bloc qui rend "🥗 Ingrédients" et on l'enrichit
old_render = """    // Ingrédients
    let ingHTML = '';
    if (ings.length === 0) {
      ingHTML = `<h3>🥗 Ingrédients</h3><div class="fiche-empty">Aucun ingrédient renseigné dans cette fiche.</div>`;
    } else {
      const rows = ings.map(i => `
        <tr>
          <td>${esc(i.nom)}</td>
          <td>${esc(String(i.quantite))}</td>
          <td>${esc(i.unite || '')}</td>
        </tr>`).join('');
      ingHTML = `
        <h3>🥗 Ingrédients (${ings.length})</h3>
        <table class="fiche-ing-table">
          <thead><tr><th>Ingrédient</th><th>Qté</th><th>Unité</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>`;
    }"""

new_render = """    // Ingrédients principaux à scanner (Scan-FEFO Phase 3)
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
    }

    // Ingrédients (liste complète)
    let ingHTML = '';
    if (ings.length === 0) {
      ingHTML = `<h3>🥗 Ingrédients</h3><div class="fiche-empty">Aucun ingrédient renseigné dans cette fiche.</div>`;
    } else {
      const rows = ings.map(i => `
        <tr style="${i.est_principal ? 'background:#fffbeb' : ''}">
          <td>${i.est_principal ? '🎯 ' : ''}${esc(i.nom)}</td>
          <td>${esc(String(i.quantite))}</td>
          <td>${esc(i.unite || '')}</td>
        </tr>`).join('');
      ingHTML = `
        <h3>🥗 Ingrédients (${ings.length}${principaux.length > 0 ? `, dont ${principaux.length} principal${principaux.length > 1 ? 'aux' : ''}` : ''})</h3>
        <table class="fiche-ing-table">
          <thead><tr><th>Ingrédient</th><th>Qté</th><th>Unité</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>`;
    }"""

if old_render in taf:
    taf = taf.replace(old_render, new_render)
    print("[TAF] ✓ renderFiche : bloc 'Ingrédients à scanner' ajouté")
    taf_changes += 1
elif "Ingrédients à scanner" in taf:
    print("[TAF] • renderFiche : bloc 'Ingrédients à scanner' déjà présent")
else:
    print("[TAF] ⚠ renderFiche : bloc Ingrédients non trouvé")

# 4. Ajouter la fonction openScannerForIngredient + listener au retour de scan
# On insère juste après la définition de closeFiche()
marker = "  // Ferme la modale ET le bandeau (n'arrête pas le chrono)\n  function closeFiche() {"
if marker in taf and "function openScannerForIngredient" not in taf:
    new_funcs = """  // ====== SCAN-FEFO Phase 3 — Lancement scanner + retour ======
  function openScannerForIngredient(ingredientId, articleId, nomIngredient) {
    const ctx = window.__currentTafContext || {};
    if (!ctx.task_id) {
      showToast('Erreur : contexte TAF perdu', 'error');
      return;
    }
    // Stocker le contexte pour le retour (TAF lira ça quand le scanner redirigera)
    localStorage.setItem('scan_fefo_context', JSON.stringify({
      task_id: ctx.task_id,
      fiche_id: ctx.fiche_id,
      tache: ctx.tache,
      ingredient_id: ingredientId,
      article_id_attendu: articleId,
      nom_attendu: nomIngredient,
      timestamp: Date.now()
    }));
    // Naviguer vers le scanner en mode unit avec return=taf
    window.location.href = '/scanner/?mode=unit&return=taf';
  }

  // Au retour du scanner : si un résultat est en localStorage, le traiter
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
  });

  // Ferme la modale ET le bandeau (n'arrête pas le chrono)
  function closeFiche() {"""
    taf = taf.replace(marker, new_funcs)
    print("[TAF] ✓ openScannerForIngredient + listener de retour ajoutés")
    taf_changes += 1
elif "function openScannerForIngredient" in taf:
    print("[TAF] • openScannerForIngredient déjà présent")
else:
    print("[TAF] ⚠ closeFiche marker non trouvé")

if taf_changes > 0:
    taf_path.write_text(taf, encoding='utf-8')
    print(f"[TAF] ✅ {taf_changes} modifs écrites.")

# ============================================================
# PATCH côté SCANNER (scanner/index.html)
# ============================================================
sc_path = Path('scanner/index.html')
sc = sc_path.read_text(encoding='utf-8')
sc_changes = 0

# 1. Détecter ?return=taf au chargement et forcer mode 'unit'
old_dom = "    // ====== HOME : routing modes ======\n    document.querySelectorAll('.mode-card').forEach(card => {"
new_dom = """    // ====== Scan-FEFO : retour vers TAF après scan ======
    const urlParams = new URLSearchParams(window.location.search);
    const returnTo = urlParams.get('return'); // 'taf' si appelé depuis TAF
    const forcedMode = urlParams.get('mode'); // 'unit' attendu pour Scan-FEFO

    // Si on arrive avec ?return=taf&mode=unit, on passe direct à l'écran unit
    if (returnTo === 'taf' && forcedMode === 'unit') {
      State.mode = 'unit';
      window.__scanFefoReturnMode = 'taf';
      setTimeout(() => {
        if (typeof resetUnitScreen === 'function') resetUnitScreen();
        if (typeof showScreen === 'function') showScreen('unit');
      }, 200);
    }

    // ====== HOME : routing modes ======
    document.querySelectorAll('.mode-card').forEach(card => {"""

if old_dom in sc and 'window.__scanFefoReturnMode' not in sc:
    sc = sc.replace(old_dom, new_dom)
    print("[Scanner] ✓ Détection ?return=taf au chargement")
    sc_changes += 1
elif 'window.__scanFefoReturnMode' in sc:
    print("[Scanner] • Détection return=taf déjà présente")
else:
    print("[Scanner] ⚠ Marker routing modes non trouvé")

# 2. Au moment de la validation unit, si mode return=taf, stocker le résultat + rediriger
old_validate = """        showToast('✓ Scan validé', 'success');
        showScreen('home');"""
new_validate = """        showToast('✓ Scan validé', 'success');
        // ====== Scan-FEFO : retour vers TAF ======
        if (window.__scanFefoReturnMode === 'taf' && State.unitType === 'etiquette_produit') {
          try {
            const { data: trac } = await sb.from('scan_tracabilite')
              .select('id, produit, article_id, lot, dlc')
              .eq('scan_id', State.unitScanId).single();
            if (trac) {
              localStorage.setItem('scan_fefo_result', JSON.stringify({
                scan_tracabilite_id: trac.id,
                article_id: trac.article_id,
                produit: trac.produit,
                lot: trac.lot,
                dlc: trac.dlc,
                scan_id: State.unitScanId,
                timestamp: Date.now()
              }));
            }
            window.location.href = '/taf/';
            return;
          } catch (e) {
            console.error('[Scan-FEFO] retour TAF échec:', e);
          }
        }
        showScreen('home');"""

if old_validate in sc and 'scan_fefo_result' not in sc:
    sc = sc.replace(old_validate, new_validate)
    print("[Scanner] ✓ btn-unit-validate : redirection vers TAF si return=taf")
    sc_changes += 1
elif 'scan_fefo_result' in sc:
    print("[Scanner] • Redirection TAF déjà branchée")
else:
    print("[Scanner] ⚠ Pattern btn-unit-validate showScreen('home') non trouvé")

if sc_changes > 0:
    sc_path.write_text(sc, encoding='utf-8')
    print(f"[Scanner] ✅ {sc_changes} modifs écrites.")

print(f"\nTotal : {taf_changes + sc_changes} modifs")
PYEOF

echo
echo "=== git status ==="
git status --short

if git diff --quiet -- taf/index.html scanner/index.html; then
  echo
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html scanner/index.html
git commit -m "feat(scan-fefo): phase 3 — bouton 📷 Scanner dans modale TAF

Branche le module Scanner sur le module TAF pour le workflow Scan-FEFO.

[TAF] taf/index.html
- SELECT fiche_ingredients élargi à est_principal + article_id
- Stocke window.__currentTafContext (task_id, fiche_id, tache) avant
  d'ouvrir la modale fiche
- renderFiche : nouvelle section 🎯 'Ingrédients à scanner' en tête
  de la modale, avec un bouton '📷 Scanner [nom]' violet par ingrédient
  principal. La table d'ingrédients met aussi 🎯 + fond jaune sur ces lignes
- openScannerForIngredient() : stocke un contexte en localStorage
  (scan_fefo_context) + navigue vers /scanner/?mode=unit&return=taf
- Listener DOMContentLoaded : au retour, lit localStorage.scan_fefo_result
  et affiche un toast 'Scan reçu : <produit> — DLC <date>'. La logique
  FEFO + sortie stock viendra en Phase 4 (TODO commenté)

[Scanner] scanner/index.html
- Au chargement, détecte ?return=taf&mode=unit dans l'URL
  → State.mode='unit' + showScreen('unit') automatique
- À la validation unit : si return=taf, récupère le scan_tracabilite
  (id, article_id, produit, lot, dlc), stocke dans localStorage
  (scan_fefo_result) et redirige vers /taf/ au lieu de showScreen('home')

Pré-requis : Phase 2 (checkbox 🎯 dans Production) doit être appliquée
pour qu'il y ait des ingrédients principaux à scanner."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
if [ -d "$ICLOUD_DIR" ]; then
  cp taf/index.html "$ICLOUD_DIR/taf/index.html" 2>/dev/null || true
  cp scanner/index.html "$ICLOUD_DIR/scanner/index.html" 2>/dev/null || true
  echo "✓ iCloud aligné (repo→iCloud) si dossier trouvé"
fi

echo
echo "=== Terminé ✓ ==="
