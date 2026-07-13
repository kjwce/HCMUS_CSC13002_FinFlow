-- Cross-account Community access and durable activity notifications.

-- Older Auth users may predate the profile trigger. Social tables reference
-- profiles(id), so repair those users before accepting likes/comments.
INSERT INTO public.profiles (id, full_name, email, created_at, budget_limit)
SELECT
  u.id,
  COALESCE(u.raw_user_meta_data ->> 'full_name', 'New FinFlow User'),
  COALESCE(u.email, ''),
  COALESCE(u.created_at, now()),
  5000000
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.community_posts
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'General',
  ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_spoiler BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.community_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.community_saves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.community_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_anonymous BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.community_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_id UUID REFERENCES public.community_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES public.community_comments(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE VIEW public.community_authors
WITH (security_invoker = false) AS
SELECT id, full_name, avatar_url FROM public.profiles;
GRANT SELECT ON public.community_authors TO authenticated;

-- Recreate the relevant policies idempotently so every authenticated user can
-- read the community and can mutate only rows carrying their own user id.
DROP POLICY IF EXISTS "everyone_read_posts" ON public.community_posts;
DROP POLICY IF EXISTS "users_insert_own_posts" ON public.community_posts;
DROP POLICY IF EXISTS "users_update_own_posts" ON public.community_posts;
DROP POLICY IF EXISTS "users_delete_own_posts" ON public.community_posts;
CREATE POLICY "everyone_read_posts" ON public.community_posts
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert_own_posts" ON public.community_posts
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_update_own_posts" ON public.community_posts
  FOR UPDATE TO authenticated USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_delete_own_posts" ON public.community_posts
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "everyone_read_likes" ON public.community_likes;
DROP POLICY IF EXISTS "users_insert_own_likes" ON public.community_likes;
DROP POLICY IF EXISTS "users_delete_own_likes" ON public.community_likes;
CREATE POLICY "everyone_read_likes" ON public.community_likes
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert_own_likes" ON public.community_likes
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_delete_own_likes" ON public.community_likes
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "everyone_read_comments" ON public.community_comments;
DROP POLICY IF EXISTS "users_insert_own_comments" ON public.community_comments;
DROP POLICY IF EXISTS "users_delete_own_comments" ON public.community_comments;
CREATE POLICY "everyone_read_comments" ON public.community_comments
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert_own_comments" ON public.community_comments
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_delete_own_comments" ON public.community_comments
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

ALTER TABLE public.community_saves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users_read_own_saves" ON public.community_saves;
DROP POLICY IF EXISTS "users_insert_own_saves" ON public.community_saves;
DROP POLICY IF EXISTS "users_delete_own_saves" ON public.community_saves;
CREATE POLICY "users_read_own_saves" ON public.community_saves
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "users_insert_own_saves" ON public.community_saves
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_delete_own_saves" ON public.community_saves
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

ALTER TABLE public.community_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users_read_own_notifications"
  ON public.community_notifications;
DROP POLICY IF EXISTS "users_update_own_notifications"
  ON public.community_notifications;
CREATE POLICY "users_read_own_notifications" ON public.community_notifications
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "users_update_own_notifications" ON public.community_notifications
  FOR UPDATE TO authenticated USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.community_adjust_likes_count()
RETURNS trigger SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE community_posts SET likes_count = likes_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  END IF;
  UPDATE community_posts SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_likes_count ON public.community_likes;
CREATE TRIGGER trg_community_likes_count
AFTER INSERT OR DELETE ON public.community_likes
FOR EACH ROW EXECUTE FUNCTION public.community_adjust_likes_count();

CREATE OR REPLACE FUNCTION public.community_adjust_comments_count()
RETURNS trigger SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE community_posts SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
  END IF;
  UPDATE community_posts SET comments_count = GREATEST(comments_count - 1, 0)
  WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_comments_count ON public.community_comments;
CREATE TRIGGER trg_community_comments_count
AFTER INSERT OR DELETE ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.community_adjust_comments_count();

-- One activity notification per recipient/event, including safe null comment
-- handling for post events.
CREATE UNIQUE INDEX IF NOT EXISTS uq_community_notification_activity
ON public.community_notifications (
  user_id,
  actor_id,
  type,
  post_id,
  COALESCE(comment_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

CREATE OR REPLACE FUNCTION public.community_notify_post_activity()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO community_notifications (
    user_id, actor_id, post_id, type, is_read, created_at
  )
  SELECT p.id, NEW.user_id, NEW.id, 'post', false, NEW.created_at
  FROM profiles p
  WHERE p.id <> NEW.user_id
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.community_notify_comment_activity()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO community_notifications (
    user_id, actor_id, post_id, comment_id, type, is_read, created_at
  )
  SELECT p.id, NEW.user_id, NEW.post_id, NEW.id, 'comment', false, NEW.created_at
  FROM profiles p
  WHERE p.id <> NEW.user_id
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_notify_post ON public.community_posts;
CREATE TRIGGER trg_community_notify_post
AFTER INSERT ON public.community_posts
FOR EACH ROW EXECUTE FUNCTION public.community_notify_post_activity();

DROP TRIGGER IF EXISTS trg_community_notify_comment ON public.community_comments;
CREATE TRIGGER trg_community_notify_comment
AFTER INSERT ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.community_notify_comment_activity();

-- Backfill all prior post/comment activity for existing accounts.
INSERT INTO public.community_notifications (
  user_id, actor_id, post_id, type, is_read, created_at
)
SELECT recipient.id, post.user_id, post.id, 'post', false, post.created_at
FROM public.profiles recipient
CROSS JOIN public.community_posts post
WHERE recipient.id <> post.user_id
ON CONFLICT DO NOTHING;

INSERT INTO public.community_notifications (
  user_id, actor_id, post_id, comment_id, type, is_read, created_at
)
SELECT recipient.id, comment.user_id, comment.post_id, comment.id,
       'comment', false, comment.created_at
FROM public.profiles recipient
CROSS JOIN public.community_comments comment
WHERE recipient.id <> comment.user_id
ON CONFLICT DO NOTHING;

-- A newly created profile receives the same historical activity immediately.
CREATE OR REPLACE FUNCTION public.community_backfill_new_profile_notifications()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO community_notifications (
    user_id, actor_id, post_id, type, is_read, created_at
  )
  SELECT NEW.id, post.user_id, post.id, 'post', false, post.created_at
  FROM community_posts post
  WHERE post.user_id <> NEW.id
  ON CONFLICT DO NOTHING;

  INSERT INTO community_notifications (
    user_id, actor_id, post_id, comment_id, type, is_read, created_at
  )
  SELECT NEW.id, comment.user_id, comment.post_id, comment.id,
         'comment', false, comment.created_at
  FROM community_comments comment
  WHERE comment.user_id <> NEW.id
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_backfill_new_profile ON public.profiles;
CREATE TRIGGER trg_community_backfill_new_profile
AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.community_backfill_new_profile_notifications();

-- Ensure Realtime can deliver cross-account inserts when the migration is
-- applied to projects where these tables were not added to the publication.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'community_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.community_notifications;
  END IF;
END $$;
