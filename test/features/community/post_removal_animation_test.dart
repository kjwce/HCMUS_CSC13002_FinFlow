import 'package:finflow/features/community/presentation/widgets/post_removal_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slides, fades, and collapses a removed post', (tester) async {
    var removing = false;
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PostRemovalAnimation(
                removing: removing,
                child: const SizedBox(
                  key: Key('post-card'),
                  width: 200,
                  height: 100,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PostRemovalAnimation)).height, 100);

    rebuild(() => removing = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));

    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(PostRemovalAnimation),
        matching: find.byType(Opacity),
      ),
    );
    final translation = tester.widget<FractionalTranslation>(
      find.descendant(
        of: find.byType(PostRemovalAnimation),
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(opacity.opacity, lessThan(1));
    expect(opacity.opacity, greaterThan(0));
    expect(translation.translation.dx, lessThan(0));

    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(PostRemovalAnimation)).height, 0);
    expect(
      tester
          .widget<IgnorePointer>(
            find.descendant(
              of: find.byType(PostRemovalAnimation),
              matching: find.byType(IgnorePointer),
            ),
          )
          .ignoring,
      isTrue,
    );
  });
}
