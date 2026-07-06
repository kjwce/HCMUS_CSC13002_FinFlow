# Current Status

## Completed

- Flutter app shell and route table.
- Launch screen.
- Login/signup option screen.
- Supabase initialization.
- Email/password sign in.
- Email/password signup with OTP verification.
- Forgot password and reset password screens.
- Profile loading from Supabase `profiles`.
- Profile update.
- Avatar image picking and upload to Supabase storage.
- Wallet onboarding for banks, e-wallets, and cash.
- Budget setup after onboarding.
- Budget limit editing in settings.
- Weekly budget editing from both profile settings and transaction history.
- Transaction add/edit/delete.
- Wallet-aware transaction creation.
- Home screen with balance, expense, budget progress, goal summary, and recent transactions.
- Transaction History screen with daily grouping, filters, and weekly spending progress.
- Saving goal creation, deletion, and progress display.
- Analytics dashboard with multiple `fl_chart` charts.
- Profile screen.
- Settings screen.
- Theme manager and dark theme definition.
- Basic i18n string manager.
- Supabase migrations for current database structure.
- Profile auto-create trigger migration.
- Bank and e-wallet logo assets.

## In Progress

- AI Assistant tab: roadmap UI only.
- Chatbot screen: static sample conversation.
- Scan screen: static receipt/scan placeholder.
- Community screen: static cards, not connected to Supabase data.
- Debug database viewer: limited Supabase summary and transaction clearing.
- Dark mode support: theme exists, but many screens still use hardcoded colors.
- Language support: `AppStrings` exists, but some UI strings are hardcoded.

## TODO

- Connect AI/chatbot to a real backend or model service if required.
- Implement receipt image capture/OCR and convert scan results into transactions.
- Connect community UI to `community_posts`.
- Implement notification settings.
- Implement account deletion flow.
- Persist custom categories instead of keeping them in memory.
- Decide whether `budgets` table should be used for per-category budgets or removed from active app scope.
- Standardize all user-facing strings through `AppStrings`.
- Improve session-based startup routing if users should skip onboarding after login.
- Add meaningful tests beyond startup widget test.

## Known Bugs

- Custom categories disappear after app restart because `CustomCategoryStore` is in-memory only.
- Existing-session startup still routes to the login/signup option screen because `LaunchScreen` always goes to onboarding.
- Finance services are `ChangeNotifier`s but exposed through plain `Provider`, so `ref.watch` alone may not rebuild consumers.

## Technical Debt

- Mixed state management pattern: Riverpod plus singleton `ChangeNotifier`s.
- No repository abstraction; services call Supabase directly.
- Supabase URL and public key are hardcoded in source constants.
- Some dependencies such as `sqflite` remain even though current storage is Supabase cloud.
- Some screens are large files with many private helper methods.
- UI uses many hardcoded colors and strings.
- Placeholder features have models/schema that are not fully wired to UI.
- Tests are minimal.

## Future Ideas

- Standardize finance providers as `ChangeNotifierProvider` or migrate to Riverpod Notifiers.
- Add persistent custom categories.
- Add transaction filters and search.
- Add wallet management screen.
- Add category budget features using the existing `budgets` table.
- Add real OCR for receipts.
- Add AI financial insights based on transaction history.
- Add community posting and reactions.
- Add push notifications for budget warnings.
- Add secure environment configuration for Supabase keys.
- Add integration tests for auth and transaction flows.
