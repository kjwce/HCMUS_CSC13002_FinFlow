import 'package:finflow/app/shell/finflow_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FinFlow app starts with launch screen', (tester) async {
    await tester.pumpWidget(const FinFlowApp());

    expect(find.text('FinFlow'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
