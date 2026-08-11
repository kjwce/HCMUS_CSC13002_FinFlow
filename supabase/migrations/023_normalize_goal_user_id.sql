-- Some early/manual FinFlow databases created goals.user_id as TEXT. The
-- advanced goal RPCs compare ownership with auth.uid() (UUID), so normalize
-- the column and policies just as migration 020 did for transactions.

DO $migration$
DECLARE
  existing_policy RECORD;
  current_user_id_type TEXT;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.goals goal
    WHERE goal.user_id::TEXT !~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) THEN
    RAISE EXCEPTION
      '023 aborted: goals.user_id contains a non-UUID value';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.goals goal
    LEFT JOIN public.profiles profile
      ON profile.id::TEXT = goal.user_id::TEXT
    WHERE profile.id IS NULL
  ) THEN
    RAISE EXCEPTION
      '023 aborted: goals contains user_id values missing from profiles';
  END IF;

  FOR existing_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'goals'
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.goals',
      existing_policy.policyname
    );
  END LOOP;

  SELECT columns.data_type
  INTO current_user_id_type
  FROM information_schema.columns AS columns
  WHERE columns.table_schema = 'public'
    AND columns.table_name = 'goals'
    AND columns.column_name = 'user_id';

  IF current_user_id_type IS NULL THEN
    RAISE EXCEPTION '023 aborted: goals.user_id does not exist';
  END IF;

  ALTER TABLE public.goals
    DROP CONSTRAINT IF EXISTS goals_user_id_fkey;

  IF current_user_id_type <> 'uuid' THEN
    EXECUTE (
      'ALTER TABLE public.goals '
      'ALTER COLUMN user_id TYPE UUID USING user_id::UUID'
    );
  END IF;

  ALTER TABLE public.goals
    ADD CONSTRAINT goals_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES public.profiles(id)
    ON DELETE CASCADE;

  ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "goals_select_own"
    ON public.goals FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

  CREATE POLICY "goals_insert_own"
    ON public.goals FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "goals_update_own"
    ON public.goals FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "goals_delete_own"
    ON public.goals FOR DELETE TO authenticated
    USING (auth.uid() = user_id);
END;
$migration$;
