-- Align profiles.role CHECK with the Flutter app, which stores lowercase
-- 'creator' | 'collector' (see onboarding_screen.dart).
-- Older remote schemas often used 'Creator' | 'Collector', causing 23514 on upsert.

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Normalize existing values so the new CHECK can apply (empty / unknown -> NULL).
UPDATE public.profiles
SET role = CASE lower(trim(role))
  WHEN 'creator' THEN 'creator'
  WHEN 'collector' THEN 'collector'
  ELSE NULL
END
WHERE role IS NOT NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (
    role IS NULL
    OR lower(role) IN ('creator', 'collector')
  );

COMMENT ON CONSTRAINT profiles_role_check ON public.profiles IS
  'Role from onboarding; accepts creator/collector in any case.';
