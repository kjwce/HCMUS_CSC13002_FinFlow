# Architecture

## High-Level Architecture

FinFlow is a feature-oriented Flutter app with shared core utilities and singleton service classes. The app uses Supabase directly from services rather than through a separate repository abstraction, and also invokes Supabase Edge Functions for AI-powered features (natural language parsing, speech-to-text, receipt scanning, bank-notification parsing, and a financial chatbot).

General layers:

- UI widgets and screens.
- Riverpod providers exposing services.
- Singleton services for auth, data access, and computed finance values.
- Models for typed data conversion.
- Supabase backend for persistence and authentication.
- Supabase Edge Functions (Deno/TypeScript) for AI features.
- Native Android Kotlin layer for the bank-notification listener (Notification Access).

## Folder Responsibilities

## `lib/main.dart`

- Creates `navigatorKey`.
- Starts the Flutter app immediately (no network wait).
- Initializes Supabase/auth in the background.
- Starts `BankNotificationImportCoordinator` (polls the native pending-notification queue).
- Listens for Supabase password recovery events.
- Pre-fetches transactions and goals when an existing session is available.
- Uses `runZonedGuarded` to catch non-fatal Supabase SDK microtask errors.

## `lib/app/`

- Owns app shell and top-level navigation.
- `finflow_app.dart` defines `MaterialApp`, `AppRoutes`, theme selection, and text scaling behavior.
- `main_shell.dart` owns the 5-slot bottom-nav shell (`IndexedStack`), redirects new users to budget setup, and initializes `NotificationService` on user load.
- `bottom_nav_bar.dart` owns the floating-pill bottom navigation UI — Home, Chatbot, **Add (center FAB)**, Community, Profile.
- `app/screens/` contains tab-level screens such as Home, Community, Profile, and the Community Post Detail screen. (The AI/roadmap screen still exists as `ai_screen.dart` but is no longer wired to a tab — the Chatbot tab is the real AI assistant.)

## `lib/core/`

- Shared configuration, constants, theme, i18n, responsive helpers, and reusable widgets.
- Should not depend on feature-specific UI.
- Contains app-wide services such as `app_init_notifier`.
- `theme/app_colors.dart` — `AppColors` palette plus `FinFlowColors` `ThemeExtension` with light/dark semantic tokens and `context.finFlowColors`.
- `widgets/notification_bell.dart` — live unread-count badge tied to `NotificationService`.

## `lib/features/`

Feature modules are grouped by domain:

- `auth`: auth models, screens, provider, service. Includes OAuth (Google, Facebook, Apple), password recovery, `deleteAccount` (calls the `delete-account` Edge Function), avatar upload, budget fields on profile.
- `finance`: transactions, wallets, goals (advanced saving goals), dashboard, categories, Quick Add (text + voice), on-device speech recognition, financial models/services.
- `budget`: first-run budget setup screen plus **per-category budgets** (category-budget model/service/provider/screens) persisted in the `budgets` table.
- `profile`: profile editing.
- `settings`: settings UI, budget editing, security screen.
- `launch`: launch and login/signup option screen.
- `scan`: **real receipt scanning** — image picker → `parse-receipt` Edge Function → `ScanResultModel` review → save as transactions. Also embeddable inside the Add Transaction sheet.
- `chatbot`: **real AI financial assistant** — conversation history, SSE streaming, image attachments, insight + chart cards (via `finance-chatbot` Edge Function).
- `community`: **fully implemented** social features — posts, comments, likes, saves, realtime updates, rich text, composer with formatting toolbar, post detail screen, notifications, and comment replies/likes.
- `notification_import`: Android bank/e-wallet notification import — reads pending notifications from a native queue via a MethodChannel, parses them with the `parse-bank-notification` Edge Function, and routes the result into the Quick Add review sheet.
- `debug`: database viewer/debug screen.

## `supabase/functions/`

- `parse-natural-language-transaction/index.ts`: Edge Function that calls Gemini to parse natural-language transaction text into structured data.
- `speech-to-text/index.ts`: Edge Function that calls Deepgram Nova-3 to transcribe audio recordings into text.
- `parse-receipt/index.ts`: Edge Function that calls Gemini to extract line items from a receipt image.
- `parse-bank-notification/index.ts`: Edge Function that calls Gemini to decide whether an Android bank notification is a transaction and parse it.
- `finance-chatbot/index.ts`: Edge Function that calls Gemini (streaming SSE + non-streaming) with grounded financial context, intent classification, insight + chart presets.
- `_shared/chat_intent.ts`: intent classifier (`general` vs `app_finance`) shared by the chatbot.
- `_shared/receipt_parser.ts`: receipt request validation + output sanitization shared by `parse-receipt`.

## `android/`

- `BankNotificationListenerService.kt`: Android `NotificationListenerService` — reads bank/e-wallet notifications, redacts account numbers, filters OTP/security messages, enqueues into SQLite, and shows a local confirmation notification.
- `BankNotificationStore.kt`: SQLite storage for enabled packages, settings, diagnostics, and the pending-notification queue (max 50).
- `BankTransactionNotificationPresenter.kt`: local notification shown when a transaction is detected.
- `NotificationListenerRebindReceiver.kt`: rebinds the listener after boot / package replace / user unlock.
- `MainActivity.kt`: exposes the `com.finflow/bank_notifications` MethodChannel used by Flutter (`BankNotificationPlatform`).

## `test/`

Unit and widget tests cover finance Quick Add (service, voice, speech recognition, flow), scan (service + screen), chatbot (service + screen), notification import (models + service), community (topics, models, comment thread, rich text formatter), theme, settings, and bottom nav. See `test/` for the full list.

## Feature Boundaries

Finance is the largest domain and includes:

- Transaction model/service/provider.
- Wallet model/service/provider.
- Goal model/service/provider with **advanced saving goals**: `goal_fund_entries` ledger, `goal_settings`, per-goal status/category/target date/funding method/auto allocation/protection/withdrawal priority/completion behavior/redirect.
- Transaction category definitions (14 built-in + custom in-memory categories).
- Quick Add natural language input (text + voice).
- Quick Add review sheet with warnings and missing-field detection.
- Add/edit transaction UI with payment-method selector (Cash/Transfer) and category grid; the Add sheet also has a **Scan** mode that embeds receipt scanning.
- Transaction history UI with period grouping, filters, and quick insights.
- Transaction Saved screen (confirmation after saving).
- Dashboard chart UI with 5 chart types using `fl_chart`.
- Payment-source onboarding (cash and transfer).
- On-device speech recognition (`QuickAddSpeechRecognitionService`) using `speech_to_text`.

Auth owns:

- Session and user profile state.
- Supabase initialization.
- Auth operations (email/password, OTP, OAuth), password recovery, account deletion.
- Avatar upload to Supabase storage.
- Budget fields (budget limit, daily budget, weekly budget) and selected category persistence on profile.

Budget (newer feature) owns:

- Per-category monthly budgets (`CategoryBudgetService` → `budgets` table) with month/year scoping and upsert on `(user_id, category, month, year)`.

Chatbot owns:

- AI conversation with real backend (`finance-chatbot`), streaming, conversation CRUD, image attachments, insight/chart rendering.

Scan owns:

- Receipt image capture/selection, `ReceiptScanService` → `parse-receipt` Edge Function, `ScanResultModel` review, saving items as transactions, embedded scan mode in Add Transaction.

Notification import owns:

- `BankNotificationPlatform` (MethodChannel wrapper), `BankNotificationImportCoordinator` (polls pending queue on a 5s timer + on app resume), `BankNotificationImportService` (→ `parse-bank-notification`), configuration screen, and one-time migration from SharedPreferences to native SQLite config.

Community owns:

- Post CRUD (create, read, update, delete) with category and anonymous support.
- Comment system with anonymous toggle, author resolution, **recursive replies** (`parent_comment_id`) and **comment likes**.
- Like/unlike with optimistic updates and Supabase sync.
- Save/bookmark with optimistic updates.
- **Realtime** — Supabase Realtime channels for new posts, like count changes, comments, and notifications.
- Post composer with rich formatting toolbar (bold, italic, underline, bullet list, spoiler).
- Rich post content renderer (marker-based: `**bold**`, `_italic_`, `~underline~`, `•` bullet, `||spoiler||`).
- Post detail screen with comment input, anonymous toggle, and thread view.
- Notification system (`NotificationService`) — realtime inserts, fetch, mark read, mark all read, enrich with author/post info; supports types `post`, `like`, `comment`, `comment_reply`, `comment_like`.
- Notification screen with Today/Earlier grouping and unread badges.

## Data Flow

Typical auth flow:

1. UI calls `AuthService` through `authServiceProvider`.
2. `AuthService` calls Supabase Auth.
3. On success, `AuthService` fetches row from `profiles`.
4. `AuthService.currentUser` updates and listeners are notified.
5. UI routes based on the loaded user state.

Typical transaction flow (goal-aware):

1. UI creates or edits a `TransactionModel`.
2. UI calls `TransactionService.add/update/delete`.
3. `add`/`update` call the RPC `create_transaction_with_goal_handling` / `update_transaction_with_goal_handling`, which insert/update the transaction and adjust virtual goal allocations in the same DB transaction (shortfall withdrawals, automatic allocations, redirect flows).
4. `add` passes `isImported` (bank-notification imports force `auto_withdraw` policy) and `goalWithdrawals` (goal_id → cap, from `ExpenseGoalWithdrawalSheet`) when the expense exceeds the actual balance.
5. Service calls `fetchTransactions` which replaces the local list; `GoalService.fetchGoals` is refreshed too.
6. `add` returns the ids of goals that just completed (UI shows `GoalCompletionDialog`).
7. UI rebuilds through manual service listeners or provider reads.

Quick Add text flow:

1. User types/pastes a transaction description (e.g. "Ăn trưa 50k bằng MoMo hôm qua").
2. `QuickAddCard` captures the text and triggers `HomeScreen._submitQuickAdd`.
3. `QuickAddService.parse()` sends the text + context (categories, wallets, locale) to the `parse-natural-language-transaction` Edge Function.
4. Edge Function validates the request, calls Gemini, sanitizes the output, and returns structured `ParserData`.
5. `QuickAddService` validates the response and builds a `QuickAddDraft` with missing-field tracking and warnings.
6. `QuickAddReviewSheet` displays the draft for user review.
7. User confirms → `QuickAddDraft.toTransactionModel()` → `TransactionService.add()` → navigate to `TransactionSavedScreen`.
8. User edits → `AddTransactionSheet` opens pre-filled from the draft.

Quick Add voice flow (recording-based):

1. User taps mic → `QuickAddVoiceService.startRecording()`.
2. Recording stops (manual or 30s timeout) → `stopAndTranscribe()`.
3. Audio sent to `speech-to-text` Edge Function → Deepgram Nova-3 transcription.
4. Transcript is injected into `QuickAddCard` text field and the text flow continues.

Quick Add voice flow (on-device speech recognition):

1. User taps mic → `QuickAddSpeechRecognitionService.startListening()`.
2. On-device `speech_to_text` delivers partial results in real time.
3. Final transcript is injected into `QuickAddCard` text field and auto-submitted.
4. Supports Vietnamese locale detection and fallback to system locale.

Receipt scan flow:

1. `ScanScreen` (tab or embedded in Add Transaction) picks an image (gallery/camera) via `image_picker`.
2. `ReceiptScanService.parseFile()` reads bytes, validates size/mime, and calls the `parse-receipt` Edge Function with `imageBase64`, `mimeType`, `locale`, `categories`.
3. Edge Function validates the request, calls Gemini (constrained JSON schema), sanitizes the output, returns `ScanResultModel`-shaped data.
4. `ScanResultModel` review UI lets the user adjust items before saving; `onConfirmed` hands the result to the parent Add Transaction flow.

Bank notification import flow:

1. Native `BankNotificationListenerService` receives a notification from an enabled bank/e-wallet package, redacts account numbers, filters OTP/security content, and enqueues it in SQLite (max 50). A local confirmation notification is shown.
2. Tapping the local notification opens the app with the queue id as a launch extra; `MainActivity` captures it.
3. `BankNotificationImportCoordinator` (5s timer + on app resume) calls `processPending()`: reads configuration (must be enabled + signed in), pulls `pending()` from the platform, prefers the launch notification, and calls `BankNotificationImportService.parse()` → `parse-bank-notification` Edge Function.
4. If the notification is a transaction, `QuickAddReviewSheet` is shown; confirm saves via `TransactionService.add(..., isImported: true)` (goes through goal-aware RPC with `auto_withdraw` shortfall policy).
5. The queue item is acknowledged; on error, retry after 1 minute.

Typical dashboard flow:

1. Dashboard/Home fetch transactions, wallets, and goals.
2. `TransactionService` computes totals and chart buckets from current user transactions.
3. `WalletService` supplies wallet metadata and initial balances.
4. `GoalService` computes goal progress from `goal_fund_entries` (local sum).
5. Home screen additionally computes: budget progress, summary metric (revenue/expense by configurable period), and per-category 7-day expense.

Community flow:

1. `CommunityScreen` (tab 4) uses `CommunityService` singleton to fetch posts and subscribes to realtime.
2. Posts are displayed via `CommunityPostCard` with like/save/comment counts.
3. User taps post → navigates to `CommunityPostDetailScreen` with the `postId`.
4. Detail screen loads comments, subscribes to realtime updates, allows commenting and replying.
5. User creates post via `CommunityComposerScreen` with formatting toolbar.
6. **Realtime**: Supabase Realtime channels push new posts, like changes, comment updates, and notifications without manual refresh.

Notification flow:

1. `MainShell` initializes `NotificationService.startForUser(userId)` on auth.
2. `NotificationService` subscribes to `community_notifications` Realtime channel.
3. Backend triggers insert rows into `community_notifications` (post activity, comment activity incl. replies, like activity incl. comment likes).
4. `NotificationBell` widget reads `unreadCount` via provider and shows red badge.
5. `NotificationScreen` fetches all notifications, enriches with author/post info, groups by Today/Earlier.
6. User taps notification → marks as read → navigates to `CommunityPostDetailScreen`.

## Riverpod Providers

Current providers are thin wrappers over singleton services:

- `authServiceProvider`: `ChangeNotifierProvider<AuthService>`.
- `transactionServiceProvider`: `Provider<TransactionService>`.
- `goalServiceProvider`: `Provider<GoalService>`.
- `walletServiceProvider`: `Provider<WalletService>`.
- `communityServiceProvider`: `Provider<CommunityService>`.
- `notificationServiceProvider`: `Provider<NotificationService>`.
- `categoryBudgetServiceProvider`: `Provider<CategoryBudgetService>`.
- `chatControllerProvider`: `ChangeNotifierProvider<ChatController>` (owns chat state, streaming, conversation CRUD).
- `languageProvider`: `Provider<AppLanguage>`.

Important behavior:

- `AuthService` and `ChatController` are exposed as `ChangeNotifierProvider`, so consumers rebuild from `ref.watch`.
- Finance services call `notifyListeners`, but their providers are plain `Provider`, so widgets do not automatically rebuild from `ref.watch` alone.
- Some screens (e.g. `HomeScreen`) manually subscribe to finance service listeners via `addListener` in `initState`.
- `CommunityService` and `NotificationService` are `ChangeNotifier`s exposed through plain `Provider`, but consumers typically rebuild via `ListenableBuilder` or calling `setState`/`ref.watch` with the provider.
- `NotificationBell` uses `ListenableBuilder` wrapping the service to get live unread count updates.

## Services

## `AuthService`

Responsibilities:

- Initialize Supabase.
- Track current user profile.
- Sign in (email/password, Google, Facebook, Apple), sign up, verify OTP, reset password, update password, change password.
- Delete account (calls the `delete-account` Edge Function).
- Upload avatar to Supabase storage.
- Update profile data (full name, email, phone, budget limit, avatar URL).
- Save selected category, daily budget, and weekly budget (with in-memory override fallback for schema migration).
- Sign out (clears local state before Supabase signOut).
- Detect if user needs budget setup.

## `TransactionService`

Responsibilities:

- Fetch, add, update, delete, and clear transactions.
- Filter transactions for current user.
- Compute monthly income, monthly expense, total balance, balance by wallet/date.
- Compute chart period buckets and category/wallet breakdowns.
- Add/update go through the goal-aware RPCs `create_transaction_with_goal_handling` / `update_transaction_with_goal_handling` with `isImported` and `goalWithdrawals` parameters.
- Use `WalletService` for initial balances and wallet grouping.
- Cached computed values for performance (`_cachedMonthlyIncome`, `_cachedPeriodBuckets`, etc.) — cleared on each `notifyListeners`.
- Period-based filtering with `ChartPeriod` enum (day/week/month/year).
- `add` returns ids of goals that just completed.

## `WalletService`

Responsibilities:

- Fetch user wallets.
- Insert onboarding wallets.
- Save the opening balances of the two system wallets (Cash / Transfer) via `saveSystemWallets`.
- Compute total initial balance.
- Lookup wallet by id (`byId`).
- Expose current user wallets.

## `GoalService`

Responsibilities:

- Fetch goals, goal fund entries, and goal settings (three parallel queries).
- Compute saved amount (`allocatedAmount`) locally by summing `goal_fund_entries` per goal.
- Expose `primaryGoal`, `activeGoals`, `availableForGoals` (local), `totalAllocated`, `assignedAutomaticPercent`.
- Set new primary goal, activate/deactivate, reorder withdrawal priority.
- Allocate / withdraw funds via RPCs `allocate_goal_funds` / `withdraw_goal_funds` (returns whether a goal just completed).
- Save `goal_settings` (expense shortfall policy).
- Delete goals.
- Auto-create default `goal_settings` row when missing.

## `QuickAddService`

Responsibilities:

- Send natural-language text + context (categories, wallets, locale) to the `parse-natural-language-transaction` Edge Function.
- Validate and sanitize the untrusted response into a `QuickAddDraft`.
- Resolve wallet hints to actual wallet IDs (with normalization and alias matching).
- Detect unsupported transfers (e.g. "Chuyển 500k từ MoMo sang MB").
- Testable via `QuickAddService.forTesting()` with injected invoker/wallets/categories.

## `QuickAddVoiceService`

Responsibilities:

- Record audio via `AudioRecorder` (WAV, 16kHz, mono).
- Manage recording lifecycle (start, stop, cancel).
- Send recorded audio to the `speech-to-text` Edge Function.
- Parse and validate the transcript response.
- Clean up temporary audio files.
- Testable via `QuickAddVoiceService.forTesting()`.
- 30-second recording timeout enforced in `HomeScreen`.

## `QuickAddSpeechRecognitionService`

Responsibilities:

- On-device speech recognition via `speech_to_text` package (no Edge Function).
- Initialize recognizer, detect available locales, select Vietnamese (vi_VN/vi-VN) or fallback to system locale.
- Start/stop/cancel listening.
- Deliver partial and final results via callback.
- Testable via `QuickAddSpeechRecognitionService.forTesting()`.

## `ReceiptScanService`

Responsibilities:

- Read receipt image bytes (size limit 8MB) and send to the `parse-receipt` Edge Function.
- Validate the structured Gemini response into a `ScanResultModel`.
- Handle version mismatch and item-level validation.
- Testable via `ReceiptScanService.forTesting()`.

## `ChatService`

Responsibilities:

- Persist conversations and messages (`chat_conversations`, `chat_messages` with `sequence_number`).
- Upload / download chat images (private `chat-images` bucket, signed URLs).
- Send messages to `finance-chatbot` (streaming SSE via `http` or non-streaming via `functions.invoke`).
- Build the request body (message, locale, timezone, currentDate, history, image).
- Parse reply, insight, and chart from the structured response.

## `CommunityService`

Responsibilities:

- Fetch all posts with author, like/save state for current user.
- Create, edit, delete posts (with category and anonymous/spoiler options).
- Optimistic toggle like/unlike with Supabase sync and rollback on failure.
- Optimistic toggle save/bookmark with rollback on failure.
- Fetch comments with author info for a specific post.
- Add comment / reply (with anonymous option and `parent_comment_id`).
- Delete own comment.
- Like/unlike comments (optimistic).
- **Realtime**: subscribe to new posts (`INSERT` on `community_posts`), like count changes (`ALL` on `community_likes`), per-post comment changes, and comment like changes.

## `NotificationService`

Responsibilities:

- Subscribe to `community_notifications` Realtime channel for live inserts.
- Fetch all notifications for current user, ordered by `created_at DESC`.
- Mark single notification as read.
- Mark all notifications as read.
- Enrich notifications with actor name/avatar and post content preview (client-side join).
- Expose `unreadCount`, `unread`, `isLoading` state.
- Unsubscribe and clear state on logout.

## `BankNotificationImportCoordinator` / `BankNotificationImportService` / `BankNotificationPlatform`

- Coordinator polls the pending queue (5s timer + on app resume + on lifecycle resume), parses via the Edge Function, shows `QuickAddReviewSheet`, and acknowledges.
- Service parses a `BankNotificationEnvelope` into a `QuickAddDraft` (validates type/amount/confidence/category, requires an active transfer wallet, adds low-confidence warning).
- Platform wraps the `com.finflow/bank_notifications` MethodChannel (config, diagnostics, pending list, acknowledge, rebind, permissions).

## Models

Main models:

- `UserModel`
- `TransactionModel`
- `WalletModel`
- `WalletPreset`
- `GoalModel` + `GoalFundEntry` + `GoalSettings` (advanced saving goals)
- `CategoryBudgetModel`
- `QuickAddDraft` — reviewable result of NL parsing (type, amount, name, category, wallet, date, confidence, missing fields, warnings).
- `QuickAddTransactionType` — enum for income/expense.
- `QuickAddMissingField` — enum tracking which fields need user input.
- `TransactionCategory`: 14 built-in categories (8 popular, 6 extended).
- `CustomCategoryDef` / `CustomCategoryStore` — in-memory custom category store (lost on restart).
- `CommunityPostModel`: full post with user_id, content, category, likes/comments count, anonymous/spoiler flags, client-side author info, isLikedByMe, isSavedByMe.
- `CommunityCommentModel`: comment with post_id, user_id, content, anonymous flag, parent_comment_id, likes, client-side author info.
- `NotificationModel`: notification with type ('post', 'like', 'comment', 'comment_reply', 'comment_like'), actor enrichment, post preview.
- `ScanResultModel` / `ScannedItem` — receipt line items with category, confidence, warnings.
- `ChatModel` / `ChatConversation` / `ChatInsight` / `ChatChart` / `ChatImageAttachment` / `PendingChatImage` — chatbot models.
- `BankNotificationConfiguration` / `BankNotificationEnvelope` / `BankNotificationParseResult` / `BankNotificationProvider` — notification import models.
- `QuickAddSpeechLocale` / `QuickAddSpeechResult` / `QuickAddSpeechException` — speech recognition types.

Models are simple data classes with `fromJson` and `toJson` methods for Supabase data conversion. `GoalFundEntry` and `GoalSettings` are read-only (no `toJson`).

## Repositories

There is no separate repository layer in the current codebase. Services directly call Supabase.

If a repository layer is introduced later, it should be done consistently and not mixed into only one feature.

## Routing

Routes are centralized in `AppRoutes` (in `finflow_app.dart`) and the `MaterialApp.routes` map.

Routes (2026):

- `/` launch, `/onboarding`, `/sign-in`, `/sign-up`, `/verify`, `/forgot-password`, `/new-password`.
- `/wallet-onboarding`, `/budget-setup`, `/category-budgets`.
- `/settings`, `/budget-limits`, `/security`, `/change-password`.
- `/chat`, `/scan`, `/community`, `/community-activity`, `/community-post-detail`, `/notifications`.
- `/dashboard`, `/edit-profile`, `/database-viewer`, `/bank-notification-import`.
- `/saving-goals`, `/saving-goals/create`, `/saving-goals/details` (argument = goal id), `/saving-goals/edit` (argument = goal id).

Some feature navigation uses direct `MaterialPageRoute` (goal details/edit via `onGenerateRoute`; community post detail via direct route).

`MainShell` uses an `IndexedStack` for bottom navigation tabs. Argument passing (int tab index) allows navigation from Profile/Home to specific tabs.

## Dependency Relationships

Main dependency direction:

- UI depends on providers and services.
- Providers depend on services.
- Services depend on models and Supabase.
- `QuickAddService` depends on `WalletService` and `CustomCategoryStore`.
- Finance computations depend on `WalletService`.
- Goal UI depends on both `GoalService` and `TransactionService`.
- Profile/settings depend on `AuthService`.
- `HomeScreen` depends on `TransactionService`, `GoalService`, `WalletService`, `QuickAddService`, `QuickAddVoiceService`, `QuickAddSpeechRecognitionService`.
- `MainShell` depends on `NotificationService` for initialization.
- `NotificationBell` depends on `NotificationService` via provider.
- Community UI depends on `CommunityService` and `NotificationService`.
- `BankNotificationImportCoordinator` depends on `BankNotificationPlatform`, `BankNotificationImportService`, `QuickAddReviewSheet`, `AddTransactionSheet`, and `TransactionService`.
- Chat UI depends on `ChatController`/`ChatService`.

Core widgets and theme should remain shared dependencies and avoid importing feature screens where possible.

## Supabase Integration

Supabase is initialized once by `AuthService.init`.

Used Supabase APIs:

- `Supabase.initialize`
- `auth.signInWithPassword`, `auth.signUp`, `auth.verifyOTP`, `auth.resetPasswordForEmail`, `auth.updateUser`, `auth.signOut`, `auth.signInWithOAuth`, `auth.onAuthStateChange`
- `functions.invoke` — `parse-natural-language-transaction`, `speech-to-text`, `parse-receipt`, `parse-bank-notification`, `finance-chatbot`, `delete-account`
- `functions.rpc` — `create_transaction_with_goal_handling`, `update_transaction_with_goal_handling`, `allocate_goal_funds`, `withdraw_goal_funds`
- `from(...).select/insert/update/delete/upsert`
- `storage.from('avatars').upload`, `getPublicUrl`
- `storage.from('chat-images').uploadBinary`, `createSignedUrl`, `download`, `remove`
- **Realtime**: `channel(...).onPostgresChanges(...).subscribe()` for community features (posts, likes, comments, comment likes, notifications)

SQL migrations define schema, RLS, storage policies, wallet/goal additions, profile triggers, community tables, goal/chat/budget tables, and notification triggers.

### Realtime Channels

Community features use Supabase Realtime for live updates:

1. **community-feed**: listens for `INSERT` on `community_posts` → add new post to top of list.
2. **community-likes**: listens for `ALL` changes on `community_likes` → update local `likesCount`.
3. **comments-{postId}**: per-post channel for `ALL` changes on `community_comments` → refetch comments.
4. **notifications-{userId}**: listens for `INSERT` on `community_notifications` filtered by `user_id` → prepend to notification list.

### Database Migrations

25 migrations exist (`supabase/migrations/001`–`025`). Key highlights:

| Migration | Description |
|-----------|-------------|
| `001_create_tables.sql` | Initial schema (profiles, transactions, transactions_backup, budgets) |
| `002_rls_policies.sql` | RLS policies for user-owned data |
| `003_storage_policies.sql` | Storage policies for avatars |
| `004_add_selected_category.sql` | Add selected_category column to profiles |
| `005_create_goals_table.sql` | Goals table |
| `006_add_wallets_and_wallet_id.sql` | Wallets table + wallet_id on transactions |
| `007_create_profile_trigger.sql` | Auto-create profile on user signup |
| `008_add_weekly_budget.sql` | Add weekly_budget column to profiles |
| `009_rename_transaction_title_to_name.sql` | Rename title column to name |
| `010_community_social_features.sql` | Full community schema (posts, likes, saves, comments, reports, notifications, media, triggers, RLS, indexes) |
| `011_fix_community_cross_account.sql` | Cross-account access fix, notification backfill, new-profile notification trigger, publication config |
| `012_add_community_like_notifications.sql` | Like notification trigger + backfill |
| `013_create_community_media_storage.sql` | `community_media` table + public `community-media` bucket (10MB) |
| `014_enable_community_comments_realtime.sql` | Add `community_comments` to `supabase_realtime` |
| `015_create_chat_history.sql` | `chat_conversations` + `chat_messages` with RLS and touch trigger |
| `016_add_chat_images.sql` | `image_path`/`image_mime_type` on chat_messages + private `chat-images` bucket (6MB) |
| `017_add_chat_message_sequence.sql` | `sequence_number` on chat_messages + sequence trigger + unique index |
| `018_add_daily_budget.sql` | `daily_budget BIGINT` column on profiles |
| `019_simplify_wallets_to_cash_and_transfer.sql` | Merge wallets into cash and transfer system sources + default-wallet trigger |
| `020_normalize_transaction_user_id.sql` | Normalize transaction ownership to UUID + cascading FK and rebuild RLS |
| `021_add_recursive_comment_replies.sql` | `parent_comment_id` + `likes_count` on comments, `community_comment_likes` table, reply/like notification triggers |
| `022_advanced_saving_goals.sql` | Goal fund entries, goal settings, goal-aware transaction RPCs, allocation/withdrawal RPCs, validation triggers |
| `023_normalize_goal_user_id.sql` | Normalize goal ownership to UUID + cascading FK and rebuild RLS |
| `024_normalize_goal_money_bigint.sql` | `target_amount`/`amount` to BIGINT |
| `025_ensure_default_goal_settings.sql` | Backfill + trigger ensuring every user has `goal_settings` |

### Edge Functions

Five Edge Functions are deployed plus shared modules:

1. **`parse-natural-language-transaction`** — TypeScript, calls Gemini (default `gemini-3.1-flash-lite`) with constrained JSON schema. Validates input, authenticates via Bearer token, sanitizes output, handles errors with locale-aware messages.
2. **`speech-to-text`** — TypeScript, calls Deepgram Nova-3 (Vietnamese language). Supports multiple audio MIME types, validates content type and size (max 5MB), authenticates via Bearer token.
3. **`parse-receipt`** — TypeScript, calls Gemini with image input + constrained JSON schema. Extracts merchant, date, currency, line items (name/amount/category/confidence), total, warnings. Auth via Bearer token. Uses `_shared/receipt_parser.ts` for validation/sanitization.
4. **`parse-bank-notification`** — TypeScript, calls Gemini to decide `isTransaction`, type, amount, name, category, date, confidence, warnings from a bank/e-wallet notification. Auth via Bearer token.
5. **`finance-chatbot`** — TypeScript, calls Gemini with grounded financial context (profiles, transactions, wallets, goals). Classifies intent (`general`/`app_finance`) via `_shared/chat_intent.ts`, returns reply + optional insight + optional chart preset (server-built). Supports streaming (SSE) and non-streaming modes. Uses its own `CHATBOT_GEMINI_API_KEY`.

## Widget Hierarchy

Startup:

```text
ProviderScope
  FinFlowApp
    MaterialApp
      LaunchScreen
      OnboardingScreen
      Auth screens (SignIn, SignUp, Verification, ForgotPassword, NewPassword, ChangePassword)
      MainShell
```

Main app:

```text
MainShell
  Scaffold
    SafeArea
      IndexedStack
        HomeScreen
        ChatScreen (AI assistant, showBackButton: false)
        ScanScreen
        CommunityScreen (realtime topic-driven feed)
        ProfileScreen
    AppBottomNavBar (floating pill)
      Home | Chatbot | Add (center FAB) | Community | Profile
```

Home:

```text
HomeScreen (ConsumerStatefulWidget, ~4000 lines)
  Stack
    SingleChildScrollView
      Stitch hero + Balance glass card (greeting, notification, balance/expense)
      Cash-flow glass metric(s)
      Budget carousel / budget card + progress bar + expense message
      Refined goals section (goal cards + progress)
      Category budget section (per-category monthly budgets)
      Goal summary card (configurable metric + category tracker)
      Quick Add card (text input + mic + submit)
      Recent transaction list (filtered by selected period)
    Positioned "View All" button (floating above bottom)
```

Quick Add review:

```text
QuickAddReviewSheet (modal bottom sheet)
  Amount summary (+/- VND + INCOME/EXPENSE/UNKNOWN badge)
  Detected fields (name, category, wallet, date) with missing-field highlight
  Warnings (yellow card for low confidence / missing fields)
  Original text (italicized quote)
  Footer: [Edit Details] [Confirm]
```

Transaction Saved confirmation:

```text
TransactionSavedScreen (full page)
  Success icon (green check circle)
  "Transaction Saved" + subtitle
  Amount card (signed amount + INCOME/EXPENSE badge)
  Details card (category, wallet, current balance)
  [Done] button → pop to home
  [Add Another] button → reopen AddTransactionSheet
```

Finance entry:

```text
AddTransactionSheet (modal bottom sheet, ~3200 lines)
  Modes: Manual / Quick Add / Scan
  "From Quick Add" badge (optional)
  Segmented income/expense tabs
  Amount input (formatted with commas)
  Transaction name field
  Payment method selector (Cash / Transfer) → the user's two system wallets
  Category grid (popular + custom + "More" for extended/custom)
  Confirm button
```

Dashboard:

```text
DashboardPage (~1700 lines)
  Header (back + title + period segment: Day/Week/Month)
  ListView
    Chart cards (scrollable, period navigation with < >)
      1. Income, Expense & Balance Line Chart
      2. Income by Category Donut
      3. Expense by Category Donut
      4. Income & Expense by Source (horizontal grouped bar)
      5. Total Income vs Expense (grouped bar)
```

Community:

```text
CommunityScreen (tab 4, topic-driven feed)
  Topic filter chips (All / Budgeting / Saving / Debt-free / Investing / General)
  └── CommunityPostCard list (realtime, like/save/comment)

CommunityComposerScreen (full-screen)
  Header: close + title ("New post" / "Edit post") + submit button
  Author row: avatar (public/anonymous toggle) + display name + category picker
  TextField (multi-line, expandable)
  Formatting toolbar: [B] [I] [U] [•] [spoiler]

CommunityPostDetailScreen (full screen)
  Header: back + "Post" title + icon
  Post card (full content, maxLines: null)
  Comments section with count header + thread rendering (replies)
  Comment tiles (avatar, name, date, content, owner delete menu, comment like)
  Bottom comment bar: anonymous toggle + TextField + send button

NotificationScreen (full screen)
  Header: back + "Notifications" + "Mark all as read"
  Today section (with "N New" badge)
  Earlier section
  Notification tiles: type-icon + "ActorName message" + time ago
  Tap → mark read → navigate to CommunityPostDetailScreen
```

Chat:

```text
ChatScreen (AI assistant, tab + standalone)
  Header: avatar + "AI Assistant" + history button + NotificationBell
  Message list (user bubbles, assistant bubbles)
  Assistant message extras: Insight card + Chart card (fl_chart, bar/donut)
  Quick prompts (suggestion chips)
  Input bar: image button + text field + send
  _ChatHistorySheet: conversation list (new/rename/delete/switch)
```

Goals:

```text
SavingGoalsScreen
  Header: gradient total balance, Available for Goals, Allocated to Goals, Allocate button
  Filter chips: All / Automatic / Manual / Completed
  Goal cards (name, category, progress %, allocated/target, funding method, target date,
             protected badge, primary badge)
  Create New Goal → GoalFormScreen

GoalFormScreen (create + edit)
  Basic information (category, name, target amount, target date)
  Initial allocation (create only)
  Funding method (Manual / Automatic with % slider + chips, capped at remaining %)
  Advanced settings (protected, primary, withdrawal priority, completion behavior + redirect goal)
  Delete goal (edit mode)

GoalDetailsScreen
  Overview card (category, name, badges, allocated, %, progress bar, target date, monthly estimate)
  Add Money / Withdraw buttons
  Funding settings card
  Activity card (recent goal_fund_entries)
```

## External Services

- **Supabase** — Authentication, database (PostgreSQL), storage (avatars, chat images), Edge Functions runtime, **Realtime** for community live updates.
- **Google Gemini** — Natural language transaction parsing, receipt extraction, bank-notification parsing, financial chatbot (via Edge Functions; default `gemini-3.1-flash-lite`).
- **Deepgram Nova-3** — Speech-to-text transcription for voice Quick Add (via Edge Function).
- **record** package — Audio recording on device (WAV, 16kHz, mono).
- **speech_to_text** package — On-device speech recognition for live dictation (no Edge Function required).
- **Android NotificationListenerService** — native bank/e-wallet transaction detection (no SMS access).
