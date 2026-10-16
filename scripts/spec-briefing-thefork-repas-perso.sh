#!/bin/bash
# ============================================================================
# Doc seule : spec du chantier Briefing (bloc TheFork en redaction + Repas perso)
# Preparee le 16/10/2026 pour la conversation PLANBTools application review.
# A lancer depuis ~/planb-tools APRES OK Eric sur le diff.
# Aucun code front touche -> pas de bump de CACHE_NAME necessaire.
# ============================================================================
cd "$(dirname "$0")/.." || exit 1

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add docs/SPEC-briefing-thefork-redaction-et-repas-perso.md \
  scripts/spec-briefing-thefork-repas-perso.sh

git commit -F - <<'MSG'
Docs : spec du chantier Briefing - bloc TheFork en redaction et bloc Repas perso

- Etat des lieux verifie : la synchro TheFork et la section de consultation
  existent deja (edge function thefork-sync, Freddy uniquement) ; il manque
  seulement le bloc dans onglet Redaction
- Chantier 1 : scinder renderTheForkSection en theForkBodyHtml + section,
  charger les resas dans loadOrCreateBriefing, afficher une form-section
  (elle entre dans le verrou des chapitres vus)
- Chantier 2 : bloc Repas perso (plat, date de production, stock, unite)
  avec migration idempotente de la colonne repas_perso sur briefings,
  les six points accroche du front et le correctif du libelle archivage
- Finitions rappelees : bump sw.js, verif syntaxe JS, etapes de test iPad

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
MSG

git push origin "$BRANCHE"
