-- Migration : suivi des chapitres vus avant publication du briefing
-- (appliquee via MCP le 02/10/2026, gardee pour trace)
ALTER TABLE briefings ADD COLUMN IF NOT EXISTS sections_vues JSONB DEFAULT '[]'::jsonb;
