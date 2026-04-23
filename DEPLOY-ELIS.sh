#!/bin/bash
# ============================================================
# DEPLOY ELIS — Sous-module ELIS dans Réceptions
# ============================================================
# Ce script documente les étapes de déploiement du sous-module
# ELIS (suivi linge / vêtements / sanitaire avec le prestataire Elis).
#
# Étape 1 : exécuter le SQL dans Supabase SQL Editor
# Étape 2 : copier les fichiers vers ~/planb-tools/ puis commit + push
# ============================================================

set -e

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"
REPO="$HOME/planb-tools"

echo "=== ÉTAPE 1 — SQL Supabase ==="
echo ""
echo "Ouvrir :"
echo "  https://supabase.com/dashboard/project/dzrherfavgiuygnimtux/sql/new"
echo ""
echo "Coller et exécuter le contenu de :"
echo "  $ICLOUD/receptions/elis-schema.sql"
echo ""
echo "Ce script crée 3 tables (elis_articles, elis_mouvements, elis_mouvements_lignes),"
echo "les RLS, et insère 21 articles de référentiel (17 Freddy + 4 Liesel)."
echo ""
echo "Vérification attendue (à exécuter après le script) :"
echo "  SELECT etablissement, service, COUNT(*)"
echo "  FROM elis_articles"
echo "  GROUP BY etablissement, service"
echo "  ORDER BY etablissement, service;"
echo ""
read -p "Le SQL a été exécuté avec succès dans Supabase ? (o/N) " ok
if [[ "$ok" != "o" && "$ok" != "O" ]]; then
  echo "Abandon. Relancez après avoir exécuté le SQL."
  exit 1
fi

echo ""
echo "=== ÉTAPE 2 — Copie vers ~/planb-tools ==="
cd "$REPO"
cp "$ICLOUD/receptions/index.html"       receptions/index.html
cp "$ICLOUD/receptions/elis-schema.sql"  receptions/elis-schema.sql

echo ""
echo "=== ÉTAPE 3 — Git commit + push ==="
git add receptions/index.html receptions/elis-schema.sql
git commit -m "feat(receptions): add ELIS sub-module for linen/uniform tracking

- New 'ELIS' tab inside the Receptions module
- Inventaire mode (Sale + Stock) and Passage mode (Retour + Livré + Stock)
- Seeded referential for Freddy (17 articles) and Liesel (4 articles)
  covering Linge-Service, Habillement-Porteur, Habillement-Groupe,
  Sanitaire and Sol-Service
- 3 new tables: elis_articles, elis_mouvements, elis_mouvements_lignes"
git push

echo ""
echo "✅ Déploiement terminé. Attendre ~1 minute que GitHub Pages propage."
echo "   URL : https://bresleric.github.io/planb-tools/receptions/"
