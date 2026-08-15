import 'package:finflow/app/shell/finflow_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets('FinFlow app starts with launch screen', (tester) async {
    await tester.pumpWidget(const FinFlowApp());

    expect(find.text('FinFlow'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
