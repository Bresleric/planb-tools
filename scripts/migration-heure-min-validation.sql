-- TAF : heure minimale de validation (une tache ne peut pas etre cochee avant cette heure, sauf admin)
-- Idempotent : peut etre relance sans risque.

ALTER TABLE taches_recurrentes ADD COLUMN IF NOT EXISTS heure_min_validation time;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS heure_min_validation time;

COMMENT ON COLUMN taches_recurrentes.heure_min_validation IS 'Heure avant laquelle la tache generee ne peut pas etre cochee (sauf admin). NULL = pas de limite.';
COMMENT ON COLUMN tasks.heure_min_validation IS 'Copie de taches_recurrentes.heure_min_validation a la generation. NULL = pas de limite.';

-- PMS Freddy : nettoyages du soir cochables a partir de 22:00
UPDATE taches_recurrentes
   SET heure_min_validation = '22:00'
 WHERE etablissement = 'freddy' AND categorie = 'Nettoyage' AND creneau = 'Soir'
   AND heure_min_validation IS NULL;

-- Taches deja generees et non faites (aujourd hui et apres)
UPDATE tasks t
   SET heure_min_validation = r.heure_min_validation
  FROM taches_recurrentes r
 WHERE t.recurrence_id = r.id AND r.heure_min_validation IS NOT NULL
   AND t.fait_par_id IS NULL AND t.heure_min_validation IS NULL
   AND t.echeance >= current_date;
