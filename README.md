# FinFlow

FinFlow is a Flutter mobile app for personal finance tracking. It helps users record income and expenses, connect transactions to wallets/bank accounts, monitor spending against budget limits, and view dashboard charts for financial insight.

The app features **AI-powered natural language and voice transaction input** via Supabase Edge Functions (Google Gemini + Deepgram).

## Features

### Core Finance
- Transaction add/edit/delete with wallet awareness
- Wallet onboarding: 27 banks, 9 e-wallets, and cash
- Monthly and weekly budget tracking
- Saving goals with progress display
- Transaction history with daily grouping and filters

### Quick Add (Text)
- Type natural language like `"Ăn trưa 50k bằng MoMo hôm qua"`
- AI parses amount, type, category, wallet, and date
- Review before saving; missing fields sent to edit form
- Supports Vietnamese, English, and mixed input

### Quick Add (Voice)
- Tap microphone to record transaction descriptions
- Speech recognition via Deepgram Nova-3
- 30-second recording limit
- Transcript auto-submitted for parsing

### Dashboard & Charts
- 5 chart types using `fl_chart`:
  - Income, Expense & Balance Line Chart
  - Income/Expense by Category Donuts
  - Income & Expense by Source (bank/ewallet/cash)
  - Total Income vs Expense comparison
- Period selector (Day / Week / Month) with offset navigation
- Touch tooltips, animated transitions

### Home Screen
- Balance and expense summary with budget progress bar
- Configurable goal summary metric (revenue/expense by period)
- Category expense tracker
- Quick Add card integrated in home
- Recent transactions filtered by period (Daily / Weekly / Monthly)

### Authentication
- Email/password sign in and sign up
- OTP verification for signup and password reset
- OAuth stubs for Google, Facebook, Apple
- Profile management with avatar upload

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

### 5. Supabase Edge Functions

The app uses two Edge Functions for AI features:

1. **`parse-natural-language-transaction`** — requires `GEMINI_API_KEY` secret
2. **`speech-to-text`** — requires `DEEPGRAM_API_KEY` secret

Deploy:
```bash
supabase functions deploy parse-natural-language-transaction
supabase functions deploy speech-to-text
supabase secrets set GEMINI_API_KEY=your_key
supabase secrets set DEEPGRAM_API_KEY=your_key
```

## Project Structure

```
lib/
├── app/
│   ├── screens/            # Main screens (Home, AI, Community, Profile)
│   └── shell/              # App shell (MainShell, FinFlowApp, BottomNavBar)
├── core/
│   ├── config/             # Environment configuration
│   ├── constants/          # Supabase URL/keys
│   ├── i18n/               # AppLanguage, AppStrings (bilingual)
│   ├── services/           # App init notifier
│   ├── theme/              # AppColors, AppTheme, AppThemeManager
│   ├── utils/              # Responsive helper
│   └── widgets/            # NotificationBell, FinFlowLogo, etc.
├── features/
│   ├── auth/               # Sign in, sign up, OTP, password reset
│   ├── budget/             # Budget setup screen
│   ├── chatbot/            # Chat screen (placeholder)
│   ├── community/          # Community screen (placeholder)
│   ├── debug/              # Database viewer
│   ├── finance/            # TRANSACTIONS, WALLETS, GOALS, QUICK ADD, DASHBOARD
│   │   ├── models/         # TransactionModel, QuickAddDraft, WalletModel, etc.
│   │   ├── presentation/   # Screens, sheets, widgets (QuickAddCard, etc.)
│   │   ├── providers/      # Riverpod providers
│   │   └── services/       # Services (incl. QuickAddService, QuickAddVoiceService)
│   ├── launch/             # Launch and onboarding screens
│   ├── profile/            # Edit profile screen
│   ├── scan/               # Receipt scanning (placeholder)
│   └── settings/           # Settings screen
assets/
├── icons/                  # SVG icons
├── icons/home/             # Home-specific SVG icons
├── logos/banks/            # 27 bank logos
├── logos/ewallets/         # 9 e-wallet + cash + other logos
├── fonts/                  # Manrope, Hanken Grotesk
├── *.png                   # Cover/background images
supabase/
├── functions/
│   ├── parse-natural-language-transaction/  # Gemini NL parser (TypeScript)
│   └── speech-to-text/                      # Deepgram STT (TypeScript)
└── migrations/             # SQL migrations
scripts/                    # Test scripts for Edge Functions
test/
└── features/finance/       # Quick Add unit and widget tests
```

## Packages Used

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management / providers |
| `supabase_flutter` | Auth, database, storage, Edge Functions |
| `fl_chart` | Dashboard charts |
| `flutter_svg` | SVG icon rendering |
| `image_picker` | Avatar image selection |
| `record` | Audio recording for voice Quick Add |
| `visibility_detector` | Screen visibility tracking |
| `sqflite` / `path` | Present but unused (cloud storage) |

## Edge Functions

### `parse-natural-language-transaction`
- **Runtime:** Deno (TypeScript)
- **AI:** Google Gemini 2.5 Flash
- **Input:** Text + categories + wallets + locale
- **Output:** Structured transaction data (type, amount, name, category, wallet, date, confidence, warnings)
- **Auth:** Bearer token (Supabase JWT)

### `speech-to-text`
- **Runtime:** Deno (TypeScript)
- **AI:** Deepgram Nova-3 (Vietnamese)
- **Input:** Raw audio bytes (max 5MB)
- **Output:** Text transcript
- **Supported formats:** MP4, MPEG, WAV, AAC, OGG, WEBM, FLAC
- **Auth:** Bearer token (Supabase JWT)

## Testing

```powershell
flutter test
```

The test suite includes 40+ tests covering:
- Quick Add service: response validation, wallet resolution, transfer detection, draft conversion
- Quick Add voice service: recording lifecycle, permissions, transcription handling, file cleanup
- Quick Add widget flow: review sheet, confirm/edit actions, voice controls, AddTransactionSheet prefill

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

### Edge Function errors
- Check that `GEMINI_API_KEY` and `DEEPGRAM_API_KEY` are set in Supabase secrets
- Verify the Edge Functions are deployed with `supabase functions list`
- Check function logs in Supabase dashboard

## Notes

- This project uses `flutter_svg` for rendering SVG icons from the Figma design.
- The app uses `flutter_riverpod` for state management.
- Icons are stored as SVG in `assets/icons/` and referenced via `SvgPicture.asset()`.
- Custom categories are currently in-memory only (lost after app restart).
- Supabase project URL and anon key are in `lib/core/constants/supabase_constants.dart`.
