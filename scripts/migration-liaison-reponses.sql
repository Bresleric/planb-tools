-- Migration : reponses dans le cahier de liaison (fil de discussion simple)
-- (appliquee via MCP le 04/10/2026, gardee pour trace)
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS reponse_a UUID REFERENCES liaison_messages(id) ON DELETE CASCADE;
