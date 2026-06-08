# Reprise de conversation — Phase 3 « production multi sous-produits » + bascule Cowork → Claude Code

## Identification

- **Sujet principal** : implémentation complète de la feature « production multi sous-produits » dans PlanB-Tools (1 production en cuisine → N étiquettes/contenants en sortie, cas Choucroute Garnie → 5 sous-produits), couplée à la bascule officielle du développement code de Cowork vers Claude Code et au nettoyage iCloud + git.
- **Date d'origine de la conversation** : 29/05/2026 (premier message : incident impression Freddy, "depuis hier nous narrivons pas à imprimer d étiquettes").
- **Date de la migration** : 2026-06-08.
- **Établissement(s) concerné(s)** : principalement **Freddy** (Choucroute Garnie, imprimante QL-820NWBc). Les modifs sont mutualisées Freddy + Liesel via le champ `fiches_techniques.partagee`, mais les tests terrain sont sur Freddy. **Liesel** n'est pas touché directement.
- **Mémoires Cowork pertinentes** : [[project_bascule_dev_claude_code]], [[project_cause_racine_ecrasements_code]], [[project_etiquettes_dk22251]], [[project_rapprochement_stock]], [[project_scan_obligatoire_production]], [[project_actions_post_production]], [[project_production_directe]], [[feedback_cp_icloud_ecrase_repo]], [[feedback_taf_sync_check_avant_modif]], [[feedback_resync_avant_edit_production]], [[feedback_apostrophes_commit_messages]], [[feedback_supabase_mcp_readonly]], [[feedback_rls_oblig_nouvelle_table]] (à créer), [[reference_planb_local_path]], [[reference_resync_from_repo]], [[reference_sw_cache_first_bump]], [[MEMORY]].

## Résumé chronologique

1. **Incident impression Freddy (29/05)** : diagnostic = iPad bascule sur un autre Wi-Fi que `laddition-3546`. Brother iPrint&Label ne trouvait plus la QL-820NWBc. Réflexe ajouté à `project_etiquettes_dk22251.md` (toujours vérifier le Wi-Fi en premier avant tout autre debug).
2. **Restauration de la feature « Production directe »** écrasée par un `cp iCloud → repo` du commit `90a37a9`. Extraction ciblée depuis le commit `f84b551` via `git show <sha>:fichier | sed`, puis ré-injection (1189 lignes JS + modale fiche picker + bandeau + section MP recap). Commit `c6e1b10` "fix(production): restauration de la production directe ecrasee".
3. **Bump SW v4 → v5** (`scripts/bump-sw-v5.sh`) pour purger le cache iPad après restauration.
4. **Discussion de fond cause-racine des écrasements** : iCloud + `~/planb-tools/` = 2 dossiers parallèles, le `cp` aveugle écrase ; sans synchronisation par git, les pertes sont inévitables. Mémoire `project_cause_racine_ecrasements_code.md` créée.
5. **Bascule Cowork → Claude Code officialisée (31/05)** : split des rôles (Cowork = porte d'entrée + spec + diag, Claude Code = exécution code, dans `~/planb-tools/`). Création de `CLAUDE.md` (playbook 11 sections) + `MODE-OPERATOIRE-CLAUDE-CODE.md` (1-pager). Test live validé via commit `d94525e` ("docs: journal des sessions - bascule officielle Cowork vers Claude Code"). Mémoire `project_bascule_dev_claude_code.md` créée.
6. **Nettoyage iCloud (31/05)** via `scripts/cleanup-icloud-code.sh` : 6 dossiers à 0 octet supprimés (`PlanB_Dashboard_Update`, `PlanB_Features_Update`, `PlanB_ModulesWithSubmenus`, `PlanbCompta-db`, `Downloads/PlanB_LoginAndMenu_Update`, `PlanB_QuickFix_Exit_Tasks_Equipment`) ; 4 dépôts git inactifs (`Kuizine` 2025-11-02, `Fiches techniques` 2025-10-13, `Kouizine` 2025-08-10, `KitchenTAF` 2026-03-09) + `PlanBistro.swiftpm` archivés (`~/iCloud-Archive-PBT-2026-05-31/`, ~3 Mo) puis supprimés. **À garder en iCloud** : `BAL_PlanB/` (factures/relances/DSN), Goodnotes, Pages, Numbers, Cowork-Artifacts.
7. **Nettoyage git** : suppression des branches orphelines `feat/caisse-historique-tableau`, `claude/nice-taussig-172c09` (worktree dans `.claude/worktrees/`), `Bresleric-patch-1` après vérification ancêtre de main. État final : `main` seule en local + distant, 1 worktree principal seul.
8. **Phase 1 BDD sous-produits** : `scripts/migration-sous-produits.sql` exécuté par Eric dans Supabase SQL Editor. Création de la table `fiches_techniques_sous_produits` + colonne `productions.parent_production_id`. Vérification : `nb_lignes_sous_produits=0` + `colonne_parent_production_id_presente=1`.
9. **Phase 2 UI Admin** : section "🍱 Sous-produits issus" ajoutée dans le formulaire d'édition fiche (production/index.html, tab-create).
10. **Bug RLS découvert** : la table `fiches_techniques_sous_produits` créée sans policy → INSERT échouait silencieusement (« new row violates row-level security policy »). Fix via `scripts/fix-rls-sous-produits.sql` appliqué par MCP Supabase : `CREATE POLICY ftsp_anon_all ON fiches_techniques_sous_produits AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);`. Règle ajoutée au `CLAUDE.md` §8 pour les futures sessions. Scan filet de sécurité : aucune autre table public avec RLS active sans policy.
11. **Refonte scanner rafale** (commits `aed2ecb` + `7b7fb7a` + `f7488f0`) : passage en mode liste cliquable (l'utilisateur choisit la MP qu'il scanne), analyse async non-bloquante, filtre `est_principal OR is_source_sous_produit` (plus d'épices dans la liste), sources de sous-produits en haut avec badge bleu « → sous-produit », bouton SHOOT fixe en bas. Bump SW v7 → v8 → v9.
12. **Phase 3 commit (a)** : fondation PDF multi-pages (refactor `genererPdfBlob` → `drawLabel` factorisé + boucle `addPage`) + handler `?prod_id=X&action=etiquette` dans production/index.html (qui détecte les filles via `parent_production_id` et génère le PDF multi). Bump SW v9 → v10.
13. **Phase 3 commit (b)** : UI N blocs sous-produits côté Production directe (`pdSaveProductionWrapper`), création mère/filles avec `parent_production_id`, pré-remplissage qty depuis `pdScannedLots` via `computeSousProduitQtys`. Commit `c3dd2dd`. Bump SW v10 → v13 (cumul avec commits intermédiaires).
14. **Fix DLC vide TAF** : alignement `saveProductionFromTaf` sur production directe (priorité manuelle > fiche > défaut +3 j). Commit `818f15d`. Bump SW v10 → v11. Bonus : code lot `MMJJ-CODE-NNN` ne sera plus `0000-CODE-001` (la DLC garantie non-null fixe ce bug latent).
15. **Bandeau DLC modale TAF** : "✅ DLC calculée : ..." (mer 4 juin 2026 / défaut +3 j) au-dessus du champ DLC manuelle, champ vide pour override seulement. Commit `1d3aa3e`. Bump SW v11 → v12. Recalcul au choix de fiche + mode "Nouveau produit".
16. **Polish UX scanner + étiquette** (commit `polish-scanner-etiquette`) : SHOOT fixe en bas (position fixed + `env(safe-area-inset-bottom)`), cadrage paysage limité à 480px max (.burst-cam-wrap), bouton "Sauvegarde PDF" qui restait figé sur "⏳ Génération PDF…" → reset via `pageshow` event (mono + multi). Bump SW v13 → v14.
17. **Phase 3 commit (c) flow TAF** (script `scripts/sous-produits-phase3c-taf.sh` prêt) : portage complet dans `saveProductionFromTaf` avec helpers TAF dupliqués (`tafGetSousProduits`, `tafComputeSousProduitQtys`, `tafRenderSousProduits`, `tafApplyMultiMode`, `tafSetupSousProduits`, `tafFormatDateTimeLocal`). UI section sous-produits dans modale TAF. Création mère + N filles. Redirection inchangée vers `?prod_id=MERE&action=etiquette&return=taf` (handler du commit a fait le reste). ~228 lignes. Bump SW v14 → v15. **EN ATTENTE DE PUSH PAR ERIC**.

## État actuel

### Exécuté / déployé / pushé (en ligne sur main + GitHub Pages)

- Restauration production directe (`c6e1b10`).
- Bascule Cowork → Claude Code + playbook (`d94525e`).
- CLAUDE.md + MODE-OPERATOIRE-CLAUDE-CODE.md poussés.
- Nettoyage iCloud effectué localement + scripts de cleanup commités.
- Nettoyage git effectué (branches orphelines + worktrees supprimés).
- Migration Phase 1 BDD sous-produits (table + colonne) exécutée dans Supabase.
- Policy RLS `ftsp_anon_all` appliquée via MCP Supabase.
- Phase 2 UI Admin sous-produits déployée.
- Refonte scanner rafale (mode liste cliquable + async + filtre + sources en haut) déployée.
- Phase 3 commit (a) — PDF multi-pages + handler `?prod_id&action=etiquette` déployé.
- Phase 3 commit (b) — validation Production directe avec sous-produits (`c3dd2dd`) déployée.
- Fix DLC vide TAF (`818f15d`) déployé.
- Bandeau DLC modale TAF (`1d3aa3e`) déployé.
- Polish UX scanner + étiquette (SW v14) déployé.
- Tests cuisine partiels validés : 5 étiquettes filles vues à l'écran sur Choucroute Garnie (mais pas encore imprimées physiquement).

### Livré mais non encore exécuté par Eric

- **`scripts/sous-produits-phase3c-taf.sh`** — Phase 3 commit (c) flow TAF. Script prêt, Eric doit faire `bash ~/planb-tools/scripts/sous-produits-phase3c-taf.sh`. Bumpera SW v14 → v15.
- Tests cible et non-régression du commit (c) à faire après push + hard-refresh PWA.
- Test physique impression Brother iPrint&Label (uniquement quand Eric est au resto Freddy, iPad sur `laddition-3546`).

### À faire (plan d'action restant numéroté)

1. Eric pousse `bash ~/planb-tools/scripts/sous-produits-phase3c-taf.sh` (commit c).
2. Hard-refresh PWA iPad pour invalider cache v14 → v15.
3. Test cible : TAF Freddy → tâche Choucroute Garnie → Play → scan des MP principales → Terminer → modale doit afficher 5 sous-produits pré-remplis → ajuster → valider → redirection production/?prod_id=MERE&action=etiquette&return=taf → PDF 5 étiquettes filles dans Safari.
4. Test non-régression : tâche TAF avec fiche standard sans sous-produits (Cervelas) → 1 étiquette mono comme avant.
5. Test physique impression (resto, Brother iPrint&Label) → 5 étiquettes papier qui sortent à la suite.
6. **Phase 4 — stock fongible** (à concevoir + implémenter) : créer des entrées `stock_mouvements` ENTREE pour chaque sous-produit cuit (Choucroute cuite, Lard salé cuit, etc.) à la validation production, et décrémenter via les ventes L'Addition. Complète la promesse initiale d'Eric ("la choucroute est fongible, on décompte les portions vendues"). Implique probablement une migration `productions.article_id` (option A3 reportée).
7. **Phase 5 — gestion erreurs scan** (à concevoir) : étiquette illisible/blanche, OCR mauvais, produit qui ne correspond pas à l'ingrédient attendu (cas test Eric : étiquette vide pour graisse de canard, paquet de knacks au lieu de gendarmes).
8. **Nettoyage scripts non suivis** dans `git status` (~20 fichiers `??`) : déplacer dans `scripts/archive/` (+ docs PDF dans `docs/`). Claude Code peut le faire mais EN ATTENTE du feu vert d'Eric.
9. **Module Trucs & Astuces** (knowledge base pannes/procédures) : design proposé, 3 questions en suspens (cf. section suivante).

## Questions en suspens

Questions auxquelles Eric n'a PAS encore répondu (à reformuler dès la nouvelle session) :

### Module Trucs & Astuces (3 questions)

1. **Qui crée des fiches Trucs & Astuces ?**
   - a) Admins uniquement
   - b) Tout collaborateur peut créer un brouillon, validé par un admin
   - c) Tout le monde peut créer directement

2. **Le scope : pannes uniquement, ou plus large ?**
   - a) Pannes seulement (« ça ne marche pas »)
   - b) Pannes + procédures (« comment changer le rouleau », « nettoyer le saladier »)
   - c) Pannes + procédures + sécurité/HACCP (« que faire en cas de coupure de courant »)

3. **Catégorisation** : catégories fixes (Imprimante / Scanner / Frigos / App / Plonge / Caisse / Autre) ou tags libres (`#imprimante`, `#bluetooth`, `#freddy`…) ?

### Autre question en attente

4. **Nettoyage scripts non suivis** : Eric a dit "on le fera quand tout sera stabilisé". À reproposer après Phase 3 complète.

## Apprentissages techniques notables

- **iCloud n'est pas synchronisé avec git** : un `cp iCloud → repo` aveugle écrase silencieusement le travail d'une autre session. Cause des 4+ régressions vécues en mai 2026. Fix durable = Claude Code travaille directement dans `~/planb-tools/`, iCloud sort du circuit pour le code.
- **Piège RLS Postgres / Supabase** : une nouvelle table sans policy avec RLS activée bloque TOUT (INSERT *et* SELECT) pour le rôle `anon`, **sans erreur visible côté SELECT** (renvoie 0 lignes silencieusement). L'INSERT lève une erreur claire mais le SELECT peut masquer le bug pendant des heures. **Règle PBT** : toute nouvelle table doit avoir `ENABLE ROW LEVEL SECURITY` + `CREATE POLICY xxx_anon_all ON table AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);`. `CREATE POLICY IF NOT EXISTS` n'existe pas en Postgres → utiliser `DROP POLICY IF EXISTS` + `CREATE POLICY` pour idempotence.
- **DLC null en cascade** : avant ce chantier, le code TAF ne posait pas de défaut +3 j si pas de fiche ni de DLC manuelle. Résultat : `productions.dlc` = null, étiquette DLC vide, ET le code lot `MMJJ-CODE-NNN` calculé depuis la DLC tombait à `0000-CODE-001`. Le fix DLC règle 2 bugs d'un coup.
- **Bouton iOS "Sauvegarde PDF"** : on ne peut PAS supprimer ce bouton du flow d'impression, il fournit le `user gesture` indispensable à iOS pour ouvrir un Blob PDF. Le bug n'était pas le bouton mais l'absence de reset de son libellé après retour du PDF (restait figé sur "⏳ Génération PDF…"). Fix via `pageshow` event.
- **L'OCR Claude Vision lit le numéro de lot différemment à chaque scan** (cf. memory `project_rapprochement_stock`) — on rapproche les étiquettes par empreinte DLC + poids exact au gramme, pas par lot OCR.
- **Sources de sous-produits sont en avant sur la liste scanner** via le flag `is_source_sous_produit` calculé côté appelants TAF + Production directe avant push dans `scan_fefo_context.ingredients`. Le scanner lui-même n'interroge pas la BDD.
- **Le scanner accepte `?return=taf` ou `?return=production`** → si on ajoute un 3e appelant, augmenter la liste dans `scanner/index.html`.
- **L'apostrophe typographique casse les `-m "..."` dans zsh** au copier-coller — toutes les conventions de commit + scripts shell doivent les éviter.
- **`init()` côté production/index.html peut être tué par n'importe quelle exception top-level avant son appel** : tous les wrappers (`saveProduction`, `closeProductionModal`) et `addEventListener` au scope top-level doivent être en try/catch sinon l'app ne booit plus du tout (cf. incident hotfix défensif déployé).
- **L'ordre de l'event loop iOS** : init() synchrone se termine AVANT que les `await DB.getFiches()` résolvent. Les `setTimeout(0, editFiche)` queué dans le `.then()` de loadFiches doit fire APRÈS `switchTab(initialTab)`. C'est l'inverse qui ne marche pas (testé).

## Données brutes utiles à recoller

### Identifiants

- **Projet Supabase** : `dzrherfavgiuygnimtux`
- **URL prod** : `https://bresleric.github.io/planb-tools/`
- **Repo local** : `/Users/eric/planb-tools/`
- **Remote** : `https://github.com/Bresleric/planb-tools.git`
- **Branche unique** : `main`
- **Cache SW actuel** : `v14` si commit (c) pas encore poussé. Sera `v15` après push.
- **Archive iCloud** : `~/iCloud-Archive-PBT-2026-05-31/` (5 tar.gz, supprimable après 1 mois si pas de regret).
- **Wi-Fi imprimante Freddy** : `laddition-3546` (à vérifier sur iPad si l'impression coince).
- **IP imprimante QL-820NWBc Freddy** : `192.168.192.125` (à confirmer, données d'avant).

### Commits clés mentionnés (SHA partiels)

| SHA | Description |
|---|---|
| `c6e1b10` | Restauration production directe écrasée |
| `d94525e` | Bascule Cowork → Claude Code (journal) |
| `aed2ecb` | Refonte scanner rafale + bump SW v8 |
| `7b7fb7a` | Flags est_principal + is_source_sous_produit dans appelants |
| `f7488f0` | Filtre épices (scanner réduit aux principaux) |
| `c3dd2dd` | Phase 3 commit (b) prod directe |
| `818f15d` | Fix DLC vide TAF |
| `1d3aa3e` | Bandeau DLC modale TAF |
| (à venir) | Phase 3 commit (c) TAF — script `sous-produits-phase3c-taf.sh` prêt |

À vérifier : `git log --oneline -30` au début de la nouvelle session pour confirmer.

### Schéma table `fiches_techniques_sous_produits` (Phase 1 BDD)

```sql
CREATE TABLE IF NOT EXISTS fiches_techniques_sous_produits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiche_id UUID NOT NULL REFERENCES fiches_techniques(id) ON DELETE CASCADE,
  ordre SMALLINT NOT NULL DEFAULT 0,
  nom TEXT NOT NULL,
  article_id UUID REFERENCES appro_ingredients(id),
  source_article_id UUID REFERENCES appro_ingredients(id),
  ratio_transformation NUMERIC NOT NULL DEFAULT 1,
  categorie TEXT,
  quantite_estimee NUMERIC,
  unite TEXT,
  dlc_jours INTEGER,
  dlc_heures INTEGER,
  temperature_stockage TEXT,
  conditionnement TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(fiche_id, nom)
);

CREATE INDEX IF NOT EXISTS idx_ftsp_fiche ON fiches_techniques_sous_produits(fiche_id);
CREATE INDEX IF NOT EXISTS idx_ftsp_source ON fiches_techniques_sous_produits(source_article_id)
  WHERE source_article_id IS NOT NULL;

ALTER TABLE productions
  ADD COLUMN IF NOT EXISTS parent_production_id UUID REFERENCES productions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_prod_parent ON productions(parent_production_id)
  WHERE parent_production_id IS NOT NULL;

ALTER TABLE fiches_techniques_sous_produits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ftsp_anon_all ON fiches_techniques_sous_produits;
CREATE POLICY ftsp_anon_all ON fiches_techniques_sous_produits
  AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);
```

### 5 sous-produits Choucroute Garnie (à vérifier en BDD après push commit c)

| Sous-produit | Source crue | Ratio | Unité | DLC (à valider terrain) |
|---|---|---|---|---|
| Choucroute cuite | Choucroute crue (seau 10 kg) | × 1 | kg | (à valider) |
| Lard salé cuit | Lard salé cru | × 1 | kg | (à valider) |
| Lard fumé cuit | Lard fumé cru | × 1 | kg | (à valider) |
| Kassler cuit | Kassler cru | × 1 | kg | (à valider) |
| Gendarmes cuits | Gendarmes crus (1 paquet = 20 pièces) | × 2 | portion (= 40 portions) | (à valider) |

**Vérif rapide** :
```sql
SELECT sp.nom, sp.source_article_id, sp.ratio_transformation, sp.quantite_estimee, sp.unite, sp.dlc_jours, sp.dlc_heures
FROM fiches_techniques_sous_produits sp
JOIN fiches_techniques f ON f.id = sp.fiche_id
WHERE f.nom ILIKE '%choucroute garnie%'
ORDER BY sp.ordre;
```

### Décisions actées (rappel pour ne pas re-débattre)

- **A1** : Phase 3 ne persiste pas `article_id` sur les filles `productions`. La Phase 4 fera A3 (entrée stock pour sous-produits cuits, nécessitera une migration `productions.article_id`).
- **B** : filles masquées de la liste principale Production via `WHERE parent_production_id IS NULL`. Drill-down possible plus tard.
- **Cowork ≠ Claude Code** : Cowork prépare specs + diagnostics, Claude Code exécute le code. iCloud sort du circuit pour le code.
- **Scanner** filtre `est_principal = true OR is_source_sous_produit = true`. Sources en haut avec badge `→ sous-produit`.
- **DLC** : priorité manuelle > fiche > défaut +3 j (TAF aligné sur Production directe).
- **Mode multi sous-produits** : champ qty global caché, N blocs affichés. Mode mono inchangé strictement.
- **Production directe** : pas de création de FT via le picker → option "Production à créer" avec `a_creer_motif`.
- **Picker production directe** : masque les fiches catégorie `plat` (cuisinées à la commande, pas produites à l'avance).

### Fichiers / scripts livrés pendant la conversation

- `~/planb-tools/CLAUDE.md` (modifié au fil de la conversation, version finale avec §8 piège RLS).
- `~/planb-tools/MODE-OPERATOIRE-CLAUDE-CODE.md` (avec section Journal des sessions en fin).
- `~/planb-tools/scripts/migration-sous-produits.sql` (exécuté).
- `~/planb-tools/scripts/fix-rls-sous-produits.sql` (appliqué via MCP).
- `~/planb-tools/scripts/cleanup-icloud-code.sh` (exécuté).
- `~/planb-tools/scripts/restore-production-directe.sh` (exécuté).
- `~/planb-tools/scripts/bump-sw-v5.sh` (et `v6`, `v7`, etc. au fil des commits).
- `~/planb-tools/scripts/setup-claude-code-playbook.sh` (exécuté).
- `~/planb-tools/scripts/polish-scanner-etiquette.sh` (exécuté).
- `~/planb-tools/scripts/sous-produits-phase3c-taf.sh` (**EN ATTENTE de bash par Eric**).

### Mémoires créées / mises à jour côté Cowork

- `memory/project_bascule_dev_claude_code.md` (nouvelle).
- `memory/project_cause_racine_ecrasements_code.md` (nouvelle).
- `memory/project_etiquettes_dk22251.md` (update : section troubleshooting Wi-Fi en fin).
- `memory/MEMORY.md` (index mis à jour avec les 2 nouvelles entrées).

## Instructions pour l'instance d'arrivée

À toi, instance Cowork sur le nouveau Mac, dès le démarrage de la session :

1. **Lis ces mémoires dans cet ordre** : `MEMORY.md` (index), puis `project_bascule_dev_claude_code.md`, `project_cause_racine_ecrasements_code.md`, `project_etiquettes_dk22251.md` (section troubleshooting), `project_rapprochement_stock.md`, `project_scan_obligatoire_production.md`, `project_production_directe.md`. Ces 6 fichiers couvrent 95 % du contexte technique de cette conversation.
2. **Lis aussi `~/planb-tools/CLAUDE.md`** (côté repo) pour les règles non-négociables ; il est aussi chargé par Claude Code à chaque session côté ligne de commande.
3. **Reprends à l'étape 1 du plan d'action restant** : demander à Eric s'il a poussé `bash ~/planb-tools/scripts/sous-produits-phase3c-taf.sh` et fait le hard-refresh PWA iPad.
4. **Avant d'agir sur la base** : vérifier l'état du repo via `git log --oneline -10` et `git status`. Confirmer qu'on est bien sur `main` à jour, sans branches orphelines.
5. **Vérification Supabase** : si tu doutes de l'état (sous-produits Choucroute Garnie présents ? policy RLS toujours là ?), exécute les queries de vérif fournies en section "Données brutes". Si MCP Supabase non authentifié, demander à Eric.
6. **Attends la réponse d'Eric à la question 1 (push Phase 3c fait ou non)** avant de proposer la suite. Ne pas anticiper Phase 4 / Phase 5 / nettoyage scripts / Trucs & Astuces tant que Phase 3 n'est pas validée terrain.
7. **Si Eric pose les 3 questions du module Trucs & Astuces** (ou y répond), c'est dans la section "Questions en suspens".
8. **Tonalité** : français, chaleureux, jamais condescendant, pas de surcharge d'actions parallèles (Eric a vécu une journée chargée, mode opératoire linéaire). Si tu vois qu'Eric s'inquiète d'une régression apparente (genre "aucune TAF liée à une FT"), demande-lui un screenshot AVANT de partir en diagnostic profond.
9. **Sur le nouveau Mac** : Eric devra probablement cloner `~/planb-tools/` depuis `https://github.com/Bresleric/planb-tools.git`, et installer Claude Code via `sudo npm install -g @anthropic-ai/claude-code`. Le mode opératoire `MODE-OPERATOIRE-CLAUDE-CODE.md` couvre les 5 étapes au démarrage d'une session.
10. **Ne pas modifier le code PBT directement depuis Cowork** en règle générale. Préparer le prompt à coller dans Claude Code. Exception : modifs mineures et isolées si Eric est explicitement OK.
