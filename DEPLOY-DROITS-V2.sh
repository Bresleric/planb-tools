#!/bin/bash
# Déploiement v2 (sécurisé) :
# - TAF : ré-application du garde-fou switchTab sur la version repo restaurée
# - Approvisionnement : masquer Catalogue + Ingrédients aux non-admins
#
# Sécurité : le script affiche les diffs et les stats, puis ATTEND une confirmation
# explicite avant de cp + commit + push. Si une diff est suspicieusement grande
# (signe que iCloud est plus ancien que repo), tu peux taper "n" pour aborter.

set -e
cd ~/planb-tools

ICLOUD="/Users/eric/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"

echo "============================================================"
echo "PHASE 1/3 — Audit (lecture seule, rien n'est modifié)"
echo "============================================================"
echo
echo "--- Tailles de fichiers (lignes / octets) ---"
printf "%-50s %s\n" "TAF iCloud:" "$(wc -lc < "$ICLOUD/taf/index.html")"
printf "%-50s %s\n" "TAF repo:"   "$(wc -lc < taf/index.html)"
printf "%-50s %s\n" "Appro iCloud:" "$(wc -lc < "$ICLOUD/planb-tools-update/approvisionnement/index.html")"
printf "%-50s %s\n" "Appro repo:"   "$(wc -lc < approvisionnement/index.html)"
echo
echo "--- Stats diff TAF (iCloud vs repo) ---"
diff -u "$ICLOUD/taf/index.html" taf/index.html | grep -E "^[+-]" | grep -v "^[+-][+-][+-]" | wc -l | xargs -I{} echo "Total lignes modifiées: {}"
echo
echo "--- Stats diff Approvisionnement (iCloud vs repo) ---"
diff -u "$ICLOUD/planb-tools-update/approvisionnement/index.html" approvisionnement/index.html | grep -E "^[+-]" | grep -v "^[+-][+-][+-]" | wc -l | xargs -I{} echo "Total lignes modifiées: {}"
echo
echo "--- Détail diff TAF (head 60) ---"
diff "$ICLOUD/taf/index.html" taf/index.html | head -60 || true
echo
echo "--- Détail diff Approvisionnement (head 60) ---"
diff "$ICLOUD/planb-tools-update/approvisionnement/index.html" approvisionnement/index.html | head -60 || true
echo

echo "============================================================"
echo "PHASE 2/3 — Confirmation"
echo "============================================================"
echo
echo "Attendu :"
echo "  - TAF : ~5 lignes modifiées (garde-fou switchTab uniquement)"
echo "  - Appro : ~25 lignes modifiées (id catalogue + updateBadges + isAdminAppro + switchTab garde-fou)"
echo
echo "Si les stats ci-dessus sont LARGEMENT supérieures, NE PAS continuer (iCloud probablement obsolète)."
echo
read -p "Continuer le cp + commit + push ? [o/N] " confirm
case "$confirm" in
    [oO]|[oO][uU][iI]|[yY]|[yY][eE][sS]) ;;
    *)
        echo "Aborted by user. Aucun fichier modifié."
        exit 0
        ;;
esac

echo
echo "============================================================"
echo "PHASE 3/3 — cp + commit + push"
echo "============================================================"

cp "$ICLOUD/taf/index.html" taf/index.html
cp "$ICLOUD/planb-tools-update/approvisionnement/index.html" approvisionnement/index.html

echo
echo "--- git status ---"
git status --short

echo
git add taf/index.html approvisionnement/index.html
git commit -m "Restreindre droits onglets : garde-fou TAF.switchTab + Approvisionnement.Catalogue & Ingrédients aux admins"
git push origin main

echo
echo "✅ Déploiement terminé."
