# Architecture

## High-Level Architecture

FinFlow is a feature-oriented Flutter app with shared core utilities and singleton service classes. The app uses Supabase directly from services rather than through a separate repository abstraction.

General layers:

- UI widgets and screens.
- Riverpod providers exposing services.
- Singleton services for auth, data access, and computed finance values.
- Models for typed data conversion.
- Supabase backend for persistence and authentication.

## Folder Responsibilities

## `lib/main.dart`

- Creates `navigatorKey`.
- Starts the Flutter app immediately.
- Initializes Supabase/auth in the background.
- Listens for Supabase password recovery events.
- Pre-fetches transactions and goals when an existing session is available.

## `lib/app/`

- Owns app shell and top-level navigation.
- `finflow_app.dart` defines `MaterialApp`, routes, theme selection, and text scaling behavior.
- `main_shell.dart` owns the 5-tab dashboard shell.
- `bottom_nav_bar.dart` owns the custom bottom navigation UI.
- `app/screens/` contains tab-level screens such as Home, AI, Community, and Profile.

## `lib/core/`

- Shared configuration, constants, theme, i18n, responsive helpers, and reusable widgets.
- Should not depend on feature-specific UI.
- Contains app-wide services such as `app_init_notifier`.

## `lib/features/`

Feature modules are grouped by domain:

- `auth`: auth models, screens, provider, service.
- `finance`: transactions, wallets, goals, dashboard, financial models/services.
- `budget`: first-run budget setup screen.
- `profile`: profile editing.
- `settings`: settings UI and budget editing.
- `launch`: launch and login/signup option screen.
- `scan`: receipt scanning placeholder.
- `chatbot`: sample chatbot UI.
- `community`: static community UI and post model.
- `debug`: database viewer/debug screen.

## Feature Boundaries

Finance is the largest domain and includes:

- Transaction model/service/provider.
- Wallet model/service/provider.
- Goal model/service/provider.
- Transaction category definitions.
- Add/edit transaction UI.
- Dashboard chart UI.
- Wallet onboarding UI.

Auth owns:

- Session and user profile state.
- Supabase initialization.
- Auth operations.
- Avatar upload.
- Selected category persistence on profile.

Profile and Settings consume `AuthService` and do not own separate profile repositories.

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
4. Service calls `fetchTransactions`.
5. Local transaction list is replaced.
6. UI rebuilds through manual service listeners or provider reads.

Typical dashboard flow:

1. Dashboard/Home fetch transactions, wallets, and goals.
2. `TransactionService` computes totals and chart buckets from current user transactions.
3. `WalletService` supplies wallet metadata and initial balances.
4. `GoalService` computes goal progress using total balance.

## Riverpod Providers

Current providers are thin wrappers over singleton services:

- `authServiceProvider`: `ChangeNotifierProvider<AuthService>`.
- `transactionServiceProvider`: `Provider<TransactionService>`.
- `goalServiceProvider`: `Provider<GoalService>`.
- `walletServiceProvider`: `Provider<WalletService>`.
- `languageProvider`: `Provider<AppLanguage>`.

Important behavior:

- `AuthService` rebuilds consumers because it is exposed as `ChangeNotifierProvider`.
- Finance services call `notifyListeners`, but their providers are plain `Provider`, so widgets do not automatically rebuild from `ref.watch` alone.
- Some screens manually subscribe to finance service listeners.

## Services

## `AuthService`

Responsibilities:

- Initialize Supabase.
- Track current user profile.
- Sign in, sign up, verify OTP, reset password, update password.
- Upload avatar to Supabase storage.
- Update profile data.
- Save selected category.
- Sign out.

## `TransactionService`

Responsibilities:

- Fetch, add, update, delete, and clear transactions.
- Filter transactions for current user.
- Compute monthly income, monthly expense, total balance.
- Compute chart period buckets and category/wallet breakdowns.
- Use `WalletService` for initial balances and wallet grouping.

## `WalletService`

Responsibilities:

- Fetch user wallets.
- Insert onboarding wallets.
- Delete wallets.
- Compute total initial balance.
- Lookup wallet by id.

## `GoalService`

Responsibilities:

- Fetch goals.
- Return active goal.
- Set new active goal.
- Delete goals.
- Compute saved amount and progress ratio.

## Models

Main models:

- `UserModel`
- `TransactionModel`
- `WalletModel`
- `GoalModel`
- `CommunityPostModel`
- `ScanResultModel`

Models are simple data classes with `fromJson` and `toJson` methods for Supabase data conversion.

## Repositories

There is no separate repository layer in the current codebase. Services directly call Supabase.

If a repository layer is introduced later, it should be done consistently and not mixed into only one feature.

## Routing

Routes are centralized in `AppRoutes` and the `MaterialApp.routes` map.

The app mostly uses named routes for full-screen flows:

- Auth.
- Settings.
- Profile edit.
- Wallet onboarding.
- Budget setup.

Some feature navigation uses direct `MaterialPageRoute` or `PageRouteBuilder`, such as opening the dashboard page from Home and editing a transaction.

`MainShell` uses an `IndexedStack` for bottom navigation tabs.

## Dependency Relationships

Main dependency direction:

- UI depends on providers and services.
- Providers depend on services.
- Services depend on models and Supabase.
- Finance computations depend on `WalletService`.
- Goal UI depends on both `GoalService` and `TransactionService`.
- Profile/settings depend on `AuthService`.

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
- `auth.onAuthStateChange`
- `from(...).select/insert/update/delete/upsert`
- `storage.from('avatars').upload`
- `storage.from('avatars').getPublicUrl`

SQL migrations define schema, RLS, storage policies, wallet/goal additions, and profile trigger.

## Widget Hierarchy

Startup:

```text
ProviderScope
  FinFlowApp
    MaterialApp
      LaunchScreen
      OnboardingScreen
      Auth screens
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
        CommunityScreen
        ProfileScreen
    AppBottomNavBar
```

Home:

```text
HomeScreen
  ScrollView
    Header and balance area
    Goal summary card
    Period tabs
    Recent transaction list
```

Finance entry:

```text
AddTransactionSheet
  Amount input
  Account selector
  Category grid
  Confirm button
```

Dashboard:

```text
DashboardPage
  Header
  ListView
    Chart cards
      Period filter
      fl_chart widget
```
