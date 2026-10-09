import 'package:cn_animations/src/progress/cn_directional_curved_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// easeIn(t) < t < easeOut(t) for every t strictly inside (0, 1), so the
// curve in use can be read back from the value alone.
const Curve _enter = Curves.easeIn;
const Curve _exit = Curves.easeOut;

/// Which curve produced [animation]'s current value: 'rest', 'enter' or
/// 'exit'.
String curveInUse(CnDirectionalCurvedAnimation animation) {
  final double t = animation.parent.value;
  final double v = animation.value;
  if (t <= 0.0 || t >= 1.0) {
    expect(v, t, reason: 'rest values pass through unchanged');
    return 'rest';
  }
  if ((v - _enter.transform(t)).abs() < 1e-9) return 'enter';
  if ((v - _exit.transform(t)).abs() < 1e-9) return 'exit';
  fail('value $v at parent $t matches neither curve');
}

CnDirectionalCurvedAnimation curved(Animation<double> parent) =>
    CnDirectionalCurvedAnimation(parent, enter: _enter, exit: _exit);

/// A ProxyAnimation that counts status listeners, to observe attach/detach.
class _CountingProxy extends ProxyAnimation {
  _CountingProxy(super.animation);

  int statusListeners = 0;

  @override
  void addStatusListener(AnimationStatusListener listener) {
    statusListeners += 1;
    super.addStatusListener(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    statusListeners -= 1;
    super.removeStatusListener(listener);
  }
}

void main() {
  testWidgets(
    'probe H: from completed, value = 0.95 then reverse() uses exit each step',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 400),
        value: 1.0,
      );
      addTearDown(controller.dispose);
      final animation = curved(controller);

      expect(controller.status, AnimationStatus.completed);
      expect(curveInUse(animation), 'rest');

      // A gesture-driven exit: value drops from 1 while status is forward.
      controller.value = 0.95;
      expect(controller.status, AnimationStatus.forward);
      expect(curveInUse(animation), 'exit');

      controller.value = 0.6;
      expect(curveInUse(animation), 'exit');

      // Commit flips the status to reverse; the curve does not change.
      controller.reverse();
      expect(controller.status, AnimationStatus.reverse);
      final steps = <String>[];
      while (controller.value > 0.0) {
        await tester.pump(const Duration(milliseconds: 40));
        steps.add(curveInUse(animation));
      }
      expect(steps.last, 'rest');
      expect(steps.sublist(0, steps.length - 1), everyElement('exit'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(controller.status, AnimationStatus.dismissed);

      // Leaving 0 now selects enter, even though the last segment was exit.
      controller.forward();
      final forward = <String>[];
      while (controller.value < 1.0) {
        await tester.pump(const Duration(milliseconds: 40));
        forward.add(curveInUse(animation));
      }
      // The first tick after forward() sits at 0 (ticker start), then enter.
      final moving = forward.where((s) => s != 'rest');
      expect(moving, isNotEmpty);
      expect(moving, everyElement('enter'));
      expect(forward.last, 'rest');
      await tester.pump(const Duration(milliseconds: 40));
      expect(controller.status, AnimationStatus.completed);
    },
  );

  test('leaving 0 locks enter until the next rest, in both directions', () {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);
    final animation = curved(controller);

    expect(curveInUse(animation), 'rest');
    for (final t in <double>[0.3, 0.7, 0.2, 0.9]) {
      controller.value = t;
      expect(curveInUse(animation), 'enter', reason: 'at $t');
    }
    // A push popped halfway: back to 0 with status reverse still uses enter.
    controller.value = 0.4;
    controller.reverse(); // status flips now; the value moves on later ticks
    expect(controller.status, AnimationStatus.reverse);
    expect(curveInUse(animation), 'enter');
  });

  test('a cancelled exit (leave 1, return toward 1) keeps exit', () {
    final controller = AnimationController(vsync: const TestVSync(), value: 1);
    addTearDown(controller.dispose);
    final animation = curved(controller);

    expect(curveInUse(animation), 'rest');
    controller.value = 0.6;
    expect(curveInUse(animation), 'exit');
    controller.value = 0.9; // moving back up, status forward
    expect(curveInUse(animation), 'exit');
    controller.value = 1.0;
    expect(curveInUse(animation), 'rest');
    controller.value = 0.8;
    expect(curveInUse(animation), 'exit');
  });

  test('mid-flight construction infers the rest from status', () {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
    addTearDown(controller.dispose);

    controller.value = 0.5; // forward
    expect(curveInUse(curved(controller)), 'enter');

    controller.reverse(); // status reverse, value still 0.5
    expect(controller.status, AnimationStatus.reverse);
    expect(curveInUse(curved(controller)), 'exit');
  });

  test('status, isCompleted and isDismissed delegate to the parent', () {
    final controller = AnimationController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    final animation = curved(controller);

    expect(animation.isDismissed, isTrue);
    controller.value = 1.0;
    expect(animation.status, AnimationStatus.completed);
    expect(animation.isCompleted, isTrue);
    controller.value = 0.95;
    expect(animation.status, AnimationStatus.forward);
  });

  test('records a rest it never read while it has listeners', () {
    final controller = AnimationController(vsync: const TestVSync());
    addTearDown(controller.dispose);
    final proxy = _CountingProxy(controller);
    final animation = curved(proxy);

    void listener() {}
    animation.addListener(listener);
    expect(proxy.statusListeners, 1);

    controller.value = 0.5;
    expect(curveInUse(animation), 'enter');
    // Reaches 1 without anyone reading the value (an offstage page), then
    // leaves it: the status listener recorded the rest.
    controller.value = 1.0;
    controller.value = 0.5;
    expect(curveInUse(animation), 'exit');

    // Detaches from the parent when the last listener goes.
    void statusListener(AnimationStatus _) {}
    animation.addStatusListener(statusListener);
    expect(proxy.statusListeners, 2); // ours + the forwarded one
    animation.removeListener(listener);
    expect(proxy.statusListeners, 2, reason: 'a status listener remains');
    animation.removeStatusListener(statusListener);
    expect(proxy.statusListeners, 0);
  });

  testWidgets('first frame of a push (proxy reads 1.0) still enters', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    nav.currentState!.push(route);
    // HeroController puts the route offstage for one frame; its animation
    // proxy reads kAlwaysCompleteAnimation.
    expect(route.offstage, isTrue);
    expect(route.animation!.value, 1.0);

    final animation = curved(route.animation!);
    void listener() {}
    animation.addListener(listener);
    addTearDown(() => animation.removeListener(listener));

    // Do not read on the frame the proxy swaps to the controller at 0.0.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final steps = <String>[];
    while (route.animation!.value < 1.0) {
      steps.add(curveInUse(animation));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(steps, isNotEmpty);
    expect(steps, everyElement('enter'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'predictive back on a real route uses exit while dragging and on commit',
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const SizedBox()),
      );
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      nav.currentState!.push(route);
      await tester.pumpAndSettle();

      final animation = curved(route.animation!);
      expect(curveInUse(animation), 'rest');

      route.handleStartBackGesture(progress: 0.95);
      await tester.pump();
      expect(route.animation!.status, AnimationStatus.forward);
      expect(curveInUse(animation), 'exit');

      route.handleUpdateBackGestureProgress(progress: 0.6);
      await tester.pump();
      expect(curveInUse(animation), 'exit');

      route.handleCommitBackGesture();
      await tester.pump();
      expect(route.animation!.status, AnimationStatus.reverse);
      while (route.animation!.value > 0.0) {
        expect(curveInUse(animation), 'exit');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    },
  );
}
