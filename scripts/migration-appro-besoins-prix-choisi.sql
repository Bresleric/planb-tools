-- Migration : choix du fournisseur memorise sur le besoin (onglet Besoins)
-- (appliquee via MCP le 03/10/2026, gardee pour trace)
ALTER TABLE appro_besoins ADD COLUMN IF NOT EXISTS prix_id UUID;
