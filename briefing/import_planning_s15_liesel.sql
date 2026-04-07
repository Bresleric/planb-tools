-- Import Planning Semaine S.15 (6-12 avril 2026) - Chez Tante Liesel
-- ComboHR Extraction

DELETE FROM planning_equipes WHERE date >= '2026-04-06' AND date <= '2026-04-12' AND etablissement = 'liesel';

-- LIESEL SALLE
INSERT INTO planning_equipes (date, etablissement, employe_nom, employe_initiales, equipe, poste, heure_debut, heure_fin, service, notes) VALUES
('2026-04-07', 'liesel', 'Charlotte MC CLOSKEY', 'CM', 'salle', 'Continue journée', '11:30', '23:00', 'journee', NULL),
('2026-04-09', 'liesel', 'Charlotte MC CLOSKEY', 'CM', 'salle', 'Ouverture', '10:30', '17:00', 'journee', NULL),
('2026-04-10', 'liesel', 'Charlotte MC CLOSKEY', 'CM', 'salle', 'Ouverture', '10:30', '18:00', 'journee', NULL),
('2026-04-11', 'liesel', 'Charlotte MC CLOSKEY', 'CM', 'salle', 'Ouverture', '10:30', '18:00', 'journee', NULL),
('2026-04-12', 'liesel', 'Charlotte MC CLOSKEY', 'CM', 'salle', 'Ouverture', '10:30', '18:00', 'journee', NULL),
('2026-04-06', 'liesel', 'Francesca NUTINI', 'FN', 'salle', 'Salle continue soir', '16:55', '23:50', 'soir', NULL),
('2026-04-09', 'liesel', 'Francesca NUTINI', 'FN', 'salle', 'Salle continue soir', '15:00', '23:00', 'soir', NULL),
('2026-04-10', 'liesel', 'Francesca NUTINI', 'FN', 'salle', 'Salle continue soir', '15:00', '23:30', 'soir', NULL),
('2026-04-12', 'liesel', 'Francesca NUTINI', 'FN', 'salle', 'Continue midi', '12:00', '21:30', 'soir', NULL),
('2026-04-06', 'liesel', 'Laurence KOHLER', 'LK', 'salle', 'Ouverture', '10:20', '18:20', 'journee', NULL),
('2026-04-07', 'liesel', 'Laurence KOHLER', 'LK', 'salle', 'Continue journée', '11:00', '23:00', 'journee', NULL),
('2026-04-10', 'liesel', 'Laurence KOHLER', 'LK', 'salle', 'Salle continue soir', '17:00', '23:30', 'soir', NULL),
('2026-04-11', 'liesel', 'Laurence KOHLER', 'LK', 'salle', 'Salle continue soir', '17:30', '23:30', 'soir', NULL),
('2026-04-12', 'liesel', 'Laurence KOHLER', 'LK', 'salle', 'Salle continue soir', '13:00', '23:00', 'soir', NULL),
('2026-04-07', 'liesel', 'Vianney STOLZ', 'VS', 'salle', 'Continue journée', '11:00', '23:00', 'journee', NULL),

-- LIESEL CUISINE
('2026-04-06', 'liesel', 'Emilienne NGO', 'EN', 'cuisine', 'Soir', '15:30', '23:50', 'soir', NULL),
('2026-04-09', 'liesel', 'Emilienne NGO', 'EN', 'cuisine', 'Continue midi', '09:00', '16:30', 'journee', NULL),
('2026-04-10', 'liesel', 'Emilienne NGO', 'EN', 'cuisine', 'Continue midi', '09:00', '16:30', 'journee', NULL),
('2026-04-11', 'liesel', 'Emilienne NGO', 'EN', 'cuisine', 'Continue midi', '09:00', '16:30', 'journee', NULL),
('2026-04-12', 'liesel', 'Emilienne NGO', 'EN', 'cuisine', 'Continue Cuisine', '11:00', '22:00', 'journee', NULL),
('2026-04-06', 'liesel', 'Tesfamariam ZERAY AREQAY', 'TZ', 'cuisine', 'Continue midi', '09:00', '16:25', 'journee', NULL),
('2026-04-07', 'liesel', 'Tesfamariam ZERAY AREQAY', 'TZ', 'cuisine', 'Continue Cuisine', '11:00', '22:00', 'journee', NULL),
('2026-04-09', 'liesel', 'Tesfamariam ZERAY AREQAY', 'TZ', 'cuisine', 'Soir', '15:30', '22:30', 'soir', NULL),
('2026-04-10', 'liesel', 'Tesfamariam ZERAY AREQAY', 'TZ', 'cuisine', 'Soir', '15:30', '22:30', 'soir', NULL),
('2026-04-11', 'liesel', 'Tesfamariam ZERAY AREQAY', 'TZ', 'cuisine', 'Soir', '15:30', '22:30', 'soir', NULL),
('2026-04-08', 'liesel', 'Jean Alejandro PENALVER', 'JP', 'cuisine', 'Continu Cuisine', '11:00', '22:00', 'journee', NULL),
('2026-04-12', 'liesel', 'Jean Alejandro PENALVER', 'JP', 'cuisine', 'Soir', '15:00', '23:00', 'soir', NULL),

-- LIESEL - VS Vianney STOLZ Cuisine shift (Monday noted as "Premier jour")
('2026-04-09', 'liesel', 'Vianney STOLZ', 'VS', 'cuisine', 'Cuisine', '09:00', '17:00', 'journee', NULL);
