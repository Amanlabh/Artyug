-- Profile banner uploads use banners/{uid}.jpg (edit_profile_screen.dart).
-- Extend storage RLS so authenticated users can write their own banner path.

DROP POLICY IF EXISTS "profiles_insert_own_avatar" ON storage.objects;
CREATE POLICY "profiles_insert_own_avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'profiles'
    AND (
      name LIKE ('avatars/' || auth.uid()::text || '%')
      OR name LIKE ('banners/' || auth.uid()::text || '%')
    )
  );

DROP POLICY IF EXISTS "profiles_update_own_avatar" ON storage.objects;
CREATE POLICY "profiles_update_own_avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'profiles'
    AND (
      name LIKE ('avatars/' || auth.uid()::text || '%')
      OR name LIKE ('banners/' || auth.uid()::text || '%')
    )
  )
  WITH CHECK (
    bucket_id = 'profiles'
    AND (
      name LIKE ('avatars/' || auth.uid()::text || '%')
      OR name LIKE ('banners/' || auth.uid()::text || '%')
    )
  );

DROP POLICY IF EXISTS "profiles_delete_own_avatar" ON storage.objects;
CREATE POLICY "profiles_delete_own_avatar"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'profiles'
    AND (
      name LIKE ('avatars/' || auth.uid()::text || '%')
      OR name LIKE ('banners/' || auth.uid()::text || '%')
    )
  );
