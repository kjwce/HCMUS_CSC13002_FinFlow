-- Add selected_category column to profiles for persisting
-- the user's chosen dynamic category in the goal summary card.
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS selected_category TEXT;
