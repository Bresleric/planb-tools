# Mémoire des décisions — PlanB-Tools

> **À quoi sert ce fichier ?** C'est la mémoire des décisions fonctionnelles importantes :
> ce qui a été mis en place, quand, et surtout **pourquoi**. À lire avant de modifier ou
> retirer un comportement qui semble « bizarre » — il a souvent une raison précise.
> (Les chantiers abandonnés, eux, vivent dans `CHANTIERS-ARCHIVES.md`.)

---

## 💶 Caisse : verrou « Contrôle CA » (v107, déployé le 10/10/2026)

- **Quoi** : dans le module Caisse, les blocs **Mouvements**, **Clôture**, l'onglet
  **Comptage** et le bouton **Terminer la clôture** sont bloqués tant que le
  **Contrôle CA n'est pas à zéro** (tolérance 1 centime). Le bouton Enregistrer
  n'est jamais bloqué : on peut toujours sauvegarder une saisie en cours.
- **Pourquoi** : le 08/10/2026 chez Freddy, une clôture a été validée avec
  **870 € d'écart** au Contrôle CA. Le verrou force à corriger la saisie
  (CA, règlements) avant de pouvoir clôturer.
- **Où** : `caisse/index.html` — `isCaBloque()`, `isChampVerrouille()`,
  `toastCaBloque()`, classe CSS `body.ca-bloque`. Freddy et Liesel.
- **Ne pas retirer** sans décision explicite d'Eric.

## 🍴 TheFork : réservations Freddy dans le Briefing (v108, déployé le 10/10/2026)

- **Quoi** : table `reservations_thefork` alimentée toutes les heures (pg_cron
  `thefork-sync-horaire`, minute 7) par l'edge function `thefork-sync`.
  Le Briefing Freddy affiche une section « Réservations TheFork » et remplit les
  compteurs Réserv. / Couv. attendus **uniquement s'ils sont vides** (une saisie
  manuelle n'est jamais écrasée).
- **Contraintes TheFork à respecter** : jeton OAuth mis en cache dans
  `pbt_private.config` (expire ~8600 s, ne JAMAIS redemander un jeton valide) ;
  limites 200 req/min et 10 000 req/jour ; **pas de webhooks** dans leur API,
  d'où la synchro horaire. Secrets `THEFORK_CLIENT_ID/SECRET` : jamais dans le
  front, le repo ou les logs.
- **Données clients minimales** : nom + allergies + commentaire. Ni téléphone ni
  email (choix délibéré, minimisation RGPD).
- **Où** : `supabase/functions/thefork-sync/index.ts`, `scripts/migration-thefork.sql`,
  `briefing/index.html` (`fetchReservationsTheFork`). Liesel : ajouter son UUID
  TheFork dans le tableau `RESTAURANTS` de la fonction le jour venu.
