# SPEC — Briefing : bloc TheFork en rédaction + bloc Repas perso

Destinataire : conversation Claude Code « PLANBTools application review »
Préparé le 16/10/2026 — état du repo vérifié : HEAD `3fcd347`, `sw.js` = `planb-tools-v119`
Fichier concerné : `~/planb-tools/briefing/index.html` (3501 lignes)

---

## 0. État des lieux (déjà vérifié, ne pas re-explorer)

**TheFork — la synchro et l'affichage existent déjà.**
- Table `reservations_thefork` alimentée toutes les heures par l'edge function `supabase/functions/thefork-sync`. 184 lignes en base, du 10/10 au 30/10, **établissement `freddy` uniquement** (Liesel n'est pas synchronisé).
- Colonnes utiles : `date`, `heure` (time), `service` (midi/soir), `couverts`, `statut` (`RECORDED` / `CANCELED` / `NO_SHOW`), `nom_client`, `allergies`, `commentaire`, `payload` (jsonb brut TheFork).
- Côté front : `fetchReservationsTheFork()` (~ligne 769) filtre déjà les annulées/no-show et renvoie `null` si rien ; `renderTheForkSection()` (~ligne 1230) rend les KPI midi / soir / total + une ligne par réservation porteuse d'allergie ou de commentaire.
- Ce bloc est affiché dans **l'onglet Briefing (consultation)** — `renderBriefing()` ~ligne 1394 — et seul quand aucun briefing n'est publié — `loadConsultation()` ~ligne 1150.
- **Il est absent de l'onglet Rédaction.** C'est tout l'objet du chantier 1 : celui qui écrit le briefing ne voit pas les réservations attendues pendant qu'il écrit.

**Repas perso — rien n'existe.** Ni colonne en base, ni code. (À ne pas confondre avec `prelevements.motif_type = 'repas_personnel'` : table vide, zéro interface, chantier parqué — hors périmètre ici.)

**RLS** : nouveau modèle `pbt_session` `FOR ALL TO authenticated` (sécurité 08-09/10/2026). Le chantier 2 n'ajoute **aucune table**, juste une colonne sur `briefings` → rien à faire côté policy, la colonne hérite de la policy de la table.

---

## 1. Chantier 1 — Bloc « Réservations TheFork » dans l'onglet Rédaction

Objectif : le rédacteur voit les réservations attendues du jour pendant qu'il rédige, et doit les avoir vues pour pouvoir publier.

### 1.1 Scinder le rendu en corps + section (indispensable)

`renderTheForkSection()` renvoie aujourd'hui un `renderSection()` complet, c'est-à-dire le markup de **consultation** (`.section-card` / `.section-header`). L'onglet Rédaction utilise un markup différent (`.form-section` / `.form-section-header` + `toggleFormSection`). Réutiliser la fonction telle quelle produirait une section imbriquée dans une section, et un chevron qui ne répond pas.

Refactor minimal, sans toucher au HTML existant :

```js
// Corps de la section TheFork (KPI + lignes a signaler), sans emballage :
// reutilise par la consultation ET par la redaction, qui ont deux markups de section differents.
function theForkBodyHtml(tf) {
    // ... tout le corps actuel de renderTheForkSection, inchange ...
    return tfHtml;
}

function renderTheForkSection(tf) {
    return renderSection('&#127860;', 'Reservations TheFork', tf.length, theForkBodyHtml(tf), true);
}
```

Les deux appels existants (`loadConsultation`, `renderBriefing`) continuent d'appeler `renderTheForkSection()` — aucun changement de leur côté.

### 1.2 Charger les réservations dans `loadOrCreateBriefing()`

Attention : la fonction a **deux chemins** — briefing existant relu en base, ou briefing neuf construit avec la continuité sélective. Il faut poser `_thefork` dans les deux cas. Le plus simple est de le faire **après** le `if / else`, juste avant `editingBriefing = briefing;` :

```js
// Reservations TheFork du jour : information de cadrage pour le redacteur
// (lecture seule, non stockee dans le briefing - la source reste reservations_thefork)
if (!isDemo && briefing) {
    briefing._thefork = await fetchReservationsTheFork(consultDate, currentEstablishment);
}

editingBriefing = briefing;
renderCreationForm(formContainer, briefing);
```

`_thefork` est un champ préfixé d'un underscore, donc **non persisté** : `saveBriefing()` construit son `record` champ par champ, il ne passera pas en base. Ne pas l'ajouter au record.

### 1.3 Afficher le bloc dans `renderCreationForm()`

À insérer juste après le bloc « Tendances » (lecture seule lui aussi), avant le bloc « Chiffres cles » :

```js
// Reservations TheFork (lecture seule, synchro horaire - Freddy uniquement)
if (b._thefork && b._thefork.length > 0) {
    html += `<div class="form-section">
        <div class="form-section-header" onclick="toggleFormSection(this)">
            <div class="section-icon">&#127860;</div>
            <div class="section-title">Reservations TheFork</div>
            <span class="section-count">${b._thefork.length}</span>
            <div class="section-chevron">&#9654;</div>
        </div>
        <div class="form-section-body">${theForkBodyHtml(b._thefork)}</div>
    </div>`;
}
```

### 1.4 Conséquence voulue sur le verrou de publication

`initSectionsVues()` enregistre **toute** `.form-section` du formulaire et lui colle une pastille « A voir / Vu ». Le bloc TheFork en reçoit donc une, avec la clé `reservations_thefork` (dérivée du titre), et il compte dans le verrou « Publier (x/y chapitres vus) ».

C'est l'effet recherché : on ne publie pas un briefing sans avoir regardé les réservations. Deux points à savoir :
- Chez Liesel, `_thefork` est `null` → bloc absent → total de chapitres inchangé. Le compteur diffère déjà par établissement, rien de nouveau.
- Les brouillons déjà enregistrés n'ont pas cette clé dans `sections_vues` → à leur réouverture, le chapitre repasse « A voir ». Normal et voulu.

### 1.5 Option à valider par Eric (ne pas coder sans son OK)

Un bouton « Reprendre les chiffres TheFork » dans le bloc, qui remplit `#f-reservations` (nombre de résas) et `#f-couverts-attendus` (somme des couverts) du service concerné. Deux réserves : TheFork ne couvre pas le téléphone ni le passage, et il ne faut pas écraser silencieusement une saisie manuelle (proposer, ne pas imposer). À trancher avant de l'écrire.

---

## 2. Chantier 2 — Bloc « Repas perso »

Saisie libre par la cuisine : **nom du plat**, **date de production**, **stock disponible**. Affiché ensuite à toute l'équipe dans le briefing.

### 2.1 Migration SQL

Créer `scripts/migration-briefing-repas-perso.sql` :

```sql
-- ============================================================
-- Migration — Briefing : bloc Repas perso
-- Projet Supabase : dzrherfavgiuygnimtux
-- Idempotente : re-executable sans erreur.
-- Pas de nouvelle table -> pas de policy a creer, la colonne
-- herite de la policy pbt_session de briefings.
-- ============================================================

ALTER TABLE briefings
  ADD COLUMN IF NOT EXISTS repas_perso jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Format attendu :
-- [{ "plat": "Boeuf bourguignon", "date_production": "2026-10-15",
--    "stock": 4, "unite": "portions" }]

-- Verification post-migration :
-- SELECT column_name, data_type FROM information_schema.columns
--   WHERE table_name = 'briefings' AND column_name = 'repas_perso';
```

Le MCP Supabase peut être read-only : tester un no-op avant de promettre la migration, sinon demander à Eric de coller le fichier dans Supabase → SQL Editor.

### 2.2 Front — six points d'accroche

**(a) `getFieldConfigs()`** — c'est la **source unique** des champs : `renderEditorItem()` rappelle `getFieldConfigs(key)` et ignore le 5e argument de `renderListEditorSection()`. Ajouter l'entrée :

```js
repas_perso: [
    { key: 'plat', label: 'Plat', type: 'text', placeholder: 'Nom du plat' },
    { key: 'date_production', label: 'Produit le', type: 'date' },
    { key: 'stock', label: 'Stock', type: 'number', placeholder: '0', width: '70px' },
    { key: 'unite', label: 'Unite', type: 'text', placeholder: 'portions', width: '80px' }
],
```

Rendu obtenu : `renderEditorItem()` casse la ligne après un champ `date`, donc deux lignes de deux champs (plat + date, puis stock + unité). C'est lisible sur iPad, ne pas chercher à l'optimiser.

**(b) `renderCreationForm()`** — après le bloc « Plats / Suggestions » :

```js
// Repas perso (archivable : le plat reste dispo d un service a l autre)
html += renderListEditorSection('&#127858;', 'Repas perso', 'repas_perso', b.repas_perso || [], getFieldConfigs('repas_perso'), true);
```

Le dernier argument `true` = `archivable` : la ligne est reportée de briefing en briefing (2.2-e) et un manager peut l'archiver avec motif quand le plat est écoulé, comme pour les produits limités.

**(c) `onArchiveCheck()`** — le libellé d'archivage se construit sur `description || produit || message`, donc une ligne Repas perso serait refusée (« Rien a archiver sur cette ligne »). Ajouter `plat` à la chaîne :

```js
const libelle = item.description || item.produit || item.message || item.plat || '';
```

**(d) `renderBriefing()`** — section de consultation, à placer après « Plats / Suggestions » (le même bloc sert aussi à l'overlay de lecture obligatoire, qui appelle `renderBriefing`) :

```js
// Section: Repas perso
{
    let rpHtml = '';
    (b.repas_perso || []).forEach(r => {
        const prod = r.date_production ? 'Produit le ' + formatDateShort(r.date_production) : '';
        const dispo = r.stock ? r.stock + ' ' + escapeHtml(r.unite || 'portions') + ' dispo' : '';
        rpHtml += `
            <div class="brief-item">
                <div class="brief-item-icon">&#127858;</div>
                <div class="brief-item-content">
                    <div class="brief-item-title">${escapeHtml(r.plat || '')}</div>
                    <div class="brief-item-subtitle">${prod}${prod && dispo ? ' — ' : ''}${dispo}</div>
                </div>
                ${r.stock ? `<span class="brief-item-badge badge-info">${r.stock}</span>` : ''}
            </div>`;
    });
    if (!rpHtml) rpHtml = emptyTxt('Aucun repas perso signale');
    html += renderSection('&#127858;', 'Repas perso', (b.repas_perso || []).length, rpHtml, true);
}
```

**(e) `saveBriefing()`** — une ligne dans le `record`, après `plats_suggestions` :

```js
repas_perso: collectEditorData('repas_perso'),
```

**(f) `loadOrCreateBriefing()`** — report d'un briefing au suivant, dans l'objet `briefing = { ... }` du chemin « briefing neuf », à côté de `produits_limites` :

```js
repas_perso: prevBriefing?.repas_perso || [],
```

Et mettre à jour le commentaire au-dessus (« On reporte UNIQUEMENT les produits limites et dates courtes ») : les repas perso sont désormais reportés aussi.

**(g) `demoBriefing`** — pour que le mode démo montre le bloc :

```js
repas_perso: [
    { plat: 'Boeuf bourguignon', date_production: '2026-10-15', stock: 4, unite: 'portions' }
],
```

### 2.3 Évolution possible, à ne PAS coder maintenant

Pré-remplir les lignes depuis le stock produits finis : la vue `v_stock_pf_pi_par_produit` donne `produit_nom`, `quantite_totale`, `unite`, `dlc_plus_proche` (19 lignes en base aujourd'hui), et `productions` donne `nom_produit` + `date_production` + `quantite_produite`. Tentant, mais ça lie le briefing à la fraîcheur des relevés de stock. À proposer à Eric une fois le bloc manuel en service.

---

## 3. Finitions obligatoires (règles CLAUDE.md)

1. **`sw.js`** : bumper `CACHE_NAME` de `planb-tools-v119` à `planb-tools-v120`, avec le commentaire daté sur le même modèle que les précédents. Sans ça les iPads PWA servent l'ancienne version.
2. **Migration** : appliquer `scripts/migration-briefing-repas-perso.sql` **avant** de pousser le front, sinon `saveBriefing` enverra une colonne inexistante et toute sauvegarde échouera.
3. **Vérif syntaxe JS** avant commit :
   ```
   node -e "const fs=require('fs');const h=fs.readFileSync('briefing/index.html','utf8');const re=/<script>([\s\S]*?)<\/script>/g;let m;while((m=re.exec(h))){try{new Function(m[1]);console.log('OK');}catch(e){console.log('ERR',e.message);}}"
   ```
4. **Commit** : `git branch --show-current` d'abord, puis script `scripts/briefing-thefork-redaction-repas-perso.sh` (add + commit + push), message **sans apostrophe**. Montrer le diff à Eric et attendre son OK explicite avant de lancer.

## 4. Étapes de test à donner à Eric (iPad, compte Freddy)

1. Onglet **Rédaction**, date du jour : le bloc « Reservations TheFork » apparaît sous Tendances avec le nombre de résas ; le déplier montre les KPI midi / soir / total et les lignes allergies ou commentaires.
2. Le bouton Publier reste verrouillé tant que ce chapitre n'est pas marqué « ✓ Vu ».
3. Bloc **Repas perso** : « + Ajouter », saisir un plat, la date d'hier, 4, « portions » → Sauvegarder → recharger la page : la ligne est toujours là.
4. Onglet **Briefing** : la section Repas perso affiche « Produit le 15/10 — 4 portions dispo ».
5. Le lendemain, en rédaction : la ligne est reprise automatiquement. Un manager peut la cocher pour l'archiver (motif obligatoire) quand le plat est écoulé.
6. Avec un compte **Liesel** : pas de bloc TheFork (pas de synchro pour cet établissement, c'est normal), bloc Repas perso présent.
