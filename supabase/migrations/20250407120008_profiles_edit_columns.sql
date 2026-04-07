-- Columns used by Flutter Edit Profile. Older Supabase schemas often only had
-- website_url / cover_photo_url; missing instagram/twitter/website causes
-- PostgREST 400 on update ("Could not find the 'instagram' column...").

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS website text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS website_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS instagram text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS twitter text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS location text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cover_photo_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cover_image_url text;

-- Keep legacy and new website fields aligned when only one was populated.
UPDATE public.profiles
SET website = website_url
WHERE (website IS NULL OR btrim(website) = '')
  AND website_url IS NOT NULL
  AND btrim(website_url) <> '';

UPDATE public.profiles
SET website_url = website
WHERE (website_url IS NULL OR btrim(website_url) = '')
  AND website IS NOT NULL
  AND btrim(website) <> '';

UPDATE public.profiles
SET cover_image_url = cover_photo_url
WHERE (cover_image_url IS NULL OR btrim(cover_image_url) = '')
  AND cover_photo_url IS NOT NULL
  AND btrim(cover_photo_url) <> '';

UPDATE public.profiles
SET cover_photo_url = cover_image_url
WHERE (cover_photo_url IS NULL OR btrim(cover_photo_url) = '')
  AND cover_image_url IS NOT NULL
  AND btrim(cover_image_url) <> '';
