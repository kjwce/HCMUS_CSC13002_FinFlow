-- ============================================================
-- 1. Fix: Thêm cột phone vào profiles
-- ============================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT NOT NULL DEFAULT '';

-- ============================================================
-- 2. Fix: Storage policies cho avatars bucket
-- ============================================================

-- Tạo bucket nếu chưa có
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Cho phép authenticated users upload file
CREATE POLICY "users_upload_own_avatar"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (string_to_array(name, '/'))[2]
  );

-- Cho phép authenticated users update file của chính mình
CREATE POLICY "users_update_own_avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (string_to_array(name, '/'))[2]
  );

-- Cho phép tất cả xem avatar (public)
CREATE POLICY "everyone_read_avatars"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'avatars');
