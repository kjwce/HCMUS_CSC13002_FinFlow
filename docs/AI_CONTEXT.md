# AI Context

## Project Purpose

FinFlow is a Flutter mobile app for personal finance tracking. It helps users record income and expenses, connect those transactions to wallets or bank accounts, monitor monthly and weekly spending against budget limits, and view dashboard charts and transaction history for financial insight. The app also features AI-powered natural-language and voice transaction input via Supabase Edge Functions.

The app is currently a mobile-first Flutter project backed by:
- **Supabase** for authentication, database (PostgreSQL), storage (avatars), Edge Functions runtime, and **Realtime** for community live updates.
- **Google Gemini 2.5 Flash** for natural-language transaction parsing (via Edge Function).
- **Deepgram Nova-3** for speech-to-text transcription (via Edge Function).

## Target Users

- Students and young professionals tracking daily income and spending.
- Users who want a simple personal finance assistant with Vietnamese banking and e-wallet concepts.
- Users who need budget monitoring, saving goals, and basic spending analytics.
- Vietnamese users who prefer natural-language and voice input for transaction recording.
- Users who engage in a community for financial tips and discussions.

## Main Features

### Core Features
- Launch, onboarding, full auth flow (email/password, OTP, password reset).
- Payment-source onboarding for cash and a shared transfer source.
- Monthly budget setup and weekly budget editing.
- Transaction CRUD with wallet awareness.
- Transaction History screen with day grouping, filters, and quick insights.
- Goal CRUD and progress display.
- Profile display, edit, and avatar upload.

### Home Dashboard
- Total balance and monthly expense summary with budget progress bar.
- Configurable goal summary card with metric picker (revenue/expense by day/week/month/year).
- Category expense tracking (selectable from all categories).
- Period tabs (Daily/Weekly/Monthly) for transaction list.
- **Quick Add card** with text input, mic button, and submit.
- Floating "View All" entry to Transaction History.

### Quick Add (Natural Language)
- Type or paste transaction description (e.g. "Ăn trưa 50k bằng MoMo hôm qua").
- Sent to `parse-natural-language-transaction` Edge Function → Gemini 2.5 Flash.
- Returns structured data: type, amount, name, category, wallet, date, confidence, warnings.
- Review sheet shows detected fields with missing-field tracking.
- Confirm directly or edit details in the Add Transaction form.
- Supports Vietnamese, English, and mixed input.
- Detects unsupported transfers (e.g. "Chuyển 500k từ MoMo sang MB").

### Quick Add (Voice — Recording-based)
- Tap mic → record audio (WAV, 16kHz, mono, 30s max).
- Audio sent to `speech-to-text` Edge Function → Deepgram Nova-3 (Vietnamese).
- Transcript auto-injected into Quick Add text field and submitted.
- Full permission handling (microphone denied → user-friendly error).
- Temporary audio files cleaned up after use.

### Quick Add (Voice — On-device Speech Recognition)
- Tap mic → on-device `speech_to_text` recognition.
- No Edge Function needed, works offline.
- Automatic Vietnamese locale detection (vi_VN/vi-VN → system locale fallback).
- Partial results delivered in real time, final transcript auto-injected.
- Separate from the recording-based flow (uses `SpeechToText` platform plugin).

### Transaction Saved Confirmation
- Full-screen confirmation after saving a transaction.
- Shows signed amount with INCOME/EXPENSE badge.
- Details card: category icon+name, wallet, current wallet balance.
- [Done] → pop to home. [Add Another] → reopen AddTransactionSheet.

### Analytics Dashboard
- 5 chart types with period selector (Day/Week/Month) and offset navigation.
- Income/Expense/Balance line chart, category donuts, source grouped bars, income-vs-expense comparison.
- Touch tooltips with VND formatting, animated entry (850ms).

### Categories
- 14 built-in categories (8 popular + 6 extended), each with key, label, icon, color.
- In-memory custom category store with icon/color picker.
- Category fallback to "Other" when no match found.

### Community (Social Features)
- **Post CRUD**: create with composer, read in feed/detail, edit, delete with authorization.
- **Comment system**: add, delete, anonymous toggle, author info enrichment.
- **Like/Unlike**: optimistic UI updates with Supabase sync and rollback.
- **Save/Bookmark**: optimistic toggle with rollback.
- **Realtime**: Supabase Realtime pushes new posts, like count changes, and comment updates.
- **Rich text formatting**: posts use marker-based formatting (`**bold**`, `_italic_`, `~underline~`, `• bullet`, `||spoiler||`).
- **Composer**: formatting toolbar, category picker, anonymous toggle, edit mode.
- **Post detail**: full post view, comment list, live comment input bar.
- **CommunityPostCard**: avatar with color-palette initials, category badge, date, formatted body, like/save/comment actions, owner menu.

### Notifications
- Notifications for: new posts from others, comments on posts, likes on posts.
- Realtime delivery via Supabase Realtime (filtered by user_id).
- Notification screen with Today/Earlier grouping, "N New" badge, "Mark all as read".
- NotificationBell widget with live unread count.
- Tap notification → mark as read → navigate to post detail.

## Folder Structure

```text
lib/
  main.dart
  app/
    screens/          # Home, AI, Community, Profile, CommunityPostDetail screens
    shell/            # MainShell, FinFlowApp, BottomNavBar
  core/
    config/           # Environment configuration
    constants/        # Supabase URL/keys
    i18n/             # AppLanguage, AppStrings (bilingual)
    services/         # App init notifier
    theme/            # AppColors, AppTheme, AppThemeManager
    utils/            # Responsive helper
    widgets/          # NotificationBell, FinFlowLogo, LanguageSwitcher, DecoratedPhoneScaffold
  features/
    auth/             # Auth screens, provider, service (Supabase auth)
    budget/           # Budget setup screen
    chatbot/          # Chat screen (static)
    community/        # COMMUNITY (FULLY IMPLEMENTED)
      models/         # CommunityPostModel, CommunityCommentModel, NotificationModel
      presentation/   # CommunityScreen (legacy), CommunityComposerScreen, NotificationScreen
                      # widgets/PostCard
      providers/      # CommunityService provider, NotificationService provider
      services/       # CommunityService (CRUD + realtime), NotificationService (realtime + fetch)
      utils/          # RichTextFormatter, CommunityDateFormat
    debug/            # Database viewer
    finance/          # FINANCE CORE
      models/         # TransactionModel, WalletModel, GoalModel, QuickAddDraft,
                      # TransactionCategory, WalletModel, QuickAddDraftModel
      presentation/   # AddTransactionSheet, DashboardPage, GoalSetupSheet,
                      # QuickAddReviewSheet, TransactionSavedScreen,
                      # WalletOnboardingScreen, TransactionHistoryScreen,
                      # EditTransactionScreen, Widgets/QuickAddCard
      providers/      # Transaction, Wallet, Goal providers
      services/       # TransactionService, WalletService, GoalService,
                      # QuickAddService, QuickAddVoiceService, QuickAddSpeechRecognitionService
    launch/           # Launch, Onboarding screens
    profile/          # Edit profile screen
    scan/             # Scan screen (placeholder)
    settings/         # Settings screen
assets/
  icons/              # SVG icons
  icons/home/         # Home-specific SVG icons (flag, etc.)
  logos/banks/        # 27 bank logos (PNG)
  logos/ewallets/     # 9 e-wallet + cash + other logos (PNG)
  *.png               # Cover/background images
supabase/
  functions/
    parse-natural-language-transaction/index.ts  # Gemini NL parser
    speech-to-text/index.ts                      # Deepgram STT
  migrations/         # 12 SQL migrations (001-012)
  .temp/              # Local Supabase temp files
scripts/
  test_parse_natural_language_transaction.ps1    # Test script for Edge Function
test/
  features/finance/
    quick_add_service_test.dart      # 15+ unit tests
    quick_add_voice_service_test.dart # 10 unit tests
    quick_add_flow_test.dart         # 15+ widget tests
  widget_test.dart
```

## Packages Used

- `flutter_riverpod`: provider layer and dependency access.
- `supabase_flutter`: authentication, database, storage, Edge Functions, **Realtime**.
- `fl_chart`: analytics dashboard charts.
- `flutter_svg`: SVG icon rendering.
- `image_picker`: profile avatar image selection.
- `record`: audio recording for voice Quick Add (WAV, 16kHz, mono).
- `speech_to_text`: on-device speech recognition for live dictation.
- `visibility_detector`: screen visibility tracking.
- `sqflite` and `path`: present in dependencies, but current data flow uses Supabase cloud storage.
- `flutter_lints`: lint rules.

## State Management

The project uses Riverpod, but many state objects are singleton services:

- `AuthService` is a singleton `ChangeNotifier` exposed through `ChangeNotifierProvider`.
- `TransactionService`, `GoalService`, `WalletService`, `CommunityService`, and `NotificationService` are singleton `ChangeNotifier`s exposed through plain `Provider`.
- Some screens manually subscribe to service listeners because plain `Provider` does not rebuild on `notifyListeners`.

Important providers:

- `authServiceProvider`
- `transactionServiceProvider`
- `goalServiceProvider`
- `walletServiceProvider`
- `communityServiceProvider`
- `notificationServiceProvider`
- `languageProvider`

Key behavior:
- `HomeScreen` subscribes to `TransactionService` and `GoalService` via `addListener` in `initState`.
- `QuickAddService`, `QuickAddVoiceService`, and `QuickAddSpeechRecognitionService` are pure controllers (no `ChangeNotifier`), used directly.
- `AddTransactionSheet` and `DashboardPage` use `ref.watch` for services.
- `NotificationBell` uses `ListenableBuilder` wrapping the notification service for live unread count updates.
- `CommunityService` uses `notifyListeners()` after every mutation (create, edit, delete, like, save, comment).

## Backend

### Supabase
Supabase provides authentication, PostgreSQL database, storage, and Edge Functions runtime.

Tables:
- `profiles`: public user profile linked to `auth.users`.
- `transactions`: user transactions with name, category, amount, date, optional wallet_id.
- `wallets`: exactly two system sources per user (`cash`, `transfer`) with initial balances.
- `goals`: saving goals with target_amount.
- `budgets`: per-category budget table (schema only, not used by app UI).
- `community_posts`: posts with content, category, anonymous/spoiler flags, likes_count, comments_count.
- `community_likes`: likes (unique per post_id + user_id), auto-updates likes_count via trigger.
- `community_saves`: bookmarks (unique per post_id + user_id).
- `community_comments`: comments with post_id, user_id, content, anonymous flag.
- `community_post_reports`: report posts (unique per post_id + reporter_id).
- `community_comment_reports`: report comments (unique per comment_id + reporter_id).
- `community_notifications`: activity notifications (user_id type actor_id post_id), marked is_read.
- `community_media`: post image/media attachments (schema exists, not used by UI).

Views:
- `community_authors`: SELECT id, full_name, avatar_url FROM profiles — used for client-side author enrichment.

Triggers:
- `community_adjust_likes_count`: INSERT/DELETE on community_likes → update likes_count.
- `community_adjust_comments_count`: INSERT/DELETE on community_comments → update comments_count.
- `community_notify_post_activity`: INSERT on community_posts → create notifications for all other users.
- `community_notify_comment_activity`: INSERT on community_comments → create notifications for post owner.
- `community_notify_like_activity`: INSERT on community_likes → create notification for post owner.
- `community_backfill_new_profile_notifications`: INSERT on profiles → backfill existing post/comment notifications.

RLS: All tables have RLS policies restricting user-owned data to the authenticated owner. Community read operations are public to authenticated users. Notification reads/updates restricted to the owning user.

Realtime: `community_notifications` is added to `supabase_realtime` publication.

### Supabase Edge Functions
Two Deno/TypeScript Edge Functions are deployed:

1. **`parse-natural-language-transaction`**
   - Endpoint: `POST /functions/v1/parse-natural-language-transaction`
   - Calls Google Gemini 2.5 Flash (`gemini-2.5-flash`) with constrained JSON schema output.
   - Accepts: text, currentDate, currentDateTime, timezone, locale, categories[], wallets[].
   - Returns: `{ success, version, data: { type, amount, name, categoryKey, walletName, date, confidence, warnings } }`.
   - Validates input (max 500 chars), authenticates via Bearer token, sanitizes response.
   - Timeout: 20s. Model can be overridden via `GEMINI_MODEL` env var.
   - Error codes: UNAUTHORIZED, INVALID_REQUEST, EMPTY_TEXT, TEXT_TOO_LONG, GEMINI_RATE_LIMITED, GEMINI_UNAVAILABLE, INVALID_MODEL_OUTPUT, INTERNAL_ERROR.
   - Bilingual error messages (vi-VN, en-US).

2. **`speech-to-text`**
   - Endpoint: `POST /functions/v1/speech-to-text`
   - Calls Deepgram Nova-3 (`nova-3`, language: `vi`) with smart formatting.
   - Accepts: raw audio bytes with `Content-Type` header.
   - Supported MIME types: `audio/mp4`, `audio/mpeg`, `audio/wav`, `audio/x-wav`, `audio/aac`, `audio/ogg`, `audio/webm`, `audio/flac`.
   - Max audio size: 5MB.
   - Returns: `{ success, version, data: { transcript } }`.
   - Authenticates via Bearer token.
   - Error codes: UNAUTHORIZED, INVALID_REQUEST, INVALID_CONTENT_TYPE, EMPTY_AUDIO, AUDIO_TOO_LARGE, UNSUPPORTED_AUDIO, EMPTY_TRANSCRIPT, DEEPGRAM_RATE_LIMITED, DEEPGRAM_UNAVAILABLE, INTERNAL_ERROR.

### Environment Variables
Edge Functions require:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_PUBLISHABLE_KEYS`
- `GEMINI_API_KEY` (for parser function)
- `DEEPGRAM_API_KEY` (for speech-to-text function)
- `GEMINI_MODEL` (optional, defaults to `gemini-2.5-flash`)

## Authentication

Authentication is centralized in `AuthService`.

Supported flows in code:

- Email/password sign in.
- Email/password signup with OTP verification.
- Forgot password and new password flow.
- OAuth method stubs for Google, Facebook, and Apple using Supabase OAuth.
- Password recovery event listener routes to `/new-password`.
- Sign out clears local user state before calling Supabase sign out.
- User profile fields: fullName, email, phone, budgetLimit, weeklyBudget, avatarUrl, selectedCategory.
- `selectedCategory` and `weeklyBudget` use in-memory override fallback for DB schema migration.
- `needsBudgetSetup` property guides post-auth routing.

## Routing

Routes are declared in `AppRoutes` inside `finflow_app.dart`.

Key routes:

- `/`: launch screen.
- `/onboarding`: login/signup option screen.
- `/sign-in`, `/sign-up`, `/verify`, `/forgot-password`, `/new-password`.
- `/wallet-onboarding`, `/budget-setup`.
- `/dashboard`, `/settings`, `/chat`, `/scan`, `/community`.
- `/edit-profile`, `/database-viewer`.
- `/notifications` → NotificationScreen (added).

The launch screen navigates to onboarding after a short delay. Sign-in routes to wallet onboarding or dashboard based on budget setup state. `MainShell` can receive a tab index argument for direct tab navigation. `MainShell` initializes `NotificationService` on user load.

Notifications route is `/notifications`. Community post detail is navigated via direct `MaterialPageRoute` (not in routes map).

## Theme

Theme is centralized in:

- `core/theme/app_colors.dart` — expanded palette with 10+ semantic colors.
- `core/theme/app_theme.dart`
- `core/theme/app_theme_manager.dart`

The app uses Material 3 with a green finance-oriented visual identity. Dark mode is available through `AppThemeManager`, but many screens still use hardcoded colors.

## Assets

Assets include:

- Cover/background images: home, profile, settings, edit profile, scan.
- SVG icons for navigation, profile actions, notification, Google icon, chart, logo, flag.
- 27 bank logos under `assets/logos/banks/`.
- 9 e-wallet logos + cash + other under `assets/logos/ewallets/`.
- Fonts: Manrope, Hanken Grotesk, Poppins, Roboto.

Legacy bank and e-wallet logo assets remain available but are no longer selected by the UI.

## Current Completed Features

### Core
- App startup and route table.
- Supabase initialization (background, non-blocking).
- Full auth flow (email/password, OTP, password reset, OAuth stubs).
- Profile fetch/update/avatar upload.
- Payment-source onboarding (cash and transfer).
- Budget setup and editing (monthly + weekly).
- Transaction CRUD with wallet awareness.
- Transaction History with daily grouping and quick insights.
- Goal CRUD and progress display.
- TransactionSavedScreen confirmation.

### Quick Add (Natural Language)
- `QuickAddDraft` model with full validation.
- `QuickAddService` — invokes Edge Function, validates response, resolves wallets, detects transfers.
- `QuickAddReviewSheet` — review before save.
- `QuickAddCard` — input UI with text/mic/submit.
- Seamless missing-field handoff to `AddTransactionSheet`.

### Quick Add (Voice — Recording)
- `QuickAddVoiceService` — recording lifecycle with `record` package.
- Audio → Edge Function → Deepgram Nova-3 → transcript → auto-submit.
- 30-second recording timeout, microphone permission handling.
- Temporary file cleanup.
- Abstracted recorder driver and file store for testing.

### Quick Add (Voice — On-device Speech Recognition)
- `QuickAddSpeechRecognitionService` — on-device dictation via `speech_to_text`.
- Automatic Vietnamese locale detection.
- Partial result streaming, final result auto-submit.
- `QuickAddSpeechDriver` abstraction for testability.

### Dashboard & Charts
- 5 chart types with period/offset navigation.
- Animated entry, touch tooltips, empty state placeholders.
- Cached period buckets and breakdowns.

### Home Screen
- Budget progress bar, configurable goal summary, category tracking.
- Period tabs, Quick Add integration, floating "View All".
- Voice recording and on-device speech recognition integration.

### Community (Full)
- Post CRUD with category, anonymous, spoiler support.
- Comment system with anonymous toggle.
- Like/unlike with optimistic updates.
- Save/bookmark with optimistic updates.
- 4 Realtime channels for live updates.
- Rich text composer with formatting toolbar.
- Rich content renderer (bold, italic, underline, bullets, spoilers).
- Post detail screen with live comment section.
- Post card with color avatar, category, date, formatted content, actions, owner menu.

### Notifications
- `NotificationService` with Realtime subscription.
- Notification types: post, like, comment.
- Notification enrichment (actor name/avatar, post preview).
- Notification screen with Today/Earlier grouping.
- NotificationBell widget with live unread badge.
- Mark read / mark all read.

### Backend
- 12 Supabase migrations (001-012).
- Community schema: 7 tables + 1 view + 5 triggers.
- Cross-account support, notification backfill, Realtime publication.
- RLS policies for community features.

### Testing
- 40+ tests across Quick Add service, voice service, and widget flow.

## Features Under Development

- AI assistant screen is a roadmap UI.
- Chatbot screen uses static sample messages.
- Scan screen is a receipt scanning placeholder.
- Community screen bottom-nav tab still uses old static placeholder; real community feed is accessed via routes/notifications.
- Database viewer is a debug-oriented Supabase summary, not a full database browser.
- Comment editing (delete only currently supported).
- Post report UI (backend tables exist but no UI).
- Community media uploads (backend `community_media` table exists but no UI).

## Important Services

- `AuthService`: Supabase init, auth, profile, avatar upload, selected category, weekly budget.
- `TransactionService`: transaction CRUD and finance computations (cached).
- `WalletService`: wallet CRUD and initial balance totals.
- `GoalService`: saving goal CRUD and progress.
- `QuickAddService`: NL text → Edge Function → QuickAddDraft.
- `QuickAddVoiceService`: audio recording → Edge Function → transcript → text.
- `QuickAddSpeechRecognitionService`: on-device speech → text.
- `CommunityService`: post/comment/like/save CRUD + Realtime subscriptions.
- `NotificationService`: notification fetch, Realtime, mark read.
- `AppThemeManager`: app theme mode.
- `AppLanguage`: simple language toggle and string access.

## Database Overview

Main tables:

- `profiles`: public user profile (id, full_name, email, phone, avatar_url, budget_limit, weekly_budget, selected_category).
- `transactions`: user transactions (id, user_id, name, category, amount, date, wallet_id).
- `wallets`: user wallets (id, user_id, name, short_name, logo_asset_path, brand_color, type, initial_balance, is_active).
- `goals`: saving goals (id, user_id, name, target_amount, created_at, is_active).
- `budgets`: per-category budget table (present in schema, not actively used by app UI).
- `community_posts`: posts (id, user_id, content, is_anonymous, is_spoiler, category, likes_count, comments_count, created_at).
- `community_likes`: likes (unique post_id + user_id).
- `community_saves`: bookmarks (unique post_id + user_id).
- `community_comments`: comments (post_id, user_id, content, is_anonymous).
- `community_notifications`: notifications (user_id, actor_id, post_id, comment_id, type, is_read).
- `community_post_reports`: post reports (reporter_id, reason, status).
- `community_comment_reports`: comment reports.
- `community_media`: post media attachments (url, media_type).

View: `community_authors` = profiles(id, full_name, avatar_url) for author enrichment.

RLS policies restrict user-owned data to the authenticated owner. Community posts are readable by all authenticated users. Notifications are only readable/updatable by the owning user.

Realtime: `community_notifications` is published via `supabase_realtime`.

## Known Limitations

- The launch screen does not automatically skip onboarding for an existing session.
- Provider usage is inconsistent: some `ChangeNotifier` services are exposed through plain `Provider`.
- Custom categories are stored only in memory and are lost after app restart.
- Some UI strings are hardcoded despite having `AppStrings`.
- Some features are placeholders, especially AI, scan, chatbot, and the bottom-nav Community tab.
- Supabase keys are currently stored in source constants.
- `GEMINI_API_KEY` and `DEEPGRAM_API_KEY` must be set in Supabase Edge Function secrets.
- `flutter analyze` was attempted previously but timed out in the local environment.
- Edge Functions use Vietnamese as default locale for speech-to-text; English-only audio may have lower accuracy.
- Community post detail and composer use hardcoded color constants instead of theme tokens.
- No tests for community features yet (posts, comments, likes, notifications).
