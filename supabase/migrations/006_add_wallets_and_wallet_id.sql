-- Create wallets table (if not already exists)
CREATE TABLE IF NOT EXISTS wallets (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  logo_asset_path TEXT NOT NULL DEFAULT '',
  brand_color TEXT NOT NULL DEFAULT '#4285F4',
  type TEXT NOT NULL DEFAULT 'bank',
  initial_balance BIGINT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS + policies for wallets
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_read_own_wallets"
  ON wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_wallets"
  ON wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_wallets"
  ON wallets FOR DELETE
  USING (auth.uid() = user_id);

-- Add wallet_id to transactions
ALTER TABLE transactions
ADD COLUMN wallet_id TEXT;
