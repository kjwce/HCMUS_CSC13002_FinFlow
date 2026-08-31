-- Unified, realtime in-app notifications and account-scoped preferences.
-- Existing community_notifications and recurring_notifications remain as
-- durable source tables during the transition and are mirrored here.

CREATE TABLE IF NOT EXISTS public.app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source_table TEXT NOT NULL DEFAULT 'app'
    CHECK (source_table IN ('app', 'community_notifications', 'recurring_notifications')),
  source_id TEXT,
  category TEXT NOT NULL
    CHECK (category IN ('transaction', 'budget', 'goal', 'recurring', 'community', 'system')),
  type TEXT NOT NULL,
  title TEXT,
  body TEXT,
  priority TEXT NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'critical')),
  action_required BOOLEAN NOT NULL DEFAULT false,
  actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  entity_type TEXT,
  entity_id TEXT,
  route_name TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT false,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('scheduled', 'active', 'completed', 'dismissed', 'failed')),
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  dedupe_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS app_notifications_source_uidx
  ON public.app_notifications (source_table, source_id)
  WHERE source_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS app_notifications_dedupe_uidx
  ON public.app_notifications (user_id, dedupe_key)
  WHERE dedupe_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS app_notifications_user_feed_idx
  ON public.app_notifications (user_id, is_archived, available_at DESC);

CREATE INDEX IF NOT EXISTS app_notifications_user_filter_idx
  ON public.app_notifications (user_id, category, action_required, is_read);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  master_enabled BOOLEAN NOT NULL DEFAULT true,
  in_app_banner_enabled BOOLEAN NOT NULL DEFAULT true,
  daily_budget_enabled BOOLEAN NOT NULL DEFAULT true,
  daily_budget_threshold INTEGER NOT NULL DEFAULT 90
    CHECK (daily_budget_threshold BETWEEN 1 AND 100),
  weekly_budget_enabled BOOLEAN NOT NULL DEFAULT true,
  weekly_budget_threshold INTEGER NOT NULL DEFAULT 80
    CHECK (weekly_budget_threshold BETWEEN 1 AND 100),
  monthly_budget_enabled BOOLEAN NOT NULL DEFAULT true,
  monthly_budget_threshold INTEGER NOT NULL DEFAULT 85
    CHECK (monthly_budget_threshold BETWEEN 1 AND 100),
  saving_goal_updates_enabled BOOLEAN NOT NULL DEFAULT true,
  recurring_expense_enabled BOOLEAN NOT NULL DEFAULT true,
  recurring_income_enabled BOOLEAN NOT NULL DEFAULT true,
  recurring_failure_enabled BOOLEAN NOT NULL DEFAULT true,
  community_likes_enabled BOOLEAN NOT NULL DEFAULT true,
  community_replies_enabled BOOLEAN NOT NULL DEFAULT true,
  community_posts_enabled BOOLEAN NOT NULL DEFAULT false,
  system_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.finflow_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_notifications_updated_at
  ON public.app_notifications;
CREATE TRIGGER trg_app_notifications_updated_at
BEFORE UPDATE ON public.app_notifications
FOR EACH ROW EXECUTE FUNCTION public.finflow_touch_updated_at();

DROP TRIGGER IF EXISTS trg_notification_preferences_updated_at
  ON public.notification_preferences;
CREATE TRIGGER trg_notification_preferences_updated_at
BEFORE UPDATE ON public.notification_preferences
FOR EACH ROW EXECUTE FUNCTION public.finflow_touch_updated_at();

CREATE OR REPLACE FUNCTION public.finflow_create_notification_preferences()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_notification_preferences
  ON public.profiles;
CREATE TRIGGER trg_profiles_notification_preferences
AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.finflow_create_notification_preferences();

INSERT INTO public.notification_preferences (user_id)
SELECT id FROM public.profiles
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_read_own_app_notifications"
  ON public.app_notifications;
DROP POLICY IF EXISTS "users_insert_own_app_notifications"
  ON public.app_notifications;
DROP POLICY IF EXISTS "users_update_own_app_notifications"
  ON public.app_notifications;
DROP POLICY IF EXISTS "users_delete_own_app_notifications"
  ON public.app_notifications;

CREATE POLICY "users_read_own_app_notifications"
  ON public.app_notifications FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "users_insert_own_app_notifications"
  ON public.app_notifications FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_update_own_app_notifications"
  ON public.app_notifications FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_delete_own_app_notifications"
  ON public.app_notifications FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_read_own_notification_preferences"
  ON public.notification_preferences;
DROP POLICY IF EXISTS "users_insert_own_notification_preferences"
  ON public.notification_preferences;
DROP POLICY IF EXISTS "users_update_own_notification_preferences"
  ON public.notification_preferences;

CREATE POLICY "users_read_own_notification_preferences"
  ON public.notification_preferences FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "users_insert_own_notification_preferences"
  ON public.notification_preferences FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users_update_own_notification_preferences"
  ON public.notification_preferences FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Community trigger output -> canonical notification feed.
CREATE OR REPLACE FUNCTION public.finflow_mirror_community_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.app_notifications (
    user_id, source_table, source_id, category, type, actor_id,
    entity_type, entity_id, route_name, payload, is_read, created_at,
    available_at
  ) VALUES (
    NEW.user_id,
    'community_notifications',
    NEW.id::text,
    'community',
    NEW.type,
    NEW.actor_id,
    CASE WHEN NEW.post_id IS NOT NULL THEN 'community_post' ELSE NULL END,
    NEW.post_id::text,
    'community_post',
    jsonb_strip_nulls(jsonb_build_object(
      'post_id', NEW.post_id,
      'comment_id', NEW.comment_id,
      'actor_id', NEW.actor_id
    )),
    NEW.is_read,
    NEW.created_at,
    NEW.created_at
  )
  ON CONFLICT (source_table, source_id) WHERE source_id IS NOT NULL
  DO UPDATE SET
    is_read = EXCLUDED.is_read,
    payload = EXCLUDED.payload,
    updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mirror_community_notification
  ON public.community_notifications;
CREATE TRIGGER trg_mirror_community_notification
AFTER INSERT OR UPDATE ON public.community_notifications
FOR EACH ROW EXECUTE FUNCTION public.finflow_mirror_community_notification();

-- Recurring history -> canonical notification feed. Future reminders remain
-- scheduled until their available_at time and are not shown early by clients.
CREATE OR REPLACE FUNCTION public.finflow_mirror_recurring_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  canonical_status TEXT;
BEGIN
  canonical_status := CASE
    WHEN NEW.status = 'completed' THEN 'completed'
    WHEN NEW.status = 'dismissed' THEN 'dismissed'
    WHEN NEW.scheduled_for > now() THEN 'scheduled'
    ELSE 'active'
  END;

  INSERT INTO public.app_notifications (
    user_id, source_table, source_id, category, type, title, body,
    priority, action_required, entity_type, entity_id, route_name,
    payload, is_read, status, available_at, created_at
  ) VALUES (
    NEW.user_id,
    'recurring_notifications',
    NEW.id,
    'recurring',
    CASE WHEN NEW.posting_mode = 'review'
      THEN 'recurring_review'
      ELSE 'recurring_automatic'
    END,
    NEW.title,
    NEW.body,
    CASE WHEN NEW.posting_mode = 'review' THEN 'high' ELSE 'normal' END,
    NEW.posting_mode = 'review' AND NEW.status = 'pending',
    'recurring_schedule',
    NEW.schedule_id,
    'recurring_details',
    jsonb_build_object(
      'schedule_id', NEW.schedule_id,
      'posting_mode', NEW.posting_mode,
      'occurrence_at', NEW.occurrence_at,
      'scheduled_for', NEW.scheduled_for
    ),
    NEW.is_read,
    canonical_status,
    NEW.scheduled_for,
    NEW.created_at
  )
  ON CONFLICT (source_table, source_id) WHERE source_id IS NOT NULL
  DO UPDATE SET
    title = EXCLUDED.title,
    body = EXCLUDED.body,
    action_required = EXCLUDED.action_required,
    payload = EXCLUDED.payload,
    is_read = EXCLUDED.is_read,
    status = EXCLUDED.status,
    available_at = EXCLUDED.available_at,
    updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_mirror_recurring_notification
  ON public.recurring_notifications;
CREATE TRIGGER trg_mirror_recurring_notification
AFTER INSERT OR UPDATE ON public.recurring_notifications
FOR EACH ROW EXECUTE FUNCTION public.finflow_mirror_recurring_notification();

-- Idempotent backfill of existing history.
INSERT INTO public.app_notifications (
  user_id, source_table, source_id, category, type, actor_id,
  entity_type, entity_id, route_name, payload, is_read, created_at,
  available_at
)
SELECT
  n.user_id,
  'community_notifications',
  n.id::text,
  'community',
  n.type,
  n.actor_id,
  CASE WHEN n.post_id IS NOT NULL THEN 'community_post' ELSE NULL END,
  n.post_id::text,
  'community_post',
  jsonb_strip_nulls(jsonb_build_object(
    'post_id', n.post_id,
    'comment_id', n.comment_id,
    'actor_id', n.actor_id
  )),
  n.is_read,
  n.created_at,
  n.created_at
FROM public.community_notifications n
ON CONFLICT (source_table, source_id) WHERE source_id IS NOT NULL DO NOTHING;

INSERT INTO public.app_notifications (
  user_id, source_table, source_id, category, type, title, body,
  priority, action_required, entity_type, entity_id, route_name,
  payload, is_read, status, available_at, created_at
)
SELECT
  n.user_id,
  'recurring_notifications',
  n.id,
  'recurring',
  CASE WHEN n.posting_mode = 'review'
    THEN 'recurring_review'
    ELSE 'recurring_automatic'
  END,
  n.title,
  n.body,
  CASE WHEN n.posting_mode = 'review' THEN 'high' ELSE 'normal' END,
  n.posting_mode = 'review' AND n.status = 'pending',
  'recurring_schedule',
  n.schedule_id,
  'recurring_details',
  jsonb_build_object(
    'schedule_id', n.schedule_id,
    'posting_mode', n.posting_mode,
    'occurrence_at', n.occurrence_at,
    'scheduled_for', n.scheduled_for
  ),
  n.is_read,
  CASE
    WHEN n.status = 'completed' THEN 'completed'
    WHEN n.status = 'dismissed' THEN 'dismissed'
    WHEN n.scheduled_for > now() THEN 'scheduled'
    ELSE 'active'
  END,
  n.scheduled_for,
  n.created_at
FROM public.recurring_notifications n
ON CONFLICT (source_table, source_id) WHERE source_id IS NOT NULL DO NOTHING;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'app_notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;
  END IF;
END
$migration$;

NOTIFY pgrst, 'reload schema';
