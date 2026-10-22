-- ============================================================================
-- AGON — Migração 014: Supabase Storage Buckets e Políticas de Acesso
-- ============================================================================
-- Descrição: Provisiona de forma idempotente os 4 buckets de arquivos do AGON:
-- 1. `avatars` (público — fotos de perfil dos alunos em `configuracoes.html`)
-- 2. `materiais` (autenticado — apostilas PDF, mapas mentais, leis esquematizadas)
-- 3. `aulas-anexos` (autenticado — slides e materiais de apoio de `aulas.html`)
-- 4. `comunidade-anexos` (autenticado — imagens e resumos anexados em `comunidade.html`)
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'storage' AND table_name = 'buckets'
  ) THEN
    -- 1. Bucket: avatars (público, limite 2 MB, imagens PNG/JPG/WEBP)
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'avatars',
      'avatars',
      true,
      2097152,
      ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    )
    ON CONFLICT (id) DO UPDATE SET
      public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

    -- 2. Bucket: materiais (privado/autenticado, limite 50 MB, PDFs)
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'materiais',
      'materiais',
      false,
      52428800,
      ARRAY['application/pdf']
    )
    ON CONFLICT (id) DO UPDATE SET
      public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

    -- 3. Bucket: aulas-anexos (privado/autenticado, limite 50 MB, PDFs/Slides/ZIP)
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'aulas-anexos',
      'aulas-anexos',
      false,
      52428800,
      ARRAY['application/pdf', 'application/zip', 'image/png', 'image/jpeg']
    )
    ON CONFLICT (id) DO UPDATE SET
      public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

    -- 4. Bucket: comunidade-anexos (autenticado, limite 10 MB, Imagens e PDFs de resumos)
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
      'comunidade-anexos',
      'comunidade-anexos',
      true,
      10485760,
      ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
    )
    ON CONFLICT (id) DO UPDATE SET
      public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;
  END IF;
END $$;

-- ============================================================================
-- POLÍTICAS EM `storage.objects`
-- ============================================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'storage' AND table_name = 'objects'
  ) THEN
    -- Leitura pública de avatares e anexos da comunidade
    DROP POLICY IF EXISTS storage_avatars_public_select ON storage.objects;
    CREATE POLICY storage_avatars_public_select ON storage.objects
      FOR SELECT USING (bucket_id IN ('avatars', 'comunidade-anexos'));

    -- Upload/Atualização do próprio avatar na pasta `<user_id>/*`
    DROP POLICY IF EXISTS storage_avatars_user_insert ON storage.objects;
    CREATE POLICY storage_avatars_user_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );

    DROP POLICY IF EXISTS storage_avatars_user_update ON storage.objects;
    CREATE POLICY storage_avatars_user_update ON storage.objects
      FOR UPDATE TO authenticated
      USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );

    -- Leitura autenticada de materiais e anexos de aulas
    DROP POLICY IF EXISTS storage_materiais_aulas_auth_select ON storage.objects;
    CREATE POLICY storage_materiais_aulas_auth_select ON storage.objects
      FOR SELECT TO authenticated
      USING (bucket_id IN ('materiais', 'aulas-anexos'));

    -- Upload de anexos na comunidade por alunos autenticados na pasta `<user_id>/*`
    DROP POLICY IF EXISTS storage_comunidade_user_insert ON storage.objects;
    CREATE POLICY storage_comunidade_user_insert ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'comunidade-anexos'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END $$;
