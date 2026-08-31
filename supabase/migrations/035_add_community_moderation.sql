-- Community moderation for the standalone FinFlow admin console.
ALTER TABLE public.community_posts
  ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

UPDATE public.community_posts
SET moderation_status = 'approved'
WHERE moderation_status = 'pending';

ALTER TABLE public.community_posts
  DROP CONSTRAINT IF EXISTS community_posts_moderation_status_check;
ALTER TABLE public.community_posts
  ADD CONSTRAINT community_posts_moderation_status_check
  CHECK (moderation_status IN ('pending', 'approved', 'rejected'));

CREATE INDEX IF NOT EXISTS idx_community_posts_moderation_queue
  ON public.community_posts(moderation_status, created_at DESC);

CREATE OR REPLACE FUNCTION public.is_community_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'role' = 'community_admin',
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_community_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_community_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_community_moderation_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF public.is_community_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.moderation_status := 'pending';
    NEW.reviewed_by := NULL;
    NEW.reviewed_at := NULL;
    NEW.rejection_reason := NULL;
  ELSE
    NEW.moderation_status := OLD.moderation_status;
    NEW.reviewed_by := OLD.reviewed_by;
    NEW.reviewed_at := OLD.reviewed_at;
    NEW.rejection_reason := OLD.rejection_reason;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_community_moderation_fields
  ON public.community_posts;
CREATE TRIGGER trg_protect_community_moderation_fields
BEFORE INSERT OR UPDATE ON public.community_posts
FOR EACH ROW EXECUTE FUNCTION public.protect_community_moderation_fields();

DROP POLICY IF EXISTS "everyone_read_posts" ON public.community_posts;
DROP POLICY IF EXISTS "authenticated_read_posts" ON public.community_posts;
DROP POLICY IF EXISTS "moderated_read_posts" ON public.community_posts;
CREATE POLICY "moderated_read_posts"
  ON public.community_posts FOR SELECT TO authenticated
  USING (
    moderation_status = 'approved'
    OR auth.uid() = user_id
    OR public.is_community_admin()
  );

DROP POLICY IF EXISTS "admins_read_post_reports"
  ON public.community_post_reports;
CREATE POLICY "admins_read_post_reports"
  ON public.community_post_reports FOR SELECT TO authenticated
  USING (public.is_community_admin());

DROP POLICY IF EXISTS "admins_read_profiles" ON public.profiles;
CREATE POLICY "admins_read_profiles"
  ON public.profiles FOR SELECT TO authenticated
  USING (public.is_community_admin());

CREATE OR REPLACE FUNCTION public.moderate_community_post(
  target_post_id UUID,
  new_status TEXT,
  reason TEXT DEFAULT NULL
)
RETURNS public.community_posts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  updated_post public.community_posts;
BEGIN
  IF NOT public.is_community_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE = '42501';
  END IF;
  IF new_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid moderation status' USING ERRCODE = '22023';
  END IF;
  IF new_status = 'rejected' AND NULLIF(BTRIM(reason), '') IS NULL THEN
    RAISE EXCEPTION 'A rejection reason is required' USING ERRCODE = '22023';
  END IF;

  UPDATE public.community_posts
  SET moderation_status = new_status,
      reviewed_by = auth.uid(),
      reviewed_at = NOW(),
      rejection_reason = CASE
        WHEN new_status = 'rejected' THEN BTRIM(reason)
        ELSE NULL
      END
  WHERE id = target_post_id
  RETURNING * INTO updated_post;

  IF updated_post.id IS NULL THEN
    RAISE EXCEPTION 'Post not found' USING ERRCODE = 'P0002';
  END IF;
  RETURN updated_post;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_community_post(UUID, TEXT, TEXT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.moderate_community_post(UUID, TEXT, TEXT)
  TO authenticated;
