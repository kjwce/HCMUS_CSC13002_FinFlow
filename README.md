# FinFlow

FinFlow is a Flutter mobile base project for a personal finance assistant app.

## Features

- Launch and onboarding screens
- Sign in, sign up, forgot password flow
- Dashboard shell with 5-tab bottom navigation (Home, AI Analysis, Scan, Community, Profile)
- Edit profile screen with form fields and toggles
- Chatbot screen
- Community screen with articles grid
- Receipt scanning (placeholder)
- SVG icons from Figma design

## Requirements

Before running the project, ensure you have the following installed:

| Tool | Version | Notes |
|------|---------|-------|
| Flutter SDK | ^3.12.2 | Run `flutter --version` to check |
| Dart SDK | ^3.12.2 | Bundled with Flutter |
| Android Studio | Latest | For Android emulator & build tools |
| VS Code | Latest | Alternative editor |
| Git | Any | For cloning the repo |
| Java JDK | 17+ | Required by Android Studio (bundled with recent versions) |

## Setup

### 1. Clone the project

```powershell
git clone <repo-url>
cd FinFlow
```

### 2. Get dependencies

```powershell
flutter pub get
```

### 3. Run the app

#### Using VS Code
1. Open the `FinFlow` folder in VS Code
2. Install the **Flutter** extension (Dart Code) if not already installed
3. Press `F5` or click **Run > Start Debugging**
4. Select an emulator/device when prompted

#### Using Android Studio

**Setup device lần đầu:**
1. Cài [Android Studio](https://developer.android.com/studio) (mới nhất)
2. Mở **AVD Manager** (biểu tượng điện thoại trong toolbar) > **Create device**
   - Chọn **Phone** > **Pixel 6** (hoặc bất kỳ)
   - Chọn system image: **API 35** (Android 15) hoặc thấp hơn
   - Nhấn **Next > Finish**
3. Vào **File > Settings > Languages & Frameworks > Flutter** (Windows)
   hoặc **Android Studio > Preferences** (macOS) — đảm bảo Flutter SDK path đúng
4. Chạy `flutter doctor` trong terminal để kiểm tra

**Chạy app:**
1. **File > Open** → chọn thư mục `FinFlow`
2. Chờ Gradle sync xong
3. Nếu có license popup, nhấn **Accept**
4. Chọn emulator từ dropdown (cạnh nút Run ▶)
5. Nhấn **Run** hoặc `Shift + F10`

#### Using terminal / PowerShell

```powershell
flutter run
```

To run on a specific device:
```powershell
flutter devices           # List available devices
flutter run -d <device-id>
```

### 4. Build APK (for testing on a real device)

```powershell
flutter build apk --debug
```

The APK will be at `build\app\outputs\flutter-apk\app-debug.apk`.

## Project Structure

```
lib/
├── app/
│   ├── screens/            # Main screens (Home, Profile, AI, Community)
│   └── shell/              # App shell (MainShell, BottomNavBar)
├── core/
│   ├── data/               # Local database
│   ├── i18n/               # Internationalization strings
│   └── theme/              # App colors & theme
├── features/
│   ├── auth/               # Sign in, sign up, forgot password
│   ├── chatbot/            # Chat screen
│   ├── community/          # Community screen
│   ├── debug/              # Database viewer
│   ├── finance/            # Transactions & budgets
│   ├── profile/            # Edit profile screen
│   ├── scan/               # Receipt scanning
│   └── settings/           # Settings screen
assets/
├── icons/                  # SVG icons from Figma
├── *.png                   # Background cover images
pubspec.yaml                # Project configuration
```

## Troubleshooting

### `flutter pub get` fails
- Ensure Flutter SDK is correctly installed and on your PATH
- Run `flutter doctor` to diagnose any issues

### Android emulator not found
- Open Android Studio, go to **Tools > Device Manager**
- Create a new virtual device if none exists
- Or use a physical device with USB debugging enabled

### Build fails on Windows
- If you see errors about `flutter_svg`, run:
```powershell
flutter clean
flutter pub get
```

### "Can't find service: activity" when running on emulator
- Restart ADB:
```powershell
adb kill-server
adb start-server
```
- Or cold-boot the emulator from Android Studio's Device Manager

## Notes

- This project uses `flutter_svg` for rendering SVG icons from the Figma design.
- The app uses `flutter_riverpod` for state management.
- Icons are stored as SVG in `assets/icons/` and referenced via `SvgPicture.asset()`.
