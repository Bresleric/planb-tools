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

## 💶 Caisse : CA pré-rempli et verrouillé depuis L'Addition (étape 1, v131, déployé le 01/11/2026)

- **Caisse : CA pré-rempli et verrouillé depuis L'Addition (étape 1), saisie
  manuelle de secours si la synchro est en panne ; étape 2 à venir = moyens de
  paiement.**
- **Pourquoi** : sur 35 journées comparées (analyse du 01/11), 29 identiques au
  centime, 4 fautes de frappe de l'équipe chez Freddy (0,01 à 0,23 €), et le
  20/10 faux côté L'Addition (jeton expiré à 18h30, CA de l'après-midi seulement).
  D'où la règle : **jamais de pré-remplissage à l'aveugle**.
- **Règle de fraîcheur** : service encore ouvert pour ce jour (`laddition_live`)
  → pris si pas d'erreur et synchro < 1 h ; jour passé (`laddition_ventes_jour`)
  → pris seulement si la dernière synchro est **après minuit** (L'Addition garde
  le service ouvert jusqu'à l'ouverture du lendemain ; le 20/10 est refusé).
  Sinon : saisie manuelle du ticket Z, avertissement orange.
- **Jour déjà enregistré avec un autre CA** : on garde l'enregistré, on affiche
  les deux et on propose « Prendre le CA L'Addition » (jamais d'écrasement
  silencieux). Lien « Saisir à la main » réservé à l'admin.
- **Traçabilité** : `caisse_controle.ca_source` ('laddition' | 'manuel') et
  `ca_laddition_le`. Les jours antérieurs au 01/11 sont à NULL.
- **Bouton « Actualiser depuis L'Addition »** : appelle l'edge function
  `laddition-live` depuis l'iPad (CORS ajouté) ; **anti-rafale 2 min** côté
  serveur car la clé publique suffit pour l'appeler (protège le compte d'Eric).
- **Inchangé** : verrou Contrôle CA (v107), paiements, CB par terminal,
  mouvements, comptage (toujours saisis à la main). Freddy et Liesel.
- **Où** : `caisse/index.html` (`chargerCaLaddition`, `appliquerCaLaddition`),
  `supabase/functions/laddition-live/index.ts`, `scripts/migration-caisse-ca-laddition.sql`.

## 💶 L'Addition Live : CA et stock en direct dans Pilotage (v113, déployé le 12/10/2026)

- **Quoi** : onglets « CA live » et « Stock » du module Pilotage, alimentés toutes les
  30 min (pg_cron `laddition-live-30min`, 8h-23h30 UTC) par l'edge function
  `laddition-live` qui lit live.laddition.com. Tables : `laddition_live` (état
  courant), `laddition_ventes_jour` (historique), `laddition_ruptures` (horodatées).
- **Authentification fragile par nature** : pas d'API officielle — on utilise le
  refreshToken du compte d'Eric, collé dans `pbt_private.config`
  (`laddition_refresh_token`) via `pbt_service_config_set`. **Jamais en clair** :
  ni repo, ni logs, ni affichage. Si L'Addition casse la synchro (rotation,
  changement d'API), l'erreur s'affiche dans Pilotage et il faut recoller un
  jeton frais depuis le navigateur.
- **Durée de vie constatée du jeton : ~8 jours** (collé le 12/10 vers 16h30,
  refusé le 20/10 à 18h30, recollé le 21/10). Panne suivante attendue vers le
  28-29/10.
- **Alerte Telegram (21/10/2026)** : au 1er échec de synchro, Eric reçoit sur
  Telegram l'erreur + les 2 lignes SQL de réparation ; rappel toutes les 6 h
  maximum tant que ça dure ; message « rétablie » au retour. État dans
  `pbt_private.config` (`laddition_alerte_debut`, `laddition_alerte_le`).
- **Pièges gérés** : articles en double dans le stock caisse (clé « nom #2 »,
  exclus des ruptures) ; compteurs ≥ 1000 = non suivis ; chaque photo contient
  le total du restaurant (prendre la plus récente, même avec 3 iPads).
- **Où** : `supabase/functions/laddition-live/index.ts`,
  `scripts/migration-laddition-live.sql`, `pilotage/index.html`.
- **Au passage** : le sw.js v113 embarque le correctif chemins relatifs et le
  ré-abonnement du chantier « notifications push » (autre conversation) ; la
  fonction `notif-push` qu'il référence restait à déployer au 12/10.

## 📦 Stock matières premières : chantier « contrôle permanent » (démarré le 02/11/2026)

- **Diagnostic** (02/11) : le stock affiché était faux. Entrées : depuis juillet,
  ~900 étiquettes/mois scannées chez Freddy mais **non rattachées à un article**
  (0 rattachement en juil./août/sept., 72 en oct.) → jamais entrées en stock.
  Sorties : seulement le scan FEFO des productions (~150/mois pour 1 100
  productions), rien pour la consommation en service. Liesel ne scanne pas
  (1-2 étiquettes/semaine) mais fait des inventaires journaliers.
- **Assainissement** (02/11, validé par Eric) : 483 lots ramenés à zéro par des
  mouvements `AJUSTEMENT` (`source_table = 'assainissement'`, réversibles) —
  371 à DLC dépassée, 63 sans DLC lisible scannés il y a > 45 j, 49 en négatif.
  Liste : `docs/ASSAINISSEMENT-STOCK-2026-11.md`.
- **Deux bugs à corriger avant toute consommation théorique** : (1) les produits
  intermédiaires entrés en stock par Production (depuis le 10/10) n'ont **aucune
  sortie** → fantômes chaque semaine ; (2) les sorties de production ont une
  **erreur d'unité** (grammes de recette comptés en kilos : −13 t d'épaule d'agneau).
- **Priorités d'Eric** : (A) savoir ce qu'il y a pour commander juste, puis (C)
  traçabilité HACCP, puis (B) pertes/écarts. Périmètre : viandes, BOF, épicerie et
  gros volumes (farine, vins de cuisine…). Les deux maisons ; Eric relance Liesel
  sur l'usage de l'app.
- **Plan** : étape 1 = réparer la porte d'entrée (rattachement express des
  étiquettes, mémorisé) ; étape 2 = sorties réalistes (consommation théorique par
  recettes + comptage périodique, PI compris) ; étape 3 = tableau de bord et alertes.

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
