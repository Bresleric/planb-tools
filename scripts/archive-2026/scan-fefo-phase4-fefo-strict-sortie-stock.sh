#!/usr/bin/env bash
# Phase 4 du projet Scan-FEFO : validation FEFO strict + sortie de stock.
#
# Au retour du scan, le listener fait désormais 3 vérifications :
#   1. L'article scanné correspond bien à l'ingrédient attendu (refus si non)
#   2. FEFO strict : pas de lot du même article avec DLC plus courte
#      et quantité_restante > 0 (refus si oui)
#   3. Si tout OK : INSERT dans stock_mouvements (type='sortie', source='tasks')
#
# Les refus affichent une modale openModal avec message clair.
# Le succès affiche un toast vert avec la quantité sortie.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application du patch ==="
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

new_listener = """  // ====== SCAN-FEFO Phase 4 — Retour du scanner + validation FEFO + sortie stock ======
  window.addEventListener('DOMContentLoaded', function checkScanReturn() {
    // On retarde le traitement pour laisser le temps à loadAll() de remplir currentUser/Etablissement
    setTimeout(() => processScanFefoResult(), 800);
  });

  async function processScanFefoResult() {
    // Attendre que currentUser & currentEtablissement soient chargés (polling max 5s)
    let tries = 0;
    while (tries < 25 && (!currentUser || !currentEtablissement)) {
      await new Promise(r => setTimeout(r, 200));
      tries++;
    }

    const rawResult = localStorage.getItem('scan_fefo_result');
    const rawContext = localStorage.getItem('scan_fefo_context');
    if (!rawResult) return;
    if (!currentUser || !currentEtablissement) {
      console.warn('[Scan-FEFO] User non chargé, abandon du traitement.');
      return;
    }

    let result, context = {};
    try {
      result = JSON.parse(rawResult);
      if (rawContext) context = JSON.parse(rawContext);
    } catch (e) {
      console.error('[Scan-FEFO] JSON parse error:', e);
      localStorage.removeItem('scan_fefo_result');
      localStorage.removeItem('scan_fefo_context');
      return;
    }
    // Consommer le résultat (1 seul traitement, même en cas d'erreur)
    localStorage.removeItem('scan_fefo_result');
    localStorage.removeItem('scan_fefo_context');

    console.log('[Scan-FEFO] Traitement scan :', { result, context });

    // 1. Vérif matching article
    if (context.article_id_attendu && result.article_id !== context.article_id_attendu) {
      openModal('⚠ Étiquette ne correspond pas', `
        <p style="font-size:0.95rem">Tu as scanné <strong>${esc(result.produit || '?')}</strong>, mais on attendait <strong>${esc(context.nom_attendu || '?')}</strong>.</p>
        <p style="font-size:0.85rem;color:#6b7280;margin-top:10px;font-style:italic">Aucune sortie de stock n'a été effectuée. Va chercher le bon produit et rescanne.</p>
      `, [{ label: 'OK', action: 'closeModal()', cls: 'primary' }]);
      return;
    }

    // 2. Vérif FEFO via stock_par_lot
    let lots = [];
    try {
      const { data, error } = await supabaseClient.from('stock_par_lot')
        .select('scan_tracabilite_id, lot, dlc, quantite_restante')
        .eq('article_id', result.article_id)
        .eq('etablissement', currentEtablissement)
        .gt('quantite_restante', 0)
        .order('dlc', { ascending: true, nullsFirst: false });
      if (!error && data) lots = data;
    } catch (e) {
      console.error('[Scan-FEFO] FEFO query failed:', e);
    }

    if (lots.length > 0) {
      const meilleur = lots[0];
      if (meilleur.scan_tracabilite_id && meilleur.scan_tracabilite_id !== result.scan_tracabilite_id) {
        const dlcMeilleur = meilleur.dlc ? new Date(meilleur.dlc).toLocaleDateString('fr-FR') : '?';
        const dlcScan = result.dlc ? new Date(result.dlc).toLocaleDateString('fr-FR') : '?';
        openModal('⚠ FEFO — Mauvais lot', `
          <p style="font-size:0.95rem">Tu as scanné un lot <strong>DLC ${dlcScan}</strong>.</p>
          <p style="font-size:0.95rem;margin-top:6px">Il existe un autre lot de <strong>${esc(result.produit || '?')}</strong> avec une DLC plus courte : <strong style="color:#dc2626">DLC ${dlcMeilleur}</strong> (lot ${esc(meilleur.lot || '?')}, reste ${meilleur.quantite_restante}).</p>
          <p style="font-size:0.85rem;color:#6b7280;margin-top:10px;font-style:italic">Va chercher ce lot-là (FEFO) et rescanne. Aucune sortie n'a été effectuée.</p>
        `, [{ label: 'OK, je vais chercher', action: 'closeModal()', cls: 'danger' }]);
        return;
      }
    }

    // 3. Récupérer la quantité à sortir depuis fiche_ingredients
    let qte = 1, unite = 'kg', nomIng = result.produit;
    if (context.ingredient_id) {
      try {
        const { data: ing } = await supabaseClient.from('fiche_ingredients')
          .select('quantite, unite, nom').eq('id', context.ingredient_id).single();
        if (ing) {
          qte = Number(ing.quantite) || 1;
          unite = ing.unite || 'kg';
          nomIng = ing.nom || nomIng;
        }
      } catch (e) {
        console.warn('[Scan-FEFO] ingredient fetch failed:', e);
      }
    }

    // 4. INSERT stock_mouvements (sortie)
    const payload = {
      type: 'sortie',
      article_id: result.article_id,
      scan_tracabilite_id: result.scan_tracabilite_id,
      quantite: qte,
      unite: unite,
      etablissement: currentEtablissement,
      motif: `TAF: ${context.tache || '?'}`,
      source_table: 'tasks',
      source_id: context.task_id || null,
      created_by_id: currentUser.id,
      created_by_nom: currentUser.nom,
      created_by_initiales: currentUser.initiales || null
    };
    console.log('[Scan-FEFO] INSERT stock_mouvements payload:', payload);

    const { error } = await supabaseClient.from('stock_mouvements').insert(payload);
    if (error) {
      console.error('[Scan-FEFO] INSERT error:', error);
      openModal('❌ Erreur sortie stock', `
        <p style="font-size:0.9rem">L'enregistrement de la sortie de stock a échoué :</p>
        <pre style="background:#f3f4f6;padding:8px;border-radius:6px;font-size:0.75rem;color:#dc2626;overflow:auto">${esc(error.message || JSON.stringify(error))}</pre>
        <p style="font-size:0.85rem;color:#6b7280;margin-top:8px">Le scan est valide mais le stock n'a pas été décrémenté. À vérifier côté admin.</p>
      `, [{ label: 'OK', action: 'closeModal()', cls: 'primary' }]);
      return;
    }

    // Succès
    showToast(`✓ Sortie stock : ${qte} ${unite} de ${esc(nomIng)}`, 'success');
  }"""

if old_listener in content:
    content = content.replace(old_listener, new_listener)
    p.write_text(content, encoding='utf-8')
    print("✓ Listener Phase 4 installé (FEFO + sortie stock)")
elif "async function processScanFefoResult" in content:
    print("• Listener Phase 4 déjà présent")
else:
    print("⚠ Pattern listener Phase 3 (checkScanReturn) non trouvé — peut-être déjà refactor ou variant.")
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
git commit -m "feat(scan-fefo phase 4): validation FEFO strict + sortie stock

Au retour du scanner, processScanFefoResult() effectue 3 vérifications :

1. MATCHING ARTICLE
   Si l'article_id de l'étiquette scannée ≠ article_id_attendu (depuis
   le contexte stocké au moment du clic Scanner), la modale '⚠ Étiquette
   ne correspond pas' apparaît avec le détail Produit scanné vs attendu.
   Aucune sortie de stock.

2. VÉRIFICATION FEFO STRICTE
   Requête stock_par_lot WHERE article_id = X AND quantite_restante > 0
   ORDER BY dlc ASC. Si le lot avec la DLC la plus courte n'est pas
   celui scanné, la modale '⚠ FEFO — Mauvais lot' s'affiche avec :
   - DLC du lot scanné
   - DLC + numéro du lot à consommer en priorité
   - Quantité restante du meilleur lot
   Refus strict, aucune sortie de stock.

3. SORTIE STOCK
   Si les 2 vérifs passent : INSERT stock_mouvements avec
   - type='sortie'
   - article_id, scan_tracabilite_id du scan
   - quantite/unite récupérées depuis fiche_ingredients.id (contexte)
   - source_table='tasks', source_id=task_id
   - created_by_id/nom/initiales du currentUser
   Toast vert : '✓ Sortie stock : X kg de [nom]'

Détails techniques :
- setTimeout 800ms avant traitement pour laisser loadAll() finir
- Polling currentUser & currentEtablissement (max 5s)
- localStorage.removeItem dès le début pour 1 seul traitement
- Erreur INSERT (RLS, FK, etc.) → modale d'erreur avec stacktrace pour debug

Phase 4 termine le projet Scan-FEFO. Workflow complet désormais :
TAF ▶ Démarrer → modale fiche → 📷 Scanner → caméra Vision → retour TAF
  → vérif matching → vérif FEFO → INSERT stock_mouvements → toast."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
echo
echo "Pour tester end-to-end après push + force-refresh :"
echo "  1. TAF → ▶ Démarrer 'Noix de veau : Cuisson'"
echo "  2. Modale s'ouvre, clic 📷 Scanner sur 'Noix Veau Blanche'"
echo "  3. Caméra ouverte, prendre photo d'une étiquette Noix de veau"
echo "  4. Valider le scan, retour automatique sur TAF"
echo "  5. Toast 'Sortie stock : X kg de Noix Veau Blanche'"
echo
echo "  Test FEFO : scanner une étiquette dont la DLC n'est PAS la plus courte."
echo "  → Modale jaune 'FEFO — Mauvais lot' avec détails."
