-- Normalize transactions.user_id to UUID and make transaction ownership
-- follow profiles/auth user deletion. This migration is safe to rerun.
--
-- Preconditions:
--   1. Every transactions.user_id is a valid UUID string.
--   2. Every transactions.user_id has a matching public.profiles row.
--
-- All mutations live in one DO statement. PostgreSQL rolls the whole statement
-- back if any step fails, including the temporary policy removals.

DO $migration$
DECLARE
  existing_policy RECORD;
  current_user_id_type TEXT;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.transactions tx
    WHERE tx.user_id::TEXT !~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) THEN
    RAISE EXCEPTION
      '020 aborted: transactions.user_id contains a non-UUID value';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.transactions tx
    LEFT JOIN public.profiles profile
      ON profile.id::TEXT = tx.user_id::TEXT
    WHERE profile.id IS NULL
  ) THEN
    RAISE EXCEPTION
      '020 aborted: transactions contains user_id values missing from profiles';
  END IF;

  -- Policy names differ between older/manual Supabase setups. Remove every
  -- transaction policy by discovery instead of assuming specific names.
  FOR existing_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'transactions'
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.transactions',
      existing_policy.policyname
    );
  END LOOP;

  SELECT columns.data_type
  INTO current_user_id_type
  FROM information_schema.columns AS columns
  WHERE columns.table_schema = 'public'
    AND columns.table_name = 'transactions'
    AND columns.column_name = 'user_id';

  IF current_user_id_type IS NULL THEN
    RAISE EXCEPTION '020 aborted: transactions.user_id does not exist';
  END IF;

  IF current_user_id_type <> 'uuid' THEN
    EXECUTE (
      'ALTER TABLE public.transactions '
      'ALTER COLUMN user_id TYPE UUID USING user_id::UUID'
    );
  END IF;

  -- Recreate the known ownership constraint so its behavior is deterministic.
  ALTER TABLE public.transactions
    DROP CONSTRAINT IF EXISTS transactions_user_id_fkey;

  ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES public.profiles(id)
    ON DELETE CASCADE;

  ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "transactions_select_own"
    ON public.transactions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

  CREATE POLICY "transactions_insert_own"
    ON public.transactions
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "transactions_update_own"
    ON public.transactions
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "transactions_delete_own"
    ON public.transactions
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
END;
$migration$;
