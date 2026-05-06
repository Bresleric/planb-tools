# Module Information — Journal d'entreprise

Publication d'informations internes ciblées + suivi de lecture explicite par utilisateur.

## Fonctionnalités

- **Publication** par l'admin (directe) ou par les collaborateurs (workflow proposition → validation).
- **Ciblage 4 niveaux** :
  - Entreprise (tous les actifs)
  - Établissement (Freddy / Liesel)
  - Équipe (cuisine, salle, bar, plonge, management…)
  - Sélection manuelle d'un ou plusieurs collaborateurs
- **Contenu** : titre + corps en markdown léger (`**gras**`, `*italique*`, `# Titre`, `- liste`, `[lien](url)`).
- **Médias** :
  - Images inline (bucket public `information-images`, max 5 Mo)
  - Pièces jointes (bucket privé `information-attachments`, signed URLs, max 20 Mo)
- **Accusé de lecture explicite** ("J'ai lu et compris") tracé par user.
- **Stats lecture admin** : taux de lecture, liste des lecteurs et des non-lecteurs.
- **Épinglage** (admin) : info en haut de la liste.
- **Cycle de vie** : `proposition` → `publiee` → `archivee` (ou `rejetee`).
- **Badge non-lus** sur la tuile du portail (RPC `info_count_non_lues`).

## Prérequis Supabase (one-shot)

### 1. Schéma SQL

Exécuter `information/schema.sql` dans le SQL Editor Supabase. Crée :

- 5 tables : `informations`, `information_targets`, `information_images`, `information_attachments`, `information_lectures`
- 1 vue : `v_informations_visibles`
- 4 fonctions : `info_visible_ids`, `info_count_non_lues`, `info_marquer_lue`, `info_stats_lecture`
- Index + trigger `updated_at`

### 2. Storage Buckets (manuel via Supabase Studio)

| Bucket | Public | MIME | Taille max |
|---|---|---|---|
| `information-images` | ✅ Oui | `image/jpeg`, `image/png`, `image/webp`, `image/gif` | 5 MB |
| `information-attachments` | ❌ Non | `application/pdf`, `image/*`, Office | 20 MB |

Convention de nommage des fichiers : `<information_id>/<uuid>.<ext>`.

## Architecture

```
information/
├── index.html      ~1500 lignes — vue collab + admin + composer + détail
├── schema.sql      ~250 lignes  — DDL + RPC + storage doc
└── README.md       (ce fichier)
```

**Patterns respectés** :
- Auth via `sessionStorage('planb_user')` (pattern de tous les modules).
- Markdown rendu **sans `innerHTML`** sur le contenu utilisateur (anti-XSS by construction).
- Liens externes en `target="_blank" rel="noopener noreferrer"`.

## Workflow utilisateur

### Collaborateur
1. Tuile portail "Information" avec badge rouge si non-lus.
2. 3 onglets : **À lire** (avec compteur), **Lues**, **Mes propositions**.
3. Bouton "Proposer une info" → modal composer → statut `proposition`.
4. Détail d'une info publiée → bouton "✓ J'ai lu et compris" qui appelle `info_marquer_lue`.

### Admin
1. Tous les onglets ci-dessus + **À valider**, **Toutes**, **Archivées**.
2. Bouton "Nouvelle info" → publication directe (statut `publiee`).
3. Sur une proposition : ✅ Publier ou ❌ Rejeter (avec motif visible par l'auteur).
4. Sur une info publiée : 🗄️ Archiver, ✏️ Modifier, ou consulter les stats de lecture.
5. Stats : taux de lecture, liste des lecteurs (avec date) + liste des non-lecteurs.

## Limites V1 connues

- Pas d'images inline dans le markdown (les images uploadées s'affichent en grille sous le texte).
- Pas de notification email/push (uniquement badge portail).
- Pas de catégories / tags (à ajouter via un champ `categorie` si besoin).
- Pas de réactions / commentaires (peut être ajouté sans casser le schéma).
- RLS non activée (cohérent avec le reste du projet, cf. audit C2/C3 — policies pré-écrites en commentaires SQL).

## Déploiement

```bash
bash scripts/deploy-information.sh
```

Le script :
1. Synchronise iCloud → `~/planb-tools/`
2. Commit + push
3. Rappelle les étapes manuelles Supabase (schéma + buckets)
