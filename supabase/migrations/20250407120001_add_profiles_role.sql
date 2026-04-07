-- Used by onboarding upsert (creator | collector). Safe if column already exists.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role text;

COMMENT ON COLUMN public.profiles.role IS
  'User-chosen path from onboarding: creator or collector.';
