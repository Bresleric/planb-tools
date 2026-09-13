#!/usr/bin/env bash
# Après validation d'une tâche TAF avec saisie production :
# - TAF redirige vers /production/?prod_id=xxx&action=etiquette
# - Production détecte le paramètre et ouvre showEtiquette(production) auto
# Remplace l'ancienne mini-modale showEtiquetteTaf (lecture seule) par
# l'éditeur d'étiquette riche du module Production.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des patchs ==="
python3 << 'PYEOF'
from pathlib import Path
changes = 0

# ============================================================
# CÔTÉ TAF — remplacer showEtiquetteTaf par navigation
# ============================================================
taf_path = Path('taf/index.html')
taf = taf_path.read_text(encoding='utf-8')

old_taf = """      closeProductionModal();
      tasks = await DB.getTasks(filterDate);
      renderFiltered();
      showToast('Production enregistrée ✓', 'success');

      // Afficher l'étiquette
      showEtiquetteTaf(saved, lot);
    } catch (e) {"""

new_taf = """      closeProductionModal();
      tasks = await DB.getTasks(filterDate);
      renderFiltered();
      showToast('Production enregistrée ✓ — ouverture étiquette…', 'success');

      // Navigation auto vers le module Production pour éditer l'étiquette
      setTimeout(() => {
        window.location.href = `../production/?prod_id=${saved.id}&action=etiquette&return=taf`;
      }, 400);
    } catch (e) {"""

if old_taf in taf:
    taf = taf.replace(old_taf, new_taf)
    taf_path.write_text(taf, encoding='utf-8')
    print("[TAF] ✓ Redirection vers /production/?prod_id=xxx&action=etiquette")
    changes += 1
elif "action=etiquette&return=taf" in taf:
    print("[TAF] • Redirection déjà en place")
else:
    print("[TAF] ⚠ Pattern showEtiquetteTaf non trouvé")

# ============================================================
# CÔTÉ PRODUCTION — détecter ?prod_id&action=etiquette au chargement
# et ouvrir showEtiquette automatiquement après chargement données
# ============================================================
prod_path = Path('production/index.html')
prod = prod_path.read_text(encoding='utf-8')

# On insère un listener DOMContentLoaded qui :
# 1. Lit les params URL
# 2. Attend que sb soit défini et que allLots soit chargé (polling max 5s)
# 3. Fetch la production via supabase
# 4. Appelle showEtiquette(production)

if "// SCAN-FEFO/TAF-LABEL : auto-ouverture étiquette" not in prod:
    # Trouver un endroit propre pour insérer le listener.
    # On l'ajoute juste avant la première occurrence de "</script>" en fin de fichier.
    marker = "</script>"
    last_marker_idx = prod.rfind(marker)
    if last_marker_idx > 0:
        autoload = """
  // ====== SCAN-FEFO/TAF-LABEL : auto-ouverture étiquette ======
  // Si on arrive depuis /taf/ après validation d'une production avec
  // ?prod_id=xxx&action=etiquette, on ouvre directement showEtiquette
  // pour la production fraîchement créée.
  (async function autoOpenEtiquetteFromTaf() {
    const urlParams = new URLSearchParams(window.location.search);
    const prodId = urlParams.get('prod_id');
    const action = urlParams.get('action');
    const ret = urlParams.get('return');
    if (!prodId || action !== 'etiquette') return;

    // Attendre que sb (supabase) soit défini + données prêtes (polling max 5s)
    let tries = 0;
    while (tries < 25 && (typeof sb === 'undefined' || !sb)) {
      await new Promise(r => setTimeout(r, 200));
      tries++;
    }
    if (typeof sb === 'undefined' || !sb) {
      console.warn('[TAF-LABEL] supabase non chargé');
      return;
    }
    // Petite pause pour laisser allLots se charger si possible
    await new Promise(r => setTimeout(r, 400));
    try {
      const { data: prod, error } = await sb.from('productions').select('*').eq('id', prodId).single();
      if (error || !prod) {
        console.warn('[TAF-LABEL] production introuvable', prodId, error);
        return;
      }
      if (typeof showEtiquette === 'function') {
        showEtiquette(prod);
      } else {
        console.warn('[TAF-LABEL] showEtiquette() non disponible');
      }
      // Bouton retour TAF en haut de la modale étiquette
      if (ret === 'taf') {
        setTimeout(() => {
          const eti = document.getElementById('etiquette');
          if (eti) {
            const headerBar = eti.querySelector('.etiquette-header-bar');
            if (headerBar && !document.getElementById('btn-back-taf')) {
              const btn = document.createElement('button');
              btn.id = 'btn-back-taf';
              btn.textContent = '← TAF';
              btn.style.cssText = 'position:absolute;top:8px;left:8px;background:rgba(255,255,255,0.2);color:white;border:1px solid rgba(255,255,255,0.4);padding:4px 10px;border-radius:6px;cursor:pointer;font-size:0.8rem;font-weight:600;';
              btn.onclick = () => { window.location.href = '../taf/'; };
              eti.querySelector('.etiquette-card').style.position = 'relative';
              eti.querySelector('.etiquette-card').appendChild(btn);
            }
          }
        }, 200);
      }
    } catch (e) {
      console.error('[TAF-LABEL] erreur', e);
    }
  })();
"""
        prod = prod[:last_marker_idx] + autoload + prod[last_marker_idx:]
        prod_path.write_text(prod, encoding='utf-8')
        print("[Production] ✓ Auto-ouverture étiquette + bouton ← TAF")
        changes += 1
    else:
        print("[Production] ⚠ </script> non trouvé")
else:
    print("[Production] • Auto-ouverture déjà en place")

print(f"\nTotal : {changes} modifs")
PYEOF

echo
git status --short

if git diff --quiet -- taf/index.html production/index.html; then
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html production/index.html
git commit -m "feat(taf+production): auto-ouverture éditeur étiquette après TAF

Après la saisie de production dans la modale TAF (validation d'une
tâche avec is_production=true et saisie de quantité/lots), au lieu
d'afficher la mini-modale showEtiquetteTaf (lecture seule), on
redirige automatiquement vers le module Production pour ouvrir
l'éditeur d'étiquette riche.

[TAF] saveProductionFromTaf :
- Toast 'Production enregistrée ✓ — ouverture étiquette…'
- setTimeout 400ms puis navigate '../production/?prod_id=\${saved.id}&action=etiquette&return=taf'

[Production] IIFE autoOpenEtiquetteFromTaf au DOMContentLoaded :
- Lit ?prod_id&action=etiquette dans l'URL
- Attend que supabase (sb) soit chargé (polling max 5s)
- Fetch la production via supabase
- Appelle showEtiquette(production) qui ouvre la modale riche existante
- Si ?return=taf : ajoute un bouton '← TAF' en haut à gauche de la
  modale étiquette pour revenir au TAF d'un clic

Workflow utilisateur :
1. TAF ▶ Démarrer production (scan principaux, chrono démarre)
2. Plus tard, click ✓ valider → modale saisie production
3. Quantité produite + lots → Enregistrer
4. Toast → redirection vers Production
5. Modale étiquette s'ouvre direct, edit + impression
6. Click '← TAF' pour revenir à la liste"

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
if [ -d "$ICLOUD_DIR" ]; then
  [ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" 2>/dev/null || true
  [ -d "$ICLOUD_DIR/production" ] && cp production/index.html "$ICLOUD_DIR/production/index.html" 2>/dev/null || true
  echo "✓ iCloud aligné si possible"
fi

echo
echo "=== Terminé ✓ ==="
