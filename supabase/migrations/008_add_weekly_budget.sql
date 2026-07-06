-- Add weekly budget to profiles for weekly spending progress.
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS weekly_budget BIGINT NOT NULL DEFAULT 0;
