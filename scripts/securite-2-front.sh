#!/bin/bash
# ============================================================================
# SECURITE Phase 2/3 : bascule du front sur les sessions securisees
# (07/10/2026). A lancer depuis ~/planb-tools APRES OK Eric sur le diff.
# Prerequis : phase 1 appliquee en base + connexions anonymes activees.
# ============================================================================
cd "$(dirname "$0")/.." || exit 1
git add js/planb-common.js index.html admin/index.html approvisionnement/index.html \
  checklist/index.html temperatures/index.html ventes/index.html taf/index.html \
  briefing/index.html production/index.html receptions/index.html receptions/elis.html \
  liaison/index.html notes-service/index.html sw.js scripts/securite-1-sessions.sql \
  scripts/securite-2-front.sh
git commit -F - <<'MSG'
Securite phase 2 : le front passe aux sessions securisees pbt

- planb-common.js : helpers PLANB.assurerSession/login/logout/verifierPin/changerPin/activerAppareil/maSession + detecteur erreurs de session
- Portail : connexion via pbt_login (appareil exige cote serveur pour les collaborateurs), ecran obligatoire de changement de code a la premiere connexion, activation appareil via RPC avec reprise automatique du login, deconnexion revoquant la session serveur, memorisation admin via p_memoriser validee par pbt_ma_session
- 19 controles PIN repartis dans 14 fichiers basculess sur pbt_login / pbt_verifier_pin : plus AUCUNE lecture de users.code dans le front
- Verrous d inactivite : verification a 6 chiffres saisis (quota anti force brute preserve)
- Admin : plus aucun PIN affiche ni saisi ; bouton Reinitialiser le code (code provisoire affiche une seule fois) ; bouton Voir l appli comme cette personne avec bandeau et retour sur le portail
- taf : liste users sans la colonne code
- sw.js : CACHE_NAME bump v93 -> v94

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG
git push -u origin claude/planb-tools-review-kuJtH
