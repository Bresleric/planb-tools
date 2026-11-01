#!/bin/bash
# Caisse : CA repris de L Addition (etape 1, 01/11/2026)
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add caisse/index.html sw.js \
        supabase/functions/laddition-live/index.ts \
        scripts/migration-caisse-ca-laddition.sql \
        scripts/caisse-ca-laddition.sh

git commit -F - <<'MSG'
Caisse : CA repris de L Addition et verrouille, saisie de secours si la synchro est en panne

- Saisie : la case CA se remplit depuis L Addition et n est plus modifiable,
  avec la mention de l heure de mise a jour de la caisse
- Regle de fraicheur : service en cours si synchro sans erreur et de moins
  d 1 h ; jour passe seulement si la derniere synchro est apres minuit
  (le 20/10, journee incomplete, aurait ete refuse)
- Plan B : case saisissable et avertissement orange saisis le CA du ticket Z
- Jour deja enregistre avec un autre CA : les deux montants affiches et
  bouton Prendre le CA L Addition, rien n est ecrase en silence
- Bouton Actualiser depuis L Addition ; deverrouillage manuel pour l admin
- Origine du CA enregistree (ca_source, ca_laddition_le) - migration appliquee
- Edge function laddition-live : appel possible depuis le navigateur (CORS)
  et anti-rafale de 2 min (deployee, v5)
- Verrou Controle CA inchange ; Freddy et Liesel
- sw.js : bump v131

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
