import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Rec {
  final List<String> rows = [];
  ModalRoute? route;
  void sample(String tag) {
    final r = route!;
    rows.add('$tag a=${r.animation!.status.name}/${r.animation!.value.toStringAsFixed(2)} s=${r.secondaryAnimation!.status.name}/${r.secondaryAnimation!.value.toStringAsFixed(2)}');
  }
}
class Probe extends StatelessWidget {
  const Probe(this.rec, {super.key});
  final Rec rec;
  @override
  Widget build(BuildContext context) { rec.route = ModalRoute.of(context); return const SizedBox.expand(); }
}
int delegatedCalls = 0;
class CnRoute<T> extends PageRoute<T> {
  CnRoute(this.child);
  final Widget child;
  @override Color? get barrierColor => null;
  @override String? get barrierLabel => null;
  @override bool get maintainState => true;
  @override Duration get transitionDuration => const Duration(milliseconds: 400);
  @override
  DelegatedTransitionBuilder? get delegatedTransition => (ctx, anim, sec, snap, child) { delegatedCalls++; return child; };
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => nextRoute is PageRoute && nextRoute.opaque;
  @override
  Widget buildPage(BuildContext c, Animation<double> a, Animation<double> s) => child;
  @override
  Widget buildTransitions(BuildContext c, Animation<double> a, Animation<double> s, Widget child) =>
      FadeTransition(opacity: CurvedAnimation(parent: a, curve: const Interval(0.3, 1)), child: child);
}
Future<void> pump(WidgetTester t, Rec rec, String tag, {int frames = 3, int ms = 50}) async {
  for (var i = 0; i < frames; i++) { await t.pump(Duration(milliseconds: ms)); rec.sample('$tag[$i]'); }
}
void main() {
  testWidgets('G: custom route with delegatedTransition over MaterialPageRoute<dynamic> and <int>', (t) async {
    final a = Rec(); final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: Probe(a)));
    nav.currentState!.push(CnRoute<dynamic>(const SizedBox()));
    await pump(t, a, 'home<dynamic>-under-cn');
    print('delegatedCalls=$delegatedCalls');
    await t.pumpAndSettle(); nav.currentState!.pop(); await t.pumpAndSettle(); print("G-a: ${a.rows.join("|")}"); a.rows.clear();
    final b = Rec();
    nav.currentState!.push(MaterialPageRoute<int>(builder: (_) => Probe(b))); await t.pumpAndSettle();
    nav.currentState!.push(CnRoute<dynamic>(const SizedBox()));
    await pump(t, b, 'material<int>-under-cn<dynamic>');
    await t.pumpAndSettle(); nav.currentState!.pop(); await t.pumpAndSettle(); print("G-b: ${b.rows.join("|")}"); b.rows.clear();
    nav.currentState!.push(CnRoute<void>(const SizedBox()));
    await pump(t, b, 'material<int>-under-cn<void>');
    await t.pumpAndSettle(); nav.currentState!.pop(); await t.pumpAndSettle(); print("G-b: ${b.rows.join("|")}"); b.rows.clear();
    // transparent PRB over CnRoute: suppressed by canTransitionTo
    final c = Rec();
    nav.currentState!.push(CnRoute<dynamic>(Probe(c))); await t.pumpAndSettle();
    nav.currentState!.push(PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) => const SizedBox(), transitionDuration: const Duration(milliseconds: 300)));
    await pump(t, c, 'cn-under-transparentPRB');
    await t.pumpAndSettle(); nav.currentState!.pop(); await t.pumpAndSettle(); print("G-c: ${c.rows.join("|")}"); c.rows.clear();
    nav.currentState!.push(CnRoute<dynamic>(const SizedBox()));
    await pump(t, c, 'cn-under-cn');
    print('G\n${a.rows.join('\n')}\n${b.rows.join('\n')}\n${c.rows.join('\n')}');
  });
  testWidgets('H: CurvedAnimation reverseCurve during predictive back drag', (t) async {
    final nav = GlobalKey<NavigatorState>(); final b = Rec();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const SizedBox()));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => Probe(b))); await t.pumpAndSettle();
    final curved = CurvedAnimation(parent: b.route!.animation!, curve: const Interval(0.5, 1.0), reverseCurve: const Interval(0.0, 0.5));
    final top = b.route as TransitionRoute;
    final out = <String>[];
    top.handleStartBackGesture(progress: 0.95); await t.pump(); out.add('start p=0.95 curved=${curved.value.toStringAsFixed(2)} status=${b.route!.animation!.status.name}');
    top.handleUpdateBackGestureProgress(progress: 0.6); await t.pump(); out.add('upd p=0.60 curved=${curved.value.toStringAsFixed(2)}');
    top.handleCommitBackGesture(); await t.pump(); out.add('commit p=${b.route!.animation!.value.toStringAsFixed(2)} curved=${curved.value.toStringAsFixed(2)} status=${b.route!.animation!.status.name}');
    await t.pump(const Duration(milliseconds: 16)); out.add('commit+16 p=${b.route!.animation!.value.toStringAsFixed(2)} curved=${curved.value.toStringAsFixed(2)}');
    print('H\n${out.join('\n')}');
  });
}
