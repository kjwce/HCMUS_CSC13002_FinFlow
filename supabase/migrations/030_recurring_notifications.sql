-- Durable in-app history for recurring reminders. System notifications are
-- scheduled by the Flutter client; this table makes the same reminder visible
-- in FinFlow's Notification Center even if the app was closed at delivery time.

CREATE TABLE IF NOT EXISTS public.recurring_notifications (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  schedule_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  posting_mode TEXT NOT NULL
    CHECK (posting_mode IN ('review', 'automatic')),
  occurrence_at TIMESTAMPTZ NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed', 'dismissed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS recurring_notifications_user_due_idx
  ON public.recurring_notifications (user_id, scheduled_for DESC);

CREATE INDEX IF NOT EXISTS recurring_notifications_schedule_idx
  ON public.recurring_notifications (schedule_id, occurrence_at DESC);

ALTER TABLE public.recurring_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their recurring notifications"
  ON public.recurring_notifications;

CREATE POLICY "Users can manage their recurring notifications"
  ON public.recurring_notifications FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'recurring_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.recurring_notifications;
  END IF;
END
$migration$;

NOTIFY pgrst, 'reload schema';
