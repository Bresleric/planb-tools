-- S.15 Planning Import for Freddy (Apr 6-12, 2026)
-- Source: ComboHR screenshots - Salle + Cuisine + Plonge

DELETE FROM planning_equipes WHERE date >= '2026-04-06' AND date <= '2026-04-12' AND etablissement = 'freddy';

-- ====== SALLE ======

INSERT INTO planning_equipes (date, etablissement, employe_nom, employe_initiales, equipe, poste, heure_debut, heure_fin, service, notes) VALUES
('2026-04-06', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continu Après-Midi', '11:30', '21:30', 'journee', '+30mn'),
('2026-04-07', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continue salle Midi', '10:00', '17:00', 'journee', '30mn'),
('2026-04-09', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continue salle Midi', '10:00', '17:00', 'journee', ''),
('2026-04-10', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continue salle Midi', '10:00', '18:30', 'journee', '30mn'),
('2026-04-11', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continue salle Midi', '10:00', '18:00', 'journee', '30mn'),
('2026-04-12', 'freddy', 'Virginie MOHR', 'VM', 'salle', 'Continue salle Midi', '10:00', '18:30', 'journee', '30mn'),

('2026-04-08', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continu salle soir', '13:30', '23:00', 'soir', '30mn'),
('2026-04-09', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continu salle soir', '13:30', '23:00', 'soir', '30mn'),
('2026-04-10', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continu salle soir', '15:00', '23:30', 'soir', '30mn'),
('2026-04-11', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continu salle soir', '17:00', '23:30', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Anne-Sophie MESSIN', 'AM', 'salle', 'Continu salle soir', '15:30', '23:30', 'soir', '30mn'),

('2026-04-06', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continue salle Midi', '10:00', '15:25', 'midi', '-1h05'),
('2026-04-07', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', '20mn'),
('2026-04-08', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continue salle Midi', '16:00', '23:00', 'soir', '30mn'),
('2026-04-09', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Fermeture', '18:00', '23:00', 'soir', '20mn'),
('2026-04-12', 'freddy', 'Emilie FORTIER', 'EF', 'salle', 'Continu salle soir', '15:00', '23:30', 'soir', '20mn'),

('2026-04-06', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continu salle soir', '15:00', '22:25', 'soir', '30mn [-2h35]'),
('2026-04-07', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continu salle soir', '13:30', '23:00', 'soir', '30mn'),
('2026-04-09', 'freddy', 'Marine MERKILED ATHANASE', 'MM', 'salle', 'Continu salle soir', '15:00', '23:00', 'soir', '30mn'),

('2026-04-06', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continue salle Midi', '10:00', '14:50', 'midi', '+10mn'),
('2026-04-08', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continue salle Midi', '10:00', '17:00', 'journee', '30mn'),
('2026-04-09', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continue salle Midi', '10:00', '17:00', 'journee', '30mn'),
('2026-04-11', 'freddy', 'Mathilde BALAS', 'MB', 'salle', 'Continue salle Midi', '10:00', '16:00', 'journee', '20mn'),

('2026-04-06', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Continu salle soir', '16:00', '22:35', 'soir', '26mn [-51mn]'),
('2026-04-07', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Fermeture', '17:00', '23:00', 'soir', '20mn'),
('2026-04-10', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Continu salle soir', '13:30', '23:30', 'soir', '30mn'),
('2026-04-11', 'freddy', 'David ROUILLAUX', 'DR', 'salle', '2-Continu Après-Midi', '12:30', '21:30', 'journee', '30mn'),
('2026-04-12', 'freddy', 'David ROUILLAUX', 'DR', 'salle', 'Continu salle soir', '14:00', '23:00', 'soir', '30mn'),

('2026-04-06', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continue salle Midi', '10:45', '17:05', 'journee', '-10mn'),
('2026-04-07', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continu salle soir', '15:00', '23:00', 'soir', '30mn'),
('2026-04-10', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continu salle soir', '16:00', '23:00', 'soir', '30mn'),
('2026-04-11', 'freddy', 'Martine OSWALD', 'MO', 'salle', 'Continu salle soir', '14:00', '23:00', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Martine OSWALD', 'MO', 'salle', '2-Continu Après-Midi', '12:30', '21:30', 'journee', '30mn'),

('2026-04-11', 'freddy', 'Valerie BRESLER', 'VB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', '30mn'),

('2026-04-08', 'freddy', 'Camille BRESLER', 'CB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', '30mn'),
('2026-04-09', 'freddy', 'Camille BRESLER', 'CB', 'salle', 'Continue salle Midi', '10:00', '15:00', 'midi', '30mn'),

('2026-04-07', 'freddy', 'Vianney STOLZ', 'VS', 'salle', 'Service', '13:00', '17:00', 'midi', '30mn'),
('2026-04-10', 'freddy', 'Vianney STOLZ', 'VS', 'salle', 'Continu salle soir', '15:00', '23:30', 'soir', '30mn');

-- ====== PLONGE ======

INSERT INTO planning_equipes (date, etablissement, employe_nom, employe_initiales, equipe, poste, heure_debut, heure_fin, service, notes) VALUES
('2026-04-08', 'freddy', 'Carole DUARTE', 'CD', 'plonge', 'Plonge longue', '11:00', '22:30', 'journee', '30mn'),
('2026-04-09', 'freddy', 'Carole DUARTE', 'CD', 'plonge', 'Plonge longue', '12:00', '22:30', 'journee', '30mn'),
('2026-04-10', 'freddy', 'Carole DUARTE', 'CD', 'plonge', 'Plonge soir', '17:00', '23:30', 'soir', '30mn'),
('2026-04-11', 'freddy', 'Carole DUARTE', 'CD', 'plonge', 'Plonge soir', '17:00', '23:30', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Carole DUARTE', 'CD', 'plonge', 'Plonge soir', '17:00', '23:30', 'soir', '30mn'),

('2026-04-06', 'freddy', 'Alemouyrodo Koffi NOUSSOUKPOE', 'AN', 'plonge', 'Plonge longue', '11:00', '22:40', 'journee', '5mn [+35mn]'),
('2026-04-07', 'freddy', 'Alemouyrodo Koffi NOUSSOUKPOE', 'AN', 'plonge', 'Plonge longue', '11:00', '22:30', 'journee', '30mn'),
('2026-04-10', 'freddy', 'Alemouyrodo Koffi NOUSSOUKPOE', 'AN', 'plonge', 'Plonge', '10:30', '16:00', 'midi', '30mn'),
('2026-04-11', 'freddy', 'Alemouyrodo Koffi NOUSSOUKPOE', 'AN', 'plonge', 'Plonge soir', '17:00', '23:30', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Alemouyrodo Koffi NOUSSOUKPOE', 'AN', 'plonge', 'Plonge', '09:00', '16:00', 'midi', '30mn');

-- ====== CUISINE ======

INSERT INTO planning_equipes (date, etablissement, employe_nom, employe_initiales, equipe, poste, heure_debut, heure_fin, service, notes) VALUES
('2026-04-06', 'freddy', 'Eve LHOPITEAU', 'EL', 'cuisine', '1: Poste Matin', '07:00', '16:00', 'journee', '30mn'),
('2026-04-07', 'freddy', 'Eve LHOPITEAU', 'EL', 'cuisine', '1: Poste Matin', '07:10', '15:30', 'midi', '30mn [-10mn]'),
('2026-04-08', 'freddy', 'Eve LHOPITEAU', 'EL', 'cuisine', '3 - Poste Soir', '15:00', '23:00', 'soir', '30mn'),
('2026-04-11', 'freddy', 'Eve LHOPITEAU', 'EL', 'cuisine', '3 - Poste Soir', '15:00', '23:00', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Eve LHOPITEAU', 'EL', 'cuisine', '3 - Poste Soir', '15:00', '23:00', 'soir', '30mn'),

('2026-04-06', 'freddy', 'Matthieu PAULUS', 'MP', 'cuisine', '2 - Après-Midi', '15:00', '21:20', 'soir', '30mn [-2h40]'),
('2026-04-07', 'freddy', 'Matthieu PAULUS', 'MP', 'cuisine', '2 - Après-Midi', '11:35', '21:00', 'journee', '30mn [-05mn]'),
('2026-04-10', 'freddy', 'Matthieu PAULUS', 'MP', 'cuisine', '2 - Après-Midi', '11:00', '20:00', 'journee', '30mn'),
('2026-04-11', 'freddy', 'Matthieu PAULUS', 'MP', 'cuisine', '3 - Poste Soir', '13:30', '20:30', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Matthieu PAULUS', 'MP', 'cuisine', '3 - Poste Soir', '16:00', '23:00', 'soir', '30mn'),

('2026-04-08', 'freddy', 'Johnny BAUER', 'JB', 'cuisine', '1- Poste Matin', '07:00', '15:30', 'midi', '30mn'),
('2026-04-09', 'freddy', 'Johnny BAUER', 'JB', 'cuisine', '1- Poste Matin', '07:00', '15:30', 'midi', '30mn'),
('2026-04-10', 'freddy', 'Johnny BAUER', 'JB', 'cuisine', '1- Poste Matin', '07:00', '15:30', 'midi', 'Durée 8h'),
('2026-04-11', 'freddy', 'Johnny BAUER', 'JB', 'cuisine', '1- Poste Matin', '07:00', '15:00', 'midi', '30mn'),
('2026-04-12', 'freddy', 'Johnny BAUER', 'JB', 'cuisine', '1- Poste Matin', '07:00', '15:00', 'midi', '30mn'),

('2026-04-09', 'freddy', 'Jean Alejandro PENALVER', 'JP', 'cuisine', '3 - Poste Soir', '15:00', '23:00', 'soir', '30mn'),
('2026-04-10', 'freddy', 'Jean Alejandro PENALVER', 'JP', 'cuisine', '3 - Poste Soir', '15:00', '23:00', 'soir', '30mn'),
('2026-04-12', 'freddy', 'Jean Alejandro PENALVER', 'JP', 'cuisine', '3 - Poste Soir', '16:00', '23:00', 'soir', '30mn'),

('2026-04-06', 'freddy', 'Clara MATTER', 'CM', 'cuisine', '3 - Poste Soir', '15:00', '22:40', 'soir', '2mn [+08mn]'),
('2026-04-07', 'freddy', 'Clara MATTER', 'CM', 'cuisine', '3 - Poste Soir', '15:30', '22:30', 'soir', '30mn'),
('2026-04-08', 'freddy', 'Clara MATTER', 'CM', 'cuisine', '3 - Poste Soir', '15:00', '23:00', 'soir', '30mn'),
('2026-04-09', 'freddy', 'Clara MATTER', 'CM', 'cuisine', '2 - Après-Midi', '11:30', '21:30', 'journee', '30mn'),

('2026-04-06', 'freddy', 'Laszlo Suhai BUSTAMANTE CARPIO', 'LB', 'cuisine', '1- Poste Matin', '08:00', '16:00', 'journee', '29mn [+01mn]'),
('2026-04-07', 'freddy', 'Laszlo Suhai BUSTAMANTE CARPIO', 'LB', 'cuisine', '1- Poste Matin', '08:00', '16:00', 'journee', '30mn'),
('2026-04-08', 'freddy', 'Laszlo Suhai BUSTAMANTE CARPIO', 'LB', 'cuisine', '1- Poste Matin', '07:00', '15:30', 'midi', '30mn'),
('2026-04-11', 'freddy', 'Laszlo Suhai BUSTAMANTE CARPIO', 'LB', 'cuisine', '1- Poste Matin', '07:00', '15:30', 'midi', '30mn'),
('2026-04-12', 'freddy', 'Laszlo Suhai BUSTAMANTE CARPIO', 'LB', 'cuisine', '1- Poste Matin', '07:00', '15:00', 'midi', '30mn'),

('2026-04-11', 'freddy', 'Vianney STOLZ', 'VS', 'cuisine', '1- Poste Matin', '07:00', '15:00', 'midi', '30mn');
