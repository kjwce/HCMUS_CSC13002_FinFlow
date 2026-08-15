# AI Context

## Project Purpose

FinFlow is a Flutter mobile app for personal finance tracking. It helps users record income and expenses, connect those transactions to wallets (cash / transfer), monitor daily/weekly/monthly spending against budget limits, and view dashboard charts and transaction history for financial insight. The app features AI-powered natural-language, voice, receipt-scanning, bank-notification import, and a conversational financial assistant, all via Supabase Edge Functions.

The app is currently a mobile-first Flutter project backed by:
- **Supabase** for authentication, database (PostgreSQL), storage (avatars, chat images), Edge Functions runtime, and **Realtime** for community live updates.
- **Google Gemini** for natural-language transaction parsing, receipt extraction, bank-notification parsing, and the financial chatbot (via Edge Functions; default `gemini-3.1-flash-lite`).
- **Deepgram Nova-3** for speech-to-text transcription (via Edge Function).
- **Android NotificationListenerService** (Kotlin) for native bank/e-wallet transaction detection.

## Target Users

- Students and young professionals tracking daily income and spending.
- Users who want a simple personal finance assistant with Vietnamese banking and e-wallet concepts.
- Users who need budget monitoring, saving goals, and basic spending analytics.
- Vietnamese users who prefer natural-language, voice, and receipt input for transaction recording.
- Users who engage in a community for financial tips and discussions.

## Main Features

### Core Features
- Launch, onboarding, full auth flow (email/password, OTP, password reset, change password, account deletion).
- Payment-source onboarding for cash and a shared transfer source.
- Monthly + daily + weekly budget setup and editing.
- Transaction CRUD with wallet awareness and goal-aware RPCs.
- Transaction History screen with day grouping, filters, and quick insights.
- Advanced saving goals (auto allocation, protection, redirect, shortfall handling).
- Profile display, edit, and avatar upload.
- Per-category monthly budgets.

### Home Dashboard
- Stitch hero + balance glass card with budget progress.
- Refined goals section + configurable goal summary card (metric picker).
- Category expense tracking and **category budget section**.
- Period tabs (Daily/Weekly/Monthly) for transaction list.
- **Quick Add card** with text input, mic button, and submit.
- Floating "View All" entry to Transaction History.

### Quick Add (Natural Language)
- Type or paste transaction description (e.g. "Ăn trưa 50k bằng MoMo hôm qua").
- Sent to `parse-natural-language-transaction` Edge Function → Gemini.
- Returns structured data: type, amount, name, category, wallet, date, confidence, warnings.
- Review sheet shows detected fields with missing-field tracking.
- Confirm directly or edit details in the Add Transaction form.
- Supports Vietnamese, English, and mixed input.
- Detects unsupported transfers (e.g. "Chuyển 500k từ MoMo sang MB").

### Quick Add (Voice — Recording-based)
- Tap mic → record audio (WAV, 16kHz, mono, 30s max).
- Audio sent to `speech-to-text` Edge Function → Deepgram Nova-3 (Vietnamese).
- Transcript auto-injected into Quick Add text field and submitted.
- Full permission handling; temporary audio files cleaned up.

### Quick Add (Voice — On-device Speech Recognition)
- Tap mic → on-device `speech_to_text` recognition (works offline).
- Automatic Vietnamese locale detection; partial results in real time.

### Receipt Scanning
- Take/select a receipt image in `ScanScreen` (tab or embedded in Add Transaction).
- Sent to `parse-receipt` Edge Function → Gemini extracts merchant, date, currency, line items, total, warnings.
- Review UI adjusts items before saving as transactions.

### Bank Notification Import (Android)
- Native listener reads bank/e-wallet notifications (Notification Access), redacts account numbers, filters OTP/security, enqueues in SQLite.
- `parse-bank-notification` Edge Function decides if a notification is a transaction and parses it.
- `QuickAddReviewSheet` lets the user confirm; saves with `isImported: true` (auto-withdraw goal shortfall policy).
- Configuration screen with 14 supported banks/e-wallets and permission guidance.

### AI Financial Assistant (Chatbot)
- Real conversation with the `finance-chatbot` Edge Function (Gemini + financial context).
- Intent classification: general chat vs. app finance questions.
- Streaming responses, conversation history (rename/delete/switch), image attachments.
- Insight cards and chart cards (bar/donut) from reply presets.

### Transaction Saved Confirmation
- Full-screen confirmation after saving (signed amount, category, wallet, current balance).
- [Done] → pop to home; [Add Another] → reopen AddTransactionSheet.

### Analytics Dashboard
- 5 chart types with period selector (Day/Week/Month) and offset navigation.
- Income/Expense/Balance line chart, category donuts, source grouped bars, income-vs-expense comparison.
- Touch tooltips with VND formatting, animated entry.

### Categories
- 14 built-in categories (8 popular + 6 extended), each with key, label, icon, color.
- In-memory custom category store with icon/color picker.
- Category fallback to "Other".

### Community (Social Features)
- **Post CRUD**, **comments** (anonymous toggle, author enrichment), **recursive replies**, **comment likes**.
- **Like/Unlike**, **Save/Bookmark** with optimistic updates.
- **Realtime** channels for posts, likes, comments, notifications.
- **Rich text formatting** (`**bold**`, `_italic_`, `~underline~`, `• bullet`, `||spoiler||`).
- **Composer** with formatting toolbar; **post detail** with thread view; **topic-driven feed** tab.

### Notifications
- Notifications for: new posts, comments, likes, comment replies, comment likes.
- Realtime delivery; Today/Earlier grouping; "N New" badge; Mark all as read.
- NotificationBell widget with live unread count; tap → post detail.

## Folder Structure

```text
lib/
  main.dart
  app/
    screens/          # Home, Community, Profile, CommunityPostDetail, AiScreen (roadmap)
    shell/            # MainShell, FinFlowApp (AppRoutes), BottomNavBar
  core/
    config/           # Environment configuration
    constants/        # Supabase URL/keys
    i18n/             # AppLanguage, AppStrings (bilingual)
    services/         # App init notifier
    theme/            # AppColors, FinFlowColors, AppTheme, AppThemeManager
    utils/            # Responsive helper
    widgets/          # NotificationBell, FinFlowLogo, LanguageSwitcher, TransactionTile,
                      # TypeChip, DecoratedPhoneScaffold
  features/
    auth/             # Auth screens, provider, service
    budget/           # Budget setup + per-category budgets (model/service/provider/screens)
    chatbot/          # Real AI assistant: models, provider, service, presentation
    community/        # FULL community: models, presentation (feed, composer, detail,
                      #   notifications, activity), providers, services, utils
    debug/            # Database viewer
    finance/          # FINANCE CORE
      models/         # TransactionModel, WalletModel, GoalModel (+GoalFundEntry, GoalSettings),
                      # QuickAddDraft, TransactionCategory, QuickAddDraftModel
      presentation/   # AddTransactionSheet, DashboardPage, GoalSetupSheet, GoalSheets,
                      # GoalFormScreen, GoalDetailsScreen, SavingGoalsScreen,
                      # QuickAddReviewSheet, TransactionSavedScreen, WalletOnboardingScreen,
                      # TransactionHistoryScreen, EditTransactionScreen,
                      # Widgets/QuickAddCard, Widgets/GoalUi
      providers/      # Transaction, Wallet, Goal providers
      services/       # TransactionService, WalletService, GoalService,
                      # QuickAddService, QuickAddVoiceService, QuickAddSpeechRecognitionService
    launch/           # Launch, Onboarding screens
    notification_import/ # Bank notification import (models, presentation, services)
    profile/          # Edit profile screen
    scan/             # Real receipt scanning (models, presentation, services)
    settings/         # Settings, budget limits, security screens
android/app/src/main/kotlin/com/finflow/
  BankNotificationListenerService.kt
  BankNotificationStore.kt
  BankTransactionNotificationPresenter.kt
  NotificationListenerRebindReceiver.kt
  MainActivity.kt
assets/
  icons/              # SVG icons (incl. categories, chatbot, home, profile)
  images/             # Cover/background images
  logos/banks/        # 27 bank logos (PNG)
  logos/ewallets/     # 9 e-wallet + cash + other logos (PNG)
  fonts/              # Manrope, Hanken Grotesk
supabase/
  functions/
    parse-natural-language-transaction/index.ts  # Gemini NL parser
    speech-to-text/index.ts                      # Deepgram STT
    parse-receipt/index.ts                       # Gemini receipt parser
    parse-bank-notification/index.ts             # Gemini bank-notification parser
    finance-chatbot/index.ts                     # Gemini financial chatbot
    _shared/chat_intent.ts                       # intent classifier
    _shared/receipt_parser.ts                    # receipt validation/sanitization
  migrations/         # 25 SQL migrations (001-025)
scripts/
  test_parse_natural_language_transaction.ps1    # Test script for Edge Function
test/                 # Unit + widget tests across features
```

## Packages Used

- `flutter_riverpod`: provider layer and dependency access.
- `supabase_flutter`: authentication, database, storage, Edge Functions, **Realtime**.
- `fl_chart`: dashboard + chatbot chart rendering.
- `flutter_svg`: SVG icon rendering.
- `image_picker`: profile avatar, receipt, and chat image selection.
- `record`: audio recording for voice Quick Add (WAV, 16kHz, mono).
- `speech_to_text`: on-device speech recognition for live dictation.
- `http`: streaming SSE from `finance-chatbot`.
- `shared_preferences`: language + legacy bank-import config.
- `visibility_detector`: screen visibility tracking.
- `sqflite` and `path`: present in Flutter deps (the native Kotlin layer has its own SQLite); current Flutter data flow uses Supabase cloud storage.
- `flutter_lints`: lint rules.

## State Management

The project uses Riverpod, but many state objects are singleton services:

- `AuthService` and `ChatController` are singletons exposed through `ChangeNotifierProvider`.
- `TransactionService`, `GoalService`, `WalletService`, `CommunityService`, `NotificationService`, and `CategoryBudgetService` are singleton `ChangeNotifier`s exposed through plain `Provider`.
- Some screens manually subscribe to service listeners because plain `Provider` does not rebuild on `notifyListeners`.

Important providers:

- `authServiceProvider`
- `transactionServiceProvider`
- `goalServiceProvider`
- `walletServiceProvider`
- `communityServiceProvider`
- `notificationServiceProvider`
- `categoryBudgetServiceProvider`
- `chatControllerProvider`
- `languageProvider`

Key behavior:
- `HomeScreen` subscribes to `TransactionService` and `GoalService` via `addListener` in `initState`.
- `QuickAddService`, `QuickAddVoiceService`, `QuickAddSpeechRecognitionService`, `ReceiptScanService`, and `ChatService` are controllers used directly.
- `NotificationBell` uses `ListenableBuilder` wrapping the notification service for live unread count updates.
- `CommunityService` uses `notifyListeners()` after every mutation.

## Backend

### Supabase
Supabase provides authentication, PostgreSQL database, storage, and Edge Functions runtime.

Tables (current, after 25 migrations):
- `profiles`: public user profile (id, full_name, email, phone, avatar_url, budget_limit, daily_budget, weekly_budget, selected_category).
- `transactions`: user transactions (id, user_id UUID→profiles, name, category, amount, date, wallet_id).
- `wallets`: exactly two system sources per user (`cash` / `transfer`), display names `Cash` / `Transfer`, with initial balances; created by a profile trigger.
- `goals`: saving goals with target_amount (BIGINT), category, target_date, funding_method, auto_allocation_percent, is_primary, is_protected, withdrawal_priority, status, completion_behavior, redirect_goal_id, image_url.
- `goal_fund_entries`: ledger of allocations/withdrawals (entry_type: initial, manual_allocation, automatic_allocation, manual_withdrawal, expense_withdrawal, completion_transfer).
- `goal_settings`: per-user expense shortfall policy (ask_each_time / auto_withdraw) and imported transaction policy (auto_withdraw).
- `budgets`: per-category monthly budgets (user_id, category, limit_amount, month, year) — used by category-budget feature.
- `chat_conversations` / `chat_messages`: AI assistant history (role, message, insight, chart, image_path, image_mime_type, sequence_number).
- Community tables: `community_posts`, `community_likes`, `community_saves`, `community_comments` (with parent_comment_id, likes_count), `community_comment_likes`, `community_post_reports`, `community_comment_reports`, `community_notifications`, `community_media`.

Views:
- `community_authors`: SELECT id, full_name, avatar_url FROM profiles — used for client-side author enrichment.

Triggers (notable):
- Community: like/comment count adjustments, post/comment/like notification creation, comment reply + comment-like notifications, backfill for new profiles.
- `create_default_wallets` — new profile gets cash + transfer wallets.
- `touch_chat_conversation` / `assign_chat_message_sequence` — chat history maintenance.
- `validate_goal_auto_percentages`, `enforce_goal_actual_balance` (constraint triggers on transactions/wallets), `ensure_default_goal_settings`.
- Profile auto-create on user signup.

RLS: All tables have RLS policies restricting user-owned data to the authenticated owner. Community read operations are public to authenticated users. Goal writes go through SECURITY DEFINER RPCs. Notification reads/updates restricted to the owning user.

Realtime: `community_notifications` (and `community_comments`, `community_comment_likes`) are in `supabase_realtime`.

### Supabase Edge Functions

1. **`parse-natural-language-transaction`**
   - Endpoint: `POST /functions/v1/parse-natural-language-transaction`
   - Calls Gemini (default `gemini-3.1-flash-lite`) with constrained JSON schema output.
   - Accepts: text, currentDate, currentDateTime, timezone, locale, categories[], wallets[].
   - Returns: `{ success, version, data: { type, amount, name, categoryKey, walletName, date, confidence, warnings } }`.
   - Validates input (max 500 chars), authenticates via Bearer token, sanitizes response.
   - Timeout: 20s. Model can be overridden via `GEMINI_MODEL` env var.
   - Error codes: UNAUTHORIZED, INVALID_REQUEST, EMPTY_TEXT, TEXT_TOO_LONG, GEMINI_RATE_LIMITED, GEMINI_UNAVAILABLE, INVALID_MODEL_OUTPUT, INTERNAL_ERROR. Bilingual errors.

2. **`speech-to-text`**
   - Endpoint: `POST /functions/v1/speech-to-text`
   - Calls Deepgram Nova-3 (`nova-3`, language: `vi`) with smart formatting.
   - Accepts: raw audio bytes with `Content-Type` header.
   - Supported MIME types: `audio/mp4`, `audio/mpeg`, `audio/wav`, `audio/x-wav`, `audio/aac`, `audio/ogg`, `audio/webm`, `audio/flac`. Max 5MB.
   - Returns: `{ success, version, data: { transcript } }`. Authenticates via Bearer token.
   - Error codes: UNAUTHORIZED, INVALID_REQUEST, INVALID_CONTENT_TYPE, EMPTY_AUDIO, AUDIO_TOO_LARGE, UNSUPPORTED_AUDIO, EMPTY_TRANSCRIPT, DEEPGRAM_RATE_LIMITED, DEEPGRAM_UNAVAILABLE, INTERNAL_ERROR.

3. **`parse-receipt`**
   - Endpoint: `POST /functions/v1/parse-receipt`
   - Calls Gemini with image inline data + constrained JSON schema (merchantName, receiptDate, currency, items[{name, amount, categoryKey, confidence, warning}], totalAmount, warnings).
   - Accepts: `{ imageBase64, mimeType, locale, categories[] }` (max 8MB image).
   - Authenticates via Bearer token; uses `_shared/receipt_parser.ts`.
   - Timeout: 30s. Errors: UNAUTHORIZED, INVALID_REQUEST, INVALID_IMAGE, IMAGE_TOO_LARGE, GEMINI_RATE_LIMITED, GEMINI_TIMEOUT, GEMINI_UNAVAILABLE, INVALID_MODEL_OUTPUT, INTERNAL_ERROR.

4. **`parse-bank-notification`**
   - Endpoint: `POST /functions/v1/parse-bank-notification`
   - Calls Gemini to classify a bank/e-wallet Android notification as transaction or not.
   - Accepts: `{ packageName, title, text, postedAt, currentDateTime, categories[] }`.
   - Returns: `{ success, version, data: { isTransaction, type, amount, name, categoryKey, date, confidence, warnings } }`.
   - Authenticates via Bearer token. Errors: UNAUTHORIZED, INVALID_REQUEST, GEMINI_RATE_LIMITED, GEMINI_TIMEOUT, GEMINI_UNAVAILABLE, INVALID_MODEL_OUTPUT, INTERNAL_ERROR.

5. **`finance-chatbot`**
   - Endpoint: `POST /functions/v1/finance-chatbot` (also streaming via `Accept: text/event-stream`).
   - Calls Gemini with grounded financial context (profiles, transactions, wallets, goals) loaded server-side.
   - Intent classification (`general` / `app_finance`) via `_shared/chat_intent.ts`.
   - Returns: `{ success, version, data: { reply, insight?, chart? } }` where chart is one of preset charts built server-side (weekly_expense_comparison, category_expenses_current_month, income_expense_current_month, budget_progress_current_month).
   - Uses its own `CHATBOT_GEMINI_API_KEY` (separate quota from Quick Add).
   - Streaming: SSE events `delta`, `done`, `error`. Timeout 20s.
   - Errors: UNAUTHORIZED, INVALID_REQUEST, INVALID_IMAGE, DATA_UNAVAILABLE, GEMINI_RATE_LIMITED, GEMINI_TIMEOUT, GEMINI_UNAVAILABLE, INVALID_MODEL_OUTPUT, INTERNAL_ERROR.

6. **`delete-account`** — referenced by `AuthService.deleteAccount()` (in `lib/features/auth/services/auth_service.dart`). **Not present in `supabase/functions/`** — must be deployed for account deletion to work.

### Environment Variables

Edge Functions require:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` / `SUPABASE_PUBLISHABLE_KEY` / `SUPABASE_PUBLISHABLE_KEYS`
- `GEMINI_API_KEY` (parser, receipt, bank-notification)
- `CHATBOT_GEMINI_API_KEY` (finance-chatbot)
- `DEEPGRAM_API_KEY` (speech-to-text)
- `GEMINI_MODEL` (optional, defaults to `gemini-3.1-flash-lite`)

## Authentication

Authentication is centralized in `AuthService`.

Supported flows in code:

- Email/password sign in.
- Email/password signup with OTP verification.
- Forgot password and new password flow.
- Change password flow.
- OAuth for Google, Facebook, Apple.
- Password recovery event listener routes to `/new-password`.
- Account deletion via `delete-account` Edge Function.
- Sign out clears local user state before calling Supabase sign out.
- User profile fields: fullName, email, phone, budgetLimit, dailyBudget, weeklyBudget, avatarUrl, selectedCategory.
- `selectedCategory`, `dailyBudget`, `weeklyBudget` use in-memory override fallback for DB schema migration.
- `needsBudgetSetup` property guides post-auth routing.

## Routing

Routes are declared in `AppRoutes` inside `finflow_app.dart`.

Key routes (2026):

- `/` launch, `/onboarding`, `/sign-in`, `/sign-up`, `/verify`, `/forgot-password`, `/new-password`.
- `/wallet-onboarding`, `/budget-setup`, `/category-budgets`.
- `/settings`, `/budget-limits`, `/security`, `/change-password`.
- `/chat`, `/scan`, `/community`, `/community-activity`, `/community-post-detail`, `/notifications`.
- `/dashboard`, `/edit-profile`, `/database-viewer`, `/bank-notification-import`.
- `/saving-goals`, `/saving-goals/create`, `/saving-goals/details`, `/saving-goals/edit`.

The launch screen navigates to onboarding after a short delay. Sign-in routes to wallet onboarding or dashboard based on budget setup state. `MainShell` can receive a tab index argument. `MainShell` initializes `NotificationService` on user load and redirects new users (budgetLimit ≤ 0) to budget setup.

## Theme

Theme is centralized in:

- `core/theme/app_colors.dart` — `AppColors` palette + `FinFlowColors` `ThemeExtension` (light/dark semantic tokens) + `context.finFlowColors`.
- `core/theme/app_theme.dart`
- `core/theme/app_theme_manager.dart`

The app uses Material 3 with a green finance-oriented visual identity. Dark mode is available through `AppThemeManager`. Many screens (home, community, profile, goals, chat) support dark mode; some still use hardcoded colors.

## Assets

Assets include:

- Cover/background images: home, profile, settings, edit profile, scan, goal.
- SVG icons for navigation, profile actions, notification, Google, charts, logo, flag, categories (duotone/fill), chatbot.
- 27 bank logos under `assets/logos/banks/`; 9 e-wallet logos + cash + other under `assets/logos/ewallets/`.
- Fonts: Manrope, Hanken Grotesk, Poppins, Roboto.

Legacy bank and e-wallet logo assets remain available but are no longer selected by the UI (system wallets are cash/transfer).

## Current Completed Features

### Core
- App startup and route table; background Supabase init.
- Full auth flow (email/password, OTP, password reset, change password, OAuth, account deletion call).
- Profile fetch/update/avatar upload.
- Payment-source onboarding (cash and transfer).
- Budget setup and editing (monthly + daily + weekly).
- Transaction CRUD with wallet awareness via goal-aware RPCs.
- Transaction History with daily grouping and quick insights.
- Advanced saving goals.
- TransactionSavedScreen confirmation.
- Per-category monthly budgets.

### Quick Add (Natural Language + Voice + On-device)
- `QuickAddDraft` model with full validation.
- `QuickAddService` — invokes Edge Function, validates response, resolves wallets, detects transfers.
- `QuickAddReviewSheet` — review before save.
- `QuickAddVoiceService` — recording → Deepgram → transcript → auto-submit.
- `QuickAddSpeechRecognitionService` — on-device dictation.

### Receipt Scanning
- `ReceiptScanService` → `parse-receipt` → `ScanResultModel` review → save.
- Embedded scan mode in Add Transaction.

### AI Assistant
- `finance-chatbot` Edge Function with grounding + intent classification + streaming.
- ChatScreen with conversations, image attachments, insight/chart cards.

### Bank Notification Import
- Native Android listener + SQLite queue + local notification.
- MethodChannel platform wrapper + coordinator + Edge Function parsing.
- Config screen with 14 banks/e-wallets + permission guidance.

### Dashboard & Charts
- 5 chart types with period/offset navigation, animated entry, tooltips, empty states, cached buckets.

### Home Screen
- Stitch hero, balance glass card, budget carousel, goals section, category budgets, goal summary, Quick Add, transaction list.

### Community (Full)
- Post CRUD, comments + recursive replies + comment likes, likes/saves, 4+ realtime channels, rich text, composer, topic-driven feed tab.

### Notifications
- `NotificationService` with realtime, types post/like/comment/comment_reply/comment_like, enrichment, Today/Earlier grouping, NotificationBell.

### Backend
- 25 Supabase migrations (001–025), 5 Edge Functions + 2 shared modules.
- Goal-aware transaction RPCs, storage buckets (avatars, community-media, chat-images).

### Testing
- Tests across Quick Add, scan, chatbot, notification import, community, theme, settings, bottom nav, home.

## Features Under Development / Placeholders

- `AiScreen` roadmap UI exists but is not wired to any tab (Chatbot tab is the real assistant).
- Community media upload composer UI (backend table + bucket exist).
- Post/comment report UI (backend tables exist).
- Goal cover image picker (`image_url` field exists).
- Goal activity "View All" is an empty handler.
- Custom categories persisted only in memory.

## Important Services

- `AuthService`: Supabase init, auth, profile, avatar upload, budget fields, account deletion.
- `TransactionService`: transaction CRUD (goal-aware RPCs) + finance computations (cached).
- `WalletService`: wallet CRUD (cash/transfer) + initial balance totals.
- `GoalService`: goal CRUD, fund entries, settings, allocation/withdrawal RPCs.
- `CategoryBudgetService`: per-category monthly budgets.
- `QuickAddService`: NL text → Edge Function → QuickAddDraft.
- `QuickAddVoiceService`: audio recording → Edge Function → transcript.
- `QuickAddSpeechRecognitionService`: on-device speech → text.
- `ReceiptScanService`: receipt image → Edge Function → ScanResultModel.
- `ChatService` / `ChatController`: AI assistant conversation, streaming, history, images.
- `CommunityService`: post/comment/like/save CRUD + Realtime subscriptions.
- `NotificationService`: notification fetch, Realtime, mark read.
- `BankNotificationPlatform` / `BankNotificationImportCoordinator` / `BankNotificationImportService`: native queue + parsing + review flow.
- `AppThemeManager`: app theme mode.
- `AppLanguage`: language toggle and string access.

## Database Overview

Main tables:

- `profiles`: id, full_name, email, phone, avatar_url, budget_limit, daily_budget, weekly_budget, selected_category.
- `transactions`: id, user_id, name, category, amount, date, wallet_id.
- `wallets`: id, user_id, name, short_name, logo_asset_path, brand_color, type (cash/transfer), initial_balance, is_active.
- `goals`: id, user_id, name, target_amount, category, target_date, funding_method, auto_allocation_percent, is_primary, is_protected, withdrawal_priority, status, completion_behavior, redirect_goal_id, image_url, created_at, is_active.
- `goal_fund_entries`: id, user_id, goal_id, amount, entry_type, source_transaction_id, note, created_at.
- `goal_settings`: user_id, expense_shortfall_policy, imported_transaction_policy, updated_at.
- `budgets`: user_id, category, limit_amount, month, year.
- `chat_conversations`, `chat_messages`.
- `community_posts`, `community_likes`, `community_saves`, `community_comments` (parent_comment_id, likes_count), `community_comment_likes`, `community_post_reports`, `community_comment_reports`, `community_notifications`, `community_media`.

Views: `community_authors` = profiles(id, full_name, avatar_url).

RLS: user-owned data restricted to owner; community reads public to authenticated users; goal writes via SECURITY DEFINER RPCs; notifications owner-only.

Realtime: `community_notifications`, `community_comments`, `community_comment_likes`.

## Known Limitations

- `delete-account` Edge Function referenced by code is missing from `supabase/functions/`.
- Custom categories stored only in memory (lost on restart).
- Finance services are `ChangeNotifier`s through plain `Provider` (manual subscription needed).
- Some UI strings and colors still hardcoded.
- `AiScreen` roadmap screen not wired to navigation.
- Community media upload + reports lack UI.
- `sqflite` in Flutter deps unused (native layer has its own SQLite).
- `flutter analyze` was previously reported to time out in the local environment.
- English-only audio may have lower accuracy in speech-to-text (Vietnamese default).
