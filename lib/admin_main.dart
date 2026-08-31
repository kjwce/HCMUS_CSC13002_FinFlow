import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/i18n/app_language.dart';
import 'core/theme/app_theme_manager.dart';
import 'features/admin/presentation/admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AppLanguage.instance.init(),
    AppThemeManager.instance.init(),
  ]);
  await Supabase.initialize(
    url: SupabaseConstants.url,
    publishableKey: SupabaseConstants.anonKey,
  );
  runApp(const FinFlowAdminApp());
}
