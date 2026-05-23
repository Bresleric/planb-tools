#!/bin/bash
# ============================================================
# Commit + push — Rapprochement etiquette production <-> lot
# en stock (Phase 1).
#  - a l'ouverture de la modale production, chaque etiquette
#    scannee est rapprochee d'un lot reellement en stock par
#    empreinte : DLC identique + poids net identique
#  - la sortie de stock vise alors le LOT RECU (reception),
#    pas l'etiquette orpheline de production
#  - matching matiere<->scan : repli sur l'article attendu de
#    la fiche quand l'IA n'a pas reconnu l'article
#  - quantite : celle de la fiche si renseignee, sinon le
#    poids des etiquettes scannees
#  - le recap affiche « rapproche au stock » / « pas trouve »
#
# Modification DEJA appliquee dans le repo par Cowork
# (taf/index.html). Ce script ne fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add taf/index.html scripts/rapprochement-stock.sh

echo ""
echo "=== Fichiers a committer ==="
git status --short taf/index.html scripts/rapprochement-stock.sh
echo ""

git commit -m "feat(stock): rapprochement etiquette production <-> lot recu

- rapprocherScansAvecStock() : a l'ouverture de la modale
  production, chaque etiquette scannee est rapprochee d'un lot
  en stock par empreinte DLC + poids net identiques (tous
  articles confondus). La sortie de stock vise le lot recu.
- applyScannedLotsToMatieres : matching matiere<->scan avec
  repli sur article_id_attendu quand l'IA n'a pas resolu
  l'article ; quantite = fiche si renseignee, sinon poids des
  etiquettes scannees ; article_id de la sortie = celui du lot.
- recap : badges « rapproche au stock » / « pas trouve en
  stock - reception manquante ? »."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
