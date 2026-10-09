import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const Widget _box = SizedBox(width: 10, height: 10);

double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

double _scale(WidgetTester tester) =>
    tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;

Offset _offset(WidgetTester tester) => tester
    .widget<SlideTransition>(find.byType(SlideTransition))
    .position
    .value;

void main() {
  group('bug 4: CnScale(forward: false)', () {
    testWidgets('animates from end to begin', (tester) async {
      await tester.pumpWidget(wrap(const CnScale(
        forward: false,
        begin: 0.5,
        end: 1.0,
        child: _box,
      )));
      expect(_scale(tester), 1.0);

      await tester.pumpAndSettle();
      expect(_scale(tester), 0.5);
    });
  });

  group('bug 5: controller switched from external to null', () {
    late AnimationController external;

    setUp(() {
      external = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
    });

    tearDown(() => external.dispose());

    testWidgets('CnFade ends visible', (tester) async {
      await tester.pumpWidget(wrap(CnFade(controller: external, child: _box)));
      expect(_opacity(tester), 0);

      await tester.pumpWidget(wrap(const CnFade(child: _box)));
      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
    });

    testWidgets('CnSlide ends at end offset', (tester) async {
      await tester.pumpWidget(wrap(CnSlide(controller: external, child: _box)));
      expect(_offset(tester), const Offset(0, 0.5));

      await tester.pumpWidget(wrap(const CnSlide(child: _box)));
      await tester.pumpAndSettle();
      expect(_offset(tester), Offset.zero);
    });

    testWidgets('CnScale ends at end scale', (tester) async {
      await tester.pumpWidget(wrap(CnScale(controller: external, child: _box)));
      expect(_scale(tester), 0.7);

      await tester.pumpWidget(wrap(const CnScale(child: _box)));
      await tester.pumpAndSettle();
      expect(_scale(tester), 1.0);
    });
  });

  group('bug 6: duration changes after the first build', () {
    const Duration delay = Duration(milliseconds: 100);
    const Duration long = Duration(seconds: 2);
    const Duration short = Duration(milliseconds: 100);

    // Change the duration before the delayed start, then check that the
    // animation finishes within the new, shorter duration.
    Future<void> runShortened(
      WidgetTester tester,
      Widget Function(Duration duration) build,
    ) async {
      await tester.pumpWidget(wrap(build(long)));
      await tester.pumpWidget(wrap(build(short)));
      await tester.pump(delay); // delay timer fires, controller starts
      await tester.pump(const Duration(milliseconds: 150));
    }

    testWidgets('CnFade', (tester) async {
      await runShortened(
        tester,
        (d) => CnFade(duration: d, delay: delay, child: _box),
      );
      expect(_opacity(tester), 1);
    });

    testWidgets('CnSlide', (tester) async {
      await runShortened(
        tester,
        (d) => CnSlide(duration: d, delay: delay, child: _box),
      );
      expect(_offset(tester), Offset.zero);
    });

    testWidgets('CnScale', (tester) async {
      await runShortened(
        tester,
        (d) => CnScale(duration: d, delay: delay, child: _box),
      );
      expect(_scale(tester), 1.0);
    });
  });

  group('bug 7: CurvedAnimation is disposed', () {
    Future<void> expectNoLeak(
      WidgetTester tester,
      Widget Function(Curve curve) build,
    ) async {
      final tracker = CurvedAnimationTracker()..start();
      addTearDown(tracker.stop);

      for (final Curve curve in [Curves.linear, Curves.easeIn, Curves.easeOut]) {
        await tester.pumpWidget(wrap(build(curve)));
      }
      await tester.pumpWidget(const SizedBox());

      expect(tracker.created.length, greaterThanOrEqualTo(3));
      expect(tracker.leaked, isEmpty);
    }

    testWidgets('CnFade', (tester) async {
      await expectNoLeak(tester, (c) => CnFade(curve: c, child: _box));
    });

    testWidgets('CnSlide', (tester) async {
      await expectNoLeak(tester, (c) => CnSlide(curve: c, child: _box));
    });

    testWidgets('CnScale', (tester) async {
      await expectNoLeak(tester, (c) => CnScale(curve: c, child: _box));
    });
  });

  group('bug 8: initial delay timer is cancelled on dispose', () {
    // The test harness fails if a Timer is still pending after the tree
    // is disposed.
    const Duration delay = Duration(seconds: 1);

    testWidgets('CnFade', (tester) async {
      await tester.pumpWidget(wrap(const CnFade(delay: delay, child: _box)));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CnSlide', (tester) async {
      await tester.pumpWidget(wrap(const CnSlide(delay: delay, child: _box)));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('CnScale', (tester) async {
      await tester.pumpWidget(wrap(const CnScale(delay: delay, child: _box)));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('previously unused parameters', () {
    testWidgets('CnSlide applies intervalBegin / intervalEnd', (tester) async {
      await tester.pumpWidget(wrap(const CnSlide(
        begin: Offset(1, 0),
        duration: Duration(seconds: 1),
        intervalBegin: 0.5,
        curve: Curves.linear,
        child: _box,
      )));
      await tester.pump(const Duration(milliseconds: 1)); // start timer fires
      await tester.pump(const Duration(milliseconds: 400));
      expect(_offset(tester), const Offset(1, 0));

      await tester.pump(const Duration(milliseconds: 350)); // t = 0.75
      expect(_offset(tester).dx, closeTo(0.5, 0.01));
    });

    testWidgets('CnFade honors durationInMilliseconds', (tester) async {
      await tester.pumpWidget(wrap(const CnFade(
        duration: Duration(seconds: 2),
        // ignore: deprecated_member_use_from_same_package
        durationInMilliseconds: 100,
        delay: Duration.zero,
        child: _box,
      )));
      await tester.pump(const Duration(milliseconds: 1)); // start timer fires
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacity(tester), 1);
    });
  });

  group('reduced motion shows the final state immediately', () {
    testWidgets('CnFade', (tester) async {
      await tester.pumpWidget(
        wrap(const CnFade(child: _box), disableAnimations: true),
      );
      expect(_opacity(tester), 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('CnSlide', (tester) async {
      await tester.pumpWidget(
        wrap(const CnSlide(child: _box), disableAnimations: true),
      );
      expect(_offset(tester), Offset.zero);
    });

    testWidgets('CnScale with forward: false', (tester) async {
      await tester.pumpWidget(wrap(
        const CnScale(forward: false, begin: 0.5, child: _box),
        disableAnimations: true,
      ));
      expect(_scale(tester), 0.5);
    });

    testWidgets('does not tick after the delay', (tester) async {
      await tester.pumpWidget(
        wrap(const CnFade(child: _box), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 20)); // delay fires
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_opacity(tester), 1);
    });

    testWidgets('respectReducedMotion: false animates anyway', (tester) async {
      await tester.pumpWidget(wrap(
        const Column(children: [
          CnFade(respectReducedMotion: false, child: _box),
          CnSlide(respectReducedMotion: false, child: _box),
          CnScale(respectReducedMotion: false, child: _box),
        ]),
        disableAnimations: true,
      ));
      expect(_opacity(tester), 0);
      expect(_offset(tester), const Offset(0, 0.5));
      expect(_scale(tester), 0.7);

      await tester.pump(const Duration(milliseconds: 20)); // delays fire
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester), allOf(greaterThan(0), lessThan(1)));
      expect(_offset(tester).dy, allOf(greaterThan(0), lessThan(0.5)));
      expect(_scale(tester), allOf(greaterThan(0.7), lessThan(1)));

      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
    });
  });
}
