#!/bin/bash
# TAF : filtre par categorie dans la barre des filtres du tableau des taches (SW v140)
set -e
cd ~/planb-tools
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git status --short taf/index.html sw.js scripts/taf-filtre-categorie.sh
echo "Commit et push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git add taf/index.html sw.js scripts/taf-filtre-categorie.sh
git commit -m "TAF : filtre par categorie dans le tableau des taches (chips construites a partir des taches du jour, avec compteur et Sans categorie, libelles lisibles pour les categories de production) + bump SW v140

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin "$BRANCHE"
echo "Pousse. Publication GitHub Pages en cours (1 a 2 minutes)."
