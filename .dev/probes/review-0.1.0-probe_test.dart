import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const Key _raKey = Key('route-aware');

Widget _app(GlobalKey<NavigatorState> navigatorKey, Widget home,
    {ValueNotifier<bool>? disable}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    navigatorObservers: [RouteAwareWidget.routeObserver],
    builder: (context, child) => disable == null
        ? child!
        : ValueListenableBuilder<bool>(
            valueListenable: disable,
            builder: (context, d, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: d),
              child: child!,
            ),
          ),
    home: home,
  );
}

Route<void> _plainRoute() => PageRouteBuilder<void>(
      pageBuilder: (c, a, s) => const Text('next page'),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      opaque: false,
    );

Finder _inside(Key key, Type type) => find.descendant(
      of: find.byKey(key, skipOffstage: false),
      matching: find.byType(type, skipOffstage: false),
    );

double _raOpacity(WidgetTester tester, [Key key = _raKey]) => tester
    .widget<FadeTransition>(_inside(key, FadeTransition).first)
    .opacity
    .value;

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => Text('n=$n');
}

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  setUp(() => navigatorKey = GlobalKey<NavigatorState>());

  testWidgets('P1 external controller ignored under reduced motion',
      (tester) async {
    final c = AnimationController(vsync: const TestVSync(), value: 0);
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(
      CnFade(controller: c, child: const SizedBox()),
      disableAnimations: true,
    ));
    final v = tester
        .widget<FadeTransition>(find.byType(FadeTransition))
        .opacity
        .value;
    // ignore: avoid_print
    print('P1 opacity with external controller at 0 under reduced motion: $v');
  });

  testWidgets('P2 runtime reduced-motion toggle loses child state + replays',
      (tester) async {
    final disable = ValueNotifier<bool>(false);
    addTearDown(disable.dispose);
    await tester.pumpWidget(_app(
      navigatorKey,
      const CnRouteAwareAnimation(key: _raKey, child: _Counter()),
      disable: disable,
    ));
    await tester.pumpAndSettle();
    tester.state<_CounterState>(find.byType(_Counter)).n = 5;
    final before = tester.state<_CounterState>(find.byType(_Counter));
    disable.value = true;
    await tester.pump();
    final mid = tester.state<_CounterState>(find.byType(_Counter));
    disable.value = false;
    await tester.pump();
    final after = tester.state<_CounterState>(find.byType(_Counter));
    final op = _raOpacity(tester);
    // ignore: avoid_print
    print('P2 state kept on->: ${identical(before, mid)}, '
        'off->: ${identical(mid, after)}, n=${after.n}, opacity right after '
        'toggle off: $op');
    await tester.pumpAndSettle();
  });

  testWidgets('P3 showPopNext:false leaves child invisible after pop',
      (tester) async {
    await tester.pumpWidget(_app(
      navigatorKey,
      const CnRouteAwareAnimation(
          key: _raKey, showPopNext: false, child: Text('A')),
    ));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(_plainRoute());
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('P3 opacity after push/pop with showPopNext:false: '
        '${_raOpacity(tester)}');
  });

  testWidgets('P4 hot reload does not replay or crash', (tester) async {
    await tester.pumpWidget(_app(
      navigatorKey,
      const CnRouteAwareAnimation(key: _raKey, child: Text('A')),
    ));
    await tester.pumpAndSettle();
    // ignore: unawaited_futures
    tester.binding.reassembleApplication();
    await tester.pump();
    // ignore: avoid_print
    print('P4 after reassemble opacity ${_raOpacity(tester)} '
        'scheduled=${tester.binding.hasScheduledFrame}');
    await tester.pumpAndSettle();
  });

  testWidgets('P5 route change resubscribe via GlobalKey reparent',
      (tester) async {
    final onA = ValueNotifier<bool>(true);
    addTearDown(onA.dispose);
    final gk = GlobalKey();
    int push = 0, pushNext = 0, popNext = 0;
    Widget ra() => RouteAwareWidget(
          key: gk,
          onPush: () => push++,
          onPushNext: () => pushNext++,
          onPopNext: () => popNext++,
          child: const Text('ra'),
        );
    await tester.pumpWidget(_app(
      navigatorKey,
      ValueListenableBuilder<bool>(
        valueListenable: onA,
        builder: (c, a, _) => a ? ra() : const SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(PageRouteBuilder<void>(
      pageBuilder: (c, a, s) => ValueListenableBuilder<bool>(
        valueListenable: onA,
        builder: (c, a, _) => a ? const SizedBox() : ra(),
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      opaque: false,
    ));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('P5 before reparent push=$push pushNext=$pushNext');
    onA.value = false; // move into route B in one frame
    await tester.pump();
    // ignore: avoid_print
    print('P5 after reparent push=$push pushNext=$pushNext '
        'exception=${tester.takeException()}');
    navigatorKey.currentState!.push(_plainRoute());
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('P5 after push C on top of B: pushNext=$pushNext');
  });

  testWidgets('P6 reduced motion turned on mid push, off later, RA inside',
      (tester) async {
    final disable = ValueNotifier<bool>(false);
    addTearDown(disable.dispose);
    await tester.pumpWidget(_app(
      navigatorKey,
      const CnRouteAwareAnimation(key: _raKey, child: Text('A')),
      disable: disable,
    ));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(_plainRoute()); // A fades out
    await tester.pumpAndSettle();
    disable.value = true;
    await tester.pump();
    navigatorKey.currentState!.pop(); // no popNext delivered
    await tester.pumpAndSettle();
    disable.value = false;
    await tester.pump();
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('P6 final opacity ${_raOpacity(tester)}');
  });
}
