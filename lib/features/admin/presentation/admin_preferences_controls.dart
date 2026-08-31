import 'package:flutter/material.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_theme_manager.dart';

class AdminPreferencesControls extends StatelessWidget {
  const AdminPreferencesControls({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: AppThemeManager.instance.toggle,
          tooltip: AppStrings.choose('Switch theme', 'Đổi giao diện'),
          icon: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
        PopupMenuButton<AppLocale>(
          tooltip: AppStrings.choose('Language', 'Ngôn ngữ'),
          onSelected: AppLanguage.instance.setLocale,
          itemBuilder: (_) => AppLocale.values
              .map(
                (locale) => PopupMenuItem(
                  value: locale,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(locale == AppLocale.english ? 'EN' : 'VI'),
                      ),
                      const SizedBox(width: 8),
                      Text(locale.label),
                      if (locale == AppLanguage.instance.locale) ...[
                        const Spacer(),
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                const Icon(Icons.language_rounded, size: 20),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(AppLanguage.instance.locale.code.toUpperCase()),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
