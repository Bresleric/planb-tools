// ============================================================
// Stock PF/PI — onglet du Module Production
// Dépendances globales (définies dans index.html) :
//   sb, currentUser, currentEtablissement,
//   showToast, showConfirmModal, canCreateStock, canDeleteStock, roleHierarchy
// ============================================================
(function() {
  'use strict';

  const PIECES = ['CUISINE', 'LABO', 'CAVE', 'SALLE', 'BAR'];
  const CAT_LABELS = {
    produit_fini: 'PF',
    produit_intermediaire: 'PI',
    mise_en_place: 'MEP'
  };
  const FAMILLE_LABELS = {
    GN: 'Bacs GN', Bac: 'Bacs', Sachet: 'Sachets',
    Seau: 'Seaux', Boite: 'Boîtes', Plaque: 'Plaques', Autre: 'Autres'
  };
  const TYPE_UNITE_LABELS = {
    masse: 'Masse', volume: 'Volume', unitaire: 'Unitaire',
    pourcentage: 'Pourcentage', autre: 'Autres'
  };

  const state = {
    booted: false,
    htmlInjected: false,
    rows: [],           // stock_pf_pi joints (fiche, meuble, contenant)
    meubles: [],        // [{id, nom, categorie, nb_niveaux}]
    contenants: [],     // [{id, code, libelle, famille, ordre}]
    unites: [],         // [{code, libelle, symbole, type, ordre}]
    produits: [],       // [{id, nom, categorie}]
    emplacements: [],   // distinct emplacements vus
    filterSearch: '',
    filterPiece: 'all',
    filterCat: 'all',
    filterMeuble: 'all',
    editingId: null,
    lastEtablissement: null
  };

  // ----- Helpers -----
  const $ = (sel, ctx) => (ctx || document).querySelector(sel);
  const $$ = (sel, ctx) => Array.from((ctx || document).querySelectorAll(sel));

  function fmtQty(q, unite) {
    if (q == null) return '—';
    const n = Number(q);
    const txt = (Math.abs(n - Math.round(n)) < 0.001) ? String(Math.round(n)) : n.toFixed(2).replace(/\.?0+$/, '');
    return unite ? `${txt} ${unite}` : txt;
  }

  function fmtDlc(dlcStr) {
    if (!dlcStr) return { txt: '—', cls: '' };
    const dlc = new Date(dlcStr + 'T23:59:59');
    const now = new Date();
    const diffH = (dlc - now) / 36e5;
    const day = dlc.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
    let cls = '';
    if (diffH < 24) cls = 'alert';
    else if (diffH < 48) cls = 'warn';
    return { txt: day, cls };
  }

  function niveauLabel(niveau, nbNiveaux) {
    if (!niveau) return '—';
    if (!nbNiveaux || nbNiveaux <= 1) return String(niveau);
    if (niveau === 1) return '1 (bas)';
    if (niveau === nbNiveaux) return `${niveau} (haut)`;
    return String(niveau);
  }

  // ----- Bootstrap : injection markup + chargement -----
  async function init() {
    if (!state.htmlInjected) {
      try {
        const res = await fetch('stock-pf-pi.html', { cache: 'no-cache' });
        if (!res.ok) throw new Error('HTTP ' + res.status);
        const html = await res.text();
        injectHtml(html);
      } catch (e) {
        console.error('[stock-pf-pi] Chargement markup KO :', e);
        const host = document.getElementById('tab-stock');
        if (host) host.innerHTML = `<div style="text-align:center; padding:40px; color:#ef4444;">Erreur de chargement du markup : ${e.message}</div>`;
        return;
      }
      bindEvents();
      state.htmlInjected = true;
    }

    // Reset si on a changé d'établissement entre 2 visites
    if (state.lastEtablissement !== currentEtablissement) {
      state.booted = false;
      state.lastEtablissement = currentEtablissement;
    }

    if (!state.booted) {
      await loadReferentiels();
      state.booted = true;
    }
    await loadStock();
  }

  function injectHtml(html) {
    const wrapper = document.createElement('div');
    wrapper.innerHTML = html;
    // Déplacer les <style> vers <head>
    wrapper.querySelectorAll('style').forEach(s => document.head.appendChild(s));
    // Déplacer la modale vers <body>
    const modal = wrapper.querySelector('#stock-modal-bg');
    if (modal) document.body.appendChild(modal);
    // Le reste va dans #tab-stock
    const host = document.getElementById('tab-stock');
    if (!host) return;
    host.innerHTML = '';
    while (wrapper.firstChild) host.appendChild(wrapper.firstChild);
  }

  // ----- Référentiels (meubles, contenants, unites, produits) -----
  async function loadReferentiels() {
    const [meublesRes, contenantsRes, unitesRes, produitsRes] = await Promise.all([
      sb.from('temp_frigos')
        .select('id, nom, categorie, nb_niveaux')
        .eq('etablissement', currentEtablissement)
        .eq('actif', true)
        .order('categorie').order('ordre'),
      sb.from('contenants').select('*').eq('actif', true).order('famille').order('ordre'),
      sb.from('unites').select('*').eq('actif', true).order('type').order('ordre'),
      sb.from('fiches_techniques')
        .select('id, nom, categorie')
        .eq('etablissement', currentEtablissement)
        .eq('actif', true)
        .in('categorie', ['produit_fini', 'produit_intermediaire', 'mise_en_place'])
        .order('nom')
    ]);

    state.meubles = meublesRes.data || [];
    state.contenants = contenantsRes.data || [];
    state.unites = unitesRes.data || [];
    state.produits = produitsRes.data || [];

    populateMeubleFilter();
  }

  function populateMeubleFilter() {
    const sel = document.getElementById('stock-meuble-filter');
    if (!sel) return;
    const opts = ['<option value="all">Tous</option>']
      .concat(state.meubles.map(m => `<option value="${m.id}">${escapeHtml(m.nom)} (${m.categorie})</option>`));
    sel.innerHTML = opts.join('');
  }

  // ----- Chargement du stock -----
  async function loadStock() {
    const tbody = document.getElementById('stock-tbody');
    if (tbody) tbody.innerHTML = '<tr><td colspan="12" style="text-align:center; padding:30px; color:var(--gray-400);">⏳ Chargement…</td></tr>';

    const { data, error } = await sb
      .from('stock_pf_pi')
      .select('*')
      .eq('etablissement', currentEtablissement)
      .order('piece')
      .order('meuble_nom')
      .order('niveau', { ascending: false })
      .order('produit_nom');

    if (error) {
      if (tbody) tbody.innerHTML = `<tr><td colspan="12" style="text-align:center; padding:30px; color:#ef4444;">Erreur : ${error.message}</td></tr>`;
      return;
    }
    state.rows = data || [];

    // Distinct emplacements pour autocomplete
    const empSet = new Set();
    state.rows.forEach(r => { if (r.emplacement && r.emplacement.trim()) empSet.add(r.emplacement.trim()); });
    state.emplacements = Array.from(empSet).sort();
    const dl = document.getElementById('stock-emplacement-list');
    if (dl) dl.innerHTML = state.emplacements.map(v => `<option value="${escapeHtml(v)}"></option>`).join('');

    render();
  }

  // ----- Filtres -----
  function getFiltered() {
    const s = state.filterSearch.toLowerCase().trim();
    return state.rows.filter(r => {
      if (state.filterPiece !== 'all' && r.piece !== state.filterPiece) return false;
      if (state.filterCat !== 'all' && r.produit_categorie !== state.filterCat) return false;
      if (state.filterMeuble !== 'all' && r.meuble_id !== state.filterMeuble) return false;
      if (s && !(r.produit_nom || '').toLowerCase().includes(s)) return false;
      return true;
    });
  }

  // ----- Render -----
  function render() {
    const tbody = document.getElementById('stock-tbody');
    if (!tbody) return;
    const rows = getFiltered();

    // Summary
    const distinctProds = new Set(rows.map(r => r.produit_nom)).size;
    const dlcAlert = rows.filter(r => {
      if (!r.dlc) return false;
      const h = (new Date(r.dlc + 'T23:59:59') - new Date()) / 36e5;
      return h < 48;
    }).length;
    document.getElementById('stock-count-lignes').textContent = rows.length;
    document.getElementById('stock-count-prods').textContent = distinctProds;
    document.getElementById('stock-count-dlc').innerHTML = dlcAlert > 0
      ? `<strong style="color:#dc2626;">${dlcAlert}</strong> DLC &lt; 48h`
      : '<span style="color:var(--gray-400);">aucune DLC critique</span>';

    if (rows.length === 0) {
      tbody.innerHTML = '<tr><td colspan="12" style="text-align:center; padding:40px; color:var(--gray-400);">📭 Aucune ligne de stock</td></tr>';
      return;
    }

    const html = rows.map(r => {
      const dlc = fmtDlc(r.dlc);
      const meuble = state.meubles.find(m => m.id === r.meuble_id);
      const nbNiv = meuble ? meuble.nb_niveaux : null;
      const cat = r.produit_categorie || '';
      const catLabel = CAT_LABELS[cat] || '';
      const uniteSymb = (state.unites.find(u => u.code === r.unite) || {}).symbole || r.unite || '';
      return `
        <tr data-id="${r.id}">
          <td>${escapeHtml(r.piece || '')}</td>
          <td>${escapeHtml(r.meuble_nom || '')}</td>
          <td>${escapeHtml(r.emplacement || '—')}</td>
          <td>${niveauLabel(r.niveau, nbNiv)}</td>
          <td class="prod">${escapeHtml(r.produit_nom || '')}</td>
          <td>${catLabel ? `<span class="badge ${cat}">${catLabel}</span>` : '<span class="badge muted">—</span>'}</td>
          <td class="num">${fmtQty(r.quantite, null)}</td>
          <td>${escapeHtml(uniteSymb)}</td>
          <td>${escapeHtml(r.contenant_libelle || '—')}</td>
          <td class="dlc ${dlc.cls}">${dlc.txt}</td>
          <td class="obs" title="${escapeHtml(r.observations || '')}">${escapeHtml(r.observations || '')}</td>
          <td class="actions">
            <button class="stock-icon-btn" data-action="edit" title="Éditer">✏️</button>
            ${canDeleteStock() ? `<button class="stock-icon-btn danger" data-action="delete" title="Supprimer">🗑️</button>` : ''}
          </td>
        </tr>
      `;
    }).join('');
    tbody.innerHTML = html;

    // Délégation clic
    tbody.querySelectorAll('tr').forEach(tr => {
      tr.addEventListener('click', (e) => {
        const id = tr.dataset.id;
        const btn = e.target.closest('[data-action]');
        if (btn && btn.dataset.action === 'delete') {
          e.stopPropagation();
          deleteRow(id);
          return;
        }
        openModal(id);
      });
    });
  }

  // ----- Modal : ouvrir / fermer -----
  function openModal(id) {
    if (id && !canCreateStock()) {
      showToast('Droits insuffisants pour éditer', 'error');
      return;
    }
    if (!id && !canCreateStock()) {
      showToast('Droits insuffisants pour créer', 'error');
      return;
    }

    state.editingId = id || null;
    const row = id ? state.rows.find(r => r.id === id) : null;

    document.getElementById('stock-modal-title').textContent = row ? 'Éditer la ligne' : 'Nouvelle ligne';
    document.getElementById('sm-id').value = row ? row.id : '';
    document.getElementById('sm-produit').value = row ? (row.produit_nom || '') : '';
    document.getElementById('sm-fiche-id').value = row && row.fiche_id ? row.fiche_id : '';
    document.getElementById('sm-produit-cat').value = row && row.produit_categorie ? row.produit_categorie : '';

    populatePieceSelect(row ? row.piece : '');
    populateMeubleSelect(row ? row.piece : '', row ? row.meuble_id : '');
    populateNiveauSelect(row ? row.meuble_id : '', row ? row.niveau : '');
    populateContenantSelect(row ? row.contenant_id : '');
    populateUniteSelect(row ? row.unite : '');

    document.getElementById('sm-emplacement').value = row ? (row.emplacement || '') : '';
    document.getElementById('sm-quantite').value = row && row.quantite != null ? row.quantite : '';
    document.getElementById('sm-dlc').value = row && row.dlc ? row.dlc : '';
    document.getElementById('sm-observations').value = row ? (row.observations || '') : '';

    const meta = document.getElementById('sm-meta');
    if (row && row.date_releve) {
      const when = new Date(row.date_releve);
      const by = row.releve_par_initiales || row.releve_par_nom || '';
      meta.style.display = '';
      meta.textContent = `Relevé le ${when.toLocaleString('fr-FR')}${by ? ' par ' + by : ''}`;
    } else {
      meta.style.display = 'none';
      meta.textContent = '';
    }

    const delBtn = document.getElementById('sm-delete');
    delBtn.style.display = (row && canDeleteStock()) ? '' : 'none';

    document.getElementById('sm-prod-results').classList.remove('visible');
    document.getElementById('stock-modal-bg').classList.add('visible');
    setTimeout(() => document.getElementById('sm-produit').focus(), 50);
  }

  function closeModal() {
    document.getElementById('stock-modal-bg').classList.remove('visible');
    state.editingId = null;
  }

  // ----- Selects de la modale -----
  function populatePieceSelect(selected) {
    const pieces = Array.from(new Set(state.meubles.map(m => m.categorie))).sort();
    const list = pieces.length ? pieces : PIECES;
    const sel = document.getElementById('sm-piece');
    sel.innerHTML = '<option value="">—</option>' + list.map(p =>
      `<option value="${p}" ${p === selected ? 'selected' : ''}>${p}</option>`
    ).join('');
  }

  function populateMeubleSelect(piece, selectedId) {
    const sel = document.getElementById('sm-meuble');
    const filtered = piece ? state.meubles.filter(m => m.categorie === piece) : state.meubles;
    sel.innerHTML = '<option value="">—</option>' + filtered.map(m =>
      `<option value="${m.id}" data-niv="${m.nb_niveaux || 1}" data-nom="${escapeHtml(m.nom)}" ${m.id === selectedId ? 'selected' : ''}>${escapeHtml(m.nom)}</option>`
    ).join('');
  }

  function populateNiveauSelect(meubleId, selected) {
    const sel = document.getElementById('sm-niveau');
    const meuble = state.meubles.find(m => m.id === meubleId);
    const nb = meuble ? (meuble.nb_niveaux || 1) : 0;
    if (!nb || nb <= 1) {
      sel.innerHTML = '<option value="">—</option>';
      return;
    }
    const opts = ['<option value="">—</option>'];
    for (let i = 1; i <= nb; i++) {
      let label = String(i);
      if (i === 1) label = '1 (bas)';
      else if (i === nb) label = `${i} (haut)`;
      opts.push(`<option value="${i}" ${i == selected ? 'selected' : ''}>${label}</option>`);
    }
    sel.innerHTML = opts.join('');
  }

  function populateContenantSelect(selectedId) {
    const byFam = {};
    state.contenants.forEach(c => {
      (byFam[c.famille] = byFam[c.famille] || []).push(c);
    });
    const sel = document.getElementById('sm-contenant');
    const fams = Object.keys(byFam).sort((a, b) => (FAMILLE_LABELS[a] || a).localeCompare(FAMILLE_LABELS[b] || b));
    let html = '<option value="">—</option>';
    fams.forEach(f => {
      html += `<optgroup label="${FAMILLE_LABELS[f] || f}">`;
      byFam[f].forEach(c => {
        html += `<option value="${c.id}" data-libelle="${escapeHtml(c.libelle)}" ${c.id === selectedId ? 'selected' : ''}>${escapeHtml(c.libelle)}</option>`;
      });
      html += '</optgroup>';
    });
    sel.innerHTML = html;
  }

  function populateUniteSelect(selectedCode) {
    const byType = {};
    state.unites.forEach(u => {
      (byType[u.type] = byType[u.type] || []).push(u);
    });
    const sel = document.getElementById('sm-unite');
    const order = ['masse', 'volume', 'unitaire', 'pourcentage', 'autre'];
    const types = Object.keys(byType).sort((a, b) => order.indexOf(a) - order.indexOf(b));
    let html = '<option value="">—</option>';
    types.forEach(t => {
      html += `<optgroup label="${TYPE_UNITE_LABELS[t] || t}">`;
      byType[t].forEach(u => {
        html += `<option value="${u.code}" ${u.code === selectedCode ? 'selected' : ''}>${escapeHtml(u.libelle)} (${escapeHtml(u.symbole)})</option>`;
      });
      html += '</optgroup>';
    });
    sel.innerHTML = html;
  }

  // ----- Combobox produit -----
  function renderProduitResults(query) {
    const results = document.getElementById('sm-prod-results');
    const q = (query || '').toLowerCase().trim();
    let list = state.produits;
    if (q) list = list.filter(p => p.nom.toLowerCase().includes(q));
    list = list.slice(0, 30);

    if (list.length === 0) {
      results.innerHTML = `<div class="sm-prod-free">Aucune fiche — la saisie libre "${escapeHtml(query)}" sera enregistrée telle quelle</div>`;
    } else {
      results.innerHTML = list.map(p => `
        <div class="sm-prod-result" data-id="${p.id}" data-cat="${p.categorie}" data-nom="${escapeHtml(p.nom)}">
          <div>${escapeHtml(p.nom)}</div>
          <div class="sm-prod-cat">${CAT_LABELS[p.categorie] || p.categorie}</div>
        </div>
      `).join('');
      results.querySelectorAll('.sm-prod-result').forEach(el => {
        el.addEventListener('mousedown', (e) => {
          e.preventDefault();
          document.getElementById('sm-produit').value = el.dataset.nom;
          document.getElementById('sm-fiche-id').value = el.dataset.id;
          document.getElementById('sm-produit-cat').value = el.dataset.cat;
          results.classList.remove('visible');
        });
      });
    }
    results.classList.add('visible');
  }

  // ----- Save -----
  async function save() {
    const produitNom = document.getElementById('sm-produit').value.trim();
    const ficheId = document.getElementById('sm-fiche-id').value || null;
    let produitCat = document.getElementById('sm-produit-cat').value || null;
    const pieceSel = document.getElementById('sm-piece').value;
    const meubleSel = document.getElementById('sm-meuble');
    const meubleId = meubleSel.value || null;
    const meubleOpt = meubleSel.options[meubleSel.selectedIndex];
    const meubleNom = meubleOpt ? (meubleOpt.dataset.nom || meubleOpt.textContent) : '';
    const niveauVal = document.getElementById('sm-niveau').value;
    const emplacement = document.getElementById('sm-emplacement').value.trim() || null;
    const contenantSel = document.getElementById('sm-contenant');
    const contenantId = contenantSel.value || null;
    const contenantOpt = contenantSel.options[contenantSel.selectedIndex];
    const contenantLib = contenantOpt ? (contenantOpt.dataset.libelle || contenantOpt.textContent) : null;
    const unite = document.getElementById('sm-unite').value || null;
    const qty = document.getElementById('sm-quantite').value;
    const dlc = document.getElementById('sm-dlc').value || null;
    const observations = document.getElementById('sm-observations').value.trim() || null;

    if (!produitNom) { showToast('Produit obligatoire', 'error'); return; }
    if (!pieceSel) { showToast('Pièce obligatoire', 'error'); return; }
    if (!meubleId || !meubleNom) { showToast('Meuble obligatoire', 'error'); return; }
    if (qty === '' || qty == null || isNaN(Number(qty))) { showToast('Quantité obligatoire', 'error'); return; }
    if (!unite) { showToast('Unité obligatoire', 'error'); return; }

    // Si on a une fiche liée, snapshot sa catégorie (au cas où elle aurait changé)
    if (ficheId) {
      const p = state.produits.find(x => x.id === ficheId);
      if (p) produitCat = p.categorie;
    }

    const payload = {
      fiche_id: ficheId,
      produit_nom: produitNom,
      produit_categorie: produitCat,
      meuble_id: meubleId,
      meuble_nom: meubleNom,
      piece: pieceSel,
      emplacement,
      niveau: niveauVal ? Number(niveauVal) : null,
      contenant_id: contenantId,
      contenant_libelle: contenantId ? contenantLib : null,
      unite,
      quantite: Number(qty),
      observations,
      etablissement: currentEtablissement,
      dlc
    };

    const saveBtn = document.getElementById('sm-save');
    saveBtn.disabled = true;
    saveBtn.textContent = '…';

    try {
      if (state.editingId) {
        // Édition : ne touche pas date_releve, mais on met à jour les snapshots
        const { error } = await sb.from('stock_pf_pi').update(payload).eq('id', state.editingId);
        if (error) throw error;
        showToast('✓ Ligne mise à jour', 'success');
      } else {
        // Création : ajoute la traçabilité du relevé
        payload.releve_par_id = currentUser.id || null;
        payload.releve_par_nom = currentUser.nom || null;
        payload.releve_par_initiales = currentUser.initiales || null;
        const { error } = await sb.from('stock_pf_pi').insert([payload]);
        if (error) throw error;
        showToast('✓ Ligne créée', 'success');
      }
      closeModal();
      await loadStock();
    } catch (e) {
      console.error('[stock-pf-pi] save KO :', e);
      showToast('Erreur : ' + e.message, 'error');
    } finally {
      saveBtn.disabled = false;
      saveBtn.textContent = 'Enregistrer';
    }
  }

  async function deleteRow(id) {
    if (!canDeleteStock()) { showToast('Droits insuffisants', 'error'); return; }
    const row = state.rows.find(r => r.id === id);
    if (!row) return;
    showConfirmModal(
      'Supprimer la ligne ?',
      `${row.produit_nom} — ${row.meuble_nom}${row.emplacement ? ' / ' + row.emplacement : ''}`,
      async () => {
        try {
          const { error } = await sb.from('stock_pf_pi').delete().eq('id', id);
          if (error) throw error;
          showToast('Ligne supprimée', 'success');
          if (state.editingId === id) closeModal();
          await loadStock();
        } catch (e) {
          showToast('Erreur : ' + e.message, 'error');
        }
      }
    );
  }

  // ----- Bind events (filtres + modale) -----
  function bindEvents() {
    // Bouton + Nouvelle ligne (filtres)
    const btnNew = document.getElementById('stock-btn-new');
    if (btnNew) btnNew.addEventListener('click', () => openModal(null));

    // Recherche
    const search = document.getElementById('stock-search');
    if (search) search.addEventListener('input', () => {
      state.filterSearch = search.value;
      render();
    });

    // Chips Pièce
    document.querySelectorAll('[data-stock-piece]').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('[data-stock-piece]').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.filterPiece = chip.dataset.stockPiece;
        render();
      });
    });

    // Chips Catégorie
    document.querySelectorAll('[data-stock-cat]').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('[data-stock-cat]').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.filterCat = chip.dataset.stockCat;
        render();
      });
    });

    // Select Meuble
    const meubleFilter = document.getElementById('stock-meuble-filter');
    if (meubleFilter) meubleFilter.addEventListener('change', () => {
      state.filterMeuble = meubleFilter.value;
      render();
    });

    // Modale : boutons
    document.getElementById('sm-cancel').addEventListener('click', closeModal);
    document.getElementById('sm-save').addEventListener('click', save);
    document.getElementById('sm-delete').addEventListener('click', () => {
      if (state.editingId) deleteRow(state.editingId);
    });

    // Fermer en cliquant le fond
    document.getElementById('stock-modal-bg').addEventListener('click', (e) => {
      if (e.target.id === 'stock-modal-bg') closeModal();
    });

    // Combobox produit
    const prodInput = document.getElementById('sm-produit');
    prodInput.addEventListener('input', () => {
      // Si la saisie ne correspond plus à la fiche actuelle, on délie
      document.getElementById('sm-fiche-id').value = '';
      document.getElementById('sm-produit-cat').value = '';
      renderProduitResults(prodInput.value);
    });
    prodInput.addEventListener('focus', () => renderProduitResults(prodInput.value));
    prodInput.addEventListener('blur', () => {
      // Léger délai pour laisser le mousedown se déclencher
      setTimeout(() => document.getElementById('sm-prod-results').classList.remove('visible'), 150);
    });

    // Cascades pièce → meuble → niveau
    document.getElementById('sm-piece').addEventListener('change', (e) => {
      populateMeubleSelect(e.target.value, '');
      populateNiveauSelect('', '');
    });
    document.getElementById('sm-meuble').addEventListener('change', (e) => {
      const meubleId = e.target.value;
      populateNiveauSelect(meubleId, '');
      // Aligner aussi la pièce si elle n'est pas cohérente
      const m = state.meubles.find(mm => mm.id === meubleId);
      if (m) document.getElementById('sm-piece').value = m.categorie;
    });
  }

  // ----- Util -----
  function escapeHtml(s) {
    if (s == null) return '';
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // ----- API publique -----
  window.StockPFPI = {
    init,
    openModal: () => openModal(null),
    reload: loadStock
  };
})();
