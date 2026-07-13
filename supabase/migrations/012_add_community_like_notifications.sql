-- Notify a post owner when another account likes the post.
CREATE OR REPLACE FUNCTION public.community_notify_like_activity()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  owner_id uuid;
BEGIN
  SELECT user_id INTO owner_id
  FROM community_posts
  WHERE id = NEW.post_id;

  IF owner_id IS NOT NULL AND owner_id <> NEW.user_id THEN
    INSERT INTO community_notifications (
      user_id, actor_id, post_id, type, is_read, created_at
    ) VALUES (
      owner_id, NEW.user_id, NEW.post_id, 'like', false, NEW.created_at
    )
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_community_notify_like ON public.community_likes;
CREATE TRIGGER trg_community_notify_like
AFTER INSERT ON public.community_likes
FOR EACH ROW EXECUTE FUNCTION public.community_notify_like_activity();

-- Preserve notifications for likes that existed before this trigger.
INSERT INTO public.community_notifications (
  user_id, actor_id, post_id, type, is_read, created_at
)
SELECT post.user_id, liked.user_id, liked.post_id, 'like', false, liked.created_at
FROM public.community_likes liked
JOIN public.community_posts post ON post.id = liked.post_id
WHERE post.user_id <> liked.user_id
ON CONFLICT DO NOTHING;
