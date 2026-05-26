#!/bin/bash
# ============================================================
# Commit + push — Production directe (Option A)
# Le bouton + du module Production ouvre :
#   1. une modale "Choix fiche technique" (obligatoire)
#   2. la modale production augmentee : bandeau chrono + bouton
#      scanner les etiquettes + recap MP avec rapprochement stock
# Cote BDD une task spontanee=true est creee a la volee (invisible
# dans le TAF) pour beneficier du chrono + des stats par personne.
# A la validation : sorties de stock pour chaque lot, task spontanee
# marquee terminee. Annuler en cours de route supprime la task.
#
# PREREQUIS : la migration SQL doit avoir ete appliquee dans
# Supabase :
#   - scripts/migration-tasks-spontanee.sql (colonne tasks.spontanee)
#
# Modification DEJA appliquee dans le repo par Cowork :
#   - taf/index.html (filtre spontanee dans DB.getTasks)
#   - production/index.html (modale fiche-picker + bandeau directe
#       + JS rapprochement + saveProduction augmentee)
#   - scanner/index.html (retour vers production/ si return=production)
# Ce script ne fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="
echo ""
echo "=== Rappel : as-tu execute scripts/migration-tasks-spontanee.sql"
echo "    dans Supabase ? Si non, fais-le avant ce push."
echo ""

git add taf/index.html production/index.html scanner/index.html \
        scripts/production-directe.sh \
        scripts/migration-tasks-spontanee.sql

echo "=== Fichiers a committer ==="
git status --short taf/index.html production/index.html scanner/index.html \
                   scripts/production-directe.sh \
                   scripts/migration-tasks-spontanee.sql
echo ""

git commit -m "feat(production): production directe depuis le module Production

- Module Production : le bouton + ouvre desormais une modale Choix
  fiche technique (obligatoire), puis la modale production
  augmentee : bandeau chrono + bouton Scanner les etiquettes + recap
  MP avec rapprochement stock identique au TAF.
- BDD : nouvelle colonne tasks.spontanee. A la selection fiche une
  task spontanee=true est creee a la volee (invisible TAF mais
  visible pour les stats par personne, chrono, scans_lots).
- B-2 strict conserve : pas de validation tant que les ingredients
  principaux ne sont pas tous scannes.
- A la validation : sorties stock pour chaque lot selectionne,
  task spontanee marquee terminee + duree figee. Annuler en cours
  de route supprime la task spontanee.
- TAF : DB.getTasks filtre spontanee=false (ou null), donc ces
  productions ne polluent pas la liste planifiee.
- Scanner : accepte ?return=production et redirige correctement
  vers ../production/ au retour."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
