-- Simplify all payment sources to exactly two system wallets per user:
-- cash (Tiền mặt) and transfer (Chuyển khoản).

BEGIN;

INSERT INTO public.wallets (
  id, user_id, name, logo_asset_path, brand_color, type,
  initial_balance, is_active
)
SELECT
  'wallet_cash_' || replace(p.id::TEXT, '-', ''),
  p.id,
  'Tiền mặt',
  'assets/logos/ewallets/cash.png',
  '#4CAF50',
  'cash',
  COALESCE(
    SUM(w.initial_balance) FILTER (WHERE w.type = 'cash'),
    0
  )::BIGINT,
  true
FROM public.profiles p
LEFT JOIN public.wallets w ON w.user_id = p.id
GROUP BY p.id
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  logo_asset_path = EXCLUDED.logo_asset_path,
  brand_color = EXCLUDED.brand_color,
  type = EXCLUDED.type,
  initial_balance = EXCLUDED.initial_balance,
  is_active = true;

INSERT INTO public.wallets (
  id, user_id, name, logo_asset_path, brand_color, type,
  initial_balance, is_active
)
SELECT
  'wallet_transfer_' || replace(p.id::TEXT, '-', ''),
  p.id,
  'Chuyển khoản',
  'assets/logos/ewallets/other.png',
  '#2878D0',
  'transfer',
  COALESCE(
    SUM(w.initial_balance) FILTER (WHERE w.type <> 'cash'),
    0
  )::BIGINT,
  true
FROM public.profiles p
LEFT JOIN public.wallets w ON w.user_id = p.id
GROUP BY p.id
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  logo_asset_path = EXCLUDED.logo_asset_path,
  brand_color = EXCLUDED.brand_color,
  type = EXCLUDED.type,
  initial_balance = EXCLUDED.initial_balance,
  is_active = true;

-- Preserve the original source classification of every transaction. Resolve
-- the destination from an existing wallet row instead of constructing an id;
-- this keeps the immediate wallet_id foreign key valid throughout the update.
UPDATE public.transactions AS tx
SET wallet_id = target_wallet.id
FROM public.wallets AS old_wallet, public.wallets AS target_wallet
WHERE tx.wallet_id = old_wallet.id
  AND target_wallet.user_id::TEXT = tx.user_id::TEXT
  AND target_wallet.type = CASE
    WHEN old_wallet.type = 'cash' THEN 'cash'
    ELSE 'transfer'
  END;

-- Previous code treated a missing source as bank, so retain that behavior by
-- assigning old null/dangling references to Chuyển khoản.
UPDATE public.transactions AS tx
SET wallet_id = target_wallet.id
FROM public.wallets AS target_wallet
WHERE target_wallet.user_id::TEXT = tx.user_id::TEXT
  AND target_wallet.type = 'transfer'
  AND (
    tx.wallet_id IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM public.wallets wallet WHERE wallet.id = tx.wallet_id
    )
  );

DELETE FROM public.wallets AS wallet
WHERE wallet.id NOT IN (
  'wallet_cash_' || replace(wallet.user_id::TEXT, '-', ''),
  'wallet_transfer_' || replace(wallet.user_id::TEXT, '-', '')
);

ALTER TABLE public.wallets
  ALTER COLUMN type SET DEFAULT 'transfer';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'wallets_type_check'
      AND conrelid = 'public.wallets'::regclass
  ) THEN
    ALTER TABLE public.wallets
      ADD CONSTRAINT wallets_type_check CHECK (type IN ('cash', 'transfer'));
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS wallets_one_source_per_user
  ON public.wallets (user_id, type);

-- Upserts from onboarding need UPDATE permission under RLS.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'wallets'
      AND policyname = 'users_update_own_wallets'
  ) THEN
    CREATE POLICY "users_update_own_wallets"
      ON public.wallets FOR UPDATE
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END;
$$;

-- Every new profile receives both sources automatically.
CREATE OR REPLACE FUNCTION public.create_default_wallets()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.wallets (
    id, user_id, name, logo_asset_path, brand_color, type, initial_balance
  ) VALUES
    (
      'wallet_cash_' || replace(NEW.id::TEXT, '-', ''), NEW.id, 'Tiền mặt',
      'assets/logos/ewallets/cash.png', '#4CAF50', 'cash', 0
    ),
    (
      'wallet_transfer_' || replace(NEW.id::TEXT, '-', ''), NEW.id,
      'Chuyển khoản', 'assets/logos/ewallets/other.png', '#2878D0',
      'transfer', 0
    )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_created_create_wallets ON public.profiles;
CREATE TRIGGER on_profile_created_create_wallets
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.create_default_wallets();

COMMIT;
