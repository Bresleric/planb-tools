-- Ajout d'un code d'ordre hiérarchique sur les éléments de check-list
-- Format : 1, 1.1, 1.2, 1.2.1, 1.2.2, 1.3, 2, 2.1...
-- Permet de définir un ordre d'exécution structuré avec sous-étapes

ALTER TABLE checklist_items
  ADD COLUMN IF NOT EXISTS ordre_code TEXT;

-- Initialisation des éléments existants : convertir l'entier "ordre" en code simple
UPDATE checklist_items
   SET ordre_code = (ordre + 1)::TEXT
 WHERE ordre_code IS NULL;
