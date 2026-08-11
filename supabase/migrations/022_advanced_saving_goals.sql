-- Advanced saving goals. Existing goals intentionally start with 0 VND:
-- balances are derived only from entries created after this migration.
BEGIN;

ALTER TABLE public.goals
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Other',
  ADD COLUMN IF NOT EXISTS target_date DATE,
  ADD COLUMN IF NOT EXISTS funding_method TEXT NOT NULL DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS auto_allocation_percent NUMERIC(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_protected BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS withdrawal_priority INTEGER NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS completion_behavior TEXT NOT NULL DEFAULT 'keep_available',
  ADD COLUMN IF NOT EXISTS redirect_goal_id TEXT REFERENCES public.goals(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS image_url TEXT;

DO $$ BEGIN
  ALTER TABLE public.budgets ADD CONSTRAINT budgets_positive_limit
    CHECK (limit_amount > 0) NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

UPDATE public.goals SET is_primary = is_active WHERE is_active;

DO $$ BEGIN
  ALTER TABLE public.goals ADD CONSTRAINT goals_positive_target CHECK (target_amount > 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.goals ADD CONSTRAINT goals_funding_method_check
    CHECK (funding_method IN ('manual', 'automatic'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.goals ADD CONSTRAINT goals_auto_percent_check
    CHECK (auto_allocation_percent >= 0 AND auto_allocation_percent <= 100);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.goals ADD CONSTRAINT goals_status_check
    CHECK (status IN ('active', 'completed', 'archived'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.goals ADD CONSTRAINT goals_completion_behavior_check
    CHECK (completion_behavior IN ('keep_available', 'redirect'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.goals ADD CONSTRAINT goals_redirect_not_self
    CHECK (redirect_goal_id IS NULL OR redirect_goal_id <> id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Preserve the most recent primary if legacy data had multiple active goals.
WITH ranked AS (
  SELECT id, row_number() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rank
  FROM public.goals WHERE is_primary
)
UPDATE public.goals g SET is_primary = false
FROM ranked r WHERE g.id = r.id AND r.rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS goals_one_primary_per_user
  ON public.goals(user_id) WHERE is_primary AND status = 'active';
CREATE INDEX IF NOT EXISTS goals_withdrawal_order
  ON public.goals(user_id, is_protected, withdrawal_priority, created_at);

CREATE TABLE IF NOT EXISTS public.goal_fund_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  goal_id TEXT NOT NULL REFERENCES public.goals(id) ON DELETE CASCADE,
  amount BIGINT NOT NULL CHECK (amount <> 0),
  entry_type TEXT NOT NULL,
  source_transaction_id TEXT REFERENCES public.transactions(id) ON DELETE CASCADE,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (entry_type IN ('initial', 'manual_allocation', 'automatic_allocation',
                        'manual_withdrawal', 'expense_withdrawal', 'completion_transfer'))
);

CREATE INDEX IF NOT EXISTS goal_fund_entries_goal_created
  ON public.goal_fund_entries(goal_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS goal_fund_entries_auto_once
  ON public.goal_fund_entries(goal_id, source_transaction_id, entry_type)
  WHERE source_transaction_id IS NOT NULL AND entry_type = 'automatic_allocation';

ALTER TABLE public.goal_fund_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users_read_own_goal_entries" ON public.goal_fund_entries;
CREATE POLICY "users_read_own_goal_entries" ON public.goal_fund_entries
  FOR SELECT USING (auth.uid() = user_id);
-- Writes go through SECURITY DEFINER functions so validation and invariants
-- cannot be bypassed by a client insert.

CREATE TABLE IF NOT EXISTS public.goal_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  expense_shortfall_policy TEXT NOT NULL DEFAULT 'ask_each_time',
  imported_transaction_policy TEXT NOT NULL DEFAULT 'auto_withdraw',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (expense_shortfall_policy IN ('ask_each_time', 'auto_withdraw')),
  CHECK (imported_transaction_policy = 'auto_withdraw')
);

ALTER TABLE public.goal_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users_read_own_goal_settings" ON public.goal_settings;
CREATE POLICY "users_read_own_goal_settings" ON public.goal_settings
  FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "users_insert_own_goal_settings" ON public.goal_settings;
CREATE POLICY "users_insert_own_goal_settings" ON public.goal_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "users_update_own_goal_settings" ON public.goal_settings;
CREATE POLICY "users_update_own_goal_settings" ON public.goal_settings
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.current_goal_allocation(p_goal_id TEXT)
RETURNS BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(SUM(e.amount), 0)::BIGINT
  FROM public.goal_fund_entries e
  WHERE e.goal_id = p_goal_id AND e.user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.available_for_goals()
RETURNS BIGINT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH actual AS (
    SELECT COALESCE((SELECT SUM(w.initial_balance) FROM public.wallets w
                     WHERE w.user_id = auth.uid()), 0)
         + COALESCE((SELECT SUM(t.amount) FROM public.transactions t
                     WHERE t.user_id = auth.uid()), 0) AS amount
  ), allocated AS (
    SELECT COALESCE(SUM(e.amount), 0) AS amount
    FROM public.goal_fund_entries e WHERE e.user_id = auth.uid()
  )
  SELECT GREATEST(actual.amount - allocated.amount, 0)::BIGINT
  FROM actual, allocated;
$$;

CREATE OR REPLACE FUNCTION public.allocate_goal_funds(
  p_goal_id TEXT, p_amount BIGINT, p_note TEXT DEFAULT NULL,
  p_entry_type TEXT DEFAULT 'manual_allocation', p_source_transaction_id TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_goal public.goals%ROWTYPE; v_current BIGINT; v_available BIGINT;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'ALLOCATION_MUST_BE_POSITIVE'; END IF;
  IF p_source_transaction_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.transactions
    WHERE id = p_source_transaction_id AND user_id = auth.uid()
  ) THEN RAISE EXCEPTION 'SOURCE_TRANSACTION_NOT_FOUND'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::TEXT));
  SELECT * INTO v_goal FROM public.goals
    WHERE id = p_goal_id AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_goal.status <> 'active' THEN RAISE EXCEPTION 'GOAL_NOT_AVAILABLE'; END IF;
  v_current := public.current_goal_allocation(p_goal_id);
  v_available := public.available_for_goals();
  IF p_amount > v_available THEN RAISE EXCEPTION 'AMOUNT_EXCEEDS_AVAILABLE'; END IF;
  IF p_amount > v_goal.target_amount - v_current THEN RAISE EXCEPTION 'AMOUNT_EXCEEDS_TARGET'; END IF;
  INSERT INTO public.goal_fund_entries(user_id, goal_id, amount, entry_type, source_transaction_id, note)
  VALUES (auth.uid(), p_goal_id, p_amount, p_entry_type, p_source_transaction_id, p_note);
  v_current := v_current + p_amount;
  IF v_current >= v_goal.target_amount THEN
    UPDATE public.goals SET status = 'completed', is_primary = false WHERE id = p_goal_id;
  END IF;
  RETURN v_current;
END; $$;

CREATE OR REPLACE FUNCTION public.withdraw_goal_funds(
  p_goal_id TEXT, p_amount BIGINT, p_note TEXT DEFAULT NULL,
  p_entry_type TEXT DEFAULT 'manual_withdrawal'
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_current BIGINT;
BEGIN
  IF p_amount <= 0 THEN RAISE EXCEPTION 'WITHDRAWAL_MUST_BE_POSITIVE'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::TEXT));
  IF NOT EXISTS (SELECT 1 FROM public.goals WHERE id = p_goal_id AND user_id = auth.uid())
    THEN RAISE EXCEPTION 'GOAL_NOT_FOUND'; END IF;
  v_current := public.current_goal_allocation(p_goal_id);
  IF p_amount > v_current THEN RAISE EXCEPTION 'AMOUNT_EXCEEDS_ALLOCATION'; END IF;
  INSERT INTO public.goal_fund_entries(user_id, goal_id, amount, entry_type, note)
  VALUES (auth.uid(), p_goal_id, -p_amount, p_entry_type, p_note);
  UPDATE public.goals SET status = 'active' WHERE id = p_goal_id AND status = 'completed';
  RETURN v_current - p_amount;
END; $$;

CREATE OR REPLACE FUNCTION public.validate_goal_auto_percentages()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_total NUMERIC;
BEGIN
  IF NEW.redirect_goal_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.goals target
    WHERE target.id = NEW.redirect_goal_id AND target.user_id = NEW.user_id
  ) THEN
    RAISE EXCEPTION 'REDIRECT_GOAL_MUST_BELONG_TO_USER';
  END IF;
  SELECT COALESCE(SUM(auto_allocation_percent), 0) INTO v_total
  FROM public.goals WHERE user_id = NEW.user_id AND id <> NEW.id
    AND funding_method = 'automatic'
    AND (status = 'active' OR (status = 'completed' AND completion_behavior = 'redirect'));
  IF NEW.funding_method = 'automatic'
     AND (NEW.status = 'active' OR (NEW.status = 'completed' AND NEW.completion_behavior = 'redirect')) THEN
    v_total := v_total + NEW.auto_allocation_percent;
  END IF;
  IF v_total > 100 THEN RAISE EXCEPTION 'AUTO_PERCENT_TOTAL_EXCEEDS_100'; END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS validate_goal_auto_percentages ON public.goals;
CREATE TRIGGER validate_goal_auto_percentages BEFORE INSERT OR UPDATE ON public.goals
  FOR EACH ROW EXECUTE FUNCTION public.validate_goal_auto_percentages();

CREATE OR REPLACE FUNCTION public.enforce_goal_actual_balance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID; v_balance BIGINT; v_allocated BIGINT;
BEGIN
  v_user_id := COALESCE(NEW.user_id, OLD.user_id);
  SELECT COALESCE((SELECT SUM(initial_balance) FROM public.wallets WHERE user_id = v_user_id), 0)
       + COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = v_user_id), 0)
    INTO v_balance;
  SELECT COALESCE(SUM(amount), 0) INTO v_allocated
    FROM public.goal_fund_entries WHERE user_id = v_user_id;
  IF v_allocated > GREATEST(v_balance, 0) THEN
    RAISE EXCEPTION 'GOAL_ALLOCATIONS_EXCEED_ACTUAL_BALANCE';
  END IF;
  RETURN NULL;
END; $$;

DROP TRIGGER IF EXISTS enforce_goal_balance_after_transaction ON public.transactions;
CREATE CONSTRAINT TRIGGER enforce_goal_balance_after_transaction
  AFTER INSERT OR UPDATE OR DELETE ON public.transactions
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.enforce_goal_actual_balance();
DROP TRIGGER IF EXISTS enforce_goal_balance_after_wallet ON public.wallets;
CREATE CONSTRAINT TRIGGER enforce_goal_balance_after_wallet
  AFTER INSERT OR UPDATE OR DELETE ON public.wallets
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
  EXECUTE FUNCTION public.enforce_goal_actual_balance();

-- Saves a transaction and adjusts virtual goal allocations in the same DB
-- transaction. This keeps total allocation <= the user's actual balance.
CREATE OR REPLACE FUNCTION public.create_transaction_with_goal_handling(
  p_id TEXT,
  p_name TEXT,
  p_category TEXT,
  p_amount BIGINT,
  p_date TIMESTAMPTZ,
  p_wallet_id TEXT DEFAULT NULL,
  p_is_imported BOOLEAN DEFAULT false,
  p_withdrawals JSONB DEFAULT NULL
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_balance BIGINT;
  v_allocated BIGINT;
  v_shortfall BIGINT;
  v_take BIGINT;
  v_goal_balance BIGINT;
  v_policy TEXT := 'ask_each_time';
  v_item JSONB;
  v_goal public.goals%ROWTYPE;
  v_redirect RECORD;
  v_auto_amount BIGINT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF p_amount = 0 THEN RAISE EXCEPTION 'TRANSACTION_AMOUNT_MUST_NOT_BE_ZERO'; END IF;
  IF p_wallet_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.wallets WHERE id = p_wallet_id AND user_id = auth.uid()
  ) THEN RAISE EXCEPTION 'WALLET_NOT_FOUND'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::TEXT));

  SELECT COALESCE((SELECT SUM(initial_balance) FROM public.wallets WHERE user_id = auth.uid()), 0)
       + COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = auth.uid()), 0)
    INTO v_balance;
  SELECT COALESCE(SUM(amount), 0) INTO v_allocated
    FROM public.goal_fund_entries WHERE user_id = auth.uid();

  IF p_amount < 0 THEN
    v_shortfall := GREATEST(v_allocated - (v_balance + p_amount), 0);
    IF v_shortfall > 0 THEN
      SELECT COALESCE(expense_shortfall_policy, 'ask_each_time') INTO v_policy
        FROM public.goal_settings WHERE user_id = auth.uid();
      IF p_is_imported THEN v_policy := 'auto_withdraw'; END IF;

      IF v_policy = 'ask_each_time' THEN
        IF p_withdrawals IS NULL OR jsonb_array_length(p_withdrawals) = 0 THEN
          RAISE EXCEPTION 'GOAL_SELECTION_REQUIRED:%', v_shortfall;
        END IF;
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_withdrawals) LOOP
          SELECT * INTO v_goal FROM public.goals
            WHERE id = v_item->>'goal_id' AND user_id = auth.uid() FOR UPDATE;
          IF NOT FOUND THEN RAISE EXCEPTION 'GOAL_NOT_FOUND'; END IF;
          v_goal_balance := public.current_goal_allocation(v_goal.id);
          v_take := LEAST(
            COALESCE((v_item->>'amount')::BIGINT, 0),
            v_goal_balance,
            v_shortfall
          );
          IF v_take > 0 THEN
            INSERT INTO public.goal_fund_entries(user_id, goal_id, amount, entry_type, note)
            VALUES (auth.uid(), v_goal.id, -v_take, 'expense_withdrawal', p_name);
            v_shortfall := v_shortfall - v_take;
          END IF;
          EXIT WHEN v_shortfall = 0;
        END LOOP;
        IF v_shortfall > 0 THEN RAISE EXCEPTION 'SELECTED_GOALS_DO_NOT_COVER_SHORTFALL:%', v_shortfall; END IF;
      ELSE
        FOR v_goal IN
          SELECT g.* FROM public.goals g
          WHERE g.user_id = auth.uid() AND g.status = 'active' AND NOT g.is_protected
          ORDER BY g.withdrawal_priority ASC, g.created_at ASC
        LOOP
          v_goal_balance := public.current_goal_allocation(v_goal.id);
          v_take := LEAST(v_goal_balance, v_shortfall);
          IF v_take > 0 THEN
            INSERT INTO public.goal_fund_entries(user_id, goal_id, amount, entry_type, note)
            VALUES (auth.uid(), v_goal.id, -v_take, 'expense_withdrawal', p_name);
            v_shortfall := v_shortfall - v_take;
          END IF;
          EXIT WHEN v_shortfall = 0;
        END LOOP;
        IF v_shortfall > 0 THEN RAISE EXCEPTION 'PROTECTED_GOALS_BLOCK_SHORTFALL:%', v_shortfall; END IF;
      END IF;
    END IF;
  END IF;

  INSERT INTO public.transactions(id, user_id, name, category, amount, date, wallet_id)
  VALUES (p_id, auth.uid(), p_name, p_category, p_amount, p_date, p_wallet_id);

  IF p_amount > 0 THEN
    FOR v_goal IN
      SELECT g.* FROM public.goals g
      WHERE g.user_id = auth.uid() AND g.status = 'active'
        AND g.funding_method = 'automatic' AND g.auto_allocation_percent > 0
      ORDER BY g.created_at ASC
    LOOP
      v_goal_balance := public.current_goal_allocation(v_goal.id);
      v_auto_amount := LEAST(
        FLOOR(p_amount * v_goal.auto_allocation_percent / 100.0)::BIGINT,
        v_goal.target_amount - v_goal_balance,
        public.available_for_goals()
      );
      IF v_auto_amount > 0 THEN
        INSERT INTO public.goal_fund_entries(
          user_id, goal_id, amount, entry_type, source_transaction_id, note
        ) VALUES (
          auth.uid(), v_goal.id, v_auto_amount, 'automatic_allocation', p_id, p_name
        );
        IF v_goal_balance + v_auto_amount >= v_goal.target_amount THEN
          UPDATE public.goals SET status = 'completed', is_primary = false WHERE id = v_goal.id;
        END IF;
      END IF;
    END LOOP;

    -- A completed goal can keep its former percentage flowing to a selected
    -- next goal without asking again at completion time.
    FOR v_redirect IN
      SELECT target.id, target.target_amount,
             completed.auto_allocation_percent AS redirect_percent
      FROM public.goals completed
      JOIN public.goals target ON target.id = completed.redirect_goal_id
      WHERE completed.user_id = auth.uid()
        AND completed.status = 'completed'
        AND completed.funding_method = 'automatic'
        AND completed.completion_behavior = 'redirect'
        AND completed.auto_allocation_percent > 0
        AND NOT EXISTS (
          SELECT 1 FROM public.goal_fund_entries current_income
          WHERE current_income.goal_id = completed.id
            AND current_income.source_transaction_id = p_id
            AND current_income.entry_type = 'automatic_allocation'
        )
        AND target.user_id = auth.uid() AND target.status = 'active'
      ORDER BY completed.created_at ASC
    LOOP
      v_goal_balance := public.current_goal_allocation(v_redirect.id);
      v_auto_amount := LEAST(
        FLOOR(p_amount * v_redirect.redirect_percent / 100.0)::BIGINT,
        v_redirect.target_amount - v_goal_balance,
        public.available_for_goals()
      );
      IF v_auto_amount > 0 THEN
        INSERT INTO public.goal_fund_entries(
          user_id, goal_id, amount, entry_type, source_transaction_id, note
        ) VALUES (
          auth.uid(), v_redirect.id, v_auto_amount, 'completion_transfer', p_id, p_name
        );
        IF v_goal_balance + v_auto_amount >= v_redirect.target_amount THEN
          UPDATE public.goals SET status = 'completed', is_primary = false WHERE id = v_redirect.id;
        END IF;
      END IF;
    END LOOP;
  END IF;
  RETURN p_id;
END; $$;

CREATE OR REPLACE FUNCTION public.update_transaction_with_goal_handling(
  p_id TEXT,
  p_name TEXT,
  p_category TEXT,
  p_amount BIGINT,
  p_date TIMESTAMPTZ,
  p_wallet_id TEXT DEFAULT NULL,
  p_withdrawals JSONB DEFAULT NULL
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old public.transactions%ROWTYPE;
  v_goal public.goals%ROWTYPE;
  v_redirect RECORD;
  v_item JSONB;
  v_balance BIGINT;
  v_allocated BIGINT;
  v_shortfall BIGINT;
  v_goal_balance BIGINT;
  v_take BIGINT;
  v_auto_amount BIGINT;
  v_policy TEXT := 'ask_each_time';
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'NOT_AUTHENTICATED'; END IF;
  IF p_amount = 0 THEN RAISE EXCEPTION 'TRANSACTION_AMOUNT_MUST_NOT_BE_ZERO'; END IF;
  IF p_wallet_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.wallets WHERE id = p_wallet_id AND user_id = auth.uid()
  ) THEN RAISE EXCEPTION 'WALLET_NOT_FOUND'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::TEXT));
  SELECT * INTO v_old FROM public.transactions
    WHERE id = p_id AND user_id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TRANSACTION_NOT_FOUND'; END IF;

  DELETE FROM public.goal_fund_entries
    WHERE user_id = auth.uid() AND source_transaction_id = p_id
      AND entry_type IN ('automatic_allocation', 'completion_transfer');
  UPDATE public.goals g SET status = 'active'
    WHERE g.user_id = auth.uid() AND g.status = 'completed'
      AND public.current_goal_allocation(g.id) < g.target_amount;

  UPDATE public.transactions SET
    name = p_name, category = p_category, amount = p_amount,
    date = p_date, wallet_id = p_wallet_id
  WHERE id = p_id AND user_id = auth.uid();

  SELECT COALESCE((SELECT SUM(initial_balance) FROM public.wallets WHERE user_id = auth.uid()), 0)
       + COALESCE((SELECT SUM(amount) FROM public.transactions WHERE user_id = auth.uid()), 0)
    INTO v_balance;
  SELECT COALESCE(SUM(amount), 0) INTO v_allocated
    FROM public.goal_fund_entries WHERE user_id = auth.uid();
  v_shortfall := GREATEST(v_allocated - v_balance, 0);

  IF v_shortfall > 0 THEN
    SELECT expense_shortfall_policy INTO v_policy
      FROM public.goal_settings WHERE user_id = auth.uid();
    IF v_policy = 'ask_each_time' THEN
      IF p_withdrawals IS NULL OR jsonb_array_length(p_withdrawals) = 0 THEN
        RAISE EXCEPTION 'GOAL_SELECTION_REQUIRED:%', v_shortfall;
      END IF;
      FOR v_item IN SELECT * FROM jsonb_array_elements(p_withdrawals) LOOP
        SELECT * INTO v_goal FROM public.goals
          WHERE id = v_item->>'goal_id' AND user_id = auth.uid() FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'GOAL_NOT_FOUND'; END IF;
        v_goal_balance := public.current_goal_allocation(v_goal.id);
        v_take := LEAST(COALESCE((v_item->>'amount')::BIGINT, 0), v_goal_balance, v_shortfall);
        IF v_take > 0 THEN
          INSERT INTO public.goal_fund_entries(user_id, goal_id, amount, entry_type, note)
          VALUES (auth.uid(), v_goal.id, -v_take, 'expense_withdrawal', p_name);
          v_shortfall := v_shortfall - v_take;
        END IF;
        EXIT WHEN v_shortfall = 0;
      END LOOP;
    ELSE
      FOR v_goal IN
        SELECT g.* FROM public.goals g
        WHERE g.user_id = auth.uid() AND g.status = 'active' AND NOT g.is_protected
        ORDER BY g.withdrawal_priority ASC, g.created_at ASC
      LOOP
        v_goal_balance := public.current_goal_allocation(v_goal.id);
        v_take := LEAST(v_goal_balance, v_shortfall);
        IF v_take > 0 THEN
          INSERT INTO public.goal_fund_entries(user_id, goal_id, amount, entry_type, note)
          VALUES (auth.uid(), v_goal.id, -v_take, 'expense_withdrawal', p_name);
          v_shortfall := v_shortfall - v_take;
        END IF;
        EXIT WHEN v_shortfall = 0;
      END LOOP;
    END IF;
    IF v_shortfall > 0 THEN RAISE EXCEPTION 'GOAL_WITHDRAWALS_DO_NOT_COVER_SHORTFALL:%', v_shortfall; END IF;
  END IF;

  IF p_amount > 0 THEN
    FOR v_goal IN
      SELECT g.* FROM public.goals g
      WHERE g.user_id = auth.uid() AND g.status = 'active'
        AND g.funding_method = 'automatic' AND g.auto_allocation_percent > 0
      ORDER BY g.created_at ASC
    LOOP
      v_goal_balance := public.current_goal_allocation(v_goal.id);
      v_auto_amount := LEAST(
        FLOOR(p_amount * v_goal.auto_allocation_percent / 100.0)::BIGINT,
        v_goal.target_amount - v_goal_balance,
        public.available_for_goals()
      );
      IF v_auto_amount > 0 THEN
        INSERT INTO public.goal_fund_entries(
          user_id, goal_id, amount, entry_type, source_transaction_id, note
        ) VALUES (
          auth.uid(), v_goal.id, v_auto_amount, 'automatic_allocation', p_id, p_name
        );
        IF v_goal_balance + v_auto_amount >= v_goal.target_amount THEN
          UPDATE public.goals SET status = 'completed', is_primary = false WHERE id = v_goal.id;
        END IF;
      END IF;
    END LOOP;
    FOR v_redirect IN
      SELECT target.id, target.target_amount,
             completed.auto_allocation_percent AS redirect_percent
      FROM public.goals completed
      JOIN public.goals target ON target.id = completed.redirect_goal_id
      WHERE completed.user_id = auth.uid()
        AND completed.status = 'completed'
        AND completed.funding_method = 'automatic'
        AND completed.completion_behavior = 'redirect'
        AND completed.auto_allocation_percent > 0
        AND NOT EXISTS (
          SELECT 1 FROM public.goal_fund_entries current_income
          WHERE current_income.goal_id = completed.id
            AND current_income.source_transaction_id = p_id
            AND current_income.entry_type = 'automatic_allocation'
        )
        AND target.user_id = auth.uid() AND target.status = 'active'
      ORDER BY completed.created_at ASC
    LOOP
      v_goal_balance := public.current_goal_allocation(v_redirect.id);
      v_auto_amount := LEAST(
        FLOOR(p_amount * v_redirect.redirect_percent / 100.0)::BIGINT,
        v_redirect.target_amount - v_goal_balance,
        public.available_for_goals()
      );
      IF v_auto_amount > 0 THEN
        INSERT INTO public.goal_fund_entries(
          user_id, goal_id, amount, entry_type, source_transaction_id, note
        ) VALUES (
          auth.uid(), v_redirect.id, v_auto_amount, 'completion_transfer', p_id, p_name
        );
        IF v_goal_balance + v_auto_amount >= v_redirect.target_amount THEN
          UPDATE public.goals SET status = 'completed', is_primary = false WHERE id = v_redirect.id;
        END IF;
      END IF;
    END LOOP;
  END IF;
  RETURN p_id;
END; $$;

COMMIT;
