# AI Context

## Project Purpose

FinFlow is a Flutter mobile app for personal finance tracking. It helps users record income and expenses, connect those transactions to wallets or bank accounts, monitor monthly and weekly spending against budget limits, and view dashboard charts and transaction history for financial insight.

The app is currently a mobile-first Flutter project backed by Supabase for authentication, database storage, and avatar storage.

## Target Users

- Students and young professionals tracking daily income and spending.
- Users who want a simple personal finance assistant with Vietnamese banking and e-wallet concepts.
- Users who need budget monitoring, saving goals, and basic spending analytics.

## Main Features

- Launch screen and login/signup entry screen.
- Supabase email/password authentication.
- OTP verification for signup and password reset flows.
- Wallet onboarding for banks, e-wallets, and cash.
- Monthly budget setup and weekly budget setup/editing.
- Home dashboard with:
  - Total balance.
  - Monthly expense.
  - Budget progress.
  - Saving goal summary.
  - Recent transactions.
- Floating `View All` entry point to the Transaction History screen.
- Add, edit, and delete transactions.
- Wallet-aware transaction entry.
- Transaction History screen with day grouping, filters, and quick insights.
- Saving goal setup and progress display.
- Analytics dashboard using charts.
- Profile display and edit screen.
- Avatar upload to Supabase storage.
- Profile and settings screens with budget editing, weekly budget editing, and theme toggle.
- Placeholder screens for AI assistant, chatbot, receipt scan, and community.

## Folder Structure

```text
lib/
  main.dart
  app/
    screens/
    shell/
  core/
    config/
    constants/
    i18n/
    services/
    theme/
    utils/
    widgets/
  features/
    auth/
    budget/
    chatbot/
    community/
    debug/
    finance/
    launch/
    profile/
    scan/
    settings/
assets/
  icons/
  logos/
  *.png cover/background assets
supabase/
  migrations/
test/
```

## Packages Used

- `flutter_riverpod`: provider layer and dependency access.
- `supabase_flutter`: authentication, database, storage.
- `fl_chart`: analytics dashboard charts.
- `flutter_svg`: SVG icon rendering.
- `image_picker`: profile avatar image selection.
- `sqflite` and `path`: present in dependencies, but current data flow uses Supabase cloud storage.
- `flutter_lints`: lint rules.

## State Management

The project uses Riverpod, but many state objects are singleton services:

- `AuthService` is a singleton `ChangeNotifier` exposed through `ChangeNotifierProvider`.
- `TransactionService`, `GoalService`, and `WalletService` are singleton `ChangeNotifier`s exposed through plain `Provider`.
- Some screens manually subscribe to service listeners because plain `Provider` does not rebuild on `notifyListeners`.

Important providers:

- `authServiceProvider`
- `transactionServiceProvider`
- `goalServiceProvider`
- `walletServiceProvider`
- `languageProvider`

## Backend

The backend is Supabase on the web. The repository keeps SQL migrations so tables and policies can be recreated in another Supabase account by copying/running the SQL.

Current Supabase areas:

- Auth users.
- Public `profiles`.
- `transactions`.
- `wallets`.
- `goals`.
- `budgets`.
- `community_posts`.
- Avatar storage bucket.
- Row Level Security policies.
- Trigger to create a profile when a new auth user signs up.

## Authentication

Authentication is centralized in `AuthService`.

Supported flows in code:

- Email/password sign in.
- Email/password signup with OTP verification.
- Forgot password and new password flow.
- OAuth method stubs for Google, Facebook, and Apple using Supabase OAuth.
- Password recovery event listener routes to `/new-password`.
- Sign out clears local user state before calling Supabase sign out.

## Routing

Routes are declared in `AppRoutes` inside `finflow_app.dart`.

Key routes:

- `/`: launch screen.
- `/onboarding`: login/signup option screen.
- `/sign-in`
- `/sign-up`
- `/verify`
- `/forgot-password`
- `/new-password`
- `/wallet-onboarding`
- `/budget-setup`
- `/dashboard`
- `/settings`
- `/chat`
- `/scan`
- `/community`
- `/edit-profile`
- `/database-viewer`

The launch screen currently navigates to the onboarding login/signup screen after a short delay. Sign-in decides whether to route to wallet onboarding or dashboard based on budget setup state.

## Theme

Theme is centralized in:

- `core/theme/app_colors.dart`
- `core/theme/app_theme.dart`
- `core/theme/app_theme_manager.dart`

The app uses Material 3 with a green finance-oriented visual identity. Dark mode is available through `AppThemeManager`, but many screens still use hardcoded colors.

## Assets

Assets include:

- Cover/background images: home, profile, settings, edit profile, scan.
- SVG icons for navigation, profile actions, notification, Google icon, chart, logo.
- Bank logos under `assets/logos/banks/`.
- E-wallet logos under `assets/logos/ewallets/`.

Bank and e-wallet presets reference these asset paths.

## Current Completed Features

- App startup and route table.
- Login/signup option screen.
- Supabase initialization.
- Email/password auth.
- OTP verification flow.
- Password reset screens.
- Profile fetch/update.
- Avatar selection and upload.
- Wallet onboarding.
- Budget setup and budget editing.
- Weekly budget editing from profile and transaction history.
- Transaction CRUD.
- Transaction History screen with daily grouping and quick insights.
- Wallet-aware transaction entry.
- Goal CRUD and progress display.
- Home dashboard summary.
- Analytics dashboard charts.
- Profile and settings screens.
- Supabase migrations for current schema.

## Features Under Development

- AI assistant screen is a roadmap UI.
- Chatbot screen uses static sample messages.
- Scan screen is a receipt scanning placeholder.
- Community screen uses static cards and is not connected to `community_posts`.
- Database viewer is a debug-oriented Supabase summary, not a full database browser.
- Notification settings and account deletion are placeholders.

## Important Services

- `AuthService`: Supabase init, auth, profile, avatar upload, selected category, weekly budget.
- `TransactionService`: transaction CRUD and finance computations.
- `WalletService`: wallet CRUD and initial balance totals.
- `GoalService`: saving goal CRUD and progress.
- `AppThemeManager`: app theme mode.
- `AppLanguage`: simple language toggle and string access.

## Database Overview

Main tables:

- `profiles`: public user profile linked to `auth.users`.
- `transactions`: user transactions with name, category, amount, date, optional wallet.
- `wallets`: user wallets/banks/e-wallets/cash with initial balance.
- `goals`: saving goals.
- `budgets`: per-category budget table currently present in schema but not the main app budget flow.
- `community_posts`: present in schema, not yet used by UI.

RLS policies restrict user-owned data to the authenticated owner. Community posts are readable by everyone according to current migration policy.

## Known Limitations

- The launch screen does not automatically skip onboarding for an existing session.
- Provider usage is inconsistent: some `ChangeNotifier` services are exposed through plain `Provider`.
- Custom categories are stored only in memory and are lost after app restart.
- Some UI strings are hardcoded despite having `AppStrings`.
- Some features are placeholders, especially AI, scan, chatbot, and community.
- Supabase keys are currently stored in source constants.
- `flutter analyze` was attempted previously but timed out in the local environment.
