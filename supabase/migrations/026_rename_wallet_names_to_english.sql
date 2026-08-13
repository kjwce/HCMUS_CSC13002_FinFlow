-- Rename the two system wallet display names to English so the UI and the
-- stored `name` stay consistent with the `type` enum (cash / transfer).
-- The `type` column is untouched (still 'cash' / 'transfer').

BEGIN;

-- 1. Update existing rows created before this migration.
UPDATE public.wallets
SET name = CASE
  WHEN type = 'cash' THEN 'Cash'
  WHEN type = 'transfer' THEN 'Transfer'
  ELSE name
END
WHERE name IN ('Tiền mặt', 'Chuyển khoản');

-- 2. New profiles must receive English names too — recreate the trigger used
--    by migration 019 so signups after this point create Cash / Transfer.
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
      'wallet_cash_' || replace(NEW.id::TEXT, '-', ''), NEW.id, 'Cash',
      'assets/logos/ewallets/cash.png', '#4CAF50', 'cash', 0
    ),
    (
      'wallet_transfer_' || replace(NEW.id::TEXT, '-', ''), NEW.id,
      'Transfer', 'assets/logos/ewallets/other.png', '#2878D0',
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
