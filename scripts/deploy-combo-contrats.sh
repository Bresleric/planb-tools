#!/bin/bash
# =============================================================================
# Deploiement de la fonction combo-contrats (reprise des contrats Combo)
# Usage : bash scripts/deploy-combo-contrats.sh   (depuis ~/planb-tools/)
# Le CLI supabase n est pas installe sur ce Mac : le script copie le code dans
# le presse-papiers et affiche les etapes a faire dans le tableau de bord.
# Pre-requis : migration-equipe-phase1.sql executee (table rh_contrats).
# Le secret COMBO_API_KEY existe deja (utilise par le veilleur).
# =============================================================================
set -e
cd "$HOME/planb-tools"
pbcopy < supabase/functions/combo-contrats/index.ts
echo "==> Code de combo-contrats copie dans le presse-papiers."
echo ""
echo "1. Supabase -> Edge Functions -> Deploy a new function -> Via Editor"
echo "2. Nom de la fonction : combo-contrats"
echo "3. Effacer le code d exemple, coller (Cmd+V), cliquer Deploy function"
echo "4. Onglet Test : lancer SANS parametre (mode lecture, ne modifie rien)"
echo "5. Copier le resultat a Claude"
