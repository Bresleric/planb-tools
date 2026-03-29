-- Planning/Scheduling schema for PlanB Tools
-- Stores all shift data for employees across establishments

CREATE TABLE IF NOT EXISTS planning_equipes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "date" date NOT NULL,
    etablissement text NOT NULL REFERENCES etablissements(id),
    employe_nom text NOT NULL,
    employe_initiales text NOT NULL,
    equipe text NOT NULL, -- cuisine, salle, plonge, aide_cuisine_plonge
    poste text, -- type of shift: Ouverture, Fermeture, Continue midi, Soir, Continu Cuisine, etc.
    heure_debut time NOT NULL,
    heure_fin time NOT NULL,
    service text, -- midi, soir, or journee (derived from shift times)
    notes text, -- Premier jour, Dernier jour, etc.
    created_at timestamptz DEFAULT now(),
    CONSTRAINT planning_equipes_unique UNIQUE("date", etablissement, employe_nom, heure_debut)
);

CREATE INDEX idx_planning_equipes_date ON planning_equipes("date", etablissement);
CREATE INDEX idx_planning_equipes_employe ON planning_equipes(employe_nom, etablissement);
CREATE INDEX idx_planning_equipes_equipe ON planning_equipes(equipe, etablissement);
