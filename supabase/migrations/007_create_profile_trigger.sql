-- Auto-create a public profile whenever a new Supabase Auth user signs up.
-- Keep this in migrations so a new Supabase project can be rebuilt from the
-- repository schema without relying on the older standalone supabase_schema.sql.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    created_at,
    budget_limit,
    selected_category
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', 'New FinFlow User'),
    COALESCE(NEW.email, ''),
    NOW(),
    5000000,
    NULL
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
