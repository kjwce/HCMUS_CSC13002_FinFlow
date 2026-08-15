# Flutter UI Guidelines

This document is for AI code generation in the FinFlow Flutter UI.

## Responsive Design

- Use the existing `Responsive` helper from `core/utils/responsive.dart` for mobile-scaled dimensions.
- Prefer `Responsive.w(context, value)`, `Responsive.h(context, value)`, and `Responsive.sp(context, value)` where nearby code already uses them.
- Keep UI mobile-first.
- Use `SafeArea` for screens that touch system bars.
- Add bottom spacing for scrollable content above the bottom navigation bar.

## MediaQuery Usage

- `FinFlowApp` disables system font scaling through `MediaQuery.copyWith(textScaler: TextScaler.noScaling)`.
- Avoid adding local text scaling unless there is a clear need.
- Use `MediaQuery.of(context).viewInsets.bottom` for bottom sheets with keyboard input.
- Do not use raw viewport width to scale fonts directly.

## Existing Responsive Helper

Follow current patterns:

- `Responsive.w` for horizontal sizes, icon widths, small square controls.
- `Responsive.h` for vertical spacing and heights.
- `Responsive.sp` for font sizes.

Do not introduce another responsive utility without replacing the old one consistently.

## Theme Usage

- Prefer `Theme.of(context)`, `AppColors`, and the `FinFlowColors` `ThemeExtension` (via `context.finFlowColors`) for colors.
- Use `AppTheme.light` and `AppTheme.dark` conventions.
- Use `AppThemeManager.instance` for theme toggling.
- When adding new screens, support both light and dark theme where practical (the redesigned screens — Home, Community, Profile, Goals, Chat — read `FinFlowColors` or local dark constants).

## Color Rules

- Use `AppColors` instead of new hardcoded colors when a matching color exists.
- Preserve existing semantic color use:
  - Green for primary actions and success/brand.
  - Light green for soft surfaces.
  - Dark green/near-black for main text.
  - Blue for scan and secondary financial emphasis.
  - Coral/red for expense, warnings, delete actions.
- If a hardcoded color is necessary, keep it local and consistent with the existing palette.

## Typography Rules

- Use `Poppins` where current feature screens use `Poppins`.
- Use `Roboto` where theme/default text is expected.
- Keep labels and metadata readable on small screens.
- Use `maxLines`, `overflow`, or flexible layout for dynamic text.
- Avoid text overlapping icons or amounts in rows.

## Widget Composition

- Break large screens into private helper widgets or methods when it improves readability.
- Keep reusable shared widgets under `core/widgets` only when they are genuinely cross-feature.
- Use feature-local private widgets for one-screen components.
- Prefer composition over large conditional blocks in build methods.

## Preferred Widgets

- `Scaffold` for full screens.
- `SafeArea` for screen bodies.
- `SingleChildScrollView` or `ListView` for vertical scrolling.
- `ListView.builder` for long or chart-heavy lists.
- `IndexedStack` for persistent bottom-nav tabs.
- `showModalBottomSheet` for add/select flows.
- `AlertDialog` for destructive confirmation.
- `SnackBar` for short feedback.
- `SvgPicture.asset` for SVG assets.
- `Image.asset` for bank/e-wallet logos and covers.

## Forbidden Practices

- Do not modify app behavior when only UI styling is requested.
- Do not add a second navigation framework unless explicitly requested.
- Do not create new global state patterns casually.
- Do not duplicate colors or responsive utilities without need.
- Do not block app startup on network calls.
- Do not place network/backend calls directly in low-level reusable widgets.
- Do not store custom categories or important user data only in memory if persistence is required.

## Layout Principles

- Keep major screens vertically scrollable.
- Use `Expanded` in rows where labels can grow.
- Give financial amount text enough space.
- Use `FittedBox` sparingly for compact controls.
- Avoid nested scroll views unless necessary.
- Keep chart containers constrained by height.
- Use empty placeholders for no-data chart states.

## Performance Considerations

- Use `RepaintBoundary` around expensive chart widgets where appropriate.
- Use `ListView.builder` for dashboard chart lists and long lists.
- Avoid repeatedly fetching data inside `build`.
- Use `initState` and `Future.microtask` for initial fetches where current patterns do this.
- Dispose controllers and remove listeners in `dispose`.
- Avoid rebuilding full screens from high-frequency listeners when a smaller widget can listen.

## Bottom Sheets

- Use `isScrollControlled: true` for sheets with forms.
- Add keyboard-aware bottom padding.
- Keep action buttons clear and reachable.
- Validate before calling services.

## Forms and Inputs

- Dispose `TextEditingController`s.
- Use numeric keyboards for amount inputs.
- Keep VND formatting consistent with existing comma formatting.
- Validate empty or invalid amount before writing to Supabase.
- Show error feedback with `SnackBar`.

## Charts

- Use `fl_chart` for chart UI.
- Keep period filtering consistent with `ChartPeriod`.
- Show a no-data placeholder when computed data is empty.
- Make wide charts horizontally scrollable.

## Navigation UI

- Use named routes for major full-screen flows listed in `AppRoutes`.
- Use direct routes only for local feature detail screens where current code already does so.
- Keep bottom navigation state inside `MainShell`.
