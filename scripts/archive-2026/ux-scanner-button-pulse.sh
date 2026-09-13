#!/usr/bin/env bash
# UX :
# 1. Bouton 📷 Scanner agrandi : icône grosse + texte 'Scanner' en dessous
# 2. Message d'avertissement '⚠ Scanne tous les ingrédients...' clignotant
#    (animation CSS pulse-warning douce 1.5s)

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des 3 patchs ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# 1. Ajout du CSS @keyframes pulse-warning
# ============================================================
css_block = """
    /* ====== Scan-FEFO : animation message d'attente + bouton scanner ====== */
    @keyframes pulse-warning {
      0%, 100% {
        background: #fef3c7;
        border-color: #fcd34d;
        box-shadow: 0 0 0 0 rgba(245, 158, 11, 0);
      }
      50% {
        background: #fde68a;
        border-color: #f59e0b;
        box-shadow: 0 0 0 4px rgba(245, 158, 11, 0.2);
      }
    }
    .scan-warning-pulse {
      animation: pulse-warning 1.5s ease-in-out infinite;
    }
    .btn-scan-camera {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 2px;
      background: #7c3aed;
      color: white;
      padding: 8px 14px;
      border: none;
      border-radius: 10px;
      cursor: pointer;
      font-weight: 600;
      font-size: 0.75rem;
      line-height: 1.1;
      box-shadow: 0 2px 4px rgba(124, 58, 237, 0.3);
      transition: all .15s;
    }
    .btn-scan-camera:hover, .btn-scan-camera:active {
      background: #6d28d9;
      transform: scale(.97);
    }
    .btn-scan-camera .scan-cam-emoji {
      font-size: 1.6rem;
      line-height: 1;
    }
"""

css_marker = "    /* ====== FICHE TECHNIQUE — modale consultation au démarrage TAF ====== */"
if css_marker in content and '.btn-scan-camera' not in content:
    content = content.replace(css_marker, css_block + '\n' + css_marker)
    print("✓ CSS pulse-warning + btn-scan-camera ajouté")
    changes += 1
elif '.btn-scan-camera' in content:
    print("• CSS déjà présent")
else:
    print("⚠ CSS marker FICHE TECHNIQUE non trouvé")

# ============================================================
# 2. Bouton Scanner : nouveau look avec icône grosse
# ============================================================
old_btn = '<button class="btn-action" style="background:#7c3aed; color:white; padding:8px 14px; font-size:0.85rem;" onclick="openScannerForIngredient(\'${i.id}\')">📷 Scanner</button>'
new_btn = '<button class="btn-scan-camera" onclick="openScannerForIngredient(\'${i.id}\')"><span class="scan-cam-emoji">📷</span><span>Scanner</span></button>'

if old_btn in content:
    content = content.replace(old_btn, new_btn)
    print("✓ Bouton 📷 Scanner : nouveau style avec icône grosse")
    changes += 1
elif 'class="btn-scan-camera"' in content:
    print("• Bouton scanner : déjà au nouveau style")
else:
    print("⚠ Bouton scanner : ancien pattern non trouvé")

# ============================================================
# 3. Message d'avertissement : ajout de la classe pulse
# ============================================================
old_warning = '<div style="background:#fef3c7; border:1px solid #fcd34d; padding:10px 14px; border-radius:6px; margin-bottom:14px; font-size:0.85rem; color:#92400e;">'
new_warning = '<div class="scan-warning-pulse" style="background:#fef3c7; border:1px solid #fcd34d; padding:10px 14px; border-radius:6px; margin-bottom:14px; font-size:0.85rem; color:#92400e; font-weight:600;">'

if old_warning in content:
    content = content.replace(old_warning, new_warning)
    print("✓ Message d'attente : classe scan-warning-pulse ajoutée")
    changes += 1
elif 'class="scan-warning-pulse"' in content:
    print("• Message d'attente : déjà clignotant")
else:
    print("⚠ Message d'avertissement : pattern non trouvé")

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
git commit -m "ux(scan-fefo): bouton 📷 plus visible + message d'attente clignotant

Modale fiche en mode obligatoire (au démarrage d'une tâche prod) :

1. Bouton 'Scanner' redessiné — nouvelle classe .btn-scan-camera :
   • Icône 📷 plus grosse (1.6rem) au-dessus du label
   • Texte 'Scanner' en dessous, font-weight 600, 0.75rem
   • Box-shadow violet pour relief
   • Bouton plus carré (10px border-radius)
   Avant : '📷 Scanner' inline, peu lisible.

2. Message d'avertissement '⚠ Scanne tous les ingrédients principaux'
   gagne une animation CSS @keyframes pulse-warning :
   • Cycle 1.5s ease-in-out infinite
   • Pulse de la couleur de fond (jaune clair → jaune moyen)
   • Pulse de la bordure (jaune → orange)
   • Ring shadow 4px alpha 0.2 à mi-cycle
   • font-weight 600 pour bien attirer l'œil
   Attire visuellement l'attention sans être agressif."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
