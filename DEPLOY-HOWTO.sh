#!/bin/bash
# Déploiement du module HowTo
# À exécuter depuis le dossier planb-tools-update/

set -e

echo "📦 Déploiement du module HowTo…"
echo ""
echo "⚠️  AVANT TOUT : exécute le schéma SQL dans Supabase"
echo "    → Ouvre le SQL Editor du projet dzrherfavgiuygnimtux"
echo "    → Colle le contenu de howto/schema.sql"
echo "    → Exécute"
echo ""
read -p "Schéma SQL exécuté ? [o/N] " ok
if [ "$ok" != "o" ] && [ "$ok" != "O" ]; then
  echo "Déploiement annulé."
  exit 1
fi

git add howto/index.html howto/schema.sql index.html DEPLOY-HOWTO.sh
git commit -m "Add HowTo module with tutorials for user onboarding

- New howto/ module with Supabase backend (3 tables)
- Step-by-step player (progress bar, prev/next)
- Admin editor for creating/editing tutorials
- View tracking per user
- 8 seed tutorials covering main modules
- Module tile added to portal grid"
git push origin main

echo ""
echo "✅ Déployé !"
echo "👉 https://bresleric.github.io/planb-tools/howto/"
