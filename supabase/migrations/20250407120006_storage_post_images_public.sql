-- Public read for `post-images` (used by legacy UploadScreen / community flows).
-- Without this, URLs stored in DB return 403 for anonymous clients and images break on web.

INSERT INTO storage.buckets (id, name, public)
VALUES ('post-images', 'post-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "post_images_select_public" ON storage.objects;
CREATE POLICY "post_images_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'post-images');
