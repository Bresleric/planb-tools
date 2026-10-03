# Reprise — Rapport journalier (module `rapport/`)

> Brief de passation pour continuer ce chantier depuis une autre conversation.
> Rédigé le 04/10/2026. État du code : v1 déployée et fonctionnelle (SW v59).

## Ce que c'est

Synthèse quotidienne pour Eric (propriétaire) : les données de la veille des DEUX
établissements côte à côte, pour décider le matin. Module `rapport/index.html`,
lecture seule, navigation par date (défaut : hier).

## Accès — lien magique (PAS le login portail)

- Table `rapport_acces` (token, nom, actif) : un token actif « Eric (iPhone/iPad) ».
- URL : `rapport/?k=<token>`. Le front vérifie le token, sinon accepte une session
  portail admin/manager. Révocation : `UPDATE rapport_acces SET actif=false`.
- ⚠️ Ne JAMAIS committer un token (repo public). Les tokens se créent en base.

## Contenu v1 (par établissement)

1. 💰 La journée : CA = caisse_controle.ca + vae (PAS ventes_journalieres, voir
   pièges) ; comparaison N-1 = ventes_journalieres du même jour de semaine un an
   avant (date - 364 j) ; statut caisse (valide / à valider / non saisie).
2. 🔔 À décider maintenant (état COURANT, pas la date affichée) : lots DLC
   aujourd'hui/demain (stock_par_lot, quantite_restante > 0), besoins appro
   statut='demande' (+ urgence), incidents briefing ouverts/en_cours.
3. ✅ Discipline (à la date affichée) : tasks faites/total (echeance = date),
   temp_releves (+ hors_norme), checklist_validations (periode = date).
4. 👥 Aujourd'hui : planning_equipes du jour (synchro Combo, 2x/jour) — effectifs
   midi/soir distincts.
5. 👤 Bloc global : combo_veilleur_log des dernières 48 h (statuts cree/a_verifier).

## Pièges connus (vérifiés, ne pas re-découvrir)

- `ventes_journalieres` : imports L'Addition ARRÊTÉS depuis le 09/06/2026. Sert
  uniquement au N-1 (données antérieures). Le CA vivant est dans `caisse_controle`.
- `objectifs_ventes` : table VIDE (0 ligne). Pas de comparaison objectif en v1.
- Écart de caisse : volontairement ABSENT de la v1. Sa formule vit dans
  caisse/index.html (différente Freddy/Liesel, FIELDS.*.calcEcart) — ne pas la
  dupliquer. Piste v2 : le module Caisse enregistre l'écart calculé en base,
  le rapport le lit.
- `checklist_validations` : en sommeil depuis fin juin (module peu utilisé).
- Statuts besoins : 'demande' (en attente), 'valide', 'commande', 'annule'.

## Idées v2 (discutées avec Eric, non arbitrées)

- Écart de caisse (via enregistrement côté module Caisse, cf. ci-dessus).
- Envoi périodique à l'administrateur : email quotidien 8h via Gmail (proposé,
  pas encore accepté) et/ou Telegram (bot jamais créé — token BotFather attendu
  depuis septembre). Le rappel iOS + lien magique est la solution en place.
- Production du jour (lots crées), réceptions, heures pointées vs planifiées.
- Relance des imports de ventes (sinon le N-1 s'assèche dès l'été 2027).

## Rappels de méthode (en plus de CLAUDE.md)

- Toute modif front user-visible → bump CACHE_NAME dans sw.js (actuel : v59).
- Flux git : commit sur la branche de travail, puis merge dans main (déploiement
  GitHub Pages) — Eric a validé ce flux en continu.
- Un chantier = une conversation à la fois (éviter deux sessions qui éditent les
  mêmes fichiers en parallèle).
