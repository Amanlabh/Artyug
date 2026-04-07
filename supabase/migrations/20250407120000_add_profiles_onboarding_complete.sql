-- Required by Flutter AuthProvider.refreshOnboardingStatus() and onboarding flow upsert.
-- Run in Supabase: SQL Editor → paste → Run, or use `supabase db push` if you use the CLI.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_complete boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.onboarding_complete IS
  'Set true when the user finishes the in-app onboarding wizard.';
