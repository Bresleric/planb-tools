# PlanB-Tools — Playbook pour Claude Code

Ce fichier est lu automatiquement à chaque session Claude Code dans ce dossier. Il condense le contexte projet et les règles non-négociables pour éviter les regressions répétées.

## 1. Qui est l'utilisateur

Eric Bresler — propriétaire avec son épouse de PLANB SARL (2 restaurants à Strasbourg : **Freddy** et **Chez Tante Liesel**) et de Moulin Neuf SARL (immobilier). Il est gérant, **pas développeur**. Il pilote PBT pour déléguer les tâches admin répétitives. Communication en **français**, ton chaleureux et pédagogique, jamais condescendant. Explique les choix et les compromis. Ne saute pas d'étape sans dire pourquoi.

## 2. Vue d'ensemble du projet

PlanB-Tools est une web-app multi-modules pour la gestion opérationnelle des restaurants : TAF (tâches du jour), Production (fiches techniques + lots), Scanner (étiquettes matières premières via Claude Vision), Réceptions, Caisse, Pointages, Stock, Approvisionnement, Achats.

- **Hébergement** : GitHub Pages, branche `main`, URL `https://bresleric.github.io/planb-tools/`
- **BDD** : Supabase Postgres (projet `dzrherfavgiuygnimtux`)
- **Auth** : maison (sessionStorage planb_user + planb_etablissement, pas Supabase Auth)
- **Tech** : HTML/CSS/JS vanilla, un fichier `index.html` par module, pas de bundler, pas de build. C'est volontaire — Eric peut comprendre/relire chaque module en un coup d'œil.
- **PWA** : service worker `sw.js`, cache-first, manifest pour add-to-homescreen iPad.

## 3. Règles git — non-négociables

Ces règles existent à cause d'incidents passés. Ne jamais les enfreindre.

- **Vérifier la branche active au début de tout bloc git** : commencer par `git status` ou `git branch --show-current`. JAMAIS `git push origin main` aveugle. Si la branche est par exemple `feat/xyz`, c'est sur celle-là qu'on push.
- **Commits via scripts/** : pour toute modification de code, créer un fichier `scripts/<feature>.sh` qui fait `git add`, `git commit -m`, `git push`. Eric le lance avec `bash scripts/...sh`. Avantage : le message commit est dans un fichier (pas exposé aux apostrophes zsh qui cassent `-m "..."`), et on garde une trace de chaque modif côté repo.
- **Apostrophes dans les messages de commit** : INTERDITES. Le shell zsh d'Eric ferme le quote au copier-coller. Reformuler sans apostrophe ("l'autre" → "autre", "l'établissement" → "etablissement", etc.).
- **iCloud ↔ repo** : `~/planb-tools/` est la SEULE source de vérité pour le code. PAS d'édition dans iCloud, PAS de `cp iCloud → repo`. Si on trouve un dossier iCloud avec du code PBT, c'est obsolète, le repo prime. Les anciens scripts `resync-from-repo.sh` et `setup-token.sh` existent mais ne devraient plus être nécessaires.
- **`git pull --ff-only` en début de session** : toujours, avant de toucher au moindre fichier. Si non fast-forward → STOP, fetch + rebase, ne pas écraser.
- **`git status` après modification** : avant chaque commit, montrer le diff à Eric et attendre son OK explicite. Ne pas commiter d'autorité.

## 4. Conventions de nommage

- L'établissement est **« Chez Tante Liesel »** ou **« Liesel »**. **JAMAIS « Bonbao »** — c'est l'ancienne enseigne, la migration technique (BDD + code) a été faite le 28/03/2026. Toute occurrence de "Bonbao" dans le code est un bug à signaler.
- Freddy = code court pour le restaurant Freddy.
- Les deux établissements partagent une grande partie du back (table `predefined_tasks`, certaines `fiches_techniques.partagee=true`) mais ont des caisses, des stocks, des comptes séparés. Un utilisateur est rattaché à un seul établissement par session (`currentEtablissement`).

## 5. Architecture technique — points sensibles

- **Tables Supabase** :
  - `tasks` (et non `task`) — NOT NULL sur `creneau`, `equipe`, `echeance`. Pas de colonne `statut` (utiliser `fait_par_id` IS NULL/NOT NULL).
  - `productions` (et non `production`) — peut avoir `fiche_id NULL` + `a_creer_motif` rempli pour les productions à créer.
  - `fiche_ingredients.est_principal` BOOLEAN — drive le scan obligatoire B-2 au démarrage de production.
  - `tasks.scans_lots` JSONB — clé = `fiche_ingredients.id`, valeur = objet enrichi (`lot`, `dlc`, `produit`, `scan_tracabilite_id`, `lots_supplementaires[]`).
  - `stock_par_lot` est une VUE, pas une table. Source = `scan_tracabilite` JOIN `scans` JOIN `appro_ingredients`. `quantite_restante` = ENTREE - SORTIE + AJUSTEMENT depuis `stock_mouvements`.
  - `appro_ingredients` = catalogue articles. PAS de colonne `etablissement` (catalogue commun).
- **Supabase MCP** : peut être **read-only**. Avant de promettre un INSERT/UPDATE/migration ou un deploy d'edge function, tester silencieusement avec un no-op. Si c'est read-only, demander à Eric de coller le SQL dans Supabase → SQL Editor (créer un fichier `scripts/migration-xxx.sql` à exécuter).
- **Service Worker cache-first** : `sw.js` à la racine, `CACHE_NAME = 'planb-tools-vN'`. **Bumper N à chaque modification user-visible** du front (HTML/JS d'un module). Sans ça, les iPads PWA continuent à servir l'ancienne version depuis le cache.
- **localStorage** est utilisé pour les handovers entre modules :
  - `scan_fefo_context` + `scan_fefo_result` : TAF/Production ↔ Scanner pour scan rafale.
  - `planb_initial_tab` (sessionStorage) : sélection d'onglet à l'ouverture d'un module.

## 6. Conventions de code dans les modules

- **Pas de framework** : vanilla JS, fonctions globales, événements via `onclick=` ou `addEventListener` direct. Pas de jQuery, pas de React, pas de TypeScript. Si une refacto est tentante, en parler à Eric d'abord.
- **CSS dans `<style>` en début de fichier**, classes utility préfixées par contexte (`.taf-`, `.fiche-`, `.modal-overlay`, etc.). Variables `--gray-200`, `--red`, `--orange` définies en haut.
- **Modales** : `<div class="modal-overlay" id="xxx-modal" style="display:none;">`, ouverte avec `style.display = 'flex'`.
- **Toasts** : `showToast('message', 'success' | 'error')`.
- **Confirmation** : `openModal(title, html, buttons)` (le helper modale générique). Pour les actions destructives, demander confirmation explicite avec un bouton `cls: 'danger'`.
- **Async** : tout est `async/await` + `try/catch` + `showToast` d'erreur en cas d'échec. Ne pas avaler les erreurs silencieusement.

## 7. Tests / vérification avant push

- **Vérification syntaxe JS minimale** :
  ```
  node -e "const fs=require('fs');const h=fs.readFileSync('production/index.html','utf8');const re=/<script>([\\s\\S]*?)<\\/script>/g;let m;while((m=re.exec(h))){try{new Function(m[1]);console.log('OK');}catch(e){console.log('ERR',e.message);}}"
  ```
  À lancer avant chaque commit qui touche du HTML/JS. Si erreur → corriger avant push.
- **Pas de mocking** des connecteurs Supabase. Les tests se font en live (Eric a un environnement de prod unique).
- **Vérification fonctionnelle = Eric teste sur iPad** après push. Toujours lui donner les **étapes de test précises** dans le message qui accompagne le push (ex. : « ouvre le TAF de Freddy, clique sur la tâche Cervelas, vérifie que le scanner s'ouvre »).

## 8. Pièges connus à éviter

- **RLS sur toute nouvelle table** : créer une table sans policy = RLS active par défaut bloque TOUT (INSERT *et* SELECT) pour le rôle `anon` → erreur « new row violates row-level security policy », et lectures vides silencieuses. **Règle PBT** : toute nouvelle table doit avoir `ENABLE ROW LEVEL SECURITY` **+** une policy permissive `FOR ALL TO anon USING (true) WITH CHECK (true)` (même pattern que `fiche_ingredients`, `fiches_techniques_actions_post`). Modèle :
  ```sql
  ALTER TABLE ma_table ENABLE ROW LEVEL SECURITY;
  DROP POLICY IF EXISTS ma_table_anon_all ON ma_table;   -- CREATE POLICY IF NOT EXISTS n'existe pas en Postgres
  CREATE POLICY ma_table_anon_all ON ma_table AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);
  ```
  Toujours inclure ce bloc dans la migration de création de table. Vérif post-migration : `SELECT tablename, policyname FROM pg_policies WHERE tablename = 'ma_table';` (incident du 31/05/2026 : `fiches_techniques_sous_produits` créée sans policy → mode multi sous-produits jamais déclenché).
- **`</script>` dans un template literal** ferme le tag parent HTML. Toujours échapper en `<\/script>`.
- **`read -p` dans les scripts bash** : ne marche pas en zsh. Utiliser `read -r REPLY` (sans `-p`) puis afficher le prompt séparément.
- **Path mapping bash sandbox ↔ Mac d'Eric** : si tu vois `/sessions/.../mnt/planb-tools/`, c'est le chemin de la VM Cowork. Sur le Mac d'Eric c'est `~/planb-tools/` ou `/Users/eric/planb-tools/`. **Toujours donner à Eric les chemins en `~/planb-tools/`** dans les scripts et les messages.
- **Le scanner accepte `?return=taf` ou `?return=production`** selon qui a lancé. Si tu ajoutes un 3e appelant, augmenter le scanner pour gérer ce return.
- **Le bouton FAB `+` de production directe** appelle `openProductionDirecte()`, pas l'ancien `openProductionModal()`. Le second existait avant, ne PAS confondre.

## 9. Mémoire long-terme (côté Cowork)

Cowork (l'autre interface où Eric pose ses questions business + admin) maintient une mémoire détaillée du projet (qui fait quoi, pourquoi telle décision, etc.). Quand Claude Code a besoin de contexte non technique (ex. : « pourquoi cette migration a été faite », « qui est ce collaborateur »), Eric peut soit te le rappeler verbalement, soit te demander à Cowork de te préparer un brief. Ne pas réinventer le contexte.

## 10. Ce que tu peux faire spontanément

- Lire des fichiers, lancer des `grep`/`glob` pour comprendre le code avant de modifier.
- Proposer des refactos PETITES et bien isolées, mais demander confirmation à Eric avant.
- Créer des scripts dans `scripts/` (commit, migration SQL, debug).
- Pousser un commit après accord explicite d'Eric.

## 11. Ce que tu ne fais JAMAIS sans demander

- Modifier `sw.js` sans bumper `CACHE_NAME`.
- Renommer ou supprimer un module entier.
- Toucher au schéma BDD sans préparer une migration SQL idempotente (avec `IF NOT EXISTS`).
- Changer un composant qui a 3+ utilisateurs en aval (ex. : `DB.getTasks`, `DB.createProduction`, scanner rafale).
- Push une grosse refonte sans avoir testé la syntaxe JS d'abord.
- Force-push.
- Commit un message avec apostrophes.

---

**En cas de doute, demander à Eric. Mieux vaut un aller-retour rapide qu'un écrasement à débugger.**
