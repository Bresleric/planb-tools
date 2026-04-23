-- ============================================================
-- IMPORT SALARIÉS depuis Combo (listeSalaries.xlsx)
-- Date import : 2026-04-23
-- Nombre de salariés : 24
-- ============================================================

BEGIN;

-- Camille BRESLER (Consultante / CDD)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Camille', 'BRESLER', 'CB',
  '2025-07-01', '2026-06-14',
  'cdd', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  NULL, '678f6dd69eec649bbbb0f42f', 'Consultante — emploi original Combo : ''Consultante'' (poste à affecter manuellement)', TRUE
);

-- Mathilde BALAS (Cheffe de rang / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Mathilde', 'BALAS', 'MB',
  '2025-05-14', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), '6835df1f40efddb2c7e9739d', NULL, TRUE
);

-- Johnny BAUER (Cuisinier / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Johnny', 'BAUER', 'JB',
  '2025-10-03', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CUIS' AND etablissement IS NULL LIMIT 1), NULL, NULL, TRUE
);

-- Laszlo Suhail BUSTAMANTE CARPIO (Apprenti cuisinier / Contrat d'apprentissage en CDD)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Laszlo Suhail', 'BUSTAMANTE CARPIO', 'LB',
  '2025-09-22', '2027-09-21',
  'cdd', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CUIS' AND etablissement IS NULL LIMIT 1), NULL, 'Apprentissage — emploi original Combo : ''Apprenti cuisinier''', TRUE
);

-- Christelle DIX (Cheffe de rang / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Christelle', 'DIX', 'CD',
  '2026-04-21', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), NULL, NULL, TRUE
);

-- Carole DUARTE (Aide de cuisine - plongeuse / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Carole', 'DUARTE', 'CD',
  '2025-05-07', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'PLG' AND etablissement IS NULL LIMIT 1), '6835dadbc8e5cd95ecce4a80', NULL, TRUE
);

-- Amauric EBERHART (Serveur / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Amauric', 'EBERHART', 'AE',
  '2026-04-21', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'SERV' AND etablissement IS NULL LIMIT 1), NULL, NULL, TRUE
);

-- Laurence KOHLER (Responsable de salle / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Laurence', 'KOHLER', 'LK',
  '2026-02-02', NULL,
  'cdi_plein', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'MH' AND etablissement IS NULL LIMIT 1), NULL, NULL, TRUE
);

-- Eve LHOPITEAU (Cuisiniere / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Eve', 'LHOPITEAU', 'EL',
  '2023-04-26', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CUIS' AND etablissement IS NULL LIMIT 1), '678f6cdd6dcd74e5648a5fe0', NULL, TRUE
);

-- Clara MATTER (Commis de cuisine / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Clara', 'MATTER', 'CM',
  '2025-10-06', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'COM' AND etablissement IS NULL LIMIT 1), NULL, NULL, TRUE
);

-- Charlotte MC CLOSKEY (Responsable desalle / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Charlotte', 'MC CLOSKEY', 'CM',
  '2024-05-22', NULL,
  'cdi_plein', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'MH' AND etablissement IS NULL LIMIT 1), '678def8cd4485072febbd3e6', NULL, TRUE
);

-- Marine MERKILED ATHANASE (Cheffe de rang / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Marine', 'MERKILED ATHANASE', 'MM',
  '2024-09-04', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), '678f6a780967647ecbc4d8cc', NULL, TRUE
);

-- Anne-Sophie MESSIN (Responsable de salle / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Anne-Sophie', 'MESSIN', 'AM',
  '2023-10-20', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'MH' AND etablissement IS NULL LIMIT 1), '0003', NULL, TRUE
);

-- Virginie MOHR (Responsable de salle / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Virginie', 'MOHR', 'VM',
  '2022-01-01', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'MH' AND etablissement IS NULL LIMIT 1), '678dffea8300719095f9cb19', NULL, TRUE
);

-- Emilienne NGO (Cuisiniere / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Emilienne', 'NGO', 'EN',
  '2016-04-01', NULL,
  'cdi_plein', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CUIS' AND etablissement IS NULL LIMIT 1), '678def8701d1dad98bc09ac8', NULL, TRUE
);

-- Rachel NGOMAYI (Serveuse / CDD)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Rachel', 'NGOMAYI', 'RN',
  '2025-07-13', '2026-04-25',
  'cdd', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'SERV' AND etablissement IS NULL LIMIT 1), '000210', NULL, TRUE
);

-- Alemoujrodo Koffi NOUSSOUKPOE (Aide de cuisine - plongeur / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Alemoujrodo Koffi', 'NOUSSOUKPOE', 'AN',
  '2025-08-19', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'PLG' AND etablissement IS NULL LIMIT 1), '0001', NULL, TRUE
);

-- Francesca NUTINI (Cheffe de range / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Francesca', 'NUTINI', 'FN',
  '2025-04-01', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), '6812840453ecb4f768622faa', NULL, TRUE
);

-- Martine OSWALD (Cheffe de rang / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Martine', 'OSWALD', 'MO',
  '2024-12-02', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), '678e00022537ccd2f2b9c55e', NULL, TRUE
);

-- Matthieu PAULUS (Cuisinier / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Matthieu', 'PAULUS', 'MP',
  '2024-03-14', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CUIS' AND etablissement IS NULL LIMIT 1), '678f6b9378c537b90b8585fe', NULL, TRUE
);

-- Jean Alejandro PENALVER (Commis de cuisine / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Jean Alejandro', 'PENALVER', 'JP',
  '2024-10-07', NULL,
  'cdi_plein', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'COM' AND etablissement IS NULL LIMIT 1), '678f6e3dec03d43edc626ec1', NULL, TRUE
);

-- Marion RAUCY (Cheffe de rang / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Marion', 'RAUCY', 'MR',
  '2026-04-28', NULL,
  'cdi_plein', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), NULL, NULL, TRUE
);

-- David ROUILLAUX (Chef de rang / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'David', 'ROUILLAUX', 'DR',
  '2024-08-19', NULL,
  'cdi_plein', 42,
  'liesel', ARRAY['liesel']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CHR' AND etablissement IS NULL LIMIT 1), '678def8b253775ca9a2b528e', NULL, TRUE
);

-- Tesfamariam ZERAY AREGAY (Cuisiniere / CDI)
INSERT INTO pointage_salaries (
  prenom, nom, initiales, date_embauche, date_fin_contrat,
  type_contrat, heures_contractuelles_semaine,
  etablissement_principal, etablissements_autorises,
  poste_principal_id, numero_interne, notes, actif
) VALUES (
  'Tesfamariam', 'ZERAY AREGAY', 'TZ',
  '2021-07-17', NULL,
  'cdi_plein', 42,
  'freddy', ARRAY['freddy']::TEXT[],
  (SELECT id FROM pointage_postes WHERE code = 'CUIS' AND etablissement IS NULL LIMIT 1), '678f69c99eec649bbbb0f40c', NULL, TRUE
);

COMMIT;

-- Vérification :
-- SELECT COUNT(*) AS nb_salaries, etablissement_principal FROM pointage_salaries GROUP BY etablissement_principal;