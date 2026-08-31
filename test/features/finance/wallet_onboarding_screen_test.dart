import 'package:finflow/core/i18n/app_language.dart';
import 'package:finflow/core/theme/app_theme.dart';
import 'package:finflow/features/finance/presentation/wallet_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AppLanguage.instance.setLocale(AppLocale.english));
  tearDown(() => AppLanguage.instance.setLocale(AppLocale.english));

  testWidgets('opening balances are grouped with thousands separators', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const WalletOnboardingScreen()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.first, '61930000');
    await tester.enterText(fields.last, '24968342');
    await tester.pump();

    expect(find.text('61,930,000'), findsOneWidget);
    expect(find.text('24,968,342'), findsOneWidget);
  });
}
