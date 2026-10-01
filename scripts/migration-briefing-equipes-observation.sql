-- Migration : colonne observation globale du bloc Equipes du briefing
-- (appliquee via MCP le 01/10/2026, gardee pour trace)
ALTER TABLE briefings ADD COLUMN IF NOT EXISTS equipes_observation TEXT;
