#!/bin/bash
# ============================================================
# Restauration de la feature Production directe
# La feature a ete ecrasee par un cp iCloud -> repo lors d'un
# commit ulterieur (commit 90a37a9 prix au litre). Re-injection
# depuis f84b551 :
#   - HTML modale fiche picker
#   - HTML bandeau directe + section MP dans production-modal
#   - FAB onclick -> openProductionDirecte
#   - JS bloc complet (~1189 lignes) : selectFicheAndStart,
#     startProductionACreer, pdOpenProductionModalForFiche,
#     pdLoadProductionMatieres, pdRapprocherScansAvecStock,
#     pdApplyScannedLotsToMatieres, pdLaunchScanner,
#     pdProcessScanReturn, pdStartChronoAfterScan, pdPause /
#     Resume / RefreshDirecteBar, wrappers saveProduction +
#     closeProductionModal, etc.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
echo ""

git add production/index.html scripts/restore-production-directe.sh

echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/restore-production-directe.sh
echo ""

git commit -m "fix(production): restauration de la production directe ecrasee

La feature production directe (option A + production a creer)
avait disparu de production/index.html suite a un cp iCloud->repo
non diffe lors du commit 90a37a9. Re-injection complete a partir
de f84b551 :

- HTML : modale fiche-picker (recherche + filtres + zone
  Production a creer) ; bandeau chrono + scanner + section recap
  MP integres dans production-modal ; FAB + repris vers
  openProductionDirecte.
- JS  : tout le bloc PRODUCTION DIRECTE (selectFicheAndStart,
  startProductionACreer, pdLaunchScanner, rapprochement stock,
  recap MP rapproche, chrono pause/resume, wrappers
  saveProduction + closeProductionModal, etc.).

Le reste du fichier (prix au litre, cascade composant, edit_fiche
robuste depuis TAF, etc.) est preserve tel quel."

echo ""
echo "=== Push ==="
git push

echo "=== Termine OK ==="
