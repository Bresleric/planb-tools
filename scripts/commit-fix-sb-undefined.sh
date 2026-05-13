#!/usr/bin/env bash
# Fix : `sb` non défini dans taf/index.html
# Cause "Erreur chargement fiche" au démarrage d'un TAF production lié à une fiche.
# Bug pré-existant (présent dans loadProductionMatieres et autres) ; mes ajouts ont
# juste rendu la régression visible.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "fix(taf): déclaration de \`sb\` (alias de supabaseClient)

Symptôme : toast rouge 'Erreur chargement fiche' apparaît au clic ▶ Démarrer
sur un TAF de production lié à une fiche technique.

Cause : 4 fonctions du fichier (openFicheConsultModal, loadProductionMatieres,
+ 2 autres) utilisent \`sb.from(...)\` mais \`sb\` n'était jamais déclaré ni
assigné dans taf/index.html (contrairement à production/index.html où
\`const sb = supabase.createClient(...)\` existe).

Trois de ces 4 usages étaient pré-existants et donc déjà cassés silencieusement
(loadProductionMatieres, code stock_par_lot et stock_mouvements). Le 4ème
introduit par la Phase 1 (openFicheConsultModal) a rendu le bug visible
parce qu'il déclenche un toast d'erreur dans le catch.

Fix :
- let sb = null  (déclaré à côté de supabaseClient ligne 995)
- sb = supabaseClient  dans initSupabase() après le createClient

Tous les usages de \`sb.from(...)\` deviennent fonctionnels d'un coup.
Smoke tests 4/4, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
