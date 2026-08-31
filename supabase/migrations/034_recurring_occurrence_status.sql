-- Turn recurring_notifications into a durable occurrence lifecycle ledger.
-- The row for each schedule/date now powers Recurring Health & History as
-- well as the reminder shown in the Notification Center.

ALTER TABLE public.recurring_notifications
  ADD COLUMN IF NOT EXISTS amount BIGINT;

UPDATE public.recurring_notifications AS occurrence
SET amount = schedule.amount
FROM public.recurring_schedules AS schedule
WHERE occurrence.schedule_id = schedule.id
  AND occurrence.amount IS NULL;

ALTER TABLE public.recurring_notifications
  DROP CONSTRAINT IF EXISTS recurring_notifications_status_check;

ALTER TABLE public.recurring_notifications
  ADD CONSTRAINT recurring_notifications_status_check
  CHECK (status IN ('pending', 'completed', 'skipped', 'failed', 'dismissed'));

CREATE INDEX IF NOT EXISTS recurring_notifications_schedule_status_idx
  ON public.recurring_notifications (schedule_id, status, occurrence_at DESC);

NOTIFY pgrst, 'reload schema';
