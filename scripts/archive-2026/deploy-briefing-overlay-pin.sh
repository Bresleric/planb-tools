#!/bin/bash
# Deploiement : overlay signature briefing obligatoire + PIN au portail (index.html racine)
#               et modale PIN inactivite dans le briefing (briefing/index.html).
# sw.js v18 a deja ete committe et pousse par un autre processus (rien a faire dessus).
#
# A lancer depuis le Mac : bash ~/planb-tools/scripts/deploy-briefing-overlay-pin.sh

set -e
cd ~/planb-tools

# --- Garde-fou branche : jamais de push aveugle sur main ---
BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
if [ "$BRANCH" != "main" ]; then
  echo "ATTENTION : tu n-es pas sur main. Verifie avant de continuer."
  echo "Tape Entree pour pousser sur $BRANCH, ou Ctrl-C pour annuler."
  read -r REPLY
fi

# --- Se mettre a jour proprement (un autre process pousse sur ce repo) ---
echo "Mise a jour fast-forward depuis origin..."
git pull --ff-only

# --- Ajout des deux fichiers concernes uniquement ---
git add index.html briefing/index.html

echo "=== Fichiers stages ==="
git status --short index.html briefing/index.html

# --- Commit (message sans apostrophes) ---
git commit -m "feat(briefing): overlay signature obligatoire + PIN au portail, modale PIN inactivite briefing

index.html racine : greffe de l-overlay briefing obligatoire avec confirmation PIN a la
connexion (checkMandatoryBriefingOnLogin / showBriefingOverlay / renderBriefingOverlayContent).
Branche sur les 4 points d-entree du portail en gardant le redirect Pointages prioritaire.
Tous les modules existants (Scanner, Stock, Information, Achats, Produits) preserves : la
version iCloud avait diverge et a ete greffee chirurgicalement, pas copiee.

briefing/index.html : remplace l-auto-deconnexion a 2 min par une modale PIN Session en
pause (3 min d-inactivite, prolongation par code). Meteo Strasbourg et tendances 4 semaines
etaient deja en prod.

sw.js bump v18 deja committe par ailleurs."

# --- Push sur la branche active ---
git push origin "$BRANCH"

echo ""
echo "=== Deploiement termine sur $BRANCH. ==="
echo "GitHub Pages va se rafraichir dans 1-2 min : https://bresleric.github.io/planb-tools/"
