-- ============================================================
-- INIT — nb_niveaux des meubles temp_frigos
-- À exécuter APRÈS schema.sql
-- Valeurs par défaut suggérées, à ajuster côté admin par établissement
-- ============================================================

-- Convention : 1 = bas, 4 = haut

-- ----------- FREDDY -----------
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'freddy' AND nom = 'CUISINE GAUCHE';
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'freddy' AND nom = 'CUISINE DROITE';
UPDATE public.temp_frigos SET nb_niveaux = 2 WHERE etablissement = 'freddy' AND nom = 'Table réfrigérée';
UPDATE public.temp_frigos SET nb_niveaux = 3 WHERE etablissement = 'freddy' AND nom = 'Vitrine à gateaux';
UPDATE public.temp_frigos SET nb_niveaux = 3 WHERE etablissement = 'freddy' AND nom = 'CONGELATEUR BAR/GLACES';
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'freddy' AND nom = 'CF POSITIVE';
UPDATE public.temp_frigos SET nb_niveaux = 3 WHERE etablissement = 'freddy' AND nom = 'CONGEL CAVE BOISSON';
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'freddy' AND nom = 'FRIGO 1 - EPICERIE';
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'freddy' AND nom = 'FRIGO 2 - LEGUMES';
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'freddy' AND nom = 'FRIGO 3 - SALLE';
UPDATE public.temp_frigos SET nb_niveaux = 2 WHERE etablissement = 'freddy' AND nom = 'TABLE REFRIGEREE GAUCHE';
UPDATE public.temp_frigos SET nb_niveaux = 2 WHERE etablissement = 'freddy' AND nom = 'TABLE REFRIGEREE DROITE';

-- ----------- LIESEL -----------
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'liesel' AND nom = 'Armoire réfrigérée';
UPDATE public.temp_frigos SET nb_niveaux = 4 WHERE etablissement = 'liesel' AND nom = 'Chambre froide';
UPDATE public.temp_frigos SET nb_niveaux = 3 WHERE etablissement = 'liesel' AND nom = 'Vitrine à Gateau';
UPDATE public.temp_frigos SET nb_niveaux = 3 WHERE etablissement = 'liesel' AND nom = 'Frigo Vin';
UPDATE public.temp_frigos SET nb_niveaux = 2 WHERE etablissement = 'liesel' AND nom = 'Congélateur Bar';

-- Vérification
SELECT etablissement, nom, categorie, nb_niveaux
  FROM public.temp_frigos
 WHERE actif = true
 ORDER BY etablissement, ordre;
