-- ============================================================================
-- Migration : pieces jointes du Cahier de liaison (06/10/2026)
-- INTEGRALEMENT APPLIQUEE via MCP le 06/10/2026 — fichier conserve pour trace.
--
-- 1. Colonne jsonb sur les messages (les PJ suivent la visibilite du message)
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS pieces_jointes jsonb NOT NULL DEFAULT '[]'::jsonb;

-- 2. Bucket Storage dedie (public : affichage direct des miniatures ;
--    chemins non devinables UUID, visibilite geree au niveau applicatif)
INSERT INTO storage.buckets (id, name, public) VALUES ('liaison-images', 'liaison-images', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Policies Storage anon pour le cahier de liaison
DROP POLICY IF EXISTS liaison_images_anon_insert ON storage.objects;
CREATE POLICY liaison_images_anon_insert ON storage.objects FOR INSERT TO anon WITH CHECK (bucket_id = 'liaison-images');
DROP POLICY IF EXISTS liaison_images_anon_select ON storage.objects;
CREATE POLICY liaison_images_anon_select ON storage.objects FOR SELECT TO anon USING (bucket_id = 'liaison-images');
DROP POLICY IF EXISTS liaison_images_anon_delete ON storage.objects;
CREATE POLICY liaison_images_anon_delete ON storage.objects FOR DELETE TO anon USING (bucket_id = 'liaison-images');

-- 4. BUG LATENT CORRIGE AU PASSAGE : les buckets du module Information
--    n existaient pas (uploads d images/PJ impossibles depuis sa mise en
--    service). Buckets crees + policies anon.
INSERT INTO storage.buckets (id, name, public) VALUES
  ('information-images', 'information-images', true),
  ('information-attachments', 'information-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS information_images_anon_all ON storage.objects;
CREATE POLICY information_images_anon_all ON storage.objects FOR ALL TO anon
  USING (bucket_id = 'information-images') WITH CHECK (bucket_id = 'information-images');
DROP POLICY IF EXISTS information_attachments_anon_all ON storage.objects;
CREATE POLICY information_attachments_anon_all ON storage.objects FOR ALL TO anon
  USING (bucket_id = 'information-attachments') WITH CHECK (bucket_id = 'information-attachments');

-- Verification (5 lignes attendues) :
-- SELECT policyname FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
--   AND (policyname LIKE 'liaison%' OR policyname LIKE 'information%');
-- ============================================================================
