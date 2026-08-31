-- Fix "Database error saving new user" during signup.
--
-- Migration 025 attached ensure_default_goal_settings_on_signup to
-- auth.users AFTER INSERT. PostgreSQL fires same-kind triggers in
-- alphabetical order by name, so that trigger ran BEFORE
-- on_auth_user_created (which creates the public.profiles row). The
-- goal_settings insert therefore violated its FK to profiles(id) and the
-- whole GoTrue signup transaction aborted.
--
-- Fix: fire the default-goal-settings insert from public.profiles AFTER
-- INSERT instead, where the profile row is guaranteed to exist.

BEGIN;

-- 1. Remove the broken trigger from auth.users.
DROP TRIGGER IF EXISTS ensure_default_goal_settings_on_signup ON auth.users;

-- 2. Recreate the function (unchanged logic) and attach it to profiles.
CREATE OR REPLACE FUNCTION public.ensure_default_goal_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.goal_settings (
    user_id,
    expense_shortfall_policy,
    imported_transaction_policy
  ) VALUES (
    NEW.id,
    'ask_each_time',
    'auto_withdraw'
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_default_goal_settings_on_profile ON public.profiles;
CREATE TRIGGER ensure_default_goal_settings_on_profile
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.ensure_default_goal_settings();

-- 3. Backfill users who never got a settings row because the old trigger
--    aborted their signup. Join profiles to respect the FK.
INSERT INTO public.goal_settings (
  user_id,
  expense_shortfall_policy,
  imported_transaction_policy
)
SELECT u.id, 'ask_each_time', 'auto_withdraw'
FROM auth.users u
JOIN public.profiles p ON p.id = u.id
ON CONFLICT (user_id) DO NOTHING;

COMMIT;

