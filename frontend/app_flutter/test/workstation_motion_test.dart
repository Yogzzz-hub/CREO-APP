import 'package:app_flutter/src/features/workstation/workstation_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Press cancellation and app pause restore visual state without activating button',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkstationPressFeedback(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Start work'),
              ),
            ),
          ),
        ),
      );
      final press = await tester.startGesture(
        tester.getCenter(find.text('Start work')),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .98,
      );
      await press.cancel();
      await tester.pump(const Duration(milliseconds: 160));
      expect(taps, 0);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      final next = await tester.startGesture(
        tester.getCenter(find.text('Start work')),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await next.cancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Start work'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    },
  );
  testWidgets('Reduced motion keeps the button stable and usable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: WorkstationPressFeedback(
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('Submit'),
            ),
          ),
        ),
      ),
    );
    final press = await tester.startGesture(
      tester.getCenter(find.text('Submit')),
    );
    await tester.pump();
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
    await press.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
