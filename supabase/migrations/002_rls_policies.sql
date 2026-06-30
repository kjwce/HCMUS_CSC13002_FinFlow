-- Enable Row Level Security on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update only their own profile
CREATE POLICY "users_read_own_profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "users_update_own_profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "users_insert_own_profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Transactions: users can CRUD only their own transactions
CREATE POLICY "users_read_own_transactions"
  ON transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_transactions"
  ON transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_transactions"
  ON transactions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_transactions"
  ON transactions FOR DELETE
  USING (auth.uid() = user_id);

-- Budgets: users can CRUD only their own budgets
CREATE POLICY "users_read_own_budgets"
  ON budgets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_budgets"
  ON budgets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_budgets"
  ON budgets FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_budgets"
  ON budgets FOR DELETE
  USING (auth.uid() = user_id);

-- Community posts: everyone can read, only own insert/update/delete
CREATE POLICY "everyone_read_posts"
  ON community_posts FOR SELECT
  USING (true);

CREATE POLICY "users_insert_own_posts"
  ON community_posts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_update_own_posts"
  ON community_posts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "users_delete_own_posts"
  ON community_posts FOR DELETE
  USING (auth.uid() = user_id);
