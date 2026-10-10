import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal tree for the basic widgets: no MaterialApp, so the only
/// transitions in the tree are the ones under test.
Widget wrap(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

/// Product of every FadeTransition and Opacity above [finder].
double effectiveOpacity(WidgetTester tester, Finder finder) {
  double opacity = 1;
  tester.element(finder).visitAncestorElements((ancestor) {
    final Widget widget = ancestor.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    if (widget is Opacity) opacity *= widget.opacity;
    return true;
  });
  return opacity;
}

/// Records CurvedAnimation creations and all disposals while active.
class CurvedAnimationTracker {
  final Set<Object> created = <Object>{};
  final Set<Object> disposed = <Object>{};

  void _listener(ObjectEvent event) {
    if (event is ObjectCreated && event.className == 'CurvedAnimation') {
      created.add(event.object);
    } else if (event is ObjectDisposed) {
      disposed.add(event.object);
    }
  }

  void start() => FlutterMemoryAllocations.instance.addListener(_listener);

  void stop() => FlutterMemoryAllocations.instance.removeListener(_listener);

  Set<Object> get leaked => created.difference(disposed);
}
