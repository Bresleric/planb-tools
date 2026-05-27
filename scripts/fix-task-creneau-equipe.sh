#!/bin/bash
# ============================================================
# Fix erreur NOT NULL sur creneau / equipe a la creation d'une
# task spontanee (production directe + production a creer).
#
# Avant : "null value in column creneau of relation tasks
# violates not-null constraint"
# Apres : creneau deduit de l'heure (Matin < 11h < Midi < 16h
# < Soir), equipe = fiche.equipe sinon currentUser.equipe
# sinon 'cuisine'.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
echo ""

git add production/index.html scripts/fix-task-creneau-equipe.sh

echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/fix-task-creneau-equipe.sh
echo ""

git commit -m "fix(production): creneau + equipe obligatoires sur task spontanee

tasks.creneau et tasks.equipe sont NOT NULL ; les payloads de
selectFicheAndStart et startProductionACreer envoyaient null,
ce qui jetait 'null value in column creneau violates not-null
constraint' au demarrage de la production.

Defaults :
- creneau : fiche.creneau sinon deduit de l'heure courante
  (Matin/Midi/Soir)
- equipe  : fiche.equipe sinon currentUser.equipe sinon 'cuisine'."

echo ""
echo "=== Push ==="
git push

echo "=== Termine OK ==="
