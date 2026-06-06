# PlanB-Tools — Contrat de données avec PLANB-pilote

Ce document formalise les **données que PlanB-Tools expose** au projet
**PLANB-pilote**. Les deux apps partagent le même projet Supabase
(`dzrherfavgiuygnimtux`). PlanB-Tools est **producteur** des données ; PLANB-pilote
les consomme en lecture seule via des vues `pilote.v_*` (cf. document miroir
[INTERFACES.md du repo planb-pilote](https://github.com/Bresleric/planb-pilote/blob/main/INTERFACES.md)).

Document tenu à jour à chaque évolution structurelle. Version contrat :
**1.1 (6 juin 2026)** — ajout des tables `combo_pointages`, `combo_user_mapping` et de la vue `pointages_unifies` suite à la migration v4 (import historique Combo).

---

## 1. Tables exposées (contrat de stabilité)

Tables dont PlanB-Tools garantit la stabilité des colonnes listées. Toute
évolution (renommage, suppression, changement de sémantique) fait l'objet d'une
**issue de pré-avis dans `Bresleric/planb-pilote`** avant déploiement (cf. §5).

| Table (schéma `public`) | Colonnes garanties | Notes |
|---|---|---|
| `users` | `id` (uuid), `code` (PIN), `nom`, `initiales`, `role`, `etablissement`, `acces_etablissements` (text[]), `actif` (bool) | PIN reste source d'auth PlanB-Tools. Toute extension RH va dans une autre table. |
| `etablissements` | `id`, `nom` | Référentiel partagé Freddy/Liesel. |
| `pointage_postes` | `id`, `code`, `nom`, `equipe`, `etablissement` (nullable) | 10 postes seedés au 23/04/2026. |
| `pointage_evenements` | `id`, `user_id` (uuid), `user_nom` (text), `type_evenement` (`debut_service`/`debut_pause`/`fin_pause`/`fin_service`), `horodatage` (timestamptz), `date_service` (date), `etablissement`, `periode_travail_id` (uuid), `source` (text) | Migration v2 (23/04/2026) : `salarie_id` → `user_id`. |
| `pointage_periodes_travail` | `id`, `user_id`, `user_nom`, `date_service`, `etablissement`, `debut_service`, `fin_service` (nullable), `duree_pauses_minutes` (int), `duree_travail_minutes` (int generé), `statut` (text), `heures_normales_minutes`, `heures_sup_minutes`, `majoration_nuit_minutes`, `majoration_dimanche_minutes`, `majoration_ferie_minutes` (NULL aujourd'hui, remplis Phase 4) | Workflow validation 6 statuts : `saisi` → `en_attente_manager` → `valide_manager` → `en_attente_salarie` → `valide_salarie` (ou `conteste`). |
| `ventes_journalieres` | `date`, `service` (`midi`/`soir`/`journee`), `etablissement`, `ca_ttc`, `ca_ht`, `couverts`, `ticket_moyen` (généré) | Import L'Addition (Liesel OK 97j, Freddy bloqué API). |
| `devices` | `id`, `nom`, `etablissement`, `code_activation`, `device_token`, `actif` | Si Pilote veut tracer activation tablettes. |
| `combo_pointages` | `id`, `date_service`, `etablissement_combo`, `etablissement`, `equipe_combo`, `equipe`, `collaborateur_nom_combo`, `user_id` (uuid, nullable), `debut_planifie`/`fin_planifiee`/`pauses_planifiees_minutes`, `debut_pointe`/`fin_pointee`/`pauses_pointees_minutes`, `debut_valide`/`fin_validee`/`pauses_validees_minutes`, `duree_travail_minutes` (généré), `valide_par_nom`, commentaires (3), import_fichier_nom | **Migration v4 (06/06/2026)**. Importé depuis exports Combo XLSX. 3 niveaux : planifié/pointé/validé (le validé = source de vérité paie). Idempotent via UNIQUE(date, collaborateur, etab, debut_planifie). 1994 lignes au 06/06 (jan→juin). |
| `combo_user_mapping` | `id`, `combo_collaborateur_nom` (unique), `user_id` (uuid, nullable), `match_method`, `match_confidence`, `notes` | **Migration v4**. Lookup table nom Combo ↔ user PBT. 29 mappings pré-remplis. `user_id NULL` = extra refusé à la création (5 cas connus). |

### Vues exposées

| Vue (schéma `public`) | Colonnes garanties | Notes |
|---|---|---|
| `pointages_unifies` | `source` (`planb-tools`/`combo`), `source_id`, `user_id`, `user_nom`, `date_service`, `etablissement`, `equipe` (nullable), `debut`, `fin`, `duree_pauses_minutes`, `duree_travail_minutes`, `statut`, `valide_par_nom` (nullable), `commentaire` | **Migration v4**. UNION de `pointage_periodes_travail` (fin_service IS NOT NULL) + `combo_pointages` (debut_valide+fin_validee IS NOT NULL). Source de vérité unifiée pour Pilote pendant la cohabitation des 2 systèmes (jusqu'à bascule 01/07/2026). |

**Total : 9 tables sources + 1 vue sous contrat.**

---

## 2. Ce qui peut changer SANS pré-avis (hors contrat)

Pour préserver la vélocité de PlanB-Tools et clarifier le périmètre :

- **Tous les fichiers HTML/CSS/JS frontend** (modules `pointages/`, `taf/`, `production/`, `receptions/`, `temperatures/`, `ventes/`, `caisse/`, `admin/`, etc.). PLANB-pilote n'en consomme aucun.
- **Tables des modules opérationnels non listés au §1** : `taf_*`, `production_*`, `receptions_*`, `temperatures_*`, `caisse_*`, `briefings_*`, etc.
- **Ajout de colonnes** à une table listée au §1 (additif, ne casse rien). Mention en changelog mais pas pré-avis bloquant.
- **Ajout de tables** dans le schéma `public` (additif).
- **Création/modification d'index** (impact perfo, pas sémantique).

---

## 3. Version courante du schéma

| Date | Migration appliquée | Commit hash PlanB-Tools | Notes |
|---|---|---|---|
| 2026-04-20 | `pointages/schema.sql` initial | (historique non traçable) | Création des 4 tables Pointages + 10 postes seedés. |
| 2026-04-23 | `pointages/migration_v2.sql` | (historique non traçable) | DROP `pointage_salaries`. Renommage `salarie_id` → `user_id`. Index unique fixé sur `(user_id, date_service)`. |
| 2026-04-26 | Hotfix SQL ad hoc dans Supabase SQL Editor | n/a (pas de fichier versionné) | Fermeture auto des périodes orphelines des jours passés + correction index unique. |
| 2026-05-14 | `pointages/migration_v3_auto_close.sql` | (historique non traçable) | Job pg_cron quotidien 23:59 UTC qui ferme auto les périodes orphelines avec fin_service=23:59:59. Élimine l'héritage des oublis fin de service. |
| 2026-06-06 | `pointages/setup_combo_users.sql` | `37389b9` | Création de 8 users + correction 2 typos (Anne-Sophie, Eric Bresler) pour matching Combo. |
| **2026-06-06** | **`pointages/migration_v4_combo_pointages.sql`** | **`a8557c2`** | **PIN ACTUEL** : tables `combo_pointages` + `combo_user_mapping` + vue `pointages_unifies`. Pré-remplit 29 mappings. **Bloc RLS ajouté par Claude Code au moment du déploiement** (oubli côté Cowork — voir feedback mémoire `feedback_rls_oblig_nouvelle_table`). |

⚠️ **Régularisation à faire** : le hotfix du 26/04 n'est pas dans un fichier versionné. Les hash des commits antérieurs au 2026-06-06 ne sont pas traçables (non capturés à l'époque) — la pratique est désormais de capturer systématiquement le hash à chaque déploiement.

---

## 4. Phases à venir et impact sur PLANB-pilote

| Phase | Période | Tables touchées | Impact Pilote |
|---|---|---|---|
| **Phase 2 — Plannings** | mai-juin 2026 | nouvelles : `pointage_plannings`, `pointage_planning_creneaux` | Additif, faible risque. |
| **Phase 3 — Congés** | juin 2026 | nouvelles : `pointage_conges_demandes`, `pointage_conges_soldes` | Additif. |
| **Phase 4 — Export paie** | juin 2026 | `pointage_periodes_travail` : remplit `heures_normales_minutes`, `heures_sup_minutes`, `majoration_*_minutes` (actuellement NULL) | **Bonne nouvelle** : Pilote pourra arrêter le workaround `NOW() - debut_service` dans `v_pointages_en_cours`. |
| **Phase 5 — RLS** | post-juin 2026 | `pointage_*` et `users` : activation Row Level Security | **Risque élevé.** Pilote devra basculer sur `service_role` key ou ajouter des policies dédiées au rôle de lecture admin. Issue de pré-avis obligatoire avant activation. |
| **Auto-fermeture nocturne** ✅ déployée 14/05 | livré | pg_cron 23:59 UTC sur `pointage_periodes_travail` | fin_service auto-rempli à 23:59:59. Pilote peut compter dessus. |
| **Import Combo backfill** ✅ déployé 06/06 | livré | `combo_pointages` + vue `pointages_unifies` | 1994 lignes jan→juin 2026 importées. Pilote peut consommer la vue. |
| **Import Combo routine quotidienne** | juin 2026 | Scheduled task Cowork → `combo_import.py` | Importe automatiquement chaque export quotidien Combo. Pas d'impact schéma. |
| **Bascule officielle Combo → PlanB-Tools natif** | 01/07/2026 | Plus aucune nouvelle ligne dans `combo_pointages` après cette date | Pilote bascule sa source de vérité sur `pointage_periodes_travail` uniquement (ou continue d'utiliser `pointages_unifies` qui couvrira automatiquement). |

---

## 5. Engagements PlanB-Tools (en miroir de Pilote)

1. **`INTERFACES.md` à jour.** Ce document est tenu à jour à chaque migration structurelle. Il est la référence officielle du contrat.
2. **Pré-avis breaking change.** Toute migration touchant les colonnes garanties au §1 (renommage, suppression, changement de sémantique) fait l'objet d'une **issue ouverte dans `Bresleric/planb-pilote`** avec le diff schéma, **avant déploiement**.
3. **Versionning.** Migrations versionnées (`schema.sql`, `migration_v2.sql`, `migration_v3.sql`...). Le tableau §3 est tenu à jour conjointement avec le pin Pilote.
4. **Référentiel légal CCN HCR exclusivement.** Tout calcul d'heures/seuils intègre CCN HCR + Code du travail français + jours fériés Alsace-Moselle. Aucune référence à L-GAV (cf. §7).
5. **Stabilité du périmètre `users`.** Les comptes Supabase Auth d'Eric et Valérie sont la propriété de Pilote — PlanB-Tools ne touche pas à ces comptes spécifiques (cf. §6 du miroir).

## 6. Engagements PLANB-pilote (reçus 28/04/2026)

1. **Lecture seule.** Pilote n'effectue jamais d'INSERT/UPDATE/DELETE sur le schéma `public`. Les écritures sont confinées au schéma `pilote` (vues).
2. **Pré-avis sur évolution de scope.** Tout ajout d'une nouvelle table source au contrat fait l'objet d'une issue dans `Bresleric/planb-tools`.
3. **Pin de version.** Pilote pin son commit hash de référence à chaque migration et tient le tableau §3 à jour.
4. **Aucune copie locale.** Pilote ne stocke pas de duplicata des données ; tout est calculé à la volée via vues SQL.
5. **Auth séparée.** Pilote utilise Supabase Auth pour Eric et Valérie. PlanB-Tools utilise les PINs sur `users.code`. Pas de croisement.

---

## 7. Référentiel légal — précision importante

⚠️ **L-GAV est interdit comme référentiel.** L-GAV est la convention collective
**suisse** de l'hôtellerie-restauration. Elle ne s'applique pas à Freddy ni à
Liesel, qui sont en France.

Le référentiel légal applicable est :

- **CCN HCR** (Convention Collective Nationale Hôtels-Cafés-Restaurants), 35 h/sem
- **Code du travail français** pour les seuils non couverts par la CCN
- **Jours fériés Alsace-Moselle** (Vendredi Saint et 26 décembre en plus du régime national)

Note historique : le `pointages/schema.sql` initial du 20/04/2026 référence
"L-GAV / 42h" comme commentaire — résidu d'une mauvaise hypothèse au cadrage.
À nettoyer dans une migration future. Aucun calcul actuellement codé sur cette
base, donc pas de risque immédiat.

---

## 8. Arbitrage de scope (miroir du §8 Pilote)

Acté le 28 avril 2026 lors des discussions croisées entre les deux sessions Cowork :

| Bloc fonctionnel | Côté Pilote | Côté PlanB-Tools |
|---|---|---|
| CA / couverts / ventes (consultation) | ✅ Lots 0-1 | (saisie + scraping L'Addition) |
| Pointages temps réel (qui est en service) | ✅ Lot 1 | (saisie via PIN) |
| Pointages historique cumulé | ✅ post Phase 4 | — |
| Suivi prêts bancaires | ✅ Lot 2 | — |
| Trésorerie 13 semaines glissantes | ✅ Lot 3 | — |
| Réserve cash | ✅ Lot 4 | — |
| Marges (food cost, labor cost) | ✅ Lot 5 | — |
| **Indicateurs RH agrégés** (masse salariale €/mois, absentéisme, soldes congés) | ✅ futur Lot 6 | (alimente la donnée) |
| **TAF / Production / Réceptions** | ❌ pas dans Pilote | ✅ écrans existants |
| **Suivi RH opérationnel quotidien** (qui est en pause maintenant, oublis à corriger, validation hebdo des pointages par Valérie) | ❌ pas dans Pilote | ✅ futur `/admin/pointages.html` |

L'artifact Cowork `planb-pointages-tracker` qui faisait du suivi pointages a
été abandonné le 28/04/2026 au profit de cette répartition.

---

## 9. Procédure en cas de divergence

Si PLANB-pilote détecte un breaking change non pré-avisé :

1. Pilote ouvre une issue de blocage dans `Bresleric/planb-tools` avec :
   - Le message d'erreur Postgres
   - Le commit suspecté côté Tools
   - L'impact constaté côté Pilote
2. PlanB-Tools propose un fix sous 24h (rollback de la migration ou hotfix permettant à Pilote de continuer en attendant son adaptation).
3. Le pin §3 du présent document et de son miroir Pilote sont mis à jour avec le commit de résolution.
4. Si récidive : retroadd au tableau §1 d'une colonne précédemment hors contrat.

---

## 10. Liens utiles

- Repo PlanB-Tools : <https://github.com/Bresleric/planb-tools>
- Repo PLANB-pilote : <https://github.com/Bresleric/planb-pilote>
- INTERFACES.md miroir côté Pilote : <https://github.com/Bresleric/planb-pilote/blob/main/INTERFACES.md>
- Projet Supabase mutualisé : <https://dzrherfavgiuygnimtux.supabase.co>
- Coordination transverse PLANB (mémoire Cowork) : `reference_coordination_transverse.md` du projet **PLANB Pilotage**

---

*Mainteneur PlanB-Tools : Eric Bresler. Document rédigé conjointement entre la session Cowork "Build tracking module for PlanB-Tools" et la session "PLANB Pilotage" le 28/04/2026.*
