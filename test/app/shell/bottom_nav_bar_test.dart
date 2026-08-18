import 'package:finflow/app/shell/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    expect(find.byKey(const Key('bottom-nav-icon-0-fill')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-icon-1-regular')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-icon-3-regular')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-icon-4-regular')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chatbot'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundles every Phosphor navigation SVG', (tester) async {
    const assets = [
      'assets/icons/navigation/house-line-regular.svg',
      'assets/icons/navigation/house-line-fill.svg',
      'assets/icons/navigation/robot-regular.svg',
      'assets/icons/navigation/robot-fill.svg',
      'assets/icons/navigation/users-three-regular.svg',
      'assets/icons/navigation/users-three-fill.svg',
      'assets/icons/navigation/user-circle-regular.svg',
      'assets/icons/navigation/user-circle-fill.svg',
    ];

    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(100), reason: asset);
    }
  });

  testWidgets('switches a destination from regular to fill', (tester) async {
    var selectedIndex = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              selectedIndex: selectedIndex,
              onTabChanged: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chatbot'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bottom-nav-icon-0-regular')), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-icon-1-fill')), findsOneWidget);
  });
}
