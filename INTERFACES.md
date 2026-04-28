# PlanB-Tools — Contrat de données avec PLANB-pilote

Ce document formalise les **données que PlanB-Tools expose** au projet
**PLANB-pilote**. Les deux apps partagent le même projet Supabase
(`dzrherfavgiuygnimtux`). PlanB-Tools est **producteur** des données ; PLANB-pilote
les consomme en lecture seule via des vues `pilote.v_*` (cf. document miroir
[INTERFACES.md du repo planb-pilote](https://github.com/Bresleric/planb-pilote/blob/main/INTERFACES.md)).

Document tenu à jour à chaque évolution structurelle. Version contrat :
**1.0 (28 avril 2026)**.

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

**Total : 7 tables sources sous contrat.**

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
| 2026-04-20 | `pointages/schema.sql` initial | (à compléter) | Création des 4 tables Pointages + 10 postes seedés. |
| 2026-04-23 | `pointages/migration_v2.sql` | (à compléter par le hash du commit `refactor(pointages): refonte selon vision Eric ...`) | DROP `pointage_salaries`. Renommage `salarie_id` → `user_id`. Index unique fixé sur `(user_id, date_service)`. |
| 2026-04-26 | Hotfix SQL ad hoc dans Supabase SQL Editor | n/a (pas de fichier versionné) | Fermeture auto des périodes orphelines des jours passés + correction index unique. |

⚠️ **Le hotfix du 26/04 n'est pas dans un fichier `migration_v3.sql`**. À régulariser : créer le fichier post-fait pour traçabilité, ou à minima ajouter une note ici.

---

## 4. Phases à venir et impact sur PLANB-pilote

| Phase | Période | Tables touchées | Impact Pilote |
|---|---|---|---|
| **Phase 2 — Plannings** | mai-juin 2026 | nouvelles : `pointage_plannings`, `pointage_planning_creneaux` | Additif, faible risque. |
| **Phase 3 — Congés** | juin 2026 | nouvelles : `pointage_conges_demandes`, `pointage_conges_soldes` | Additif. |
| **Phase 4 — Export paie** | juin 2026 | `pointage_periodes_travail` : remplit `heures_normales_minutes`, `heures_sup_minutes`, `majoration_*_minutes` (actuellement NULL) | **Bonne nouvelle** : Pilote pourra arrêter le workaround `NOW() - debut_service` dans `v_pointages_en_cours`. |
| **Phase 5 — RLS** | post-juin 2026 | `pointage_*` et `users` : activation Row Level Security | **Risque élevé.** Pilote devra basculer sur `service_role` key ou ajouter des policies dédiées au rôle de lecture admin. Issue de pré-avis obligatoire avant activation. |
| **Auto-fermeture nocturne** des périodes orphelines | mai 2026 | INSERTs/UPDATEs sur `pointage_periodes_travail` (job cron Supabase) | Pas d'impact schéma. Améliore la fiabilité des données lues par Pilote. |
| **Correction `duree_travail_minutes`** | en parallèle | Nouvelles fermetures auto utiliseront une heure estimée (pas `fin_service = debut_service`) | Pilote pourra simplifier son workaround. |

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
