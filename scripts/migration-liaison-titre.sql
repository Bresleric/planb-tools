-- Migration : titre optionnel des messages du cahier de liaison
-- (appliquee via MCP le 05/10/2026, gardee pour trace)
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS titre TEXT;
