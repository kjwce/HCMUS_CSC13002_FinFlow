import 'package:finflow/app/shell/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBottomNav(
    WidgetTester tester, {
    required double bottomInset,
    VoidCallback? onAddTap,
    ValueChanged<int>? onTabChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 852),
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              key: const ValueKey('bottom-nav'),
              onAddTap: onAddTap,
              onTabChanged: onTabChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('adds the Android three-button navigation inset', (tester) async {
    await pumpBottomNav(tester, bottomInset: 48);

    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-nav'))).height,
      118,
    );
  });

  testWidgets('keeps the designed height when no bottom inset exists', (
    tester,
  ) async {
    await pumpBottomNav(tester, bottomInset: 0);

    expect(tester.getSize(find.byKey(const ValueKey('bottom-nav'))).height, 70);
  });

  testWidgets('center plus triggers add without changing tabs', (tester) async {
    var addCount = 0;
    var tabChangeCount = 0;
    await pumpBottomNav(
      tester,
      bottomInset: 0,
      onAddTap: () => addCount++,
      onTabChanged: (_) => tabChangeCount++,
    );

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 180));

    expect(addCount, 1);
    expect(tabChangeCount, 0);
  });

  testWidgets('shows the Stitch icons and labels', (tester) async {
    await pumpBottomNav(tester, bottomInset: 0);

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chatbot'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
