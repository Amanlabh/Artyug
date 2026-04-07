-- Storage buckets + RLS for artwork uploads and profile avatars.
-- Without these policies, uploads fail with:
-- StorageException: new row violates row-level security policy (403).
--
-- Apply: Supabase Dashboard → SQL Editor → run this file, or `supabase db push`.

-- ── Buckets (public read so getPublicUrl() works for clients) ─────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('paintings', 'paintings', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- ── paintings: path is {auth.uid}/{timestamp}.{ext} ─────────────────────────
DROP POLICY IF EXISTS "paintings_select_public" ON storage.objects;
CREATE POLICY "paintings_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'paintings');

DROP POLICY IF EXISTS "paintings_insert_own_folder" ON storage.objects;
CREATE POLICY "paintings_insert_own_folder"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'paintings'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "paintings_update_own_folder" ON storage.objects;
CREATE POLICY "paintings_update_own_folder"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'paintings'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'paintings'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "paintings_delete_own_folder" ON storage.objects;
CREATE POLICY "paintings_delete_own_folder"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'paintings'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── profiles: path is avatars/{userId}.jpg (see edit_profile_screen.dart) ───
DROP POLICY IF EXISTS "profiles_select_public" ON storage.objects;
CREATE POLICY "profiles_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'profiles');

DROP POLICY IF EXISTS "profiles_insert_own_avatar" ON storage.objects;
CREATE POLICY "profiles_insert_own_avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'profiles'
    AND name LIKE ('avatars/' || auth.uid()::text || '%')
  );

DROP POLICY IF EXISTS "profiles_update_own_avatar" ON storage.objects;
CREATE POLICY "profiles_update_own_avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'profiles'
    AND name LIKE ('avatars/' || auth.uid()::text || '%')
  )
  WITH CHECK (
    bucket_id = 'profiles'
    AND name LIKE ('avatars/' || auth.uid()::text || '%')
  );

DROP POLICY IF EXISTS "profiles_delete_own_avatar" ON storage.objects;
CREATE POLICY "profiles_delete_own_avatar"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'profiles'
    AND name LIKE ('avatars/' || auth.uid()::text || '%')
  );
