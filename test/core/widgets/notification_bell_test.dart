import 'package:finflow/core/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bell matches the circular light and dark header controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(body: Center(child: NotificationBell())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final circle = find.byKey(const Key('notification-bell-circle'));
    expect(tester.getSize(circle), const Size(40, 40));
    var decoration =
        tester.widget<Container>(circle).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, const Color(0xFFD7F5EA));
    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Center(child: NotificationBell())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    decoration = tester.widget<Container>(circle).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF0A241F));
    expect(tester.takeException(), isNull);
  });
}
