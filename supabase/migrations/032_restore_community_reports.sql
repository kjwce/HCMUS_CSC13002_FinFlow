-- Restore the PA02 community report tables when migration history says 010 was
-- applied but the report relations are missing from the remote schema.

CREATE TABLE IF NOT EXISTS public.community_post_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, reporter_id)
);

CREATE TABLE IF NOT EXISTS public.community_comment_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID NOT NULL REFERENCES public.community_comments(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (comment_id, reporter_id)
);

CREATE INDEX IF NOT EXISTS idx_community_post_reports_reporter
  ON public.community_post_reports(reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_post_reports_status
  ON public.community_post_reports(status, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_community_comment_reports_reporter
  ON public.community_comment_reports(reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_community_comment_reports_status
  ON public.community_comment_reports(status, created_at ASC);

ALTER TABLE public.community_post_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_comment_reports ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'community_post_reports'
      AND policyname = 'users_insert_own_reports'
  ) THEN
    CREATE POLICY "users_insert_own_reports"
      ON public.community_post_reports FOR INSERT
      WITH CHECK (auth.uid() = reporter_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'community_post_reports'
      AND policyname = 'users_read_own_reports'
  ) THEN
    CREATE POLICY "users_read_own_reports"
      ON public.community_post_reports FOR SELECT
      USING (auth.uid() = reporter_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'community_comment_reports'
      AND policyname = 'users_insert_own_comment_reports'
  ) THEN
    CREATE POLICY "users_insert_own_comment_reports"
      ON public.community_comment_reports FOR INSERT
      WITH CHECK (auth.uid() = reporter_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'community_comment_reports'
      AND policyname = 'users_read_own_comment_reports'
  ) THEN
    CREATE POLICY "users_read_own_comment_reports"
      ON public.community_comment_reports FOR SELECT
      USING (auth.uid() = reporter_id);
  END IF;
END
$$;

GRANT SELECT, INSERT ON public.community_post_reports TO authenticated;
GRANT SELECT, INSERT ON public.community_comment_reports TO authenticated;
