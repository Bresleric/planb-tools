#!/bin/bash
# Rapport du jour enrichi : synthese a traiter, messages des equipes, travail des equipes sur 7 jours
set -e
cd ~/planb-tools
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add rapport/index.html sw.js scripts/rapport-reporting-a-traiter.sh
git commit -m "Rapport: synthese a traiter, messages des equipes regroupes et travail des equipes sur 7 jours

- Carte de synthese en tete : caisses a valider, besoins appro, scans a valider, incidents ouverts, produits sans fiche
- Par etablissement : bloc A traiter (besoins anciens, caisses non validees 14 j, scans 30 j, productions sans fiche 30 j)
- Bloc Messages des equipes : incidents regroupes par description (le briefing les duplique), taches signalees, rappels actifs
- Tableau 7 jours : TAF faites/prevues, productions, releves frigos, etiquettes scannees
- Informations proposees a valider en tete de page
- SW v57

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
