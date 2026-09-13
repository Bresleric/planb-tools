#!/usr/bin/env bash
# Trace repo du fix RLS sous-produits + regle CLAUDE.md (RLS sur toute nouvelle table).
# Le fix BDD lui-meme a deja ete applique en prod via le MCP Supabase.
# Usage : bash scripts/commit-fix-rls-sous-produits.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add CLAUDE.md scripts/fix-rls-sous-produits.sql

echo "=== Diff resume ==="
git status --short

git commit -m "fix(bdd): policy RLS manquante sur fiches_techniques_sous_produits

La table avait RLS active mais aucune policy (oubli migration Phase 1) :
tout INSERT/SELECT bloque pour anon -> sous-produits jamais sauves -> mode
multi jamais declenche. Ajout policy ftsp_anon_all (ALL, anon, true/true),
calquee sur fiches_techniques_actions_post. Deja applique en prod via MCP.

- scripts/fix-rls-sous-produits.sql : le fix idempotent (DROP IF EXISTS + CREATE)
- CLAUDE.md : nouvelle regle PBT - toute nouvelle table doit avoir RLS active
  + policy permissive anon ALL true/true, incluse dans la migration de creation"

git push origin main

echo "=== Termine ==="
