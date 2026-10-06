# Reprise — Rapport journalier (module `rapport/`)

> Brief de passation pour continuer ce chantier depuis une autre conversation.
> Rédigé le 04/10/2026, mis à jour le 04/10/2026 (v2). État du code : v2.1 (SW v70).

## Ce que c'est

Synthèse quotidienne pour Eric (propriétaire), lue le MATIN : les DEUX
établissements côte à côte. Module `rapport/index.html`, lecture seule.
Logique de dates (arbitrée par Eric) : J = date affichée (défaut : hier) =
le BILAN ; J+1 = « aujourd'hui » (TAF, CA attendu, équipe) ; J+2 = « demain »
(TAF). Les flèches ‹ › déplacent tout ensemble.

## Accès — lien magique (PAS le login portail)

- Table `rapport_acces` (token, nom, actif) : un token actif « Eric (iPhone/iPad) ».
- URL : `rapport/?k=<token>`. Le front vérifie le token, sinon accepte une session
  portail admin/manager. Révocation : `UPDATE rapport_acces SET actif=false`.
- ⚠️ Ne JAMAIS committer un token (repo public). Les tokens se créent en base.

## Contenu v2 (par établissement) — demande d'Eric du 04/10/2026

1. 💰 La journée (J) : CA = caisse_controle.ca + vae, vs N-1 (ventes_journalieres
   date - 364 j) et vs prévu (briefing_previsions.ca_prevu, somme midi+soir) ;
   ÉCART DE CAISSE via `js/caisse-calc.js` (fond de départ = comptage_caisse de
   J-1, 0 si absent — même règle que le module Caisse) ; statut validée/à valider ;
   cumul du mois (1er → J) en % vs N-1 et en % du prévu, calculés seulement sur
   les jours présents des deux côtés.
2. 📅 Aujourd'hui (J+1) : CA attendu (+ couverts attendus), équipe midi/soir
   (planning_equipes), TAF de J+1 et J+2 : compteur + liste dépliable par créneau.
3. 🔔 À décider maintenant (état COURANT) : DLC aujourd'hui/demain, incidents
   ouverts, LISTE des besoins appro statut='demande' (urgents en tête).
4. ✅ Bilan de J : TAF faites/total, checklists ; températures (équipements
   relevés / actifs, passages = même personne à moins de 45 min d'écart, avec
   l'heure, hors norme, manquants) ; productions (dépliable, `date_production`
   dans la journée locale) ; réceptions = `scan_sessions.date_reception` (le
   module Réceptions actuel ; `receptions_documents` / `reception_sessions`
   sont morts depuis avril) ; cartons = `cartons_jvr.created_at` dans J (pas
   de notion de validation : saisi = validé).
5. Bloc global : notes de service (actives, non expirées) et informations
   (publiées, non archivées) dont le % de lecture < 100 %, avec les MÊMES règles
   de ciblage que les modules notes-service et information ; combo_veilleur_log 48 h.

### Ajouts v2.1 (demande Eric du 04/10/2026)

- 📅 Aujourd'hui : productions réalisées aujourd'hui (J+1, liste dépliée) et
  📒 cahier de liaison (`liaison_messages` non archivés, messages racines
  seulement, 7 derniers jours) : % de lecture par message. Cibles = destinataires
  du message, ou à défaut tous les users actifs de l'établissement, auteur exclu
  (`liaison_lectures`). Les destinataires nommés qui n'ont pas lu sont affichés.
- ✅ Bilan de J : ⏱️ planning vs pointage, SOURCE COMBO (table `combo_pointages`).
  L'équipe badge dans COMBO (badgeuse), PAS dans le module Pointages PBT
  (`pointage_periodes_travail` ne contient que quelques personnes : ne pas s'en servir).
  Alertes : non badgé, sortie non badgée, retard ≥ 10 min, pause badgée < prévue
  - 10 min, écart retenu/prévu ≥ 30 min (si entrée ET sortie badgées).

## Synchro des pointages Combo (mise en place le 04/10/2026)

- Edge function `combo-pointages` (supabase/functions/combo-pointages) appelée par
  pg_cron `combo-pointages-sync`. HORAIRES (demande Eric 06/10, il est matinal) :
  veilleur `0 0,1,9 * * *`, pointages `5 0,1,9 * * *` (GMT). pg_cron est en GMT sans
  heure d'été : le double passage 0h+1h GMT garantit un passage à 2h00 à Strasbourg
  toute l'année ; 9h GMT = passage de rattrapage des corrections managers.
  Trace : scripts/migration-combo-horaires-2h.sql.
  Par défaut : J-2 et J-1. Rattrapage : `?start=AAAA-MM-JJ&end=AAAA-MM-JJ`.
  Historique chargé depuis le 01/09/2026. Trace : scripts/migration-combo-pointages-cron.sql.
- Source : GET /api/v1/plannings (même endpoint que le veilleur). Champs par shift :
  `starts_at/ends_at/break_duration` (prévu), `real_starts_at/real_ends_at/
  real_break_duration` (retenu, arrondi par Combo), `events[]` (badgeages bruts :
  clock_in, clock_out, break_start, break_end avec event_occurred_at).
- Stockage : prévu → *_planifie ; badgeages bruts → debut_pointe/fin_pointee/
  pauses_pointees_minutes ; retenu → debut_valide/fin_validee/pauses_validees_minutes.
  `duree_travail_minutes` est une colonne GÉNÉRÉE (ne pas l'insérer).
  Lignes API marquées `import_fichier_nom = 'api-combo'` (remplacées à chaque passage) ;
  les lignes de juin (imports Excel) ne sont pas touchées.
- ⚠️ PIÈGE : sans badgeage, Combo RECOPIE le prévu dans le retenu (et une sortie
  non badgée reçoit l'heure de fin prévue). « Non badgé » = debut_pointe IS NULL.
- ⚠️ PIÈGE API Combo : `end_date` est EXCLUE. start=J&end=J+1 renvoie le seul jour J.
  Ce piège faisait que le veilleur ne chargeait jamais le planning du lendemain :
  corrigé le 04/10/2026 (end_date = après-demain), veilleur v4.
- Fonction `combo-diagnostic` : neutralisée (renvoie 410). Peut être supprimée
  depuis le dashboard Supabase.

## Formules de caisse partagées

`js/caisse-calc.js` (objet global `CAISSE_CALC.freddy|liesel`) est la SOURCE
UNIQUE des formules (contrôle CA, total CB, caisse théorique, écart). Le
module Caisse (`FIELDS.*.calc*`) et le rapport y font référence. Ne jamais
recopier une formule ailleurs.

## Pièges connus (vérifiés, ne pas re-découvrir)

- `ventes_journalieres` : imports L'Addition ARRÊTÉS depuis le 09/06/2026. Sert
  uniquement au N-1 (données antérieures). Le CA vivant est dans `caisse_controle`.
- `objectifs_ventes` : table VIDE (0 ligne). Pas de comparaison objectif en v1.
- Caisse : AUCUNE journée n'est marquée `valide=true` depuis au moins 14 jours
  (badge « à valider » partout). Question de process à poser à Eric.
- Températures Liesel : pas de statut N_A utilisé depuis août (normal ?).
- Réceptions Liesel : aucune scan_session depuis juillet 2026.
- Cartons : dernier carton saisi le 30/06/2026.
- `checklist_validations` : en sommeil depuis fin juin (module peu utilisé).
- Statuts besoins : 'demande' (en attente), 'valide', 'commande', 'annule'.

## Idées v2 (discutées avec Eric, non arbitrées)

- Envoi périodique à l'administrateur : email quotidien 8h via Gmail (proposé,
  pas encore accepté) et/ou Telegram (bot jamais créé — token BotFather attendu
  depuis septembre). Le rappel iOS + lien magique est la solution en place.
- Heures pointées vs planifiées.
- Relance des imports de ventes (sinon le N-1 s'assèche dès l'été 2027).

## Rappels de méthode (en plus de CLAUDE.md)

- Toute modif front user-visible → bump CACHE_NAME dans sw.js (actuel : v60).
- Flux git : commit sur la branche de travail, puis merge dans main (déploiement
  GitHub Pages) — Eric a validé ce flux en continu.
- Un chantier = une conversation à la fois (éviter deux sessions qui éditent les
  mêmes fichiers en parallèle).
