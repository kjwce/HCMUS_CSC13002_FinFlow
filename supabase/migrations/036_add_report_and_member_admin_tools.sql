-- Report handling and member posting restrictions for Community Admin.
ALTER TABLE public.community_posts
  ADD COLUMN IF NOT EXISTS removed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS removed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS removal_reason TEXT;

ALTER TABLE public.community_posts
  DROP CONSTRAINT IF EXISTS community_posts_moderation_status_check;
ALTER TABLE public.community_posts
  ADD CONSTRAINT community_posts_moderation_status_check
  CHECK (moderation_status IN ('pending', 'approved', 'rejected', 'removed'));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_community_muted BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS community_muted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS community_muted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS community_mute_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_community_muted
  ON public.profiles(is_community_muted)
  WHERE is_community_muted = true;

CREATE OR REPLACE FUNCTION public.is_community_user_muted(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT COALESCE(
    (SELECT profile.is_community_muted
     FROM public.profiles profile
     WHERE profile.id = target_user_id),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_community_user_muted(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_community_user_muted(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_community_mute_fields()
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
    NEW.is_community_muted := false;
    NEW.community_muted_at := NULL;
    NEW.community_muted_by := NULL;
    NEW.community_mute_reason := NULL;
  ELSE
    NEW.is_community_muted := OLD.is_community_muted;
    NEW.community_muted_at := OLD.community_muted_at;
    NEW.community_muted_by := OLD.community_muted_by;
    NEW.community_mute_reason := OLD.community_mute_reason;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_community_mute_fields ON public.profiles;
CREATE TRIGGER trg_protect_community_mute_fields
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_community_mute_fields();

CREATE OR REPLACE FUNCTION public.assert_community_post_allowed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_community_admin()
     AND public.is_community_user_muted(NEW.user_id) THEN
    RAISE EXCEPTION 'COMMUNITY_USER_MUTED'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assert_community_post_allowed
  ON public.community_posts;
CREATE TRIGGER trg_assert_community_post_allowed
BEFORE INSERT ON public.community_posts
FOR EACH ROW EXECUTE FUNCTION public.assert_community_post_allowed();

DROP POLICY IF EXISTS "users_insert_own_posts" ON public.community_posts;
CREATE POLICY "users_insert_own_posts"
  ON public.community_posts FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND NOT public.is_community_user_muted(auth.uid())
  );

CREATE OR REPLACE FUNCTION public.remove_reported_community_post(
  target_post_id UUID,
  reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NOT public.is_community_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE = '42501';
  END IF;
  IF NULLIF(BTRIM(reason), '') IS NULL THEN
    RAISE EXCEPTION 'A removal reason is required' USING ERRCODE = '22023';
  END IF;

  UPDATE public.community_posts
  SET moderation_status = 'removed',
      removed_at = NOW(),
      removed_by = auth.uid(),
      removal_reason = BTRIM(reason),
      reviewed_at = NOW(),
      reviewed_by = auth.uid()
  WHERE id = target_post_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Post not found' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.community_post_reports
  SET status = 'resolved'
  WHERE post_id = target_post_id AND status = 'pending';
END;
$$;

REVOKE ALL ON FUNCTION public.remove_reported_community_post(UUID, TEXT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remove_reported_community_post(UUID, TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.set_community_user_muted(
  target_user_id UUID,
  muted BOOLEAN,
  reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  target_is_admin BOOLEAN;
BEGIN
  IF NOT public.is_community_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE = '42501';
  END IF;
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot mute your own admin account'
      USING ERRCODE = '22023';
  END IF;
  IF muted AND NULLIF(BTRIM(reason), '') IS NULL THEN
    RAISE EXCEPTION 'A mute reason is required' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(
    user_record.raw_app_meta_data ->> 'role' = 'community_admin',
    false
  )
  INTO target_is_admin
  FROM auth.users user_record
  WHERE user_record.id = target_user_id;

  IF COALESCE(target_is_admin, false) THEN
    RAISE EXCEPTION 'Another community admin cannot be muted'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.profiles
  SET is_community_muted = muted,
      community_muted_at = CASE WHEN muted THEN NOW() ELSE NULL END,
      community_muted_by = CASE WHEN muted THEN auth.uid() ELSE NULL END,
      community_mute_reason = CASE
        WHEN muted THEN BTRIM(reason)
        ELSE NULL
      END
  WHERE id = target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'P0002';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.set_community_user_muted(UUID, BOOLEAN, TEXT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_community_user_muted(UUID, BOOLEAN, TEXT)
  TO authenticated;
