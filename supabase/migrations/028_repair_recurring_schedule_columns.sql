-- Migration 027 creates the recurring table for new environments. Some
-- existing environments already had an earlier version of the table, so
-- CREATE TABLE IF NOT EXISTS did not add the newer scheduling preferences.
-- Keep this repair idempotent so it is safe for both schema variants.

ALTER TABLE public.recurring_schedules
  ADD COLUMN IF NOT EXISTS wallet_id TEXT
    REFERENCES public.wallets(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS posting_mode TEXT NOT NULL DEFAULT 'review',
  ADD COLUMN IF NOT EXISTS reminder_days INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS use_last_day BOOLEAN NOT NULL DEFAULT false;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.recurring_schedules'::regclass
      AND conname = 'recurring_schedules_posting_mode_check'
  ) THEN
    ALTER TABLE public.recurring_schedules
      ADD CONSTRAINT recurring_schedules_posting_mode_check
      CHECK (posting_mode IN ('review', 'automatic'));
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.recurring_schedules'::regclass
      AND conname = 'recurring_schedules_reminder_days_check'
  ) THEN
    ALTER TABLE public.recurring_schedules
      ADD CONSTRAINT recurring_schedules_reminder_days_check
      CHECK (reminder_days BETWEEN 0 AND 30);
  END IF;
END
$migration$;

-- Ask PostgREST to refresh immediately instead of waiting for its schema
-- cache poll interval. This resolves PGRST204 for clients already running.
NOTIFY pgrst, 'reload schema';
