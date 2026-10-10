import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
Future<void> pump(WidgetTester t, Rec rec, String tag, {int frames = 3, int ms = 50}) async {
  for (var i = 0; i < frames; i++) { await t.pump(Duration(milliseconds: ms)); rec.sample('$tag[$i]'); }
}
void main() {
  testWidgets('B1: showDialog + showGeneralDialog over PageRouteBuilder', (t) async {
    final rec = Rec(); final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const SizedBox()));
    nav.currentState!.push(PageRouteBuilder(pageBuilder: (_, __, ___) => Probe(rec), transitionDuration: const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    showDialog(context: rec.route!.subtreeContext!, builder: (_) => const AlertDialog(title: Text('d')));
    await pump(t, rec, 'dialog');
    nav.currentState!.pop(); await t.pumpAndSettle();
    showGeneralDialog(context: rec.route!.subtreeContext!, pageBuilder: (_, __, ___) => const Text('g'));
    await pump(t, rec, 'general');
    nav.currentState!.pop(); await t.pumpAndSettle();
    nav.currentState!.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SizedBox()));
    await pump(t, rec, 'fullscreenDialog-over-PRB');
    print('B1\n${rec.rows.join('\n')}');
  });
  testWidgets('B2: cupertino popups over CupertinoPageRoute', (t) async {
    final rec = Rec(); final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(CupertinoApp(navigatorKey: nav, home: Probe(rec)));
    showCupertinoDialog(context: rec.route!.subtreeContext!, builder: (_) => const Text('d'));
    await pump(t, rec, 'cupertinoDialog');
    nav.currentState!.pop(); await t.pumpAndSettle();
    showCupertinoModalPopup(context: rec.route!.subtreeContext!, builder: (_) => const Text('p'));
    await pump(t, rec, 'cupertinoPopup');
    nav.currentState!.pop(); await t.pumpAndSettle();
    nav.currentState!.push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const SizedBox()));
    await pump(t, rec, 'fullscreenDialog');
    print('B2\n${rec.rows.join('\n')}');
  });
  testWidgets('E2: route beneath a pushReplacement; MaterialPageRoute pushed over PageRouteBuilder', (t) async {
    final a = Rec(); final b = Rec(); final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: nav, home: Probe(a)));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => Probe(b))); await t.pumpAndSettle();
    nav.currentState!.pushReplacement(MaterialPageRoute(builder: (_) => const SizedBox()));
    await pump(t, a, 'a-during-replace');
    await t.pumpAndSettle(); a.sample('a-after-replace');
    nav.currentState!.popUntil((r) => r.isFirst); await t.pumpAndSettle(); a.rows.clear();
    // Material route over a PageRouteBuilder-based route: does PRB's secondary run?
    final p = Rec();
    nav.currentState!.push(PageRouteBuilder(pageBuilder: (_, __, ___) => Probe(p), transitionDuration: const Duration(milliseconds: 300)));
    await t.pumpAndSettle();
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const SizedBox()));
    await pump(t, p, 'prb-under-material');
    await t.pumpAndSettle(); nav.currentState!.pop(); await t.pumpAndSettle();
    // and a PRB pushed over a MaterialPageRoute (a): does Material's secondary run? (canTransitionTo needs mixin or delegatedTransition)
    nav.currentState!.pop(); await t.pumpAndSettle(); a.rows.clear();
    nav.currentState!.push(PageRouteBuilder(pageBuilder: (_, __, ___) => const SizedBox(), transitionDuration: const Duration(milliseconds: 300)));
    await pump(t, a, 'material-under-prb');
    print('E2\n${a.rows.join('\n')}\n${p.rows.join('\n')}');
  });
  testWidgets('F: ListView.builder children carry IndexedSemantics; viewport lookup', (t) async {
    final keys = List.generate(30, (i) => GlobalKey());
    await t.pumpWidget(MaterialApp(home: ListView.builder(itemCount: 30, itemExtent: 100, itemBuilder: (_, i) => SizedBox(key: keys[i]))));
    final built = keys.where((k) => k.currentContext != null).length;
    final ctx = keys[0].currentContext!;
    final idx = ctx.findAncestorWidgetOfExactType<IndexedSemantics>();
    final vp = RenderAbstractViewport.maybeOf(ctx.findRenderObject());
    final box = ctx.findRenderObject() as RenderBox;
    final vpBox = vp as RenderBox;
    final last = keys.lastWhere((k) => k.currentContext != null);
    final lastBox = last.currentContext!.findRenderObject() as RenderBox;
    print('F built=$built index0=${idx?.index} viewport=${vp.runtimeType} vpRect=${vpBox.localToGlobal(Offset.zero) & vpBox.size} item0=${box.localToGlobal(Offset.zero)} lastBuilt=${keys.indexOf(last)} at ${lastBox.localToGlobal(Offset.zero)} screen=${t.view.physicalSize / t.view.devicePixelRatio}');
  });
}
