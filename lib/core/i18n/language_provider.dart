import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';

/// Expose AppLanguage singleton as Riverpod provider.
final languageProvider = Provider<AppLanguage>((ref) {
  return AppLanguage.instance;
});
