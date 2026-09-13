#!/usr/bin/env bash
# Fix 404 au clic Scanner : remplace les chemins absolus /scanner/ et /taf/
# par des chemins relatifs ../scanner/ et ../taf/ pour fonctionner sur
# GitHub Pages servi sous /planb-tools/.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application du fix ==="
python3 << 'PYEOF'
from pathlib import Path
changes_total = 0

# ============================================================
# taf/index.html : '/scanner/?mode=unit&return=taf' → '../scanner/?mode=unit&return=taf'
# ============================================================
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
old = "window.location.href = '/scanner/?mode=unit&return=taf';"
new = "window.location.href = '../scanner/?mode=unit&return=taf';"
if old in content:
    content = content.replace(old, new)
    p.write_text(content, encoding='utf-8')
    print("✓ taf/index.html : '/scanner/' → '../scanner/'")
    changes_total += 1
elif new in content:
    print("• taf/index.html : déjà à jour")
else:
    print("⚠ taf/index.html : pattern non trouvé")

# ============================================================
# scanner/index.html : 'window.location.href = '/taf/'' → '../taf/'
# ============================================================
p = Path('scanner/index.html')
content = p.read_text(encoding='utf-8')
old = "window.location.href = '/taf/';"
new = "window.location.href = '../taf/';"
if old in content:
    content = content.replace(old, new)
    p.write_text(content, encoding='utf-8')
    print("✓ scanner/index.html : '/taf/' → '../taf/'")
    changes_total += 1
elif new in content:
    print("• scanner/index.html : déjà à jour")
else:
    print("⚠ scanner/index.html : pattern non trouvé")

print(f"\nTotal : {changes_total} modifs")
PYEOF

echo
git status --short

if git diff --quiet -- taf/index.html scanner/index.html; then
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html scanner/index.html
git commit -m "fix(scan-fefo phase 3): chemins relatifs pour GitHub Pages

Symptôme : clic sur 📷 Scanner → 404 'bresleric.github.io/scanner/'
n'existe pas, car le repo est servi sous /planb-tools/.

Fix : remplacement des chemins absolus par des chemins relatifs.
- taf/index.html : '/scanner/?mode=unit&return=taf' → '../scanner/...'
- scanner/index.html : '/taf/' → '../taf/'

Les chemins relatifs marchent à la fois en local (file://), sur
GitHub Pages (/planb-tools/) et sur un éventuel custom domain plus tard."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
if [ -d "$ICLOUD_DIR" ]; then
  cp taf/index.html "$ICLOUD_DIR/taf/index.html" 2>/dev/null || true
  cp scanner/index.html "$ICLOUD_DIR/scanner/index.html" 2>/dev/null || true
  echo "✓ iCloud aligné si dossier trouvé"
fi

echo
echo "=== Terminé ✓ ==="
