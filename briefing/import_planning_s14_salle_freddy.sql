-- Planning Salle Freddy S.14 (30 mars - 5 avril 2026)
-- Données manquantes ajoutées depuis capture ComboHR

INSERT INTO planning_equipes ("date", etablissement, employe_nom, employe_initiales, equipe, poste, heure_debut, heure_fin, service, notes) VALUES
-- Shifts non-assignés
('2026-03-30', 'freddy', 'Non-assigné', 'NA', 'salle', 'Fermeture', '18:00', '23:00', 'soir', NULL),
('2026-04-01', 'freddy', 'Non-assigné', 'NA', 'salle', 'Continu salle soir', '15:00', '23:00', 'soir', NULL),
('2026-04-02', 'freddy', 'Non-assigné', 'NA', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', NULL),
('2026-04-03', 'freddy', 'Non-assigné', 'NA', 'salle', 'Continue salle Midi', '10:00', '17:00', 'midi', NULL),
('2026-04-04', 'freddy', 'Non-assigné', 'NA', 'salle', 'Continue salle Midi', '10:00', '17:00', 'midi', NULL),
('2026-04-05', 'freddy', 'Non-assigné', 'NA', 'salle', 'Continue salle Midi', '10:30', '16:00', 'midi', NULL),

-- Virginie MOHR
('2026-03-30', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu salle soir', '17:00', '23:00', 'soir', NULL),
('2026-04-01', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu salle soir', '15:00', '23:00', 'soir', NULL),
('2026-04-02', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu salle soir', '13:30', '23:00', 'journee', NULL),
('2026-04-03', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu salle soir', '14:00', '23:30', 'journee', NULL),
('2026-04-04', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu salle soir', '16:00', '23:30', 'soir', NULL),
('2026-04-05', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu salle soir', '14:00', '23:30', 'journee', NULL),

-- Anne-Sophie MESSIN
('2026-04-01', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continue salle Midi', '10:00', '18:00', 'midi', NULL),
('2026-04-02', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continue salle Midi', '10:00', '18:00', 'midi', NULL),
('2026-04-03', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continue salle Midi', '10:00', '18:00', 'midi', NULL),
('2026-04-04', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continue salle Midi', '10:00', '18:00', 'midi', NULL),
('2026-04-05', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', '2-Continu Après-Midi', '12:00', '21:00', 'journee', NULL),

-- Emilie FORTIER
('2026-04-02', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continu salle soir', '15:00', '23:00', 'soir', 'Premier jour'),
('2026-04-03', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continu salle soir', '17:00', '23:30', 'soir', NULL),
('2026-04-05', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continue salle Midi', '10:00', '17:00', 'midi', NULL),

-- Marine MERKILED ATHANASE
('2026-03-30', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continue salle Midi', '10:00', '18:00', 'midi', NULL),
('2026-03-31', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continue salle Midi', '10:00', '18:30', 'midi', NULL),
('2026-04-03', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', '2-Continu Après-Midi', '12:00', '21:00', 'journee', NULL),
('2026-04-04', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continu salle soir', '14:00', '23:00', 'journee', NULL),
('2026-04-05', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continu salle soir', '17:00', '23:30', 'soir', NULL),

-- Mathilde BALAS
('2026-04-01', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continu salle soir', '13:30', '23:00', 'journee', NULL),
('2026-04-02', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continu salle soir', '17:00', '23:00', 'soir', NULL),
('2026-04-03', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continu salle soir', '16:00', '23:00', 'soir', NULL),
('2026-04-04', 'freddy', 'Mathilde BALAS', 'MB', 'salle', '2-Continu Après-Midi', '12:00', '21:30', 'journee', NULL),
('2026-04-05', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', NULL),

-- David ROUILLAUX
('2026-03-31', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Fermeture', '18:00', '23:00', 'soir', NULL),
('2026-04-01', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Fermeture', '18:00', '23:00', 'soir', NULL),
('2026-04-04', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Fermeture', '18:00', '23:30', 'soir', NULL),
('2026-04-05', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Fermeture', '18:00', '23:30', 'soir', NULL),

-- Martine OSWALD
('2026-03-30', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continu salle soir', '13:30', '23:00', 'journee', NULL),
('2026-03-31', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continu salle soir', '13:30', '23:00', 'journee', NULL),
('2026-04-03', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continue salle Midi', '10:00', '17:00', 'midi', NULL),
('2026-04-04', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continue salle Midi', '10:00', '17:00', 'midi', NULL),
('2026-04-05', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continue salle Midi', '10:00', '18:00', 'midi', NULL),

-- Camille BRESLER (12h|9h)
('2026-04-01', 'freddy', 'Camille BRESLER', 'CB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', 'Premier jour'),
('2026-04-02', 'freddy', 'Camille BRESLER', 'CB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', NULL),

-- Camille BRESLER (12h|3h) - Dernier jour mar 31
('2026-03-30', 'freddy', 'Camille BRESLER', 'CB', 'salle', 'Continue salle Midi', '10:00', '13:30', 'midi', NULL),

-- Valerie BRESLER
('2026-03-31', 'freddy', 'Valerie BRESLER', 'VB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', NULL),
('2026-04-04', 'freddy', 'Valerie BRESLER', 'VB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', NULL);
