CREATE TABLE IF NOT EXISTS public.community_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  media_type TEXT NOT NULL DEFAULT 'image',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_community_media_post
  ON public.community_media(post_id);

ALTER TABLE public.community_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "everyone_read_media" ON public.community_media;
CREATE POLICY "everyone_read_media"
ON public.community_media FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "users_insert_own_media" ON public.community_media;
CREATE POLICY "users_insert_own_media"
ON public.community_media FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users_delete_own_media" ON public.community_media;
CREATE POLICY "users_delete_own_media"
ON public.community_media FOR DELETE TO authenticated
USING (auth.uid() = user_id);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'community-media',
  'community-media',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "community_media_public_read" ON storage.objects;
CREATE POLICY "community_media_public_read"
ON storage.objects FOR SELECT
USING (bucket_id = 'community-media');

DROP POLICY IF EXISTS "community_media_owner_insert" ON storage.objects;
CREATE POLICY "community_media_owner_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'community-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "community_media_owner_delete" ON storage.objects;
CREATE POLICY "community_media_owner_delete"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'community-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
