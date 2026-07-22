# Architecture

## High-Level Architecture

FinFlow is a feature-oriented Flutter app with shared core utilities and singleton service classes. The app uses Supabase directly from services rather than through a separate repository abstraction, and also invokes Supabase Edge Functions for AI-powered features (natural language parsing, speech-to-text).

General layers:

- UI widgets and screens.
- Riverpod providers exposing services.
- Singleton services for auth, data access, and computed finance values.
- Models for typed data conversion.
- Supabase backend for persistence and authentication.
- Supabase Edge Functions (Deno/TypeScript) for AI features.

## Folder Responsibilities

## `lib/main.dart`

- Creates `navigatorKey`.
- Starts the Flutter app immediately (no network wait).
- Initializes Supabase/auth in the background.
- Listens for Supabase password recovery events.
- Pre-fetches transactions and goals when an existing session is available.
- Uses `runZonedGuarded` to catch non-fatal Supabase SDK microtask errors.

## `lib/app/`

- Owns app shell and top-level navigation.
- `finflow_app.dart` defines `MaterialApp`, routes, theme selection, and text scaling behavior.
- `main_shell.dart` owns the 5-tab dashboard shell with `IndexedStack` and initializes `NotificationService` on user load.
- `bottom_nav_bar.dart` owns the custom bottom navigation UI with Figma-designed SVG/CustomPaint icons (Home, Analysis, Scan, Community, Profile).
- `app/screens/` contains tab-level screens such as Home, AI, Community, Profile, and the Community Post Detail screen.

## `lib/core/`

- Shared configuration, constants, theme, i18n, responsive helpers, and reusable widgets.
- Should not depend on feature-specific UI.
- Contains app-wide services such as `app_init_notifier`.
- `widgets/notification_bell.dart` — live unread-count badge tied to `NotificationService`.

## `lib/features/`

Feature modules are grouped by domain:

- `auth`: auth models, screens, provider, service. Also includes OAuth stubs (Google, Facebook, Apple).
- `finance`: transactions, wallets, goals, dashboard, categories, Quick Add (text + voice), speech recognition, financial models/services.
- `budget`: first-run budget setup screen.
- `profile`: profile editing.
- `settings`: settings UI and budget editing.
- `launch`: launch and login/signup option screen.
- `scan`: receipt scanning placeholder UI.
- `chatbot`: sample chatbot UI with static messages.
- `community`: **fully implemented** social features — posts, comments, likes, saves, realtime updates, rich text (bold/italic/underline/spoilers), composer with formatting toolbar, post detail screen, and notifications.
- `debug`: database viewer/debug screen.

## `supabase/functions/`

- `parse-natural-language-transaction/index.ts`: Edge Function that calls Google Gemini 2.5 Flash to parse natural-language transaction text into structured data.
- `speech-to-text/index.ts`: Edge Function that calls Deepgram Nova-3 to transcribe audio recordings into text.

## `test/features/finance/`

- `quick_add_service_test.dart`: Unit tests for `QuickAddService` — response validation, category/wallet resolution, transfer detection.
- `quick_add_voice_service_test.dart`: Unit tests for `QuickAddVoiceService` — recording lifecycle, permission handling, transcription errors.
- `quick_add_flow_test.dart`: Widget tests for the full Quick Add UI flow — review sheet, confirm, edit, voice controls.

## Feature Boundaries

Finance is the largest domain and includes:

- Transaction model/service/provider.
- Wallet model/service/provider.
- Goal model/service/provider.
- Transaction category definitions (14 built-in + custom in-memory categories).
- Quick Add natural language input (text + voice).
- Quick Add review sheet with warnings and missing-field detection.
- Add/edit transaction UI with payment-method selector (Cash/Transfer) and category grid.
- Transaction history UI with period grouping, filters, and quick insights.
- Transaction Saved screen (confirmation after saving).
- Dashboard chart UI with 5 chart types using `fl_chart`.
- Payment-source onboarding UI (cash and transfer).
- Goal summary with configurable metric (revenue/expense by period) and category tracking.
- On-device speech recognition (`QuickAddSpeechRecognitionService`) using `speech_to_text` for direct voice-to-text input (separate from the Deepgram Edge Function recording flow).

Auth owns:

- Session and user profile state.
- Supabase initialization.
- Auth operations (email/password, OTP, OAuth stubs).
- Avatar upload to Supabase storage.
- Weekly budget and selected category persistence on profile.

Profile and Settings consume `AuthService` and do not own separate profile repositories.

Community owns:

- Post CRUD (create, read, update, delete) with category and anonymous support.
- Comment system with anonymous toggle and author resolution.
- Like/unlike with optimistic updates and Supabase sync.
- Save/bookmark with optimistic updates.
- **Realtime** — Supabase Realtime channels for new posts, like count changes, and new comments.
- Post composer with rich formatting toolbar (bold, italic, underline, bullet list, spoiler).
- Rich post content renderer (marker-based: `**bold**`, `_italic_`, `~underline~`, `•` bullet, `||spoiler||`).
- Post detail screen with comment input and anonymous toggle.
- Notification system (`NotificationService`) — realtime inserts, fetch, mark read, mark all read, enrich with author/post info.
- Notification screen with Today/Earlier grouping and unread badges.

## Data Flow

Typical auth flow:

1. UI calls `AuthService` through `authServiceProvider`.
2. `AuthService` calls Supabase Auth.
3. On success, `AuthService` fetches row from `profiles`.
4. `AuthService.currentUser` updates and listeners are notified.
5. UI routes based on the loaded user state.

Typical transaction flow:

1. UI creates or edits a `TransactionModel`.
2. UI calls `TransactionService.add/update/delete`.
3. Service writes to Supabase `transactions`.
4. Service calls `fetchTransactions` which replaces the local list.
5. UI rebuilds through manual service listeners or provider reads.

Quick Add text flow:

1. User types/pastes a transaction description (e.g. "Ăn trưa 50k bằng MoMo hôm qua").
2. `QuickAddCard` captures the text and triggers `HomeScreen._submitQuickAdd`.
3. `QuickAddService.parse()` sends the text + context (categories, wallets, locale) to the `parse-natural-language-transaction` Edge Function.
4. Edge Function validates the request, calls Gemini 2.5 Flash, sanitizes the output, and returns structured `ParserData`.
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

Typical dashboard flow:

1. Dashboard/Home fetch transactions, wallets, and goals.
2. `TransactionService` computes totals and chart buckets from current user transactions.
3. `WalletService` supplies wallet metadata and initial balances.
4. `GoalService` computes goal progress using total balance.
5. Home screen additionally computes: budget progress, summary metric (revenue/expense by configurable period), and per-category 7-day expense.

Community flow:

1. `CommunityScreen` (tab 4) uses `CommunityService` singleton to fetch posts.
2. Posts are displayed via `CommunityPostCard` with like/save/comment counts.
3. User taps post → navigates to `CommunityPostDetailScreen` with the `postId`.
4. Detail screen loads comments, subscribes to realtime updates, allows commenting.
5. User creates post via `CommunityComposerScreen` with formatting toolbar.
6. **Realtime**: Supabase Realtime channels push new posts, like changes, and comment updates without manual refresh.

Notification flow:

1. `MainShell` initializes `NotificationService.startForUser(userId)` on auth.
2. `NotificationService` subscribes to `community_notifications` Realtime channel.
3. Backend triggers (`community_notify_post_activity`, `community_notify_comment_activity`, `community_notify_like_activity`) insert rows into `community_notifications`.
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
- `languageProvider`: `Provider<AppLanguage>`.

Important behavior:

- `AuthService` rebuilds consumers because it is exposed as `ChangeNotifierProvider`.
- Finance services call `notifyListeners`, but their providers are plain `Provider`, so widgets do not automatically rebuild from `ref.watch` alone.
- Some screens (e.g. `HomeScreen`) manually subscribe to finance service listeners via `addListener` in `initState`.
- `CommunityService` and `NotificationService` are `ChangeNotifier`s exposed through plain `Provider`, but consumers typically rebuild via `ListenableBuilder` or calling `setState`/`ref.watch` with the provider.
- `NotificationBell` uses `ListenableBuilder` wrapping the service to get live unread count updates.

## Services

## `AuthService`

Responsibilities:

- Initialize Supabase.
- Track current user profile.
- Sign in (email/password, Google, Facebook, Apple OAuth stubs), sign up, verify OTP, reset password, update password.
- Upload avatar to Supabase storage.
- Update profile data (full name, email, phone, budget limit, avatar URL).
- Save selected category (with local override fallback for schema migration).
- Save weekly budget.
- Sign out (clears local state before Supabase signOut).
- Detect if user needs budget setup.

## `TransactionService`

Responsibilities:

- Fetch, add, update, delete, and clear transactions.
- Filter transactions for current user.
- Compute monthly income, monthly expense, total balance.
- Compute chart period buckets and category/wallet breakdowns.
- Use `WalletService` for initial balances and wallet grouping.
- Cached computed values for performance (`_cachedMonthlyIncome`, `_cachedPeriodBuckets`, etc.) — cleared on each `notifyListeners`.
- Period-based filtering with `ChartPeriod` enum (day/week/month/year).
- Compute balance by wallet (`balanceByWallet`).

## `WalletService`

Responsibilities:

- Fetch user wallets.
- Insert onboarding wallets.
- Save the opening balances of the two system wallets.
- Compute total initial balance.
- Lookup wallet by id (`byId`).
- Expose current user wallets.

## `GoalService`

Responsibilities:

- Fetch goals.
- Return active goal.
- Set new active goal (deactivates previous active goal).
- Delete goals.
- Compute saved amount and progress ratio from total balance.

## `QuickAddService` (NEW)

Responsibilities:

- Send natural-language text + context (categories, wallets, locale) to the `parse-natural-language-transaction` Edge Function.
- Validate and sanitize the untrusted response into a `QuickAddDraft`.
- Resolve wallet hints to actual wallet IDs (with normalization and alias matching).
- Detect unsupported transfers (e.g. "Chuyển 500k từ MoMo sang MB").
- Testable via `QuickAddService.forTesting()` with injected invoker/wallets/categories.

## `QuickAddVoiceService` (NEW)

Responsibilities:

- Record audio via `AudioRecorder` (WAV, 16kHz, mono — upgraded from AAC-LC).
- Manage recording lifecycle (start, stop, cancel).
- Send recorded audio to the `speech-to-text` Edge Function.
- Parse and validate the transcript response.
- Clean up temporary audio files.
- Testable via `QuickAddVoiceService.forTesting()` with injected recorder/files/invoker.
- 30-second recording timeout enforced in `HomeScreen`.

## `QuickAddSpeechRecognitionService` (NEW)

Responsibilities:

- On-device speech recognition via `speech_to_text` package (no Edge Function).
- Initialize recognizer, detect available locales, select Vietnamese (vi_VN/vi-VN) or fallback to system locale.
- Start/stop/cancel listening.
- Deliver partial and final results via callback.
- Testable via `QuickAddSpeechRecognitionService.forTesting()` with custom `QuickAddSpeechDriver`.

## `CommunityService`

Responsibilities:

- Fetch all posts with author, like/save state for current user.
- Create, edit, delete posts (with category and anonymous/spoiler options).
- Optimistic toggle like/unlike with Supabase sync and rollback on failure.
- Optimistic toggle save/bookmark with rollback on failure.
- Fetch comments with author info for a specific post.
- Add comment (with anonymous option).
- Delete own comment.
- **Realtime**: subscribe to new posts (`INSERT` on `community_posts`), like count changes (`ALL` on `community_likes`), and per-post comment changes.

## `NotificationService`

Responsibilities:

- Subscribe to `community_notifications` Realtime channel for live inserts.
- Fetch all notifications for current user, ordered by `created_at DESC`.
- Mark single notification as read.
- Mark all notifications as read.
- Enrich notifications with actor name/avatar and post content preview (client-side join).
- Expose `unreadCount`, `unread`, `isLoading` state.
- Unsubscribe and clear state on logout.

## Models

Main models:

- `UserModel`
- `TransactionModel`
- `WalletModel`
- `WalletPreset`
- `GoalModel`
- `QuickAddDraft` (NEW): Reviewable result of NL parsing — tracks type, amount, name, category, wallet, date, confidence, missing fields, warnings.
- `QuickAddTransactionType` (NEW): Enum for income/expense.
- `QuickAddMissingField` (NEW): Enum tracking which fields need user input.
- `TransactionCategory`: 14 built-in categories (8 popular, 6 extended).
- `CustomCategoryDef` / `CustomCategoryStore` (NEW): In-memory custom category store (lost on restart).
- `CommunityPostModel`: Full post with user_id, content, category, likes/comments count, anonymous/spoiler flags, client-side author info, isLikedByMe, isSavedByMe.
- `CommunityCommentModel`: Comment with post_id, user_id, content, anonymous flag, client-side author info.
- `CommunityPostModel` display name logic: anonymous → "Anonymous", else authorName → "FinFlow user".
- `NotificationModel`: notification with type ('post', 'like', 'comment'), actor enrichment, post preview.
- `ScanResultModel`
- `QuickAddSpeechLocale` / `QuickAddSpeechResult` / `QuickAddSpeechException` (NEW): speech recognition types.

Models are simple data classes with `fromJson` and `toJson` methods for Supabase data conversion.

## Repositories

There is no separate repository layer in the current codebase. Services directly call Supabase.

If a repository layer is introduced later, it should be done consistently and not mixed into only one feature.

## Routing

Routes are centralized in `AppRoutes` and the `MaterialApp.routes` map.

The app mostly uses named routes for full-screen flows:

- Auth (sign-in, sign-up, forgot/reset password, verification).
- Settings.
- Profile edit.
- Wallet onboarding.
- Budget setup.
- Dashboard, Chat, Scan, Community, Database Viewer, Notifications.

Some feature navigation uses direct `MaterialPageRoute` or `PageRouteBuilder`:

- Dashboard page from Home (slide transition).
- Transaction history from Home (slide transition, returns tab index).
- Edit transaction screen.
- Community Post Detail screen (from notifications or community feed, takes `postId`).
- Community Composer (full-screen).

`MainShell` uses an `IndexedStack` for bottom navigation tabs. Argument passing (int tab index) allows navigation from Profile/Home to specific tabs.

New routes added:

- `/notifications` → `NotificationScreen`
- `/community-post-detail` (via direct `MaterialPageRoute`, not in routes map)

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

Core widgets and theme should remain shared dependencies and avoid importing feature screens where possible.

## Supabase Integration

Supabase is initialized once by `AuthService.init`.

Used Supabase APIs:

- `Supabase.initialize`
- `auth.signInWithPassword`
- `auth.signUp`
- `auth.verifyOTP`
- `auth.resetPasswordForEmail`
- `auth.updateUser`
- `auth.signOut`
- `auth.signInWithOAuth` (Google, Facebook, Apple stubs)
- `auth.onAuthStateChange`
- `functions.invoke` — `parse-natural-language-transaction` and `speech-to-text` Edge Functions
- `from(...).select/insert/update/delete/upsert`
- `storage.from('avatars').upload`
- `storage.from('avatars').getPublicUrl`
- **Realtime**: `channel(...).onPostgresChanges(...).subscribe()` for community features (posts, likes, comments, notifications)

SQL migrations define schema, RLS, storage policies, wallet/goal additions, profile trigger, community tables (posts, likes, saves, comments, notifications, reports, media), and notification triggers.

### Realtime Channels

Community features use Supabase Realtime for live updates:

1. **community-feed**: listens for `INSERT` on `community_posts` → add new post to top of list.
2. **community-likes**: listens for `ALL` changes on `community_likes` → update local `likesCount`.
3. **comments-{postId}**: per-post channel for `ALL` changes on `community_comments` → refetch comments.
4. **notifications-{userId}**: listens for `INSERT` on `community_notifications` filtered by `user_id` → prepend to notification list.

### Database Migrations

| Migration | Description |
|-----------|-------------|
| `001_create_tables.sql` | Initial schema (profiles, transactions, transactions_backup, budgets) |
| `002_rls_policies.sql` | RLS policies for user-owned data |
| `003_storage_policies.sql` | Storage policies for avatars |
| `004_add_selected_category.sql` | Add selected_category column to profiles |
| `005_create_goals_table.sql` | Goals table |
| `006_add_wallets_and_wallet_id.sql` | Wallets table + wallet_id on transactions |
| `019_simplify_wallets_to_cash_and_transfer.sql` | Merge wallets into cash and transfer system sources |
| `020_normalize_transaction_user_id.sql` | Normalize transaction ownership to UUID + cascading FK and rebuild RLS |
| `007_create_profile_trigger.sql` | Auto-create profile on user signup |
| `008_add_weekly_budget.sql` | Add weekly_budget column to profiles |
| `009_rename_transaction_title_to_name.sql` | Rename title column to name |
| `010_community_social_features.sql` | Full community schema (posts, likes, saves, comments, reports, notifications, media, triggers, RLS, indexes) |
| `011_fix_community_cross_account.sql` | Cross-account access fix, notification backfill, new-profile notification trigger, publication config |
| `012_add_community_like_notifications.sql` | Like notification trigger + backfill |

### Edge Functions

Two Supabase Edge Functions are deployed:

1. **`parse-natural-language-transaction`** — TypeScript, calls Google Gemini 2.5 Flash with constrained JSON schema. Validates input, authenticates via Bearer token, sanitizes output, handles errors with locale-aware messages.
2. **`speech-to-text`** — TypeScript, calls Deepgram Nova-3 (Vietnamese language). Supports multiple audio MIME types, validates content type and size (max 5MB), authenticates via Bearer token.

## Widget Hierarchy

Startup:

```text
ProviderScope
  FinFlowApp
    MaterialApp
      LaunchScreen
      OnboardingScreen
      Auth screens (SignIn, SignUp, Verification, ForgotPassword, NewPassword)
      MainShell
```

Main app:

```text
MainShell
  Scaffold
    SafeArea
      IndexedStack
        HomeScreen
        AiScreen
        ScanScreen
        CommunityScreen (legacy static — replaced by new tabbed feed)
        ProfileScreen
    AppBottomNavBar
      _FigmaHomeIcon | _FigmaAnalysisIcon | Scan FAB | _FigmaCommunityIcon | _FigmaProfileIcon
```

Note: The bottom-navigation Community tab still points to the old `CommunityScreen` with static placeholder cards. The full community UI (realtime feed, post cards, composer) is accessible through routes and the notification system. Community post detail is navigated via `MaterialPageRoute`.

Home:

```text
HomeScreen (ConsumerStatefulWidget, ~1840 lines)
  Stack
    SingleChildScrollView
      Header + Balance area (background image, total balance/expense, budget progress)
      Goal summary card (configurable revenue/expense metric + category tracker)
      Period tabs (Daily/Weekly/Monthly)
      QuickAddCard (text input + mic + submit)
        └── TextField + VoiceButton (mic/stop icon) + SubmitButton (bolt icon)
      Recent transaction list (filtered by selected period)
    Positioned "View All" button (floating above bottom)
```

Quick Add review:

```text
QuickAddReviewSheet (modal bottom sheet, ~550 lines)
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
AddTransactionSheet (modal bottom sheet)
  "From Quick Add" badge (optional)
  Segmented income/expense tabs
  Amount input (formatted with commas)
  Transaction name field
  Payment method selector (Cash / Transfer)
    → Uses the user's two system wallets
  Category grid (popular + custom + "More" for extended/custom)
  Confirm button
```

Dashboard:

```text
DashboardPage (~1493 lines)
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
CommunityScreen (legacy, static placeholder cards)
  └── _PostCard (title, body, reaction chip)

CommunityComposerScreen (full-screen)
  Header: close + title ("New post" / "Edit post") + submit button
  Author row: avatar (public/anonymous toggle) + display name + category picker
  TextField (multi-line, 4+ lines, expandable)
  Formatting toolbar: [B] [I] [U] [•] [spoiler]

CommunityPostCard (rich card, used in feed + detail)
  Avatar (color-palette initials) + display name + date · category
  Post content (RichPostContent: supports **bold**, _italic_, ~underline~, • bullets, ||spoiler||)
  Action row: ♥ count | 💬 count | bookmark toggle
  Owner menu: ⋮ → Edit / Delete

CommunityPostDetailScreen (full screen)
  Header: back + "Post" title + icon
  Post card (full content, maxLines: null)
  Comments section with count header
  Comment tiles (avatar, name, date, content, owner delete menu)
  Bottom comment bar: anonymous toggle + TextField + send button

NotificationScreen (full screen)
  Header: back + "Notifications" + "Mark all as read"
  Today section (with "N New" badge)
  Earlier section
  Notification tiles: type-icon + "ActorName message" + time ago
  Tap → mark read → navigate to CommunityPostDetailScreen
```

## External Services

- **Supabase** — Authentication, database (PostgreSQL), storage (avatars), Edge Functions runtime, **Realtime** for community live updates.
- **Google Gemini 2.5 Flash** — Natural language transaction parsing (via Edge Function).
- **Deepgram Nova-3** — Speech-to-text transcription for voice Quick Add (via Edge Function).
- **record** package — Audio recording on device (WAV, 16kHz, mono).
- **speech_to_text** package — On-device speech recognition for live dictation (no Edge Function required).
