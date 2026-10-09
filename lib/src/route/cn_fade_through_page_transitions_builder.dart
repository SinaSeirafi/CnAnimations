import 'package:flutter/material.dart';

import '../choreography/cn_route_choreography.dart' show CnRouteTiming;
import '../progress/cn_directional_curved_animation.dart';

/// Fade-through transition designed for the element choreography: the page
/// below stays fully visible for the first part of a push while its elements
/// exit, then the incoming page fades and lifts in over the rest. On pop the
/// top page is gone within the first 40 % so the page below can bring its
/// elements back. 400 ms both ways.
class CnFadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates the builder. [backgroundColor] defaults to
  /// `ColorScheme.surface` of the surrounding theme.
  const CnFadeThroughPageTransitionsBuilder({
    this.backgroundColor,
    this.timing = CnRouteTiming.standard,
  });

  /// Color painted behind the incoming page.
  final Color? backgroundColor;

  /// Reserved for API parity with the element choreography. The page
  /// transition itself keeps its fixed fade-through intervals and 400 ms
  /// duration; element timing is read from the scope and the widgets.
  final CnRouteTiming timing;

  /// Fade-in window of route progress.
  static const Interval _enter = Interval(0.3, 1.0);

  /// Fade-out window of route progress (read while progress falls from 1).
  static const Interval _exit = Interval(0.6, 1.0);

  static const Offset _lift = Offset(0, 0.02);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  /// Non-null on purpose: `MaterialRouteTransitionMixin.canTransitionTo` on the
  /// page below only lets its secondaryAnimation run when the next route has a
  /// delegated transition (or is a Material route). The no-op keeps the page
  /// below still while its elements do the exit.
  @override
  DelegatedTransitionBuilder? get delegatedTransition => _noOpDelegate;

  static Widget? _noOpDelegate(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) =>
      child;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _CnFadeThrough(
      animation: animation,
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}

class _CnFadeThrough extends StatefulWidget {
  const _CnFadeThrough({
    required this.animation,
    required this.color,
    required this.child,
  });

  final Animation<double> animation;
  final Color color;
  final Widget child;

  @override
  State<_CnFadeThrough> createState() => _CnFadeThroughState();
}

class _CnFadeThroughState extends State<_CnFadeThrough> {
  late CnDirectionalCurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = _make();
  }

  CnDirectionalCurvedAnimation _make() => CnDirectionalCurvedAnimation(
        widget.animation,
        enter: CnFadeThroughPageTransitionsBuilder._enter,
        exit: CnFadeThroughPageTransitionsBuilder._exit,
      );

  @override
  void didUpdateWidget(_CnFadeThrough old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) _curved = _make();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: _curved.drive(
          Tween<Offset>(
            begin: CnFadeThroughPageTransitionsBuilder._lift,
            end: Offset.zero,
          ),
        ),
        child: ColoredBox(color: widget.color, child: widget.child),
      ),
    );
  }
}
