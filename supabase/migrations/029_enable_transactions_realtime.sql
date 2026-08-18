-- Transaction cards and lists must update when another client changes data.
-- Adding the table to the publication is idempotent for existing projects.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.transactions;
  END IF;
END
$$;
