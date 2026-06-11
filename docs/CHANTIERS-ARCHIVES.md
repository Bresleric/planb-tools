# Chantiers archivés & idées dormantes — PlanB-Tools

> **À quoi sert ce fichier ?** C'est la mémoire des chantiers abandonnés, remplacés ou mis en pause.
> Quand une idée « subite » revient, on regarde ici : ce que c'était, pourquoi on l'a rangé,
> et comment le ressusciter. **Rien n'est jamais perdu** : git garde tout l'historique.
>
> **Pour ressusciter un élément** : demander à Claude Code de restaurer le dossier depuis
> le commit indiqué (commande type : `git checkout <commit> -- <chemin>`).
>
> Dernier commit contenant tous les fichiers archivés ci-dessous : **`6fbdda2`** (11/06/2026).

---

## 🗑️ Archivés le 11/06/2026 (ménage post-audit)

### `numerisations/` — Hub de numérisation OCR (Tesseract)
- **Ce que c'était** : un 2e point d'entrée pour scanner factures, BL et étiquettes (~2 900 lignes),
  avec OCR Tesseract.js côté client (texte brut, pas d'extraction structurée).
  Tables : `numerisations`, `numerisations_pages` (+ `schema_v2.sql` jamais activé avec `etiquettes_data`).
- **Pourquoi archivé** : doublon direct du module **Scanner**, qui fait la même chose en mieux
  (Claude Vision → extraction JSON structurée → traçabilité HACCP). Avoir 2 portes d'entrée
  pour le même geste créait de la confusion. Décision Eric du 11/06/2026 : Scanner = hub unique.
- **Si l'idée revient** : ne pas ressusciter tel quel — étendre plutôt le Scanner (nouveau
  `type_document` dans l'edge function `extract-document`).
- **Tables en base** : `numerisations` (2 lignes), `numerisations_pages` (3 lignes) — conservées,
  inoffensives. À supprimer un jour via migration si on veut faire le ménage en base aussi.

### `objectifs/` — Module Objectifs de Ventes autonome
- **Ce que c'était** : saisie des objectifs de CA jour par jour (N-1 calé + multiplicateur,
  badges fériés/vacances 8 pays). Jamais branché au portail.
- **Pourquoi archivé** : **porté comme onglet 🎯 Objectifs du module Ventes** (commit `f2b48e6`,
  validé sur iPad le 11/06/2026). Le dossier autonome devenait une double source de vérité.
- **Si l'idée revient** : tout est déjà vivant dans `ventes/index.html` (namespace JS `OBJ`).

### `kitchen-taf/` — Ancien module TAF
- **Ce que c'était** : la toute première version du TAF (« Kitchen TAF »).
- **Pourquoi archivé** : remplacé depuis longtemps par `taf/` (6 300 lignes, en prod).
- **Si l'idée revient** : aucune raison — `taf/` fait tout.

### `poc-scanner/` — Preuve de concept du scanner (1,2 Mo)
- **Ce que c'était** : POC « étiquettes chambre froide » avec vignettes de test.
- **Pourquoi archivé** : remplacé par le module `scanner/` en prod.

### `planb-pilote-snippets/` — Brouillons PlanB Pilote
- **Ce que c'était** : prototype « récap productions par collaborateur » (chrono TAF).
- **Pourquoi archivé** : brouillon d'exploration jamais intégré. L'idée (temps moyens de
  production par collaborateur) reste intéressante → données déjà collectées par le chrono TAF.

### `planb-tools-update/` — Ancien outil de migration
- **Ce que c'était** : pages de transition (receptions, stock-pf-pi) d'une ancienne migration.
- **Pourquoi archivé** : migration terminée, plus aucun usage.

### `receptions-audit.html` — Page d'audit ponctuelle
- **Ce que c'était** : page de debug/audit des réceptions, créée pour une investigation.
- **Pourquoi archivé** : investigation terminée.

### Scripts racine : `DEPLOY-DROITS-TABS.sh`, `DEPLOY-DROITS-V2.sh`, `DEPLOY-ELIS.sh`, `DEPLOY-HOWTO.sh`, `REVERT-TAF.sh`
- **Ce que c'était** : scripts de déploiement/retour arrière de chantiers passés (droits, Elis, HowTo, TAF).
- **Pourquoi archivés** : chantiers livrés depuis longtemps ; la convention actuelle range les
  scripts dans `scripts/`.

### `migration_prelevement_stock.sql` (racine) → déplacé vers `scripts/migrations/`
- Pas supprimé : déplacé à sa place conventionnelle. Voir « Prélèvement de stock » ci-dessous.

---

## 💤 Idées dormantes (chantiers B — codés à moitié, à reprendre un jour)

### 🔔 Notifications push iOS
- **État** : service worker prêt à RECEVOIR (Phase 0, `sw.js`), table `push_subscriptions` vide,
  table `notification_windows` configurée (4 lignes). Manque : l'abonnement côté iPad (Phase 1-3)
  et le ré-abonnement auto (Phase 4, TODO dans `sw.js`).
- **Potentiel** : alertes températures non relevées, caisse non contrôlée, briefing non lu…
- **Reprendre par** : edge function `send-push` + bouton « activer les notifications » dans le portail.

### 📦 Appro — Réception Phase 2 (scan des lots)
- **État** : Phase 1 (validation manuelle) en prod. Bouton « 🔒 Scanner (Phase 2) » désactivé dans
  `approvisionnement/index.html`. Tables `appro_receptions` / `appro_reception_articles` prêtes
  (colonne `scan_tracabilite_id` en attente).
- **Reprendre par** : ouvrir le Scanner avec `?return=appro`, remplir `scan_tracabilite_id` au retour.

### 🏷️ Prélèvement de stock
- **État** : migration appliquée (tables `prelevements`, `etiquettes_prelevement`,
  `rapprochement_apprentissage` — vides), **zéro interface**. SQL conservé dans
  `scripts/migrations/migration_prelevement_stock.sql`.
- **L'idée** : scanner l'étiquette d'un lot en stock pour en sortir une portion
  (production, repas perso, mise en place), avec étiquette enfant si reconditionnement.
- **Reprendre par** : un mode `?mode=prelevement` dans le Scanner + écriture `stock_mouvements` SORTIE.

### 📣 Briefings — extensions jamais utilisées
- Tables `briefing_rappels`, `briefing_produits`, `briefing_resume_hebdo`, `service_briefings` : vides.
  Sous-fonctions imaginées puis non utilisées. À réactiver ou supprimer en base un jour.

### 📰 Information — ciblage & pièces jointes
- Tables `information_targets/images/attachments/lectures` : vides. Le module Information existe,
  ces extensions n'ont jamais servi.

### 🤖 Apprentissage du rapprochement
- Table `rapprochement_apprentissage` : vide. Idée : mémoriser les corrections manuelles du
  matching étiquettes ↔ BL pour améliorer le rapprochement automatique au fil du temps.

---

## 🗄️ Vieilles tables en base (non touchées, candidates à suppression future)

Premier schéma « anglais » remplacé par les versions françaises — toutes vides, inoffensives :
`cash_controls`, `clock_events`, `supply_requests`, `deliveries`, `delivery_documents`.
À supprimer un jour via une migration `DROP TABLE` si on veut une base impeccable.
