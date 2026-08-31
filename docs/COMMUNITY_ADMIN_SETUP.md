# FinFlow Community Admin

Admin Console là một Flutter Web entry point riêng, nên không thay đổi luồng
khởi động của ứng dụng mobile FinFlow.

## 1. Áp dụng database migration

Chạy các migration Supabase của dự án, bao gồm
`035_add_community_moderation.sql` và
`036_add_report_and_member_admin_tools.sql`.

Migration này:

- thêm trạng thái `pending`, `approved`, `rejected` cho bài viết;
- chỉ hiển thị bài đã duyệt trong feed;
- bảo vệ các trường kiểm duyệt bằng trigger và RLS;
- tạo RPC duyệt/từ chối bài chỉ dành cho admin.
- cho phép admin xử lý báo cáo, gỡ bài có lưu vết và mute/unmute quyền đăng bài;
- chặn user bị mute tạo bài mới trực tiếp tại database.

## 2. Tạo tài khoản admin cố định

Trong Supabase Dashboard, vào **Authentication → Users → Add user** và tạo tài
khoản bằng email/mật khẩu admin mong muốn. Không đặt mật khẩu trong source code.

Sau đó mở SQL Editor và cấp role cho đúng email đó:

```sql
UPDATE auth.users
SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
  || '{"role":"community_admin"}'::jsonb
WHERE email = 'admin@your-domain.com';
```

Nếu tài khoản đang đăng nhập, hãy đăng xuất rồi đăng nhập lại để JWT nhận role
mới. Chỉ `app_metadata` được dùng để cấp quyền; client không thể tự chỉnh role.

## 3. Chạy Admin Console

```bash
flutter run -d chrome -t lib/admin_main.dart
```

Build bản web để triển khai:

```bash
flutter build web -t lib/admin_main.dart
```

Output nằm trong `build/web`. Nên triển khai Admin Console ở subdomain riêng,
ví dụ `admin.finflow.vn`.
