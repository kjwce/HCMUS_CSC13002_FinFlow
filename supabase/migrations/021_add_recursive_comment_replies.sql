-- Recursive Community replies + likes on comments.
-- Existing top-level comments remain valid because parent_comment_id is NULL.

ALTER TABLE public.community_comments
  ADD COLUMN IF NOT EXISTS parent_comment_id UUID
    REFERENCES public.community_comments(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.community_comments
  DROP CONSTRAINT IF EXISTS community_comments_likes_count_check;
ALTER TABLE public.community_comments
  ADD CONSTRAINT community_comments_likes_count_check
  CHECK (likes_count >= 0);

CREATE INDEX IF NOT EXISTS idx_community_comments_thread
  ON public.community_comments(post_id, parent_comment_id, created_at);

-- A parent cannot be moved after creation. On insert, requiring an existing
-- parent from the same post also prevents self references and cycles while
-- still allowing an arbitrary number of reply levels.
CREATE OR REPLACE FUNCTION public.community_validate_comment_parent()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  parent_post_id UUID;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.parent_comment_id IS DISTINCT FROM OLD.parent_comment_id THEN
    RAISE EXCEPTION 'A comment cannot be moved to another thread';
  END IF;

  IF NEW.parent_comment_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.parent_comment_id = NEW.id THEN
    RAISE EXCEPTION 'A comment cannot reply to itself';
  END IF;

  SELECT post_id INTO parent_post_id
  FROM public.community_comments
  WHERE id = NEW.parent_comment_id;

  IF parent_post_id IS NULL THEN
    RAISE EXCEPTION 'The parent comment does not exist';
  END IF;

  IF parent_post_id <> NEW.post_id THEN
    RAISE EXCEPTION 'A reply must belong to the same post as its parent';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_validate_comment_parent
  ON public.community_comments;
CREATE TRIGGER trg_community_validate_comment_parent
BEFORE INSERT OR UPDATE OF parent_comment_id, post_id
ON public.community_comments
FOR EACH ROW EXECUTE FUNCTION public.community_validate_comment_parent();

CREATE TABLE IF NOT EXISTS public.community_comment_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL
    REFERENCES public.community_comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_comment_likes_comment
  ON public.community_comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_community_comment_likes_user
  ON public.community_comment_likes(user_id);

ALTER TABLE public.community_comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "everyone_read_comment_likes"
  ON public.community_comment_likes;
DROP POLICY IF EXISTS "users_insert_own_comment_likes"
  ON public.community_comment_likes;
DROP POLICY IF EXISTS "users_delete_own_comment_likes"
  ON public.community_comment_likes;

CREATE POLICY "everyone_read_comment_likes"
  ON public.community_comment_likes
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "users_insert_own_comment_likes"
  ON public.community_comment_likes
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_delete_own_comment_likes"
  ON public.community_comment_likes
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE
  ON public.community_comment_likes TO authenticated;

CREATE OR REPLACE FUNCTION public.community_adjust_comment_likes_count()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_comments
    SET likes_count = likes_count + 1
    WHERE id = NEW.comment_id;
    RETURN NEW;
  END IF;

  UPDATE public.community_comments
  SET likes_count = GREATEST(likes_count - 1, 0)
  WHERE id = OLD.comment_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_comment_likes_count
  ON public.community_comment_likes;
CREATE TRIGGER trg_community_comment_likes_count
AFTER INSERT OR DELETE ON public.community_comment_likes
FOR EACH ROW EXECUTE FUNCTION public.community_adjust_comment_likes_count();

-- Repair likes_count if this migration is re-run after data already exists.
UPDATE public.community_comments comment
SET likes_count = (
  SELECT COUNT(*)::INTEGER
  FROM public.community_comment_likes liked
  WHERE liked.comment_id = comment.id
);

-- Replace the old broad comment notification trigger. A root comment notifies
-- the post owner; a reply notifies the author of its direct parent.
CREATE OR REPLACE FUNCTION public.community_notify_comment_activity()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recipient_id UUID;
  activity_type TEXT;
BEGIN
  IF NEW.parent_comment_id IS NULL THEN
    SELECT user_id INTO recipient_id
    FROM public.community_posts
    WHERE id = NEW.post_id;
    activity_type := 'comment';
  ELSE
    SELECT user_id INTO recipient_id
    FROM public.community_comments
    WHERE id = NEW.parent_comment_id;
    activity_type := 'comment_reply';
  END IF;

  IF recipient_id IS NOT NULL AND recipient_id <> NEW.user_id THEN
    INSERT INTO public.community_notifications (
      user_id, actor_id, post_id, comment_id, type, is_read, created_at
    ) VALUES (
      recipient_id, NEW.user_id, NEW.post_id, NEW.id,
      activity_type, false, NEW.created_at
    )
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.community_notify_comment_like_activity()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recipient_id UUID;
  related_post_id UUID;
BEGIN
  SELECT user_id, post_id INTO recipient_id, related_post_id
  FROM public.community_comments
  WHERE id = NEW.comment_id;

  IF recipient_id IS NOT NULL AND recipient_id <> NEW.user_id THEN
    INSERT INTO public.community_notifications (
      user_id, actor_id, post_id, comment_id, type, is_read, created_at
    ) VALUES (
      recipient_id, NEW.user_id, related_post_id, NEW.comment_id,
      'comment_like', false, NEW.created_at
    )
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_notify_comment_like
  ON public.community_comment_likes;
CREATE TRIGGER trg_community_notify_comment_like
AFTER INSERT ON public.community_comment_likes
FOR EACH ROW
EXECUTE FUNCTION public.community_notify_comment_like_activity();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'community_comment_likes'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.community_comment_likes;
  END IF;
END
$$;
