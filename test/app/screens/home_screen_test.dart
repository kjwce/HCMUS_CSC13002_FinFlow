import 'package:finflow/app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-publishable-key',
    );
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SafeArea(child: HomeScreen())),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders Stitch sections without overflow on a narrow phone', (
    tester,
  ) async {
    await pumpHome(tester, const Size(320, 568));

    expect(find.text('View Financial Insights'), findsOneWidget);
    expect(find.text('Savings Goals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the transaction section on a large phone', (
    tester,
  ) async {
    await pumpHome(tester, const Size(430, 932));
    await tester.scrollUntilVisible(
      find.text('Recent Transactions'),
      350,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
