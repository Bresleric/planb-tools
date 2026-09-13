#!/usr/bin/env bash
# La liste de création de tâche pioche désormais dans 2 sources :
# - Fiches techniques (cas actuel)
# - + Predefined_tasks sans fiche (51 entrées : 15 prod sans recette + 36 non-prod)
# Distinction visuelle : 🏭 fiche / 📋 predef. Le bouton 'À créer' reste pour
# ce qui n'existe nulle part.

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
# 1. Élargir renderPredefinedList : 2 sources
# ============================================================
old_filter = """    // Filtre sur nom, code_court, catégorie de la fiche
    const filtered = productionFiches
      .filter(f => f.actif !== false)
      .filter(f => !s
        || f.nom.toLowerCase().includes(s)
        || (f.code_court || '').toLowerCase().includes(s)
        || (f.categorie || '').toLowerCase().includes(s));

    // Liste des fiches (15 max)
    list.innerHTML = filtered.slice(0, 15).map(f => {
      const sel = (selectedPredefined?.source_type === 'fiche' && selectedPredefined?.fiche_id === f.id);
      const codeBadge = f.code_court
        ? `<span style="color:#7c3aed;font-weight:700;font-size:0.7rem;padding:1px 5px;background:#f3e8ff;border-radius:4px;margin-right:6px;">${esc(f.code_court)}</span>`
        : '';
      return `<div class="predef-item ${sel ? 'selected' : ''}" onclick="selectPredefined('${f.id}')">
        <span class="badge-production" style="margin-right:4px">🏭</span>${codeBadge}${esc(f.nom)}
        <span style="color:var(--gray-400);font-size:0.75rem;margin-left:6px">${esc(f.categorie || '')}</span>
      </div>`;
    }).join('');

    if (filtered.length === 0) {
      const msg = s
        ? `Aucune fiche ne correspond à « ${esc(s)} ».`
        : `Aucune fiche technique disponible.`;
      list.innerHTML = `<div class="predef-item" style="color:var(--gray-500);font-style:italic;cursor:default;border:none">${msg}</div>`;
    }"""

new_filter = """    // === Source 1 : Fiches techniques actives ===
    const filteredFiches = productionFiches
      .filter(f => f.actif !== false)
      .filter(f => !s
        || f.nom.toLowerCase().includes(s)
        || (f.code_court || '').toLowerCase().includes(s)
        || (f.categorie || '').toLowerCase().includes(s));

    // === Source 2 : Predefined_tasks actives sans fiche (15 prod sans recette + 36 non-prod) ===
    // Ces predefs sont des libellés légitimes qui n'ont pas de fiche dédiée
    // (ex: 'Nettoyer hotte', 'Mariner viande', 'Sauce poisson', 'A créer').
    const filteredPredefs = (predefinedTasks || [])
      .filter(p => p.actif !== false && !p.fiche_id)
      .filter(p => !s
        || (p.nom || '').toLowerCase().includes(s)
        || (p.categorie || '').toLowerCase().includes(s));

    // === Rendu : Fiches d'abord (max 10), puis predefs (max 8) ===
    let html = '';

    if (filteredFiches.length > 0) {
      html += filteredFiches.slice(0, 10).map(f => {
        const sel = (selectedPredefined?.source_type === 'fiche' && selectedPredefined?.fiche_id === f.id);
        const codeBadge = f.code_court
          ? `<span style="color:#7c3aed;font-weight:700;font-size:0.7rem;padding:1px 5px;background:#f3e8ff;border-radius:4px;margin-right:6px;">${esc(f.code_court)}</span>`
          : '';
        return `<div class="predef-item ${sel ? 'selected' : ''}" onclick="selectPredefined('${f.id}')">
          <span class="badge-production" style="margin-right:4px">🏭</span>${codeBadge}${esc(f.nom)}
          <span style="color:var(--gray-400);font-size:0.75rem;margin-left:6px">${esc(f.categorie || '')}</span>
        </div>`;
      }).join('');
    }

    if (filteredPredefs.length > 0) {
      if (filteredFiches.length > 0) {
        html += `<div style="font-size:0.7rem;color:var(--gray-500);text-transform:uppercase;font-weight:600;padding:8px 4px 4px;border-top:1px solid var(--gray-100);margin-top:4px;">Tâches sans fiche technique</div>`;
      }
      html += filteredPredefs.slice(0, 8).map(p => {
        const sel = (selectedPredefined?.source_type === 'predef' && selectedPredefined?.id === p.id);
        const icon = p.is_production ? '📋' : '🧹';
        return `<div class="predef-item ${sel ? 'selected' : ''}" onclick="selectPredefTask('${p.id}')">
          <span style="margin-right:4px">${icon}</span>${esc(p.nom)}
          <span style="color:var(--gray-400);font-size:0.75rem;margin-left:6px">${esc(p.categorie || '')}</span>
        </div>`;
      }).join('');
    }

    if (filteredFiches.length === 0 && filteredPredefs.length === 0) {
      const msg = s
        ? `Aucune fiche ou tâche prédéfinie ne correspond à « ${esc(s)} ».`
        : `Aucune fiche/tâche disponible.`;
      html = `<div class="predef-item" style="color:var(--gray-500);font-style:italic;cursor:default;border:none">${msg}</div>`;
    }

    list.innerHTML = html;"""

if old_filter in content:
    content = content.replace(old_filter, new_filter)
    print("✓ renderPredefinedList : 2 sources (fiches + predefs sans fiche)")
    changes += 1
elif "Source 2 : Predefined_tasks actives sans fiche" in content:
    print("• renderPredefinedList déjà sur 2 sources")
else:
    print("⚠ renderPredefinedList : ancien filter non trouvé")

# ============================================================
# 2. Ajouter selectPredefTask juste après selectPredefined
# ============================================================
old_close = """      // Phase 2 — Propagation des nouveaux champs TAF depuis la fiche
      if (fiche.equipe) {
        selectedPredefined.equipe = fiche.equipe;
        document.querySelectorAll('#create-equipe .chip').forEach(c => {
          c.classList.toggle('active', c.dataset.val === fiche.equipe);
        });
      }
      if (fiche.creneau) {
        selectedPredefined.creneau = fiche.creneau;
        document.querySelectorAll('#create-creneau .chip').forEach(c => {
          c.classList.toggle('active', c.dataset.val === fiche.creneau);
        });
      }
      // categorie_taf de la fiche (Cuissons, Pâtisserie, etc.) écrase 'Production' choisi par défaut
      if (fiche.categorie_taf) {
        document.querySelectorAll('#create-categorie .chip').forEach(c => {
          c.classList.toggle('active', c.dataset.val === fiche.categorie_taf);
        });
      }

    // (catégorie pré-sélectionnée plus haut depuis fiche.categorie_taf ou par défaut 'Production')
    if (!document.querySelector('#create-categorie .chip.active')) {
      document.querySelectorAll('#create-categorie .chip').forEach(c => {
        c.classList.toggle('active', c.dataset.val === 'Production');
      });
    }
  }

  function selectCustomTask(name) {"""

new_close = """      // Phase 2 — Propagation des nouveaux champs TAF depuis la fiche
      if (fiche.equipe) {
        selectedPredefined.equipe = fiche.equipe;
        document.querySelectorAll('#create-equipe .chip').forEach(c => {
          c.classList.toggle('active', c.dataset.val === fiche.equipe);
        });
      }
      if (fiche.creneau) {
        selectedPredefined.creneau = fiche.creneau;
        document.querySelectorAll('#create-creneau .chip').forEach(c => {
          c.classList.toggle('active', c.dataset.val === fiche.creneau);
        });
      }
      // categorie_taf de la fiche (Cuissons, Pâtisserie, etc.) écrase 'Production' choisi par défaut
      if (fiche.categorie_taf) {
        document.querySelectorAll('#create-categorie .chip').forEach(c => {
          c.classList.toggle('active', c.dataset.val === fiche.categorie_taf);
        });
      }

    // (catégorie pré-sélectionnée plus haut depuis fiche.categorie_taf ou par défaut 'Production')
    if (!document.querySelector('#create-categorie .chip.active')) {
      document.querySelectorAll('#create-categorie .chip').forEach(c => {
        c.classList.toggle('active', c.dataset.val === 'Production');
      });
    }
  }

  // Sélection d'une predefined_task (sans fiche) : nettoyage, vérif, prod sans recette, etc.
  function selectPredefTask(predefId) {
    const p = (predefinedTasks || []).find(x => x.id === predefId);
    if (!p) return;
    selectedPredefined = {
      source_type: 'predef',
      id: p.id,
      fiche_id: null,
      nom: p.nom,
      is_production: !!p.is_production,
      categorie_production: p.categorie_production || null
    };
    const icon = p.is_production ? '📋' : '🧹';
    const area = document.getElementById('selected-task-area');
    area.innerHTML = `<div class="selected-task-display">
      <span class="name">${icon} ${esc(p.nom)}</span>
      <button class="btn-clear" onclick="clearPredefined()">✕</button>
    </div>`;
    document.getElementById('search-predef').style.display = 'none';
    document.getElementById('predef-list').style.display = 'none';

    // Propagation des attributs de la predef
    if (p.equipe) {
      selectedPredefined.equipe = p.equipe;
      document.querySelectorAll('#create-equipe .chip').forEach(c => {
        c.classList.toggle('active', c.dataset.val === p.equipe);
      });
    }
    if (p.creneau) {
      selectedPredefined.creneau = p.creneau;
      document.querySelectorAll('#create-creneau .chip').forEach(c => {
        c.classList.toggle('active', c.dataset.val === p.creneau);
      });
    }
    if (p.categorie) {
      document.querySelectorAll('#create-categorie .chip').forEach(c => {
        c.classList.toggle('active', c.dataset.val === p.categorie);
      });
    }
  }

  function selectCustomTask(name) {"""

if old_close in content:
    content = content.replace(old_close, new_close)
    print("✓ Nouvelle fonction selectPredefTask ajoutée")
    changes += 1
elif "function selectPredefTask" in content:
    print("• selectPredefTask déjà présente")
else:
    print("⚠ selectPredefTask : bloc d'insertion non trouvé")

# ============================================================
# 3. submitCreate : si source_type='predef', is_production, fiche_id selon predef (pas a_traiter)
# ============================================================
old_submit = """      // Source = fiche technique : propage is_production + fiche_id + cat. prod
      if (selectedPredefined.source_type === 'fiche' || selectedPredefined.is_production) {
        baseData.is_production = true;
        baseData.fiche_id = selectedPredefined.fiche_id || null;
        baseData.categorie_production = selectedPredefined.categorie_production || null;
      }

      // Source = À créer : flag a_traiter pour l'admin
      if (selectedPredefined.source_type === 'a_creer' || selectedPredefined.is_a_creer) {
        baseData.a_traiter = true;
      }"""

new_submit = """      // Source = fiche technique : propage is_production + fiche_id + cat. prod
      if (selectedPredefined.source_type === 'fiche') {
        baseData.is_production = true;
        baseData.fiche_id = selectedPredefined.fiche_id || null;
        baseData.categorie_production = selectedPredefined.categorie_production || null;
      }

      // Source = predef sans fiche : on copie ses attributs (pas de a_traiter, c'est légitime)
      if (selectedPredefined.source_type === 'predef') {
        baseData.is_production = !!selectedPredefined.is_production;
        baseData.fiche_id = null;
        baseData.categorie_production = selectedPredefined.categorie_production || null;
      }

      // Source = À créer : flag a_traiter pour l'admin
      if (selectedPredefined.source_type === 'a_creer' || selectedPredefined.is_a_creer) {
        baseData.a_traiter = true;
      }"""

if old_submit in content:
    content = content.replace(old_submit, new_submit)
    print("✓ submitCreate : gestion source 'predef' ajoutée")
    changes += 1
elif "source_type === 'predef'" in content and "baseData.fiche_id = null" in content:
    print("• submitCreate : déjà géré")
else:
    print("⚠ submitCreate : bloc à modifier non trouvé")

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
git commit -m "feat(taf/create): liste 2 sources (fiches + predefs sans fiche)

Symptôme : 'Fond de tarte' existait comme predefined_task mais
n'apparaissait pas dans la liste de création (qui ne piochait que
dans les fiches techniques). L'utilisateur tapait 'fond' → rien
trouvé → bouton À créer → tâche custom marquée a_traiter=true.

Fix : la liste pioche maintenant dans 2 sources :
1. Fiches techniques actives (cas actuel)
   → icône 🏭 + code court violet + cat. fiche
2. Predefined_tasks actives SANS fiche_id (51 entrées : 15 prod
   sans recette + 36 non-prod : Nettoyage, Sauces simples, Vérif...)
   → icône 📋 (production) ou 🧹 (non-production), cat. TAF

Séparateur visuel 'Tâches sans fiche technique' entre les deux blocs.

Nouvelle fonction selectPredefTask(id) :
- Copie nom, is_production, categorie_production, equipe, creneau,
  categorie depuis la predef
- N'AJOUTE PAS a_traiter (c'est une predef légitime, pas du custom)

submitCreate gère désormais 3 source_type :
- 'fiche' : is_production=true + fiche_id (cas actuel)
- 'predef' : is_production selon predef, fiche_id=null
- 'a_creer' : a_traiter=true (custom)

Bouton À créer reste en bas pour les libellés vraiment nouveaux."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
