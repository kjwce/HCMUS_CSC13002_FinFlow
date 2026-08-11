-- Some early/manual FinFlow databases created saving-goal money columns as
-- INTEGER (int4). VND targets can legitimately exceed int4's 2,147,483,647
-- limit, so normalize them to BIGINT without changing existing values.
BEGIN;

ALTER TABLE public.goals
  ALTER COLUMN target_amount TYPE BIGINT
  USING target_amount::BIGINT;

ALTER TABLE public.goal_fund_entries
  ALTER COLUMN amount TYPE BIGINT
  USING amount::BIGINT;

COMMIT;
