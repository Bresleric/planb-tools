#!/bin/bash
# ============================================================
# Commit + push — Production directe v2 :
#   - Plus de bouton « Creer une fiche » dans le fiche picker
#   - A la place : zone « Production a creer » (textarea motif +
#     bouton). Cree une task spontanee + a_traiter, fiche_id null,
#     a_creer_motif rempli. Admin reprend ensuite pour creer la
#     fiche correspondante.
#   - Filtre la categorie « Plat » du fiche picker (les plats
#     sont cuisines a la commande, pas produits a l'avance).
#
# Modification DEJA appliquee dans le repo par Cowork
# (production/index.html). Ce script ne fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="
echo ""

git add production/index.html scripts/production-acreer-no-plat.sh

echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/production-acreer-no-plat.sh
echo ""

git commit -m "feat(production): production a creer + filtre Plat

- Fiche picker : retire la CTA 'Creer une fiche' au profit d'une
  zone 'Production a creer'. Le collaborateur saisit une description
  (>= 5 caracteres) et clique 'Demarrer une production a creer'.
  Une task spontanee + a_traiter est creee (fiche_id null, motif
  conserve dans observation et a_creer_motif). Pas de scan
  obligatoire (pas de fiche), chrono demarre immediatement, pas de
  sortie stock. La task sera reprise par l'admin pour creer la
  fiche correspondante.
- Le fiche picker filtre la categorie 'plat' : les plats sont
  cuisines a la commande, pas produits a l'avance, donc inutile
  de polluer la liste."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
