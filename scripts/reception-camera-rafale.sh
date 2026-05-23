#!/bin/bash
# ============================================================
# Commit + push — Camera live « rafale » dans la reception
# groupee (module Scanner) :
#  - liste deroulante des fournisseurs au clic + champ libre
#  - « Scanner une etiquette » lance la camera live rafale
#  - bouton « Fin de scan des etiquettes » -> numerisation du BL
#  - extraction Claude Vision en tache de fond
#
# Les modifications sont DEJA appliquees dans le repo par
# Cowork (scanner/index.html). Ce script ne fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add scanner/index.html scripts/reception-camera-rafale.sh

echo ""
echo "=== Fichiers a committer ==="
git status --short scanner/index.html scripts/reception-camera-rafale.sh
echo ""

git commit -m "feat(scan): camera live rafale dans la reception groupee

- Selecteur fournisseur : la liste s'ouvre au clic/focus (plus seulement
  a la frappe), filtrage conserve, creation d'un fournisseur libre.
- « Scanner une etiquette » lance la camera live rafale (meme principe
  que le TAF) : 1 SHOOT par etiquette, extraction Claude Vision en
  tache de fond, liste qui se remplit au fil des analyses.
- Bouton « Fin de scan des etiquettes » -> enchaine automatiquement
  sur la numerisation du BL / facture (SHOOT plein cadre ou import PDF).
- Repli sur l'appareil photo natif si getUserMedia indisponible."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
