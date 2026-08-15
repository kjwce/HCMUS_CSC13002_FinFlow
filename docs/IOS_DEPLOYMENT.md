# Hướng dẫn build & cài FinFlow lên iPhone (Codemic + Sideloadly)

> **Mục đích:** Test app FinFlow trên iPhone thật **mà không cần máy Mac, không cần Apple Developer Program ($99/năm), và không đưa mật khẩu Apple ID lên cloud.**

Quy trình tổng quan:

```
Git push → Codemagic (build .app KHÔNG ký) → tải về Windows → Sideloadly (ký bằng Apple ID free) → iPhone
```

| Thành phần | Vai trò |
|---|---|
| **Codemagic** | Build Flutter iOS trên cloud macOS (miễn phí 500 min/tháng) |
| **Sideloadly** | Ký + cài `.app` vào iPhone bằng Apple ID (free 7 ngày / miễn phí vĩnh viễn nếu dùng Apple ID có hỗ trợ) |

---

## ⚠️ Bảo mật — trả lời lo ngại về Apple ID

**Codemagic KHÔNG bao giờ thấy mật khẩu Apple ID của bạn.**

- `codemagic.yaml` **không khai báo `ios_signing`** → build ra file `.app` **chưa ký** (`--no-codesign`).
- Mật khẩu Apple ID **chỉ được nhập trong Sideloadly trên máy Windows của bạn**, truyền **trực tiếp từ máy bạn → iPhone**, không đi qua Codemagic hay bất kỳ đám mây nào.
- Bản build không ký cũng không thể chạy được nếu không có bạn ký — không ai khác lợi dụng được.

> 💡 Sideloadly gửi mật khẩu lên server của Apple (để xin chứng chỉ), **không phải** lên Sideloadly. Đây là luồng chuẩn của Apple cho free provisioning.

---

## 1. Cấu hình đã làm sẵn trong repo

### `ios/` (đã tạo bằng `flutter create --platforms=ios --org com.finflow`)

| Cấu hình | Giá trị |
|---|---|
| Bundle ID | `com.finflow.finflow` |
| Deployment target | **iOS 13.0** |
| Tên hiển thị | **FinFlow** (khớp Android) |

### `ios/Runner/Info.plist` (đã validate bằng `plistlib`)

- **Deep link Supabase:** scheme `io.supabase.flutter` — khớp với `redirectTo: 'io.supabase.flutter://login-callback'` trong `lib/features/auth/services/auth_service.dart`. Cần để OAuth Google/Facebook trả về app sau khi đăng nhập.
- **4 permission keys** (thiếu sẽ **crash app** khi dùng tính năng scan / voice add):

| Key | Tính năng |
|---|---|
| `NSCameraUsageDescription` | Quét biên lai (Receipt Scan) |
| `NSMicrophoneUsageDescription` | Ghi âm nhập chi tiêu (Voice Add) |
| `NSSpeechRecognitionUsageDescription` | Nhận dạng giọng nói (Voice Add) |
| `NSPhotoLibraryUsageDescription` | Chọn ảnh hóa đơn từ thư viện |

### `ios/` — Swift Package Manager (không dùng CocoaPods)
- Project này dùng **Swift Package Manager** (Flutter mới tích hợp SPM): không có Podfile, các plugin iOS được resolve tự động trong Xcode build. **Không cần `pod install`.**

### `codemagic.yaml`
- Workflow `finflow-ios-unsigned`: build **debug, không ký** → artifact là file `.app`.
- Xem chi tiết bên dưới.

---

## 2. Lần đầu: cài Sideloadly trên Windows

1. Tải **Sideloadly** từ trang chính thức: https://sideloadly.io/
2. Cài đặt **iTunes** và **iCloud** từ Microsoft Store (Sideloadly dựa vào driver của chúng):
   - Microsoft Store → tìm **"iTunes"** và **"iCloud"** → Cài đặt.
3. Cài **iTunes** bản đầy đủ (nếu Store thiếu driver): tải từ https://www.apple.com/itunes/ → chọn **Windows**.
4. Chạy Sideloadly → nếu được hỏi, đồng ý cài **Apple Mobile Device Support** driver.

> ⚠️ Nếu Sideloadly báo không thấy iPhone, hãy cài lại iTunes đầy đủ rồi **restart máy** — đây là nguyên nhân phổ biến nhất.

---

## 3. Build trên Codemagic

### Bước 3.1 — Push code lên Git

```bash
git add -A
git commit -m "Add iOS support + Codemagic config"
git push origin main
```

### Bước 3.2 — Kết nối repo trên Codemagic

1. Đăng ký https://codemagic.io/ (Google/GitHub login).
2. **Add application** → chọn Git provider (GitHub/GitLab/Bitbucket) → chọn repo `FinFlow`.
3. Codemagic tự đọc `codemagic.yaml` → sẽ thấy workflow **"FinFlow iOS (unsigned, for Sideloadly)"**.
4. Bấm **"Start new build"** (chọn workflow nếu cần).

### Bước 3.3 — Tải artifact

1. Build chạy ~5–10 phút (bản đầu tiên lâu hơn do download dependencies).
2. Khi build xong, vào tab **Builds** → chọn build thành công.
3. Kéo xuống mục **Artifacts** → tải file `Runner.app` (đã nén `.zip`).
4. **Giải nén** để lấy thư mục `Runner.app` hoàn chỉnh.

> 💡 Nếu quên tải, artifact vẫn nằm trong tab Builds của dự án trên Codemagic.

---

## 4. Ký & cài bằng Sideloadly

### Bước 4.1 — Chuẩn bị iPhone

> ⚠️ **Bước này BẮT BUỘC cắm cáp USB.** Sideloadly cài app bằng cách bấm gói lên iPhone qua cáp (không có chế độ cài qua Wi-Fi). Chuẩn bị trước trên máy:

1. **iOS 13 trở lên** (app deployment target 13.0).
2. Cắm iPhone vào máy Windows bằng **cáp USB gốc** (bấm **Trust** trên iPhone nếu được hỏi — cần để máy tính truy cập).
3. Nếu lần đầu dùng Sideloadly, bật **Developer Mode** trên **iPhone** (cài đặt này ngay trên máy, không cần cáp):
   - **Cài đặt → Quyền riêng tư & Bảo mật → Developer Mode** → bật → khởi động lại iPhone.
   - (Mục này có từ iOS 16; iOS 15 trở xuống không có và không cần.)

### Bước 4.2 — Ký & cài

1. Mở **Sideloadly**.
2. **iOS Device:** chọn iPhone của bạn (nếu không thấy, kiểm tra lại iTunes/iCloud driver).
3. **IPA / .app:** chọn thư mục `Runner.app` đã giải nén.
4. **Apple ID:** nhập Apple ID + mật khẩu (chỉ dùng cục bộ).
   - Nếu Apple ID có **2FA**: trong Sideloadly chọn **"Apple ID Login"** → đăng nhập trên máy để xin **App-Specific Password** (mục này rất quan trọng).
   - Hoặc tự tạo **App-Specific Password** tại https://appleid.apple.com/account/manage → **App-Specific Passwords** → dán vào Sideloadly.
5. **Install Options:**
   - Tích **"Automatically install on connect"** nếu muốn.
   - Nếu muốn giữ app lâu hơn: tích **"Get & Install plugins"** (chỉ 3 app miễn phí: Sideloadly Helper + 2 khác) → app sống tới **365 ngày** thay vì 7 ngày.
6. Bấm **Start** → Sideloadly ký + cài. Chờ chữ **"Complete"**.

### Bước 4.3 — Tin cậy app trên iPhone

Lần đầu mở app sẽ bị iOS chặn:
- **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị** (hoặc **Cấu hình hồ sơ**) → chọn Apple ID của bạn → **Tin cậy** → **Tin cậy** lần nữa.

> 💡 Nếu iOS 13/14 không thấy mục này: **Cài đặt → Cài đặt chung → Quản lý thiết bị**.

Sau đó mở **FinFlow** bình thường.

---

## 5. Lưu ý khi test trên iPhone

- **OAuth Google/Facebook:** nhờ deep link `io.supabase.flutter` đã cấu hình, app sẽ quay lại sau khi đăng nhập. Lần đầu mở app nhớ **Trust** profile (bước 4.3) trước, nếu không deep link có thể bị chặn.
- **Scan biên lai / Voice Add:** iOS sẽ hiện hộp thoại xin quyền camera / microphone / speech — bấm **Allow**.
- **Hạn dùng 7 ngày:** app tự ký bằng Apple ID free sẽ hết hạn sau 7 ngày. Hết hạn → cắm lại iPhone, mở Sideloadly, bấm **Start** lại (không cần xoá app).
- **Chỉ 3 app ký free** bằng 1 Apple ID. Ký thêm app khác sẽ bị Sideloadly hỏi gỡ app cũ hoặc đăng ký UDID.
- **Không bật iCloud trên nhiều máy** cùng lúc khi ký — dễ bị khóa provisioning.

---

## 6. Troubleshooting

| Vấn đề | Cách xử lý |
|---|---|
| Sideloadly không thấy iPhone | Cài lại iTunes đầy đủ + iCloud, restart máy, dùng cáp gốc |
| "Requires a valid provisioning profile" | Apple ID free bị giới hạn — đăng nhập lại / tạo App-Specific Password, hoặc xoá app cũ để ký lại |
| App crash ngay khi mở | Kiểm tra **Trust profile** (bước 4.3); thử gỡ app + cài lại |
| Build Codemagic fail | Vào log build → chỗ lỗi (thường do `pod install` / version Flutter). Báo lại để sửa |
| Scan bị lỗi permission | Vào Cài đặt → FinFlow → bật Camera/Microphone/Speech & nhận dạng giọng nói |
| App hết hạn 7 ngày | Cắm iPhone, Sideloadly → Start lại (kỳ hạn được gia hạn) |

---

## 7. Muốn app không hết hạn (tuỳ chọn)

- **Apple Developer Program ($99/năm):** cho phép app ký 1 năm, đủ chức năng, không giới hạn 3 app. Cần kê khai **UDID** của iPhone trong Developer portal rồi cấp profile.
- Sau khi đã build bằng Codemagic không ký như hiện tại, khi có Developer Program bạn chỉ cần:
  1. Thêm `ios_signing` + certificate vào `codemagic.yaml`.
  2. Codemagic build `.ipa` đã ký → cài bằng Sideloadly (hoặc Xcode, hoặc Apple Configurator).

---

## ✅ Checklist hoàn tất

- [ ] `ios/` tạo bằng `flutter create` (Bundle ID `com.finflow.finflow`, target iOS 13.0)
- [ ] Info.plist: display name `FinFlow`, deep link `io.supabase.flutter`, 4 permission keys
- [ ] `flutter analyze` sạch (No issues)
- [ ] `codemagic.yaml` có workflow build unsigned
- [ ] Đã cài Sideloadly + iTunes + iCloud trên Windows
- [ ] iPhone đã kết nối, bật Developer Mode, app đã Trust
- [ ] Đã đăng ký App-Specific Password (nếu Apple ID bật 2FA)
