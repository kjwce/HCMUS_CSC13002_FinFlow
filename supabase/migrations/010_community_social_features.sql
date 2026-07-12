-- Community social features: categories, likes, saves, comments.

-- ---------------------------------------------------------------------------
-- Extend community_posts
-- ---------------------------------------------------------------------------
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General',
  ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- Likes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Saves (bookmarks)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Comments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Keep denormalized counters in sync
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION community_adjust_likes_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE community_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE community_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_community_likes_count ON community_likes;
CREATE TRIGGER trg_community_likes_count
  AFTER INSERT OR DELETE ON community_likes
  FOR EACH ROW EXECUTE FUNCTION community_adjust_likes_count();

CREATE OR REPLACE FUNCTION community_adjust_comments_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE community_posts SET comments_count = GREATEST(comments_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_community_comments_count ON community_comments;
CREATE TRIGGER trg_community_comments_count
  AFTER INSERT OR DELETE ON community_comments
  FOR EACH ROW EXECUTE FUNCTION community_adjust_comments_count();

-- ---------------------------------------------------------------------------
-- Public, minimal author info for community screens.
-- profiles itself is locked to "own row only", so posts/comments authored by
-- other users are exposed through this SECURITY DEFINER view instead of
-- opening up the whole profiles table.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW community_authors WITH (security_invoker = false) AS
  SELECT id, full_name, avatar_url FROM profiles;

GRANT SELECT ON community_authors TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_read_likes"
  ON community_likes FOR SELECT
  USING (true);

CREATE POLICY "users_insert_own_likes"
  ON community_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_likes"
  ON community_likes FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "users_read_own_saves"
  ON community_saves FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_saves"
  ON community_saves FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_saves"
  ON community_saves FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "everyone_read_comments"
  ON community_comments FOR SELECT
  USING (true);

CREATE POLICY "users_insert_own_comments"
  ON community_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_comments"
  ON community_comments FOR DELETE
  USING (auth.uid() = user_id);
