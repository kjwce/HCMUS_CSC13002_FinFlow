import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_theme_manager.dart';
import '../services/admin_moderation_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_login_screen.dart';
import 'admin_theme.dart';

class FinFlowAdminApp extends StatefulWidget {
  const FinFlowAdminApp({super.key});

  @override
  State<FinFlowAdminApp> createState() => _FinFlowAdminAppState();
}

class _FinFlowAdminAppState extends State<FinFlowAdminApp> {
  final _service = AdminModerationService();
  late Future<bool> _authorization;

  @override
  void initState() {
    super.initState();
    _authorization = _service.isCurrentUserAdmin();
    AppLanguage.instance.addListener(_rebuildPreferences);
    AppThemeManager.instance.addListener(_rebuildPreferences);
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_rebuildPreferences);
    AppThemeManager.instance.removeListener(_rebuildPreferences);
    super.dispose();
  }

  void _rebuildPreferences() => setState(() {});

  void _refreshAuthorization() {
    setState(() {
      _authorization = _service.isCurrentUserAdmin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinFlow Community Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(Brightness.light),
      darkTheme: buildAdminTheme(Brightness.dark),
      themeMode: AppThemeManager.instance.mode,
      locale: Locale(AppLanguage.instance.locale.code),
      supportedLocales: const [Locale('en'), Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<bool>(
        future: _authorization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _AdminLoadingScreen();
          }
          if (snapshot.data == true) {
            return AdminDashboardScreen(
              service: _service,
              onSignedOut: _refreshAuthorization,
            );
          }
          return AdminLoginScreen(
            service: _service,
            onSignedIn: _refreshAuthorization,
          );
        },
      ),
    );
  }
}

class _AdminLoadingScreen extends StatelessWidget {
  const _AdminLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
