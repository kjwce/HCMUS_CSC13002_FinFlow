CREATE TABLE IF NOT EXISTS recurring_schedules (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'Other',
  amount BIGINT NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly')),
  next_occurrence TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  wallet_id TEXT REFERENCES wallets(id) ON DELETE SET NULL,
  posting_mode TEXT NOT NULL DEFAULT 'review'
    CHECK (posting_mode IN ('review', 'automatic')),
  reminder_days INTEGER NOT NULL DEFAULT 1
    CHECK (reminder_days BETWEEN 0 AND 30),
  use_last_day BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE recurring_schedules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their recurring schedules"
  ON recurring_schedules;

CREATE POLICY "Users can manage their recurring schedules"
  ON recurring_schedules FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
