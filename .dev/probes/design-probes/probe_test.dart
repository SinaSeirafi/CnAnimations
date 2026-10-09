import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records (status, animation.value, secondary.value) of the route found at [key] each frame.
class Rec {
  final List<String> rows = [];
  ModalRoute? route;
  void sample(String tag) {
    final r = route!;
    rows.add('$tag a=${r.animation!.status.name}/${r.animation!.value.toStringAsFixed(2)} s=${r.secondaryAnimation!.status.name}/${r.secondaryAnimation!.value.toStringAsFixed(2)} gesture=${r.navigator!.userGestureInProgress}');
  }
}

class Probe extends StatelessWidget {
  const Probe(this.rec, {super.key, this.child});
  final Rec rec; final Widget? child;
  @override
  Widget build(BuildContext context) {
    rec.route = ModalRoute.of(context);
    return child ?? const SizedBox.expand();
  }
}

Future<void> pump(WidgetTester t, Rec rec, String tag, {int frames = 6, int ms = 50}) async {
  for (var i = 0; i < frames; i++) { await t.pump(Duration(milliseconds: ms)); rec.sample('$tag[$i]'); }
}

void main() {
  testWidgets('A: showDialog over MaterialPageRoute (android)', (t) async {
    final rec = Rec();
    await t.pumpWidget(MaterialApp(theme: ThemeData(platform: TargetPlatform.android), home: Probe(rec)));
    rec.sample('rest');
    showDialog(context: rec.route!.subtreeContext!, builder: (_) => const AlertDialog(title: Text('d')));
    await pump(t, rec, 'dialog', frames: 4);
    print('A\n${rec.rows.join('\n')}');
  });
  testWidgets('A2: showDialog over MaterialPageRoute (iOS)', (t) async {
    final rec = Rec();
    await t.pumpWidget(MaterialApp(theme: ThemeData(platform: TargetPlatform.iOS), home: Probe(rec)));
    showDialog(context: rec.route!.subtreeContext!, builder: (_) => const AlertDialog(title: Text('d')));
    await pump(t, rec, 'dialog', frames: 3);
    showModalBottomSheet(context: rec.route!.subtreeContext!, builder: (_) => const SizedBox(height: 100));
    await pump(t, rec, 'sheet', frames: 3);
    print('A2\n${rec.rows.join('\n')}');
  });
  testWidgets('B: showDialog over PageRouteBuilder / opaque:false PageRouteBuilder', (t) async {
    final rec = Rec();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const SizedBox()));
    nav.currentState!.push(PageRouteBuilder(pageBuilder: (_, __, ___) => Probe(rec), transitionDuration: const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    rec.sample('rest');
    showDialog(context: rec.route!.subtreeContext!, builder: (_) => const AlertDialog(title: Text('d')));
    await pump(t, rec, 'dialog', frames: 3);
    nav.currentState!.pop(); await t.pumpAndSettle(); rec.rows.clear();
    nav.currentState!.push(PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) => const SizedBox(), transitionDuration: const Duration(milliseconds: 300)));
    await pump(t, rec, 'transparentPRB', frames: 3);
    print('B\n${rec.rows.join('\n')}');
  });
  testWidgets('C: Cupertino swipe back drives previous secondary; status during drag', (t) async {
    final rec = Rec(); final rec2 = Rec();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, theme: ThemeData(platform: TargetPlatform.iOS), home: Probe(rec)));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => Probe(rec2)));
    await t.pumpAndSettle();
    rec.sample('below-rest'); rec2.sample('top-rest');
    final g = await t.startGesture(const Offset(5, 300));
    await t.pump();
    await g.moveBy(const Offset(100, 0)); await t.pump(); rec.sample('below-drag100'); rec2.sample('top-drag100');
    await g.moveBy(const Offset(200, 0)); await t.pump(); rec.sample('below-drag300'); rec2.sample('top-drag300');
    await g.moveBy(const Offset(-150, 0)); await t.pump(); rec.sample('below-drag150'); rec2.sample('top-drag150');
    await g.up(); await t.pump(); rec.sample('below-up'); rec2.sample('top-up');
    await pump(t, rec2, 'top-after', frames: 3, ms: 100); 
    await pump(t, rec, 'below-after', frames: 2, ms: 100);
    print('C\n${rec.rows.join('\n')}\n${rec2.rows.join('\n')}');
  });
  testWidgets('D: predictive back API directly', (t) async {
    final rec = Rec(); final rec2 = Rec();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: Probe(rec)));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => Probe(rec2)));
    await t.pumpAndSettle();
    final top = rec2.route as TransitionRoute;
    top.handleStartBackGesture(progress: 0.95); await t.pump(); rec.sample('below-start'); rec2.sample('top-start');
    top.handleUpdateBackGestureProgress(progress: 0.6); await t.pump(); rec.sample('below-upd'); rec2.sample('top-upd');
    top.handleCancelBackGesture(); await t.pump(); rec.sample('below-cancel0'); rec2.sample('top-cancel0');
    await pump(t, rec2, 'top-cancel', frames: 3, ms: 100);
    top.handleStartBackGesture(progress: 0.9); top.handleUpdateBackGestureProgress(progress: 0.4); await t.pump(); rec2.sample('top-upd2');
    top.handleCommitBackGesture(); await t.pump(); rec.sample('below-commit0'); rec2.sample('top-commit0');
    await pump(t, rec2, 'top-commit', frames: 3, ms: 100);
    print('D\n${rec.rows.join('\n')}\n${rec2.rows.join('\n')}');
  });
  testWidgets('E: pushReplacement, popUntil, zero duration, didAdd home', (t) async {
    final a = Rec(); final b = Rec(); final c = Rec();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: Probe(a)));
    a.sample('home-first-frame');
    nav.currentState!.push(MaterialPageRoute(builder: (_) => Probe(b))); await t.pumpAndSettle();
    nav.currentState!.pushReplacement(MaterialPageRoute(builder: (_) => Probe(c)));
    await pump(t, b, 'b-replaced', frames: 3, ms: 100);
    await pump(t, a, 'a-during-replace', frames: 1, ms: 10);
    await t.pumpAndSettle();
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const SizedBox())); await t.pumpAndSettle();
    a.rows.clear(); c.rows.clear();
    nav.currentState!.popUntil((r) => r.isFirst);
    await pump(t, a, 'a-popUntil', frames: 3, ms: 100);
    await pump(t, c, 'c-popUntil', frames: 1, ms: 10);
    await t.pumpAndSettle();
    final z = Rec();
    nav.currentState!.push(PageRouteBuilder(pageBuilder: (_, __, ___) => Probe(z), transitionDuration: Duration.zero));
    await t.pump(); z.sample('zero-first-frame'); a.sample('a-under-zero');
    print('E\n${a.rows.join('\n')}\n${b.rows.join('\n')}\n${c.rows.join('\n')}\n${z.rows.join('\n')}');
  });
}
