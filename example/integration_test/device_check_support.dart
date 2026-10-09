/// Helpers for the on-device check (STATUS step 7). They read the real
/// example app: element values come from each keyed `CnRouteAnimation`'s own
/// `FadeTransition` / `SlideTransition` (the first of each below the key), and
/// "visible" multiplies every opacity on the way to the root, so a page's
/// fade-through and an `Offstage` count too.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// One line of machine-readable output, collected by the report.
void report(String line) => debugPrintSynchronously('CNREPORT $line');

String f3(double v) => v.toStringAsFixed(3);

Finder keyed(String label) =>
    find.byKey(ValueKey<String>(label), skipOffstage: false);

bool exists(String label) => keyed(label).evaluate().isNotEmpty;

Finder _own<T>(String label) => find
    .descendant(
      of: keyed(label),
      matching: find.byType(T, skipOffstage: false),
    )
    .first;

/// The element's own opacity (choreography only).
double opacityOf(WidgetTester tester, String label) =>
    tester.widget<FadeTransition>(_own<FadeTransition>(label)).opacity.value;

/// The element's own slide, as a fraction of its size.
Offset offsetOf(WidgetTester tester, String label) =>
    tester.widget<SlideTransition>(_own<SlideTransition>(label)).position.value;

/// Opacity actually reaching the screen for [element]: the product of every
/// `FadeTransition` / `Opacity` above it, 0 under an active `Offstage`.
double effectiveOpacityOfElement(Element element) {
  double o = 1.0;
  bool offstage = false;
  void visit(Widget w) {
    if (w is FadeTransition) {
      o *= w.opacity.value;
    } else if (w is Opacity) {
      o *= w.opacity;
    } else if (w is Offstage && w.offstage) {
      offstage = true;
    } else if (w is Visibility && !w.visible) {
      offstage = true;
    }
  }

  visit(element.widget);
  element.visitAncestorElements((Element a) {
    visit(a.widget);
    return true;
  });
  return offstage ? 0.0 : o.clamp(0.0, 1.0);
}

/// Effective opacity of the keyed element's content (below its own fade).
double effectiveOpacity(WidgetTester tester, String label) {
  final Element inner = _own<ScaleTransition>(label).evaluate().first;
  return effectiveOpacityOfElement(inner);
}

/// Whether the keyed element's rect overlaps the screen.
bool onScreen(WidgetTester tester, String label) {
  final Finder f = keyed(label);
  if (f.evaluate().isEmpty) return false;
  final RenderObject? ro = f.evaluate().first.renderObject;
  if (ro is! RenderBox || !ro.hasSize || !ro.attached) return false;
  final Rect r = MatrixUtils.transformRect(
    ro.getTransformTo(null),
    Offset.zero & ro.size,
  );
  final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  return r.overlaps(Offset.zero & screen);
}

/// The route the keyed element lives in.
ModalRoute<Object?> routeOf(WidgetTester tester, String label) =>
    ModalRoute.of(tester.element(keyed(label)))!;

/// Samples one value set per rendered frame (post-frame, so after layout and
/// with the values that were painted), stamped with the frame's vsync time.
class FrameSampler<T> {
  FrameSampler(this.read);

  final T Function() read;
  final List<({Duration t, T v})> samples = <({Duration t, T v})>[];
  bool _on = false;

  void start() {
    _on = true;
    _schedule();
  }

  void stop() => _on = false;

  void _schedule() {
    SchedulerBinding.instance.addPostFrameCallback((Duration stamp) {
      if (!_on) return;
      samples.add((t: stamp, v: read()));
      _schedule();
    });
  }
}

/// Number of Hero flights in progress: a hero in flight hides its own child
/// under an `Offstage(offstage: true)` placeholder.
int heroesHidden() => find
    .descendant(
      of: find.byType(Hero, skipOffstage: false),
      matching: find.byWidgetPredicate(
        (Widget w) => w is Offstage && w.offstage,
        skipOffstage: false,
      ),
      skipOffstage: false,
    )
    .evaluate()
    .length;

/// The flight shuttle's rect: the hero thumbnail icon that is not inside any
/// `Hero` (the default shuttle is the destination hero's child, placed in the
/// overlay). Null when no flight is on screen.
Rect? shuttleRect(WidgetTester tester) {
  final Finder icons = find.byIcon(Icons.image_outlined, skipOffstage: false);
  for (final Element e in icons.evaluate()) {
    bool inHero = false;
    e.visitAncestorElements((Element a) {
      if (a.widget is Hero) {
        inHero = true;
        return false;
      }
      return true;
    });
    if (!inHero) {
      // The shuttle's own box: the Container that holds the icon.
      Element box0 = e;
      e.visitAncestorElements((Element a) {
        if (a.widget is Container) {
          box0 = a;
          return false;
        }
        return true;
      });
      final RenderBox box = box0.renderObject! as RenderBox;
      return MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
    }
  }
  return null;
}
