#!/usr/bin/env bash
# Phase 2 de la fusion predefined_tasks ↔ fiches_techniques.
# Restaure les fonctionnalités effacées par le cp iCloud précédent ET
# ajoute la propagation des nouveaux champs (equipe/creneau/categorie_taf)
# depuis fiches_techniques.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

# Vérifier que le commit de référence existe
if ! git show 2b35a79:taf/index.html > /tmp/2b35a79_taf.html 2>/dev/null; then
  echo "❌ Impossible d'extraire 2b35a79:taf/index.html — refuse de continuer."
  exit 1
fi

echo
echo "=== Restauration des fonctions perdues ==="
python3 << 'PYEOF'
import re
from pathlib import Path

REF = Path('/tmp/2b35a79_taf.html').read_text(encoding='utf-8')
CUR_PATH = Path('taf/index.html')
cur = CUR_PATH.read_text(encoding='utf-8')
changes = 0

def find_function_block(text, signature_re, max_search_lines=200):
    """Cherche un bloc de fonction depuis sa signature jusqu'à sa fermeture '  }'.
    Capture aussi les commentaires juste au-dessus (lignes commençant par '  //').
    Retourne (start_line_idx, end_line_idx, block_text) ou None."""
    lines = text.split('\n')
    sig_re = re.compile(signature_re)
    for i, line in enumerate(lines):
        if sig_re.search(line):
            # Remonter pour les commentaires
            start = i
            j = i - 1
            while j >= 0 and re.match(r'^  (//|/\*|\*)', lines[j]):
                start = j
                j -= 1
            # Avancer jusqu'à la fin de la fonction
            brace = 0
            seen_open = False
            for k in range(i, min(i + max_search_lines, len(lines))):
                l = lines[k]
                for ch in l:
                    if ch == '{':
                        brace += 1; seen_open = True
                    elif ch == '}':
                        brace -= 1
                        if seen_open and brace == 0:
                            block = '\n'.join(lines[start:k+1])
                            return (start, k, block)
            return None
    return None

# ============================================================
# 1. renderPredefinedList — remplacer par version 2b35a79
# ============================================================
ref_block = find_function_block(REF, r'^  function renderPredefinedList\(')
cur_block = find_function_block(cur, r'^  function renderPredefinedList\(')
if ref_block and cur_block:
    if 'productionFiches' in ref_block[2] and 'productionFiches' not in cur_block[2]:
        cur = cur.replace(cur_block[2], ref_block[2])
        print("✓ renderPredefinedList restauré (source = productionFiches)")
        changes += 1
    elif 'productionFiches' in cur_block[2]:
        print("• renderPredefinedList : déjà à jour (utilise productionFiches)")
    else:
        print("⚠ renderPredefinedList : situation inattendue")
else:
    print("⚠ renderPredefinedList : non trouvé dans ref ou current")

# ============================================================
# 2. selectPredefined — remplacer + ajouter propagation Phase 2
# ============================================================
ref_block = find_function_block(REF, r'^  function selectPredefined\(')
cur_block = find_function_block(cur, r'^  function selectPredefined\(')
if ref_block and cur_block:
    # Construire la nouvelle version : celle de 2b35a79 + propagation Phase 2
    new_select = ref_block[2]
    # Ajouter la propagation après la définition de selectedPredefined
    propagation = """      // Phase 2 — Propagation des nouveaux champs TAF depuis la fiche
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
"""
    # Insérer la propagation juste avant la fermeture finale '}' de la fonction
    # On l'insère après 'document.getElementById(\'predef-list\').style.display = \'none\';'
    marker = "    document.getElementById('predef-list').style.display = 'none';"
    if marker in new_select and 'fiche.categorie_taf' not in new_select:
        new_select = new_select.replace(
            marker,
            marker + "\n\n" + propagation.rstrip()
        )
        # Et on retire la pré-sélection 'Production' qui est maintenant remplacée par fiche.categorie_taf
        new_select = new_select.replace(
            """    // Pré-sélection auto de la catégorie 'Production'
    document.querySelectorAll('#create-categorie .chip').forEach(c => {
      c.classList.toggle('active', c.dataset.val === 'Production');
    });""",
            """    // (catégorie pré-sélectionnée plus haut depuis fiche.categorie_taf ou par défaut 'Production')
    if (!document.querySelector('#create-categorie .chip.active')) {
      document.querySelectorAll('#create-categorie .chip').forEach(c => {
        c.classList.toggle('active', c.dataset.val === 'Production');
      });
    }"""
        )
    if new_select != cur_block[2]:
        cur = cur.replace(cur_block[2], new_select)
        print("✓ selectPredefined restauré + propagation Phase 2 (equipe/creneau/categorie_taf)")
        changes += 1
    else:
        print("• selectPredefined : déjà à jour")
else:
    print("⚠ selectPredefined : non trouvé")

# ============================================================
# 3. selectCustomTask
# ============================================================
ref_block = find_function_block(REF, r'^  function selectCustomTask\(')
cur_block = find_function_block(cur, r'^  function selectCustomTask\(')
if ref_block and cur_block:
    if "source_type: 'a_creer'" in ref_block[2] and "source_type: 'a_creer'" not in cur_block[2]:
        cur = cur.replace(cur_block[2], ref_block[2])
        print("✓ selectCustomTask restauré (is_a_creer = true)")
        changes += 1
    elif "source_type: 'a_creer'" in cur_block[2]:
        print("• selectCustomTask : déjà à jour")
    else:
        print("⚠ selectCustomTask : situation inattendue")
else:
    print("⚠ selectCustomTask : non trouvé")

# ============================================================
# 4. submitCreate — modifier baseData pour gérer a_traiter et source_type
# ============================================================
old_submit_section = """      // Propager les champs production depuis predefined_task
      if (selectedPredefined.is_production) {
        baseData.is_production = true;
        baseData.fiche_id = selectedPredefined.fiche_id || null;
        baseData.categorie_production = selectedPredefined.categorie_production || null;
      }"""

new_submit_section = """      // Source = fiche technique : propage is_production + fiche_id + cat. prod
      if (selectedPredefined.source_type === 'fiche' || selectedPredefined.is_production) {
        baseData.is_production = true;
        baseData.fiche_id = selectedPredefined.fiche_id || null;
        baseData.categorie_production = selectedPredefined.categorie_production || null;
      }

      // Source = À créer : flag a_traiter pour l'admin
      if (selectedPredefined.source_type === 'a_creer' || selectedPredefined.is_a_creer) {
        baseData.a_traiter = true;
      }"""

if old_submit_section in cur:
    cur = cur.replace(old_submit_section, new_submit_section)
    print("✓ submitCreate : a_traiter + source_type ajoutés")
    changes += 1
elif "baseData.a_traiter = true" in cur:
    print("• submitCreate : déjà à jour")
else:
    print("⚠ submitCreate : pattern non trouvé")

# ============================================================
# 5. Bloc "Tâches à traiter" dans renderAdminTab
# ============================================================
# Récupérer le bloc depuis 2b35a79 : commence à "    // Tâches à traiter"
# jusqu'à juste avant "        <h3>Par équipe</h3>" (qui était la 1ère section avant)
ref_lines = REF.split('\n')
ref_start_at = None
ref_end_at = None
for i, l in enumerate(ref_lines):
    if l.strip() == '// Tâches à traiter (a_traiter = true, non finies)':
        ref_start_at = i
    if ref_start_at is not None and 'aTraiter.length > 0 ? `' in l and i > ref_start_at + 5:
        # On cherche la fin du bloc `} ` : ` : ''}` qui ferme l'expression ternaire
        pass

# Plus simple : on injecte directement un bloc hardcodé connu
admin_marker = """    mc.innerHTML = `
      <div class="admin-section">
        <div class="stat-row">"""

a_traiter_block_to_add = """    // Tâches à traiter (a_traiter = true, non finies)
    const aTraiter = tasks.filter(t => t.a_traiter && !t.fait_par_id);

    """

# Trouver l'emplacement et ajouter les variables au début de renderAdminTab
admin_re = re.compile(r'(  function renderAdminTab\(\) \{\n    const mc = document\.getElementById\(\x27main-content\x27\);)', re.MULTILINE)
if admin_re.search(cur) and 'const aTraiter = tasks.filter' not in cur:
    cur = admin_re.sub(r'\1\n    // Tâches à traiter (a_traiter = true, non finies)\n    const aTraiter = tasks.filter(t => t.a_traiter && !t.fait_par_id);', cur, count=1)
    print("✓ renderAdminTab : variable aTraiter ajoutée")
    changes += 1
elif 'const aTraiter = tasks.filter' in cur:
    print("• renderAdminTab : variable aTraiter déjà présente")

# Ajouter la stat-card "À traiter" + section UI
old_stat_row_end = """          <div class="stat-card stat-red"><div class="value">${overdue}</div><div class="label">En retard</div></div>
        </div>"""
new_stat_row_end = """          <div class="stat-card stat-red"><div class="value">${overdue}</div><div class="label">En retard</div></div>
          ${aTraiter.length > 0 ? `<div class="stat-card" style="background:#fef3c7;color:#92400e"><div class="value">${aTraiter.length}</div><div class="label">À traiter</div></div>` : ''}
        </div>

        ${aTraiter.length > 0 ? `
        <h3 style="color:#9a3412;display:flex;align-items:center;gap:8px">
          ⚠ Tâches à traiter
          <span style="font-size:0.75rem;font-weight:400;color:#6b7280;font-style:italic">— libellés saisis manuellement, à valider</span>
        </h3>
        <div style="background:#fffbeb;border:1px solid #fde68a;border-radius:8px;padding:8px;margin-bottom:14px">
          ${aTraiter.map(t => {
            const createdDt = t.date_creation ? new Date(t.date_creation).toLocaleDateString('fr-FR', { day:'2-digit', month:'2-digit' }) : '';
            return `<div style="display:flex;align-items:center;gap:8px;padding:8px;background:white;border:1px solid #fde68a;border-radius:6px;margin-bottom:6px;flex-wrap:wrap">
              <span style="flex:1;min-width:200px;font-weight:600">${esc(t.tache)}</span>
              <span style="font-size:0.72rem;color:#6b7280">par ${esc(t.createur_nom || '?')} le ${esc(createdDt)}</span>
              <div style="display:flex;gap:4px">
                <button class="btn-modal primary" style="font-size:0.75rem;padding:5px 10px"
                        onclick="adminLinkFiche('${t.id}')" title="Lier à une fiche existante">🔗 Lier fiche</button>
                <button class="btn-modal" style="font-size:0.75rem;padding:5px 10px;background:#dbeafe;color:#1e40af"
                        onclick="adminPromoteToPredef('${t.id}')" title="Créer en tâche prédéfinie">+ Predef</button>
                <button class="btn-modal" style="font-size:0.75rem;padding:5px 10px;background:#e5e7eb;color:#374151"
                        onclick="adminIgnoreATraiter('${t.id}')" title="Garder la tâche, juste retirer le flag">Ignorer</button>
              </div>
            </div>`;
          }).join('')}
        </div>
        ` : ''}"""

if old_stat_row_end in cur and 'À traiter</div></div>' not in cur:
    cur = cur.replace(old_stat_row_end, new_stat_row_end)
    print("✓ renderAdminTab : bloc 'Tâches à traiter' ajouté")
    changes += 1
elif 'À traiter</div></div>' in cur:
    print("• renderAdminTab : bloc 'Tâches à traiter' déjà présent")
else:
    print("⚠ renderAdminTab : stat-row end non trouvée")

# ============================================================
# 6. 4 fonctions admin perdues (adminLinkFiche, adminDoLinkFiche, adminPromoteToPredef, adminIgnoreATraiter)
# ============================================================
funcs_to_restore = ['adminIgnoreATraiter', 'adminLinkFiche', 'adminDoLinkFiche', 'adminPromoteToPredef']
for fname in funcs_to_restore:
    if f'function {fname}' in cur:
        print(f"• {fname} : déjà présente")
        continue
    ref_block = find_function_block(REF, rf'^  async function {fname}\(')
    if ref_block:
        # Insérer juste avant 'function showAddPredefinedModal'
        marker = '  function showAddPredefinedModal() {'
        if marker in cur:
            cur = cur.replace(marker, ref_block[2] + '\n\n  ' + marker)
            print(f"✓ {fname} insérée")
            changes += 1
        else:
            print(f"⚠ {fname} : marker showAddPredefinedModal non trouvé")
    else:
        print(f"⚠ {fname} : non trouvée dans 2b35a79")

# ============================================================
# Sauvegarde
# ============================================================
if changes > 0:
    CUR_PATH.write_text(cur, encoding='utf-8')
    print(f"\n✅ {changes} modifs écrites sur disque.")
else:
    print("\nAucun changement appliqué.")
PYEOF

echo
echo "=== git status ==="
git status --short

if git diff --quiet -- taf/index.html; then
  echo
  echo "Rien à commiter — fichier déjà à jour."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html
git commit -m "feat(taf): Phase 2 — création basée sur fiches + propagation TAF

Restaure les 5 fonctionnalités effacées par le cp iCloud du commit
562e3f1, et ajoute en plus la propagation des nouveaux champs TAF
depuis fiches_techniques (equipe/creneau/categorie_taf).

Fonctionnalités restaurées (depuis le commit 2b35a79) :
- renderPredefinedList : source = productionFiches (catalogue des
  fiches techniques), pas plus predefined_tasks. Bouton '+ À créer'
  toujours visible.
- selectPredefined : prend un fiche_id, marque source_type='fiche'.
- selectCustomTask : marque source_type='a_creer' + is_a_creer=true.
- submitCreate : si source_type='a_creer', tasks.a_traiter=true.
- renderAdminTab : nouveau bloc 'Tâches à traiter' jaune en haut.
- 4 fonctions admin (adminLinkFiche, adminDoLinkFiche,
  adminPromoteToPredef, adminIgnoreATraiter).

Phase 2 — Propagation depuis fiches_techniques :
- selectPredefined propage maintenant fiche.equipe, fiche.creneau et
  fiche.categorie_taf vers les chips correspondants en plus de la
  catégorie 'Production' par défaut.
- Les colonnes ajoutées par la migration Phase 1 du 14/5/2026
  deviennent ainsi utilisées au moment de la création de tâche."

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
