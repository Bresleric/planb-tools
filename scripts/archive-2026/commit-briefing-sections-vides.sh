#!/usr/bin/env bash
# Affiche toutes les sections du briefing meme vides (Aucun / RAS en gris)
# pour que les collaborateurs voient la structure complete et reperent
# un oubli du redacteur. Vue Briefing + overlay de signature obligatoire.
set -e
cd ~/planb-tools

git add briefing/index.html index.html sw.js

git commit -m "feat(briefing): affiche toutes les sections meme vides avec Aucun/RAS

- renderBriefing (onglet Briefing) et renderBriefingOverlayContent (overlay signature)
- sections evenements, plats, produits limites, dates courtes, incidents, objectifs, rappels, notes
- texte gris Aucun/RAS quand vide, badge compteur a 0
- bump SW cache v20

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"

git push origin main
echo "Push OK"
