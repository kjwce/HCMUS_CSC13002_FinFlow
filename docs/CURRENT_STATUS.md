# Current Status

## Completed

### Core App
- Flutter app shell and route table.
- Launch screen with animated transitions.
- Login/signup option screen.
- Supabase initialization (non-blocking, background).
- Email/password sign in.
- Email/password signup with OTP verification.
- OAuth stubs for Google, Facebook, Apple sign-in.
- Forgot password and reset password screens.
- Password recovery event listener routes to `/new-password`.
- Profile loading from Supabase `profiles`.
- Profile update.
- Avatar image picking and upload to Supabase storage.
- Payment-source onboarding for cash and transfer.
- Budget setup after onboarding.
- Budget limit editing in settings.
- Weekly budget editing from both profile settings and transaction history.

### Finance Core
- Transaction CRUD with wallet-awareness.
- Transaction History screen with daily grouping, filters, and weekly spending progress.
- Saving goal creation, deletion, and progress display.
- Goal summary with configurable metric (revenue/expense by configurable period).
- Category tracking on home screen (selectable from all 14 built-in + custom categories).
- Dynamic summary metric picker (revenue/expense tracked over day/week/month/year).
- **TransactionSavedScreen** — full confirmation page after saving a transaction showing amount, category, wallet, current balance, with [Done] and [Add Another] actions.

### Quick Add (Natural Language)
- **`QuickAddDraft`** model with type, amount, name, category, wallet, date, confidence, missing fields, warnings.
- **`QuickAddService`** — sends text + context to Supabase Edge Function, validates response, resolves wallets, detects unsupported transfers.
- **`QuickAddReviewSheet`** — modal bottom sheet to review detected transaction before saving.
- **`QuickAddCard`** — input widget with text field, mic button, submit button.
- Seamless handoff: missing fields → `AddTransactionSheet` pre-filled from draft.
- Transfer detection (e.g. "Chuyển 500k từ MoMo sang MB") prevented with warning.

### Quick Add (Voice — Recording-based)
- **`QuickAddVoiceService`** — audio recording with `record` package (WAV, 16kHz, mono — upgraded from AAC-LC).
- Recording lifecycle: start, stop, cancel, 30-second timeout.
- Audio sent to `speech-to-text` Edge Function (Deepgram Nova-3).
- Transcript injected directly into Quick Add text field → auto-submits for parsing.
- Microphone permission handling.
- Abstracted recorder driver (`QuickAddRecorderDriver`) and file store (`QuickAddVoiceFileStore`) for testability.

### Quick Add (Voice — On-device Speech Recognition)
- **`QuickAddSpeechRecognitionService`** — on-device speech recognition via `speech_to_text` package.
- No Edge Function required, works offline for dictation.
- Automatic locale detection: prefers Vietnamese (vi_VN/vi-VN), falls back to system locale.
- Partial results delivered in real-time, final transcript auto-injected.
- Abstracted driver (`QuickAddSpeechDriver`) for testability.
- `QuickAddSpeechRecognitionService.forTesting()` injects custom driver.

### Supabase Edge Functions
- **`parse-natural-language-transaction`** — TypeScript, calls Google Gemini 2.5 Flash with constrained JSON schema, validates input/output, locale-aware errors.
- **`speech-to-text`** — TypeScript, calls Deepgram Nova-3 (Vietnamese), supports 8+ audio MIME types, 5MB audio limit.
- Both functions authenticate via Bearer token with Supabase JWT verification.

### Dashboard & Charts
- Analytics dashboard with period selector (Day/Week/Month) and offset navigation.
- 5 chart types using `fl_chart`:
  1. Income, Expense & Balance Line Chart.
  2. Income by Category Donut.
  3. Expense by Category Donut.
  4. Income & Expense by Source (horizontal grouped bar: transfer/cash).
  5. Total Income vs Expense (grouped bar with surplus/deficit).
- Scrollable wide charts with period navigation.
- Touch tooltips, animated entry (850ms ease-out).
- Empty state placeholders for no-data charts.

### Home Screen
- Configurable goal summary with metric picker and category tracking.
- Budget progress bar with monthly limit.
- Period tabs (Daily/Weekly/Monthly) for transaction list.
- Quick Add card integrated in home scroll.
- Floating "View All" button for transaction history navigation.
- Greeting (morning/afternoon/evening).
- Voice recording and on-device speech recognition integration.

### Categories
- 14 built-in transaction categories (8 popular + 6 extended).
- In-memory **`CustomCategoryStore`** with icon and color picker.
- Category fallback to "Other" when no match found.
- Category selection for goal summary tracking.

### Community (Social Features — FULLY IMPLEMENTED)
- **Post CRUD**: create, read (feed + detail), edit, delete with user authorization.
- **Comment system**: add, delete, anonymous toggle, author enrichment.
- **Like/Unlike**: optimistic updates with Supabase sync and rollback on failure.
- **Save/Bookmark**: optimistic toggle with rollback on failure.
- **Realtime** — 4 Supabase Realtime channels:
  - `community-feed`: new posts appear instantly at top of feed.
  - `community-likes`: like counts update live.
  - `comments-{postId}`: per-post comment live updates.
  - `notifications-{userId}`: live notification delivery.
- **`CommunityPostCard`** — rich card with color-avatar initials, category badge, formatted date (e.g. "6th May"), RichPostContent rendering, inline like/save/comment actions, owner edit/delete menu.
- **`CommunityPostDetailScreen`** — full post view, comments list, bottom comment input bar with anonymous toggle, owner delete on comments.
- **`CommunityComposerScreen`** — full-screen composer with formatting toolbar (bold, italic, underline, bullet list, spoiler), category picker, anonymous toggle, edit mode support.
- **Rich text format**: posts stored as plain text, rendered with custom parser:
  - `**bold**` → bold
  - `_italic_` → italic
  - `~underline~` → underline
  - `•` at line start → bullet point
  - `||spoiler||` → blurred "tap to reveal" (animated)
- **`stripFormattingForPreview`** — sanitizes formatted text for feed card previews, replaces spoiler content with emoji placeholder.
- **`CommunityCommentModel`** — supports anonymous display name logic (`isAnonymous ? 'Anonymous' : authorName`).
- **Post categories**: Budgeting, Saving, Debt-free, Investing, General.

### Notification System
- **`NotificationService`** — singleton ChangeNotifier managing fetch, realtime subscription, mark read/mark all read.
- **`NotificationModel`** — supports types: 'post', 'like', 'comment'; client-side enrichment (actor name, avatar, post preview).
- **Realtime subscription**: filters by `user_id` on `community_notifications` INSERT.
- **Notification enrichment**: joins `community_authors` for actor info, `community_posts` for content preview (strips formatting, truncates to 60 chars).
- **`NotificationBell`** widget — reusable consumer widget showing unread count badge; integrated in Profile, Settings, and other screens.
- **`NotificationScreen`** — full screen with Today/Earlier grouping, "N New" badges, "Mark all as read", time-ago formatting, tap-to-navigate to post detail.

### Backend
- 12 Supabase migrations including:
  - `010_community_social_features.sql`: Full community schema with 7 tables (posts, likes, saves, comments, reports, notifications, media), triggers for like/comment counts, `community_authors` view, indexes, RLS policies.
  - `011_fix_community_cross_account.sql`: Cross-account access fix, profile backfill, notification auto-creation triggers (post, comment), new-profile backfill, Supabase Realtime publication config.
  - `012_add_community_like_notifications.sql`: Like notification trigger + historical backfill.
- Profile auto-create trigger migration.
- RLS policies for user-owned data.
- Legacy bank/e-wallet logo assets plus the active cash/transfer assets.

### Testing
- **`quick_add_service_test.dart`** — 15+ unit tests for response validation, category/wallet resolution, transfer detection, draft conversion.
- **`quick_add_voice_service_test.dart`** — 10 unit tests for recording lifecycle, permission handling, transcription errors, file cleanup.
- **`quick_add_flow_test.dart`** — 15+ widget tests for Quick Add review sheet, confirm action, edit details, voice controls, AddTransactionSheet prefill.

### UI & Theme
- 5-tab bottom navigation with CustomPaint Figma icons (Home, Analysis, Scan, Community, Profile).
- Profile screen with menu items (edit profile, security, settings, help, logout).
- Settings screen with budget editing, language toggle, theme toggle, notification settings.
- Theme manager and dark theme definition (`AppThemeManager`).
- Basic i18n string manager (`AppStrings`, `AppLanguage`).
- Responsive design helpers (`Responsive.w/h/sp`).
- CustomPaint home icons (wallet, car, food).

## In Progress

- AI Assistant tab: roadmap UI only.
- Chatbot screen: static sample conversation.
- Scan screen: static receipt/scan placeholder UI.
- Community screen (tab 4 — bottom nav): still pointing to old static `CommunityScreen` placeholder; the real community feed is navigated via routes/notifications.
- Debug database viewer: limited Supabase summary and transaction clearing.
- Dark mode support: theme exists, but many screens still use hardcoded colors.
- Language support: `AppStrings` exists, but some UI strings are hardcoded.

## TODO

- Connect AI/chatbot to a real backend or model service if required.
- Implement receipt image capture/OCR and convert scan results into transactions.
- Wire the bottom-nav Community tab to the real community feed (currently still static placeholder).
- Implement comment editing (currently only delete is supported).
- Implement post report UI (backend tables exist).
- Implement media/image upload for community posts (backend `community_media` table exists).
- Implement account deletion flow.
- Persist custom categories (`CustomCategoryStore`) to Supabase instead of in-memory only.
- Decide whether `budgets` table should be used for per-category budgets or removed from active app scope.
- Standardize all user-facing strings through `AppStrings`.
- Improve session-based startup routing (skip onboarding for existing sessions).
- Add integration tests for auth and transaction flows.
- Add transaction filters and search.
- Add wallet management screen (edit, delete, transfer between wallets).
- Add category budget features using the existing `budgets` table.
- Replace hardcoded colors with theme colors across all screens.
- Add Supabase Edge Function deployment CI.
- Add tests for community features (posts, comments, likes, notifications).

## Known Bugs

- Custom categories disappear after app restart because `CustomCategoryStore` is in-memory only.
- Existing-session startup still routes to the login/signup option screen because `LaunchScreen` always goes to onboarding.
- Finance services are `ChangeNotifier`s but exposed through plain `Provider`, so `ref.watch` alone may not rebuild consumers.
- Bottom-nav Community tab still shows static placeholder content instead of the real community feed (but community features are fully implemented via other routes).
- `NotificationBell` may not update in real time when the notification service state changes from a different route — depends on provider scope.

## Technical Debt

- Mixed state management pattern: Riverpod plus singleton `ChangeNotifier`s.
- No repository abstraction; services call Supabase directly.
- Supabase URL and public key are hardcoded in source constants.
- GEMINI_API_KEY and DEEPGRAM_API_KEY are environment variables expected by Edge Functions — no local fallback.
- `AndroidManifest.xml` includes `RECORD_AUDIO` permission for voice Quick Add.
- Some dependencies such as `sqflite` remain even though current storage is Supabase cloud.
- Some screens are large files with many private helper methods (notably `home_screen.dart` at 1840 lines and `dashboard_page.dart` at 1493 lines).
- UI uses many hardcoded colors and strings.
- Community tab (bottom-nav index 3) is not wired to the real community implementation.
- Community post card, composer, and detail screens still use hardcoded color constants rather than theme tokens.

## Future Ideas

- Standardize finance providers as `ChangeNotifierProvider` or migrate to Riverpod Notifiers.
- Add persistent custom categories.
- Add transaction filters and search.
- Add wallet management screen (edit, delete, transfer between wallets).
- Add category budget features using the existing `budgets` table.
- Add real OCR for receipts (current scan screen is placeholder).
- Add AI financial insights based on transaction history.
- Add community posting and reactions (core done, more features: image upload, polls, reports UI).
- Add push notifications for community activity and budget warnings.
- Add secure environment configuration for Supabase keys.
- Add Edge Function deployment CI/CD.
- Add integration tests for auth, transaction, and community flows.
- Localize the Quick Add review sheet and Edge Function responses fully.
- Add comment mentions and reply threading in community.
- Add custom notification preferences (which events trigger notifications).
- Add community moderation tools (report review, content moderation).
