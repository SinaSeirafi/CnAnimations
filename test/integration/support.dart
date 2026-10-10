/// Shared harness for the integration and claim tests (design §8).
///
/// Everything here goes through the public barrel. Element values are read
/// from the element's own `FadeTransition` / `SlideTransition` (the first of
/// each below the keyed `CnRouteAnimation`), with `skipOffstage: false`
/// because a fully covered page is offstage.
library;

import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// No stagger, so expected values are exact functions of route progress.
const CnRouteTiming flat = CnRouteTiming(exitStagger: 0, enterStagger: 0);

/// The default slices with the curves the element applies to them.
const Interval enterSlice = Interval(0.35, 1.0, curve: Curves.easeOutCubic);
const Interval exitSlice = Interval(0.0, 0.35, curve: Curves.easeIn);

/// shown while this page enters (A rising from 0), no stagger.
double shownEntering(double a) => enterSlice.transform(a);

/// shown while this page leaves (A falling from 1), no stagger.
double shownLeaving(double a) => 1.0 - exitSlice.transform(1.0 - a);

/// covered while S rises from 0 (cover), or falls back to 0 without having
/// reached 1 (a reversed push), no stagger.
double coveredAt(double s) => exitSlice.transform(s);

/// The default uncover slice (review R6) with the exit curve.
const Interval uncoverSlice = Interval(0.3, 0.65, curve: Curves.easeIn);

/// covered while S falls from 1 (uncover: pop, interactive back, and a
/// cancelled back gesture climbing back to 1), no stagger.
double uncoveredAt(double s) => uncoverSlice.transform(s);

const double eps = 1e-6;

const List<TargetPlatform> _allPlatforms = TargetPlatform.values;

/// The fade-through installed for every platform, on [platform].
ThemeData fadeThroughTheme({
  TargetPlatform platform = TargetPlatform.android,
}) => ThemeData(
  platform: platform,
  pageTransitionsTheme: PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      for (final TargetPlatform p in _allPlatforms)
        p: const CnFadeThroughPageTransitionsBuilder(),
    },
  ),
);

/// The two ways to install the fade-through (design §3.7).
enum Install { cnPageRoute, themeOverMaterial }

Route<T> routeFor<T>(Install install, WidgetBuilder builder) {
  switch (install) {
    case Install.cnPageRoute:
      return CnPageRoute<T>(builder: builder);
    case Install.themeOverMaterial:
      return MaterialPageRoute<T>(builder: builder);
  }
}

/// CnPageRoute must work without touching the theme, so its variant runs
/// under the stock theme.
ThemeData themeFor(
  Install install, {
  TargetPlatform platform = TargetPlatform.android,
}) {
  switch (install) {
    case Install.cnPageRoute:
      return ThemeData(platform: platform);
    case Install.themeOverMaterial:
      return fadeThroughTheme(platform: platform);
  }
}

Finder _own<T>(String label) => find
    .descendant(
      of: find.byKey(ValueKey<String>(label), skipOffstage: false),
      matching: find.byType(T, skipOffstage: false),
    )
    .first;

bool exists(String label) => find
    .byKey(ValueKey<String>(label), skipOffstage: false)
    .evaluate()
    .isNotEmpty;

/// The element's own opacity.
double opacityOf(WidgetTester tester, String label) =>
    tester.widget<FadeTransition>(_own<FadeTransition>(label)).opacity.value;

/// The element's own slide, as a fraction of its size.
Offset offsetOf(WidgetTester tester, String label) =>
    tester.widget<SlideTransition>(_own<SlideTransition>(label)).position.value;

/// The element's own scale.
double scaleOf(WidgetTester tester, String label) =>
    tester.widget<ScaleTransition>(_own<ScaleTransition>(label)).scale.value;

ModalRoute<Object?> routeOf(WidgetTester tester, String label) => ModalRoute.of(
  tester.element(find.byKey(ValueKey<String>(label), skipOffstage: false)),
)!;

/// Records the last progress handed to a `builder:`.
class ProgressLog {
  CnElementProgress? last;

  Widget builder(BuildContext context, CnElementProgress p, Widget? child) {
    last = p;
    return child!;
  }
}

/// A 100 px tall element.
Widget item(
  String label, {
  CnRouteTiming? timing = flat,
  double height = 100,
  Widget? child,
  CnRouteAnimationBuilder? builder,
}) {
  return CnRouteAnimation(
    key: ValueKey<String>(label),
    timing: timing,
    builder: builder,
    child: child ?? SizedBox(height: height, child: Text(label)),
  );
}

Widget column(List<Widget> children) =>
    Column(mainAxisSize: MainAxisSize.min, children: children);

Future<GlobalKey<NavigatorState>> pumpApp(
  WidgetTester tester,
  Widget home, {
  ThemeData? theme,
  TransitionBuilder? builder,
}) async {
  final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: theme ?? fadeThroughTheme(),
      builder: builder,
      home: home,
    ),
  );
  return nav;
}

/// Pumps [frames] frames of [step], calling [each] after every one.
Future<void> pumpFrames(
  WidgetTester tester,
  int frames, {
  Duration step = const Duration(milliseconds: 16),
  void Function(int frame)? each,
}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(step);
    each?.call(i);
  }
}

/// Asserts consecutive samples never differ by more than [bound].
void expectContinuous(List<double> samples, double bound, {String? what}) {
  for (int i = 1; i < samples.length; i++) {
    expect(
      (samples[i] - samples[i - 1]).abs(),
      lessThanOrEqualTo(bound),
      reason:
          '${what ?? 'sample'} jumped between frame ${i - 1} '
          '(${samples[i - 1]}) and $i (${samples[i]}); all: $samples',
    );
  }
}

/// Sends a system (Android) predictive-back message on the real channel,
/// as the engine would.
Future<void> sendBackGesture(
  WidgetTester tester,
  String method, {
  double progress = 0.0,
}) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(
      method,
      method == 'startBackGesture' || method == 'updateBackGestureProgress'
          ? <String, Object?>{
              'touchOffset': <double>[5.0, 300.0],
              'progress': progress,
              'swipeEdge': 0,
            }
          : null,
    ),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
}

/// Counts live AnimationControllers and CurvedAnimations through
/// FlutterMemoryAllocations (debug builds dispatch these events).
class AllocationTracker {
  final Map<String, Set<Object>> created = <String, Set<Object>>{};
  final Set<Object> disposed = <Object>{};

  void _listener(ObjectEvent event) {
    if (event is ObjectCreated) {
      created.putIfAbsent(event.className, () => <Object>{}).add(event.object);
    } else if (event is ObjectDisposed) {
      disposed.add(event.object);
    }
  }

  void start() => FlutterMemoryAllocations.instance.addListener(_listener);
  void stop() => FlutterMemoryAllocations.instance.removeListener(_listener);

  Set<Object> live(String className) =>
      (created[className] ?? <Object>{}).difference(disposed);
}
