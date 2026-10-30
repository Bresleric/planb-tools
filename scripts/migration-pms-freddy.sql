-- PMS Freddy : import des 44 taches de nettoyage du plan de maitrise sanitaire
-- (source : PMS CUISINE EPACK.numbers, onglets LISTE + LABO PLAN DE NETTOYAGE)
-- Cible : taches_recurrentes (TAF > Recurrences), etablissement freddy, non partagees.
-- Idempotent : une tache deja presente (meme nom, freddy) n est pas recreee.
-- A coller dans Supabase > SQL Editor, puis lancer.

INSERT INTO taches_recurrentes
  (nom, equipe, creneau, priorite, categorie, frequence_type, frequence_valeur,
   observation, date_debut, etablissement, partagee, actif, cree_par_nom)
SELECT v.nom, v.equipe, v.creneau, 3, 'Nettoyage', v.ft, v.fv,
       v.obs, v.dd, 'freddy', false, true, 'PMS Freddy'
FROM (VALUES
  ('Nettoyage local poubelle : Local poubelle', 'cuisine', 'Matin', 'jours_semaine', '[2, 5]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cave : Chambre froide positive (sol et étagères)', 'cuisine', 'Matin', 'jours_semaine', '[1]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cave : Sol', 'cuisine', 'Matin', 'jours_semaine', '[1]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cave : Congélateur cave boissons', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cave : Étagère cave 3 (sec)', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy.', DATE '2026-11-05'),
  ('Nettoyage cave : Murs', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy.', DATE '2026-11-09'),
  ('Nettoyage cuisine : Portes, poignées, vitres, plans de travail (table froid, chaud, passe)', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après chaque utilisation.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Petit matériel (robot...)', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après chaque utilisation.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Sols', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après le service du soir.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Poubelle', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Vario Cooking', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après le service du soir.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Table réfrigérée', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Surface, porte, poignées.', DATE '2026-11-02'),
  ('Nettoyage cuisine : SpeedX', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après chaque utilisation.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Murs', 'cuisine', 'Matin', 'jours_semaine', '[2]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Étagères, placards, tables', 'cuisine', 'Matin', 'jours_semaine', '[2]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Table poste chaud (entrée gauche)', 'cuisine', 'Matin', 'jours_semaine', '[2]'::jsonb, 'PMS Freddy. Étagères haute et basse.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Meuble table réfrigérée', 'cuisine', 'Matin', 'jours_semaine', '[2]'::jsonb, 'PMS Freddy. Étagère et paroi intérieure.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Table poste froid', 'cuisine', 'Matin', 'jours_semaine', '[2]'::jsonb, 'PMS Freddy. Étagères haute et basse.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Frigo cuisine gauche', 'cuisine', 'Matin', 'jours_semaine', '[1]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Frigo cuisine droite', 'cuisine', 'Matin', 'jours_semaine', '[1]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Grilles hottes', 'cuisine', 'Matin', 'jours_semaine', '[4]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Four', 'cuisine', 'Soir', 'jours_semaine', '[3, 7]'::jsonb, 'PMS Freddy. Nettoyage four après le service du soir.', DATE '2026-11-02'),
  ('Nettoyage cuisine : Fenêtre cuisine', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy.', DATE '2026-11-12'),
  ('Nettoyage cuisine : Déplacer les meubles', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy. Nettoyage derrière les meubles.', DATE '2026-11-16'),
  ('Nettoyage salle/cuisine : Congélateur bar (glaces)', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy. À décongeler.', DATE '2026-11-19'),
  ('Nettoyage labo : Portes, poignées, plan de travail', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après chaque utilisation. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Éliminer les déchets 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter.', DATE '2026-11-02'),
  ('Nettoyage labo : Sol', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après le service. Protocole : détergent 2 doses pour 8 L, balai brosse / seau / raclette. 1) Balayer et ramasser les déchets 2) Appliquer et frotter au balai brosse 3) Laisser agir 10 min 4) Passer la serpillière en récupérant le maximum d''eau 5) Laisser sécher.', DATE '2026-11-02'),
  ('Nettoyage labo : Poubelle', 'cuisine', 'Soir', 'quotidien', NULL, 'PMS Freddy. Après le service. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Sortir le sac 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, laisser sécher.', DATE '2026-11-02'),
  ('Nettoyage labo : Table réfrigérée gauche', 'cuisine', 'Matin', 'jours_semaine', '[3]'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-02'),
  ('Nettoyage labo : Table réfrigérée droite', 'cuisine', 'Matin', 'jours_semaine', '[3]'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-02'),
  ('Nettoyage labo : Machines (thermoplongeurs, robots et batteurs, sous-videuse)', 'cuisine', 'Matin', 'jours_semaine', '[3]'::jsonb, 'PMS Freddy. À nettoyer aussi après chaque utilisation. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-02'),
  ('Nettoyage labo : Cellule de refroidissement', 'cuisine', 'Matin', 'jours_semaine', '[3]'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-02'),
  ('Nettoyage labo : Îlot central, étagères', 'cuisine', 'Matin', 'jours_semaine', '[3]'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-02'),
  ('Nettoyage labo : Frigo 1 - épicerie sèche', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-04'),
  ('Nettoyage labo : Frigo 2 - légumes', 'cuisine', 'Matin', 'tous_x_jours', '14'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-11'),
  ('Nettoyage labo : Frigo 3 - salle', 'cuisine', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy. Protocole : dégraissant + eau chaude, lavette / brosse / seau. 1) Débarrasser l''installation de son contenu 2) Pulvériser 3) Laisser agir 10 min 4) Frotter ou brosser à l''eau chaude 5) Rincer, essuyer, désinfecter 6) Remettre le contenu en place.', DATE '2026-11-18'),
  ('Nettoyage labo : Elis - torchons et tabliers', 'cuisine', 'Matin', 'jours_semaine', '[4]'::jsonb, 'PMS Freddy. Compter le linge sale et le mettre en sac pour la reprise du vendredi matin.', DATE '2026-11-02'),
  ('Nettoyage plonge : Sol', 'plonge', 'Soir', 'quotidien', NULL, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage plonge : Machine', 'plonge', 'Soir', 'quotidien', NULL, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage plonge : Évier plonge', 'plonge', 'Soir', 'quotidien', NULL, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage plonge : Poubelle', 'plonge', 'Soir', 'quotidien', NULL, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage plonge : Étagères', 'plonge', 'Matin', 'jours_semaine', '[1]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage plonge : Chariot', 'plonge', 'Matin', 'jours_semaine', '[1]'::jsonb, 'PMS Freddy.', DATE '2026-11-02'),
  ('Nettoyage plonge : Mur carrelage', 'plonge', 'Matin', 'tous_x_jours', '28'::jsonb, 'PMS Freddy.', DATE '2026-11-23')
) AS v(nom, equipe, creneau, ft, fv, obs, dd)
WHERE NOT EXISTS (
  SELECT 1 FROM taches_recurrentes t
  WHERE t.etablissement = 'freddy' AND lower(t.nom) = lower(v.nom)
);

-- Verification : doit afficher 44 lignes
SELECT frequence_type, frequence_valeur, creneau, equipe, nom, date_debut
FROM taches_recurrentes
WHERE cree_par_nom = 'PMS Freddy'
ORDER BY equipe, frequence_type, nom;
