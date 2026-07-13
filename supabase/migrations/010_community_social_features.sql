-- =============================================================================
-- FULL Community migration — tự tạo community_posts nếu chưa có
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Tạo community_posts nếu chưa tồn tại
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  is_spoiler BOOLEAN NOT NULL DEFAULT false,
  category TEXT NOT NULL DEFAULT 'General',
  likes_count INTEGER NOT NULL DEFAULT 0,
  comments_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Nếu bảng đã tồn tại (từ migration 001), chạy thêm các cột còn thiếu
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General',
  ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_spoiler BOOLEAN NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- 1. Likes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

-- ---------------------------------------------------------------------------
-- 2. Saves (bookmarks)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

-- ---------------------------------------------------------------------------
-- 3. Comments
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
-- 4. Report bài post
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_post_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, reporter_id)
);

-- ---------------------------------------------------------------------------
-- 5. Report bình luận
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_comment_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES community_comments(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (comment_id, reporter_id)
);

-- ---------------------------------------------------------------------------
-- 6. Thông báo tương tác
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES community_comments(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 7. Media đính kèm bài post
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS community_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  media_type TEXT NOT NULL DEFAULT 'image',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 8. Triggers — tự động cập nhật số lượng like/comment
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
-- 9. View community_authors
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW community_authors WITH (security_invoker = false) AS
  SELECT id, full_name, avatar_url FROM profiles;

GRANT SELECT ON community_authors TO authenticated;

-- ---------------------------------------------------------------------------
-- 10. Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_community_posts_created
  ON community_posts(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_category
  ON community_posts(category);

CREATE INDEX IF NOT EXISTS idx_community_posts_user
  ON community_posts(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_likes_post
  ON community_likes(post_id);

CREATE INDEX IF NOT EXISTS idx_community_likes_user
  ON community_likes(user_id, post_id);

CREATE INDEX IF NOT EXISTS idx_community_saves_user
  ON community_saves(user_id, post_id);

CREATE INDEX IF NOT EXISTS idx_community_comments_post
  ON community_comments(post_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_community_notifications_user
  ON community_notifications(user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_media_post
  ON community_media(post_id);

-- ---------------------------------------------------------------------------
-- 11. RLS — community_posts
-- ---------------------------------------------------------------------------
ALTER TABLE community_posts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 12. RLS — community_likes
-- ---------------------------------------------------------------------------
ALTER TABLE community_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_read_likes"
  ON community_likes FOR SELECT
  USING (true);

CREATE POLICY "users_insert_own_likes"
  ON community_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_likes"
  ON community_likes FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 13. RLS — community_saves
-- ---------------------------------------------------------------------------
ALTER TABLE community_saves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_read_own_saves"
  ON community_saves FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_saves"
  ON community_saves FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_saves"
  ON community_saves FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 14. RLS — community_comments
-- ---------------------------------------------------------------------------
ALTER TABLE community_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_read_comments"
  ON community_comments FOR SELECT
  USING (true);

CREATE POLICY "users_insert_own_comments"
  ON community_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_comments"
  ON community_comments FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 15. RLS — community_post_reports
-- ---------------------------------------------------------------------------
ALTER TABLE community_post_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_own_reports"
  ON community_post_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "users_read_own_reports"
  ON community_post_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------------
-- 16. RLS — community_comment_reports
-- ---------------------------------------------------------------------------
ALTER TABLE community_comment_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_insert_own_comment_reports"
  ON community_comment_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "users_read_own_comment_reports"
  ON community_comment_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------------
-- 17. RLS — community_notifications
-- ---------------------------------------------------------------------------
ALTER TABLE community_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_read_own_notifications"
  ON community_notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "users_update_own_notifications"
  ON community_notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 18. RLS — community_media
-- ---------------------------------------------------------------------------
ALTER TABLE community_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "everyone_read_media"
  ON community_media FOR SELECT
  USING (true);

CREATE POLICY "users_insert_own_media"
  ON community_media FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_media"
  ON community_media FOR DELETE
  USING (auth.uid() = user_id);
