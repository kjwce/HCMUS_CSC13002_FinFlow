# FinFlow

FinFlow is a Flutter mobile app for personal finance tracking. It helps users record income and expenses, connect transactions to wallets (cash / transfer), monitor daily/weekly/monthly spending against budget limits, track saving goals, and view dashboard charts for financial insight.

The app features **AI-powered input and assistance** via Supabase Edge Functions: natural-language and voice transaction entry (Google Gemini + Deepgram), receipt scanning (Gemini), bank/e-wallet notification import (Gemini + native Android), and a conversational financial assistant (Gemini).

## Features

### Core Finance
- Transaction add/edit/delete with wallet awareness (goal-aware RPCs keep goal allocations consistent)
- Payment-source onboarding: cash + transfer (the two system wallets)
- Monthly, daily, and weekly budget tracking
- **Advanced saving goals**: auto allocation % of income, protected goals, withdrawal priority, redirect on completion, shortfall handling
- Per-category monthly budgets
- Transaction history with daily grouping and filters

### Quick Add (Text)
- Type natural language like `"Ăn trưa 50k bằng MoMo hôm qua"`
- AI parses amount, type, category, wallet, and date
- Review before saving; missing fields sent to edit form
- Supports Vietnamese, English, and mixed input

### Quick Add (Voice)
- Tap microphone to record transaction descriptions
- Speech recognition via Deepgram Nova-3 (recording-based) or on-device `speech_to_text`
- 30-second recording limit; transcript auto-submitted for parsing

### Receipt Scanning
- Snap/select a receipt in the Scan tab (or inside Add Transaction → Scan)
- AI extracts merchant, date, and line items with categories
- Review and adjust before saving as transactions

### Bank Notification Import (Android)
- Reads bank/e-wallet notifications via Notification Access (native listener)
- AI decides whether a notification is a transaction and parses it
- Review via Quick Add sheet and save with one tap
- Supports 14 Vietnamese banks/e-wallets (configurable)

### AI Financial Assistant (Chatbot tab)
- Real conversation grounded in your finances
- Streaming responses, conversation history, image attachments
- Insight cards and chart cards

### Dashboard & Charts
- 5 chart types using `fl_chart`:
  - Income, Expense & Balance Line Chart
  - Income/Expense by Category Donuts
  - Income & Expense by Source (cash/transfer)
  - Total Income vs Expense comparison
- Period selector (Day / Week / Month) with offset navigation
- Touch tooltips, animated transitions

### Home Screen
- Balance and expense summary with budget progress
- Goals section + configurable goal summary metric
- Category expense tracker and category budgets
- Quick Add card integrated in home
- Recent transactions filtered by period (Daily / Weekly / Monthly)

### Community
- Posts, comments (with replies), likes, saves
- Realtime updates; rich text (bold, italic, underline, bullets, spoilers)
- Notifications (posts, comments, likes, replies, comment likes)

### Authentication
- Email/password sign in and sign up
- OTP verification for signup and password reset
- OAuth for Google, Facebook, Apple
- Profile management with avatar upload; account deletion

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

The app uses five Edge Functions for AI features (plus a shared module):

1. **`parse-natural-language-transaction`** — requires `GEMINI_API_KEY`
2. **`speech-to-text`** — requires `DEEPGRAM_API_KEY`
3. **`parse-receipt`** — requires `GEMINI_API_KEY`
4. **`parse-bank-notification`** — requires `GEMINI_API_KEY`
5. **`finance-chatbot`** — requires `CHATBOT_GEMINI_API_KEY` (separate quota)

Deploy:
```bash
supabase functions deploy parse-natural-language-transaction
supabase functions deploy speech-to-text
supabase functions deploy parse-receipt
supabase functions deploy parse-bank-notification
supabase functions deploy finance-chatbot
supabase secrets set GEMINI_API_KEY=your_key
supabase secrets set DEEPGRAM_API_KEY=your_key
supabase secrets set CHATBOT_GEMINI_API_KEY=your_key
```

> **Note:** `AuthService.deleteAccount()` invokes a `delete-account` Edge Function. It is referenced in code but not present in `supabase/functions/` — deploy one before relying on account deletion.

## Project Structure

```
lib/
├── app/
│   ├── screens/            # Home, Community, Profile, CommunityPostDetail, AiScreen (roadmap)
│   └── shell/              # MainShell, FinFlowApp (AppRoutes), BottomNavBar
├── core/
│   ├── config/             # Environment configuration
│   ├── constants/          # Supabase URL/keys
│   ├── i18n/               # AppLanguage, AppStrings (bilingual)
│   ├── services/           # App init notifier
│   ├── theme/              # AppColors, FinFlowColors, AppTheme, AppThemeManager
│   ├── utils/              # Responsive helper
│   └── widgets/            # NotificationBell, FinFlowLogo, etc.
├── features/
│   ├── auth/               # Sign in, sign up, OTP, password reset, change password, delete account
│   ├── budget/             # Budget setup + per-category budgets
│   ├── chatbot/            # Real AI assistant (conversations, streaming, images)
│   ├── community/          # Real community feed, posts, comments, likes, notifications
│   ├── debug/              # Database viewer
│   ├── finance/            # TRANSACTIONS, WALLETS, GOALS, QUICK ADD, DASHBOARD
│   │   ├── models/         # TransactionModel, QuickAddDraft, GoalModel, WalletModel, etc.
│   │   ├── presentation/   # Screens, sheets, widgets (QuickAddCard, GoalUi, etc.)
│   │   ├── providers/      # Riverpod providers
│   │   └── services/       # Services (incl. QuickAddService, ReceiptScanService)
│   ├── launch/             # Launch and onboarding screens
│   ├── notification_import/# Bank/e-wallet notification import (Android)
│   ├── profile/            # Edit profile screen
│   ├── scan/               # Receipt scanning (real, via parse-receipt)
│   └── settings/           # Settings, budget limits, security screens
android/app/src/main/kotlin/com/finflow/  # Native bank-notification listener + MethodChannel
assets/
├── icons/                  # SVG icons (incl. categories, chatbot)
├── images/                 # Cover/background images
├── logos/banks/            # 27 bank logos
├── logos/ewallets/         # 9 e-wallet + cash + other logos
├── fonts/                  # Manrope, Hanken Grotesk
supabase/
├── functions/              # 5 Edge Functions + _shared modules
└── migrations/             # 25 SQL migrations (001-025)
scripts/                    # Test scripts for Edge Functions
test/                       # Unit + widget tests across features
```

## Packages Used

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management / providers |
| `supabase_flutter` | Auth, database, storage, Edge Functions, Realtime |
| `fl_chart` | Dashboard + chatbot charts |
| `flutter_svg` | SVG icon rendering |
| `image_picker` | Avatar, receipt, and chat image selection |
| `record` | Audio recording for voice Quick Add |
| `speech_to_text` | On-device speech recognition |
| `http` | Streaming SSE from `finance-chatbot` |
| `shared_preferences` | Language + legacy bank-import config |
| `visibility_detector` | Screen visibility tracking |
| `sqflite` / `path` | Present in Flutter deps but unused (native layer has its own SQLite) |

## Edge Functions

### `parse-natural-language-transaction`
- **Runtime:** Deno (TypeScript)
- **AI:** Google Gemini (default `gemini-3.1-flash-lite`)
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

### `parse-receipt`
- **Runtime:** Deno (TypeScript)
- **AI:** Gemini (image input, constrained JSON schema)
- **Input:** `{ imageBase64, mimeType, locale, categories[] }` (max 8MB)
- **Output:** merchant, date, currency, line items (name/amount/category/confidence), total, warnings
- **Auth:** Bearer token (Supabase JWT)

### `parse-bank-notification`
- **Runtime:** Deno (TypeScript)
- **AI:** Gemini
- **Input:** `{ packageName, title, text, postedAt, currentDateTime, categories[] }`
- **Output:** `{ isTransaction, type, amount, name, categoryKey, date, confidence, warnings }`
- **Auth:** Bearer token (Supabase JWT)

### `finance-chatbot`
- **Runtime:** Deno (TypeScript)
- **AI:** Gemini + financial context (profiles, transactions, wallets, goals)
- **Input:** `{ message, locale, timezone, currentDate, history[], imagePath?, imageMimeType? }`
- **Output:** `{ reply, insight?, chart? }` — streaming (SSE) and non-streaming
- **Auth:** Bearer token (Supabase JWT); uses `CHATBOT_GEMINI_API_KEY`

## Testing

```powershell
flutter test
```

The test suite covers:
- Quick Add service: response validation, wallet resolution, transfer detection, draft conversion
- Quick Add voice service: recording lifecycle, permissions, transcription handling, file cleanup
- Quick Add speech recognition service and flow
- Receipt scan service + screen
- Chatbot service + screen
- Bank notification import models + service
- Community topics, models, comment thread, rich text formatter
- Theme, settings budget limits, bottom nav, home screen

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
- Check that `GEMINI_API_KEY`, `DEEPGRAM_API_KEY`, and `CHATBOT_GEMINI_API_KEY` are set in Supabase secrets
- Verify the Edge Functions are deployed with `supabase functions list`
- Check function logs in Supabase dashboard

## Notes

- This project uses `flutter_svg` for rendering SVG icons from the Figma design.
- The app uses `flutter_riverpod` for state management.
- Icons are stored as SVG in `assets/icons/` and referenced via `SvgPicture.asset()`.
- Custom categories are currently in-memory only (lost after app restart).
- Wallets are simplified to two system sources per user: **Cash** and **Transfer** (the DB `type` is `cash` / `transfer`; the display `name` is `Cash` / `Transfer`).
- Bank notification import works on Android and requires Notification Access + POST_NOTIFICATIONS (Android 13+).
- Supabase project URL and anon key are in `lib/core/constants/supabase_constants.dart`.
