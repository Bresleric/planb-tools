-- ============================================================
-- Module HowTo — Tutoriels d'utilisation PlanB Tools
-- ============================================================

-- Table : tutoriels
CREATE TABLE IF NOT EXISTS howto_tutoriels (
    id BIGSERIAL PRIMARY KEY,
    module_id TEXT NOT NULL,           -- taf, caisse, checklist, briefings, etc. ou 'general'
    titre TEXT NOT NULL,
    description TEXT,
    icone TEXT DEFAULT '💡',
    niveau TEXT DEFAULT 'debutant',    -- debutant, intermediaire, avance
    duree_sec INTEGER DEFAULT 90,      -- durée estimée en secondes
    role_min TEXT DEFAULT 'collaborateur', -- collaborateur, responsable, manager, admin
    equipe TEXT,                       -- null = toutes, sinon : salle, cuisine, plonge, autre
    video_url TEXT,                    -- URL YouTube/Vimeo embed (optionnel)
    ordre INTEGER DEFAULT 0,
    actif BOOLEAN DEFAULT true,
    cree_par_id BIGINT,
    cree_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_howto_tutoriels_module ON howto_tutoriels(module_id, actif);
CREATE INDEX IF NOT EXISTS idx_howto_tutoriels_ordre ON howto_tutoriels(ordre);

-- Table : étapes
CREATE TABLE IF NOT EXISTS howto_etapes (
    id BIGSERIAL PRIMARY KEY,
    tutoriel_id BIGINT NOT NULL REFERENCES howto_tutoriels(id) ON DELETE CASCADE,
    ordre INTEGER NOT NULL DEFAULT 0,
    titre TEXT NOT NULL,
    texte TEXT,
    image_url TEXT,                    -- URL image ou data:image/... base64
    astuce TEXT,                       -- petit encart "bon à savoir"
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_howto_etapes_tuto ON howto_etapes(tutoriel_id, ordre);

-- Table : vues (tracking)
CREATE TABLE IF NOT EXISTS howto_vues (
    id BIGSERIAL PRIMARY KEY,
    tutoriel_id BIGINT NOT NULL REFERENCES howto_tutoriels(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL,
    user_nom TEXT,
    user_initiales TEXT,
    etablissement TEXT,
    vu_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tutoriel_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_howto_vues_user ON howto_vues(user_id);
CREATE INDEX IF NOT EXISTS idx_howto_vues_tuto ON howto_vues(tutoriel_id);

-- ============================================================
-- SEED — 8 tutoriels de démarrage
-- ============================================================

INSERT INTO howto_tutoriels (id, module_id, titre, description, icone, niveau, duree_sec, role_min, ordre)
VALUES
  (1, 'general', 'Se connecter à PlanB Tools', 'Utiliser ton code PIN et choisir ton établissement', '🔐', 'debutant', 60, 'collaborateur', 1),
  (2, 'taf', 'Valider une tâche dans le TAF', 'Marquer une tâche comme faite et ajouter une observation', '📋', 'debutant', 75, 'collaborateur', 2),
  (3, 'checklist', 'Compléter une Check-List de service', 'Valider les items d''une check-list avant ouverture', '✅', 'debutant', 90, 'collaborateur', 3),
  (4, 'caisse', 'Saisir un contrôle de caisse', 'Enregistrer les comptages en fin de service', '🧾', 'debutant', 120, 'collaborateur', 4),
  (5, 'temperatures', 'Faire le relevé des frigos', 'Saisir les températures du matin et gérer un hors-norme', '🌡️', 'debutant', 90, 'collaborateur', 5),
  (6, 'briefings', 'Consulter le briefing avant son service', 'Lire le briefing et marquer l''accusé de lecture', '📢', 'debutant', 60, 'collaborateur', 6),
  (7, 'approvisionnement', 'Signaler un besoin d''achat', 'Ajouter un article à la liste des besoins', '📦', 'debutant', 80, 'collaborateur', 7),
  (8, 'production', 'Imprimer une étiquette DLC', 'Créer un lot et imprimer l''étiquette', '🏷️', 'intermediaire', 100, 'collaborateur', 8)
ON CONFLICT (id) DO NOTHING;

-- Étapes tuto 1 : connexion
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (1, 1, 'Ouvre PlanB Tools', 'Depuis l''icône sur l''écran d''accueil de la tablette, touche l''icône orange PlanB Tools. L''app s''ouvre en plein écran.', null),
 (1, 2, 'Saisis ton code PIN', 'Tape ton code personnel à 4 ou 6 chiffres sur le pavé numérique. Si tu ne le connais pas, demande à ton manager.', 'Ne partage jamais ton code PIN — chaque action est tracée à ton nom.'),
 (1, 3, 'Choisis ton établissement', 'Sélectionne Freddy ou Liesel selon l''endroit où tu travailles aujourd''hui. Tu arriveras sur le tableau des modules.', null),
 (1, 4, 'C''est parti', 'Tu vois maintenant les tuiles des modules auxquels tu as accès. Touche une tuile pour y entrer.', null)
ON CONFLICT DO NOTHING;

-- Étapes tuto 2 : TAF
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (2, 1, 'Ouvre le module TAF', 'Sur le tableau des modules, touche la tuile 📋 TAF. Tu vois la liste des tâches du jour pour ton équipe.', null),
 (2, 2, 'Filtre sur ton créneau', 'En haut, choisis Matin, Midi ou Soir pour voir seulement les tâches de ton service.', 'La pastille orange sur la tuile TAF indique le nombre de tâches qui te sont attribuées.'),
 (2, 3, 'Valide une tâche', 'Touche la ligne d''une tâche. Un écran de validation s''ouvre. Touche le gros bouton ✓ Fait et confirme avec tes initiales.', null),
 (2, 4, 'Ajoute une observation si besoin', 'Avant de valider, tu peux écrire une remarque dans le champ Observation : utile pour signaler un problème au manager.', 'Une tâche validée passe en vert et disparaît des pastilles.')
ON CONFLICT DO NOTHING;

-- Étapes tuto 3 : Check-List
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (3, 1, 'Ouvre Check-Lists', 'Touche la tuile ✅ Check-Lists sur le tableau des modules.', null),
 (3, 2, 'Choisis la check-list du service', 'Sélectionne la check-list qui correspond à ton moment : ouverture midi, fermeture soir, etc.', 'Seules les check-lists actives aujourd''hui apparaissent dans ta liste.'),
 (3, 3, 'Valide chaque item', 'Pour chaque ligne, touche la case à cocher dès que la tâche est faite. Le compteur en haut avance au fur et à mesure.', null),
 (3, 4, 'Termine la check-list', 'Quand tous les items sont cochés, la check-list passe en vert et enregistre automatiquement l''heure et tes initiales.', 'Si tu reviens plus tard, les items que tu as déjà cochés sont conservés.')
ON CONFLICT DO NOTHING;

-- Étapes tuto 4 : Caisse
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (4, 1, 'Ouvre Contrôle Caisse', 'Touche la tuile 🧾 Contrôle Caisse.', null),
 (4, 2, 'Choisis le service', 'Sélectionne Midi ou Soir pour le service que tu veux contrôler.', null),
 (4, 3, 'Saisis les totaux de caisse', 'Reporte les montants depuis la caisse : CA, espèces, CB, tickets. Les totaux se calculent automatiquement.', 'Laisse à 0 les lignes que tu n''as pas — ne mets pas de tiret ni de texte.'),
 (4, 4, 'Saisis le comptage physique', 'Compte ton fond de caisse et renseigne chaque coupure. L''écart avec la caisse théorique apparaît en bas.', 'Un écart de plus de 5€ doit être signalé à ton responsable.'),
 (4, 5, 'Valide', 'Touche Enregistrer. Le contrôle est sauvegardé et visible dans l''historique.', null)
ON CONFLICT DO NOTHING;

-- Étapes tuto 5 : Températures
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (5, 1, 'Ouvre Températures', 'Touche la tuile 🌡️ Températures. Tu vois la liste de tous les frigos et chambres à contrôler.', null),
 (5, 2, 'Saisis chaque température', 'Pour chaque frigo, tape la température lue sur le thermomètre. Le champ devient rouge si la valeur est hors norme.', 'Le relevé se fait le matin une fois par jour, avant le début de service.'),
 (5, 3, 'Prends la photo si demandée', 'Si l''app te demande une photo (aléatoire ou obligatoire en cas de hors norme), touche l''icône appareil photo et photographie le thermomètre.', null),
 (5, 4, 'Re-contrôle 1h plus tard', 'En cas de hors norme, une tâche est créée automatiquement dans le TAF pour re-contrôler dans 1h. Ne l''oublie pas.', 'Si la température reste hors norme, alerte immédiatement le manager.')
ON CONFLICT DO NOTHING;

-- Étapes tuto 6 : Briefings
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (6, 1, 'Ouvre Briefings', 'Touche la tuile 📋 Briefings avant ton service.', 'Le briefing du service est publié par le manager 30 min avant l''ouverture.'),
 (6, 2, 'Lis le briefing du jour', 'Parcours les sections : équipes, chiffres prévus, produits limités, événements, objectifs. Prends 1 minute pour bien tout voir.', null),
 (6, 3, 'Valide ton accusé de lecture', 'En bas du briefing, touche le bouton J''ai lu le briefing. Ton nom apparaît dans la liste des lecteurs.', 'Sans accusé de lecture, le manager pensera que tu n''es pas informé.')
ON CONFLICT DO NOTHING;

-- Étapes tuto 7 : Approvisionnement
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (7, 1, 'Ouvre Approvisionnement', 'Touche la tuile 📦 Approvisionnement puis l''onglet Besoins.', null),
 (7, 2, 'Cherche l''article manquant', 'Tape le nom dans la barre de recherche. Le catalogue contient plus de 700 articles déjà référencés.', 'Si l''article n''existe pas, demande au manager de le créer plutôt que d''écrire un nom libre.'),
 (7, 3, 'Saisis la quantité et l''urgence', 'Choisis la quantité et le niveau d''urgence : normal, urgent, très urgent.', null),
 (7, 4, 'Valide le besoin', 'Touche Ajouter le besoin. Il apparaît dans la liste et sera traité par le responsable des commandes.', null)
ON CONFLICT DO NOTHING;

-- Étapes tuto 8 : Production
INSERT INTO howto_etapes (tutoriel_id, ordre, titre, texte, astuce) VALUES
 (8, 1, 'Ouvre Production', 'Touche la tuile 🏭 Production.', null),
 (8, 2, 'Choisis la fiche technique', 'Sélectionne la préparation que tu viens de faire (ex : sauce tomate, pâte à pizza).', 'Si la fiche n''existe pas, demande au chef de la créer avant.'),
 (8, 3, 'Crée le lot', 'Saisis la quantité produite. Le système génère automatiquement un numéro de lot au format MMJJ-CODE-NNN.', null),
 (8, 4, 'Imprime l''étiquette', 'Touche 🏷️ Imprimer. L''étiquette sort sur la Brother QL820 avec le nom du produit, la date de fabrication, la DLC calculée et le code lot.', 'Colle l''étiquette immédiatement sur le contenant, avant de le ranger en chambre froide.')
ON CONFLICT DO NOTHING;

-- Remise à jour de la séquence
SELECT setval('howto_tutoriels_id_seq', (SELECT MAX(id) FROM howto_tutoriels));
