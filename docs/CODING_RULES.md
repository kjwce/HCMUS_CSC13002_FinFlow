# Coding Rules

## Naming Conventions

- Dart files use `snake_case.dart`.
- Classes, widgets, enums, and models use `PascalCase`.
- Methods, variables, fields, and providers use `camelCase`.
- Private members use a leading underscore.
- Provider names end with `Provider`.
- Service classes end with `Service`.
- Model classes end with `Model`.

## Folder Conventions

Use existing feature layout:

```text
features/<feature>/
  models/
  presentation/
  providers/
  services/
```

Only create folders that are needed for that feature.

Shared app-level code belongs in:

- `app/` for shell, routes, tab-level screens.
- `core/` for theme, utilities, constants, app-wide widgets.

## File Naming

- Screen files end in `_screen.dart` or `_page.dart`.
- Bottom sheet files may end in `_sheet.dart`.
- Provider files end in `_provider.dart`.
- Service files end in `_service.dart`.
- Model files end in `_model.dart`.

Follow the naming style already used in the same folder.

## Riverpod Usage

Current project style:

- Use providers as thin accessors to singleton services.
- Read services with `ref.read(...)` for actions.
- Watch services with `ref.watch(...)` for UI state, but remember plain `Provider` does not react to `notifyListeners`.

When changing provider patterns:

- Be consistent across the feature.
- Prefer `ChangeNotifierProvider` if UI must rebuild from `notifyListeners`.
- Avoid mixing multiple state management styles in the same feature.

## Service Usage

- Keep Supabase calls inside service classes.
- UI should call service methods through providers or the singleton when existing code does that.
- Services should update local cached state after successful writes.
- Services should notify listeners after state changes.
- Services should guard against missing authenticated users.

## Async Rules

- Use `async`/`await` for Supabase calls.
- Check `mounted` or `context.mounted` after awaits before touching UI context.
- Use `try/catch` around network/database operations.
- Do not fetch data repeatedly from `build`.
- Use `Future.microtask` in `initState` only when matching existing pattern.

## Error Handling

- Auth failures usually return `false` or throw user-facing messages depending on existing method behavior.
- UI should show `SnackBar` for failed save/add/update actions.
- Services may log non-fatal errors with `debugPrint`.
- Avoid crashing the app for Supabase initialization failures; current startup intentionally continues in a no-backend mode.

## Logging

- Use `debugPrint` for development logs.
- Keep logs short and useful.
- Do not log passwords, OTP tokens, or private user data.
- Existing code logs some auth/debug events; follow that style only when needed.

## Comments

- Prefer self-explanatory code.
- Add comments for non-obvious behavior, such as:
  - Why startup does not wait for network.
  - Why a route redirect is delayed with post-frame callback.
  - Why a cache is cleared on notify.
- Do not add comments that restate obvious assignments.

## Code Formatting

- Use Dart formatting conventions.
- Keep imports grouped by Dart/Flutter/package/local style.
- Avoid unrelated formatting churn.
- Keep long widgets readable by extracting helper methods or private widgets.

## Reusable Widgets

Use `core/widgets` for shared widgets used across multiple features, such as:

- Logo.
- Notification bell.
- Transaction tile.
- Language switcher.
- Shared scaffolds.

Keep feature-specific widgets private in the feature file or folder.

## Extension Methods

The project has a context extension for language helpers in `app_language.dart`.

Rules:

- Add extensions only when they improve repeated call sites.
- Keep extensions near their domain.
- Avoid broad extensions on common types unless clearly useful.

## Separation of Concerns

- UI builds widgets and handles user interaction.
- Services own Supabase access and computed domain data.
- Models own serialization/deserialization.
- Theme/colors stay in `core/theme`.
- Static strings should use `AppStrings` where practical.
- Assets should be referenced from declared `pubspec.yaml` paths.

## Best Practices Already Used

- Guarding startup with `runZonedGuarded`.
- Rendering app immediately while Supabase initializes in background.
- Disposing controllers.
- Checking `mounted` after async calls.
- Using RLS in Supabase migrations.
- Keeping route names centralized in `AppRoutes`.
- Using models for Supabase row parsing.
- Using services as the boundary for backend operations.
- Using empty chart placeholders instead of rendering broken charts.
- Using cached computed values in `TransactionService`.

## Important Cautions

- Do not overwrite user changes in a dirty worktree.
- Do not remove existing Supabase migrations unless explicitly requested.
- Keep SQL migrations as the source of database structure.
- Avoid reintroducing standalone schema files that can drift from migrations.
- Preserve current app flows unless the task explicitly asks to change them.
