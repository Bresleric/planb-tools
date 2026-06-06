# Import Combo → Supabase

Script d'import des données de pointages depuis les fichiers Excel exportés de **Combo** vers la table `combo_pointages` de Supabase.

Préparé en parallèle de l'application native PlanB-Tools pour :
1. **Préparer la bascule** prévue au 01/07/2026 (archivage de l'historique RH avant coupure de Combo)
2. **Cross-checker** les pointages PlanB-Tools natifs avec ceux validés dans Combo (source de vérité paie actuelle)
3. **Alimenter PlanB-Pilote** via la vue `pointages_unifies`

---

## 📦 Prérequis

### 1. Migration SQL appliquée

Avant le premier import, exécuter dans Supabase :
- `pointages/setup_combo_users.sql` (déjà fait le 2026-06-06, commit `37389b9`)
- `pointages/migration_v4_combo_pointages.sql` (à exécuter via Claude Code)

Cette migration crée :
- Table `combo_pointages`
- Table `combo_user_mapping` (pré-remplie avec 29 mappings)
- Vue `pointages_unifies` (consommée par PlanB-Pilote)

### 2. Dépendances Python

```bash
pip3 install openpyxl supabase
```

### 3. Variables d'environnement

Le script a besoin du **service_role key** (pas l'anon key, sinon RLS bloque les écritures) :

```bash
export SUPABASE_URL='https://dzrherfavgiuygnimtux.supabase.co'
export SUPABASE_SERVICE_KEY='eyJhbGciOiJI...'  # Dashboard Supabase > Project Settings > API > service_role
```

⚠️ **Ne jamais committer le service_role key**. Le stocker dans `~/.zshrc` ou un fichier `.env` (gitignored).

---

## 🚀 Utilisation

### Import d'un fichier unique

```bash
cd ~/planb-tools/pointages/scripts
python3 combo_import.py "/path/to/Rapport des émargements et validations - 2026-06-01 au 2026-06-05.xlsx"
```

### Import de tous les fichiers d'un dossier

```bash
python3 combo_import.py --all ~/Library/Mobile\ Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools/_imports/combo/
```

### Simulation (dry-run, sans toucher à la base)

```bash
python3 combo_import.py --dry-run /path/to/file.xlsx
```

### Mode verbeux (debug)

```bash
python3 combo_import.py -v /path/to/file.xlsx
```

---

## 🔁 Idempotence

L'import est **idempotent** grâce à la contrainte `UNIQUE(date_service, collaborateur_nom_combo, etablissement_combo, debut_planifie)` sur `combo_pointages` :

- Réimporter le même fichier ne crée **pas de doublons** : les lignes existantes sont mises à jour (UPSERT).
- Réimporter un fichier modifié (par exemple Valérie a corrigé une heure dans Combo après l'export précédent) met à jour les valeurs.

---

## 🧩 Mapping des utilisateurs

Le script utilise la table `combo_user_mapping` pour faire correspondre les noms Combo aux `users.id` PlanB-Tools.

- **Si un nom Combo n'est pas dans `combo_user_mapping`** : la ligne est quand même importée dans `combo_pointages`, mais avec `user_id = NULL`. Le script affiche un warning à la fin avec la liste des noms non mappés.
- **Pour ajouter un mapping manuel** :

```sql
INSERT INTO combo_user_mapping (combo_collaborateur_nom, user_id, match_method)
SELECT 'Nom Tel Que Dans Combo', u.id, 'manual'
FROM users u WHERE u.nom = 'Nom Tel Que Dans PlanB-Tools';
```

---

## 📅 Workflow recommandé pour le backfill historique

Pour importer les 6 mois jan→juin 2026 (déjà uploadés dans iCloud) :

```bash
# Backfill complet en une commande
python3 combo_import.py \
  "~/Library/Mobile Documents/.../uploads/Rapport des émargements et validations - 2026-01-01 au 2026-01-31.xlsx" \
  "~/Library/Mobile Documents/.../uploads/Rapport des émargements et validations - 2026-02-01 au 2026-02-28.xlsx" \
  "~/Library/Mobile Documents/.../uploads/Rapport des émargements et validations - 2026-03-01 au 2026-03-31.xlsx" \
  "~/Library/Mobile Documents/.../uploads/Rapport des émargements et validations - 2026-04-01 au 2026-04-30.xlsx" \
  "~/Library/Mobile Documents/.../uploads/Rapport des émargements et validations - 2026-05-01 au 2026-05-31.xlsx" \
  "~/Library/Mobile Documents/.../uploads/Rapport des émargements et validations - 2026-06-01 au 2026-06-05.xlsx"
```

Attendu : environ **1995 lignes upsertées**.

---

## 🗓️ Routine quotidienne (à mettre en place après le backfill)

Une fois le backfill validé, on mettra en place une routine quotidienne :

1. Eric exporte chaque matin depuis Combo le rapport de la veille (CSV ou XLSX)
2. Il le dépose dans `~/Library/Mobile Documents/.../PlanB-Tools/_imports/combo/`
3. Une **scheduled task Cowork** détecte le nouveau fichier et appelle `combo_import.py`
4. Une notification résume les lignes ajoutées et signale les éventuels noms non mappés

La scheduled task sera créée dans une session Cowork ultérieure, après validation du script en mode manuel.

---

## 🐛 Dépannage

### Problème : "ERREUR : module supabase manquant"

```bash
pip3 install --break-system-packages supabase openpyxl
```

### Problème : `Onglet 'Planb' introuvable`

Vérifier que le fichier Combo a bien un onglet nommé `Planb` (vu sur les 6 fichiers déjà reçus).

### Problème : `RLS bloque les écritures`

S'assurer que la variable `SUPABASE_SERVICE_KEY` contient bien la **service_role key** (pas l'anon key, qui est lecture seule par défaut).

### Vérifier ce qui a été importé

```sql
-- Compteur global
SELECT COUNT(*) AS nb_lignes, MIN(date_service) AS depuis, MAX(date_service) AS jusqu_a
FROM combo_pointages;

-- Par établissement
SELECT etablissement, COUNT(*) FROM combo_pointages GROUP BY etablissement;

-- Lignes sans user mappé (à vérifier si elles devraient être mappées)
SELECT DISTINCT collaborateur_nom_combo, COUNT(*) AS nb_services
FROM combo_pointages WHERE user_id IS NULL
GROUP BY collaborateur_nom_combo ORDER BY nb_services DESC;

-- Vérifier la vue unifiée
SELECT source, COUNT(*) FROM pointages_unifies GROUP BY source;
```

---

## 📝 Notes pour évolution

- **Plannings** : le rapport Combo contient les `debut_planifie/fin_planifiee`. Une fois la Phase 2 Plannings codée dans PlanB-Tools, on pourra cross-checker.
- **Pauses** : Combo distingue planifié/pointé/validé pour les pauses. Combo est plus précis que le natif actuel (qui agrège juste `duree_pauses_minutes`).
- **Validateurs** : 4 personnes valident dans Combo (Valérie 78%, Eric 17%, Virginie 4%, Camille 0.6%). Peut alimenter un dashboard "qui valide quoi" dans Pilote.
