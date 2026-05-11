#!/bin/bash
# ============================================================
# Stock PF/PI — Copie iCloud → repo git + commit + push
# Lance depuis n'importe où, le script gère tout
# ============================================================
set -e

SRC_DIR="$HOME/Documents/Claude/Projects/PlanB-Tools/planb-tools-update/stock-pf-pi"
REPO_DIR="$HOME/planb-tools"
DST_DIR="$REPO_DIR/planb-tools-update/stock-pf-pi"

echo "═══════════════════════════════════════════════════"
echo "  Stock PF/PI — Déploiement vers repo"
echo "═══════════════════════════════════════════════════"

# 0. Vérifier le repo
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "✗ Repo git introuvable dans $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

# 1. État git AVANT (jamais de push sur main aveugle)
BRANCH=$(git branch --show-current)
echo ""
echo "→ Branche active : $BRANCH"
echo "→ git status :"
git status -s
echo ""

if [ -n "$(git status -s)" ]; then
  echo "⚠  Le repo contient des modifs non commitées. Vérifie avant de continuer."
  read -p "Continuer quand même ? (y/N) " yn
  [ "$yn" = "y" ] || exit 0
fi

# 2. Pull pour éviter d'écraser un commit distant
echo "→ git pull origin $BRANCH"
git pull origin "$BRANCH"

# 3. Diff entre iCloud (source) et repo (cible) AVANT cp
mkdir -p "$DST_DIR"
echo ""
echo "→ Diff iCloud ↔ repo (rouge = à venir du chat) :"
if diff -rq "$SRC_DIR" "$DST_DIR" 2>/dev/null; then
  echo "  (identique — rien à copier)"
  exit 0
fi
echo ""

read -p "Appliquer ce diff ? (y/N) " yn
[ "$yn" = "y" ] || exit 0

# 4. Copie
echo "→ Copie des fichiers..."
cp -v "$SRC_DIR"/*.sql "$DST_DIR/"
cp -v "$SRC_DIR"/*.md  "$DST_DIR/"
cp -v "$SRC_DIR"/*.sh  "$DST_DIR/" 2>/dev/null || true

# 5. Commit
git add planb-tools-update/stock-pf-pi/
echo ""
echo "→ git status après add :"
git status -s

git commit -m "feat(stock-pf-pi): schema stock_pf_pi + unites + contenants GN

- Table stock_pf_pi liee a fiches_techniques + temp_frigos
- Table unites normalisee (13 unites)
- Table contenants avec nomenclature GN complete (44 GN + 14 autres)
- temp_frigos etendu avec nb_niveaux (1-4)
- Seeds + init meubles + import des 7 lignes Excel d'Eric
- Spec front-end pour onglet Module Production"

# 6. Push sur la branche active (pas main aveugle)
echo ""
echo "→ git push origin $BRANCH"
git push origin "$BRANCH"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✅ Stock PF/PI livré sur la branche $BRANCH"
echo "═══════════════════════════════════════════════════"
