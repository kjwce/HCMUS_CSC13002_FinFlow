-- The UI treats a missing settings row as ask_each_time. The transaction RPC
-- must see the same persisted default; otherwise NULL falls into its automatic
-- branch and protected goals selected by the user are skipped.
BEGIN;

INSERT INTO public.goal_settings (
  user_id,
  expense_shortfall_policy,
  imported_transaction_policy
)
SELECT id, 'ask_each_time', 'auto_withdraw'
FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

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

DROP TRIGGER IF EXISTS ensure_default_goal_settings_on_signup ON auth.users;
CREATE TRIGGER ensure_default_goal_settings_on_signup
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.ensure_default_goal_settings();

COMMIT;
