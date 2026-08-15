# Current Status

_Updated 2026-08-05. Reflects the current codebase (25 Supabase migrations, 5 Edge Functions + shared modules, native Android notification listener, ~40k lines of Dart)._

## Completed

### Core App
- Flutter app shell and route table.
- Launch screen with animated transitions.
- Login/signup option screen.
- Supabase initialization (non-blocking, background).
- Email/password sign in.
- Email/password signup with OTP verification.
- OAuth for Google, Facebook, Apple.
- Forgot password and reset password screens; password recovery event listener routes to `/new-password`.
- Change password screen (`/change-password`).
- **Account deletion** via the `delete-account` Edge Function.
- Profile loading from Supabase `profiles`.
- Profile update + avatar upload to Supabase storage.
- Payment-source onboarding for cash and transfer.
- Budget setup after onboarding (monthly + daily + weekly).
- Budget limit editing in settings; weekly budget editing from profile settings and transaction history.

### Finance Core
- Transaction CRUD with wallet awareness — **add/update go through the goal-aware RPCs** `create_transaction_with_goal_handling` / `update_transaction_with_goal_handling`.
- Transaction History screen with daily grouping, filters, and weekly spending progress.
- Advanced saving goals: goal list, create/edit form, details, allocate/withdraw sheets, completion dialog, shortfall withdrawal selection.
- Goal fund ledger (`goal_fund_entries`) with initial/manual/automatic allocations, expense withdrawals, completion transfers.
- Automatic allocation of income to goals by percentage; redirect-on-completion to another goal.
- Protected goals, withdrawal priority reordering, primary goal.
- Goal settings (expense shortfall policy: ask each time / auto withdraw).
- Category tracking on home screen; dynamic summary metric picker (revenue/expense tracked over day/week/month/year).
- **TransactionSavedScreen** — confirmation page after saving.

### Quick Add (Natural Language)
- **`QuickAddDraft`** model with type, amount, name, category, wallet, date, confidence, missing fields, warnings.
- **`QuickAddService`** — sends text + context to Supabase Edge Function, validates response, resolves wallets, detects unsupported transfers.
- **`QuickAddReviewSheet`** — review before save.
- **`QuickAddCard`** — input widget with text field, mic button, submit button.
- Seamless handoff: missing fields → `AddTransactionSheet` pre-filled from draft.
- Transfer detection (e.g. "Chuyển 500k từ MoMo sang MB") prevented with warning.

### Quick Add (Voice — Recording-based)
- **`QuickAddVoiceService`** — audio recording with `record` package (WAV, 16kHz, mono).
- Recording lifecycle: start, stop, cancel, 30-second timeout.
- Audio sent to `speech-to-text` Edge Function (Deepgram Nova-3).
- Transcript injected directly into Quick Add text field → auto-submits.
- Microphone permission handling; abstracted recorder driver + file store for testability.

### Quick Add (Voice — On-device Speech Recognition)
- **`QuickAddSpeechRecognitionService`** — on-device `speech_to_text`.
- No Edge Function required; automatic Vietnamese locale detection; partial results in real time.
- Abstracted driver (`QuickAddSpeechDriver`) for testability.

### Receipt Scanning (real, replaces placeholder)
- **`ReceiptScanService`** — sends image to `parse-receipt` Edge Function, validates structured Gemini response.
- **`ScanResultModel` / `ScannedItem`** — line items with name, amount, category, confidence, warnings.
- `ScanScreen` with camera/gallery pick, processing state, review UI; **embeddable inside Add Transaction sheet (Scan mode)**.
- Testable via `ReceiptScanService.forTesting()`.

### AI Financial Assistant (real, replaces static chatbot)
- **`finance-chatbot`** Edge Function — Gemini with grounded financial context, intent classification (`general`/`app_finance`), streaming (SSE) + non-streaming.
- **`ChatScreen`** — real conversations with history sheet (new/rename/delete/switch), streaming typing indicator, image attachments (gallery/camera, ≤6MB), quick prompts.
- **Insight cards + chart cards** (bar/donut via `fl_chart`) built from reply presets.
- Conversation persistence (`chat_conversations`, `chat_messages` with `sequence_number`), private `chat-images` bucket with signed URLs.
- Uses its own `CHATBOT_GEMINI_API_KEY`.

### Bank Notification Import (native Android)
- **`BankNotificationListenerService`** (Kotlin) — reads bank/e-wallet notifications via Notification Access, redacts account numbers, filters OTP/security content, enqueues into SQLite (max 50), shows a local confirmation notification.
- **`BankNotificationStore`** — SQLite config/settings/pending queue; **`BankTransactionNotificationPresenter`** — local notification; **`NotificationListenerRebindReceiver`** — rebind on boot/replace/unlock.
- **`BankNotificationPlatform`** — MethodChannel `com.finflow/bank_notifications` (config, diagnostics, pending, acknowledge, rebind, permissions).
- **`BankNotificationImportCoordinator`** — polls pending queue (5s timer + on resume), parses via `parse-bank-notification`, shows `QuickAddReviewSheet`, saves with `isImported: true` (forces auto-withdraw shortfall policy), acknowledges.
- **`BankNotificationImportService`** — validates parsed draft (requires active transfer wallet, low-confidence warning).
- **Import configuration screen** — consent dialog, notification-access status, POST_NOTIFICATIONS, battery optimization, 14 supported bank/e-wallet packages, test notification (debug).
- One-time migration from SharedPreferences config to native SQLite.

### Budget
- First-run budget setup (monthly + daily + weekly).
- **Per-category monthly budgets** — `CategoryBudgetService` → `budgets` table (upsert on `user_id, category, month, year`), category-budget screens and home-section display.

### Dashboard & Charts
- Analytics dashboard with period selector (Day/Week/Month) and offset navigation.
- 5 chart types using `fl_chart` (line, category donuts, source grouped bars, income-vs-expense).
- Touch tooltips, animated entry, empty-state placeholders, cached buckets.

### Home Screen
- Stitch hero + balance glass card; cash-flow glass metrics.
- Budget carousel / budget card with progress bar and expense message.
- Refined goals section + goal summary card (metric picker + category tracking).
- **Category budget section** (per-category monthly budgets).
- Period tabs (Daily/Weekly/Monthly) for transaction list; Quick Add card; floating "View All".
- Voice recording and on-device speech recognition integration.

### Categories
- 14 built-in transaction categories (8 popular + 6 extended).
- In-memory **`CustomCategoryStore`** with icon and color picker.
- Category fallback to "Other".

### Community (Social Features — FULLY IMPLEMENTED)
- **Post CRUD**, **comment system** (anonymous toggle, author enrichment).
- **Recursive comment replies** (`parent_comment_id`) with thread rendering.
- **Comment likes** (`community_comment_likes`).
- **Like/Unlike** and **Save/Bookmark** with optimistic updates and rollback.
- **Realtime** — channels for new posts, like changes, comments, notifications.
- **Rich text**: `**bold**`, `_italic_`, `~underline~`, `•` bullet, `||spoiler||`; `stripFormattingForPreview` for previews.
- **Composer** with formatting toolbar, category picker, anonymous toggle, edit mode.
- **Post detail** with thread view and live comment bar.
- **Community tab (bottom-nav) wired to the real topic-driven feed** (All / Budgeting / Saving / Debt-free / Investing / General).

### Notification System
- **`NotificationService`** — fetch, realtime subscription, mark read / mark all read.
- Types: `post`, `like`, `comment`, `comment_reply`, `comment_like`.
- Enrichment (actor name/avatar, post preview); Today/Earlier grouping; time-ago.
- **`NotificationBell`** — live unread-count badge in Profile, Settings, and other screens.

### Backend
- **25 Supabase migrations (001–025)**: initial schema, RLS, storage, wallets → cash/transfer, community features, chat history/images/sequence, daily budget, normalize UUID + BIGINT, recursive comment replies, advanced saving goals.
- Community schema: posts, likes, saves, comments (with replies/likes), reports, notifications, media + view + triggers.
- **Goal-aware transaction RPCs** and goal allocation/withdrawal RPCs with validation + advisory locks.
- Chat history schema with per-conversation message sequencing.
- Storage buckets: `avatars`, `community-media` (public, 10MB), `chat-images` (private, 6MB).
- 5 Edge Functions + 2 shared modules (chat intent, receipt parser).
- Profile auto-create trigger; default wallet + goal-settings triggers.

### Testing
- Unit + widget tests across: Quick Add service/voice/speech/flow, receipt scan service + screen, chatbot service + screen, notification import models + service, community (topics, models, comment thread, rich text), theme, settings budget limits, bottom nav, home screen. See `test/`.

### UI & Theme
- Floating-pill bottom navigation: Home | Chatbot | **Add (center FAB)** | Community | Profile.
- Profile screen with menu (edit profile, security, settings, community activity, logout).
- Settings screen with budget editing, language toggle, theme toggle, notification settings.
- `FinFlowColors` `ThemeExtension` with light/dark semantic tokens + `context.finFlowColors`.
- Dark mode supported across redesigned screens (home, community, profile, goals, chat).
- i18n (`AppStrings`) bilingual EN/VI for many strings.

## In Progress / Placeholders

- `AiScreen` (roadmap UI) still exists as a file but is **not wired to any tab** (the Chatbot tab is the real AI assistant).
- Goal activity "View All" button in `GoalDetailsScreen` is an empty `onPressed`.
- Goal `image_url` field exists but there is no image-picker UI for goals yet.
- Media/image upload for community posts (backend `community_media` table + bucket exist, no composer UI).
- Post/comment report UI (backend tables exist).
- Custom categories stored in-memory only (lost on restart).
- Debug database viewer: limited Supabase summary + transaction clearing.
- Some UI strings still hardcoded despite `AppStrings`.

## TODO

- Add composer UI for community media uploads (bucket + table exist).
- Implement post/comment report UI.
- Add account-deletion UX polish (Edge Function exists, callers exist).
- Persist custom categories to Supabase.
- Add image picker UI for goal cover (`image_url` exists).
- Complete goal activity "View All".
- Decide whether the legacy `goal_setup_sheet.dart` should be removed now that `GoalFormScreen` is the full-featured form.
- Standardize remaining user-facing strings through `AppStrings`.
- Add integration tests for auth, transaction, goals, chat, and notification-import flows.
- Add wallet management screen (edit/delete) — wallets are now system cash/transfer only.
- Add Edge Function deployment CI.

## Known Bugs / Limitations

- Custom categories disappear after app restart (`CustomCategoryStore` in-memory only).
- Finance services are `ChangeNotifier`s exposed through plain `Provider`, so `ref.watch` alone may not rebuild consumers (screens manually subscribe).
- `AuthService.deleteAccount()` invokes the `delete-account` Edge Function, but the function directory does **not** include a `delete-account/` implementation — deploying it is required for account deletion to work.
- Some screens still use hardcoded color constants rather than `FinFlowColors` tokens.
- Bank notification import only works on Android and requires Notification Access + POST_NOTIFICATIONS (Android 13+).

## Technical Debt

- Mixed state management pattern: Riverpod plus singleton `ChangeNotifier`s.
- No repository abstraction; services call Supabase directly.
- Supabase URL and public key are hardcoded in source constants.
- `GEMINI_API_KEY` / `DEEPGRAM_API_KEY` / `CHATBOT_GEMINI_API_KEY` are env vars expected by Edge Functions — no local fallback.
- `AndroidManifest.xml` includes `RECORD_AUDIO` permission for voice Quick Add + `BIND_NOTIFICATION_LISTENER_SERVICE` for the import listener.
- Some dependencies such as `sqflite` remain even though current storage is Supabase cloud (the native Kotlin layer uses its own SQLite).
- Some screens are large files (home_screen ~4000 lines, add_transaction_sheet ~3200 lines, transaction_history ~2100 lines).
- `delete-account` Edge Function missing from `supabase/functions/`.

## Future Ideas

- Push notifications for community activity and budget warnings.
- Secure environment configuration for Supabase keys.
- Edge Function deployment CI/CD.
- Comment mentions and deeper reply threading UX.
- Custom notification preferences (which events trigger notifications).
- Community moderation tools (report review, content moderation).
- Real OCR improvements / multi-receipt scanning.
- Localize Quick Add review sheet and Edge Function responses fully.
