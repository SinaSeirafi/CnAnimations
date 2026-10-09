import 'package:flutter/material.dart';

import '../choreography/cn_route_choreography.dart' show CnRouteTiming;
import 'cn_fade_through_page_transitions_builder.dart';

/// Standalone route using [CnFadeThroughPageTransitionsBuilder], for apps that
/// do not want to touch their theme.
///
/// Interactive back (Android predictive back, the iOS edge swipe) works as
/// described on [CnFadeThroughPageTransitionsBuilder]; this route uses the
/// same gesture wiring.
///
/// Mixes in [MaterialRouteTransitionMixin] so Material routes beneath it
/// recognize it by type, independent of the generic-type quirk in
/// `MaterialRouteTransitionMixin.canTransitionTo` (`MaterialPageRoute<int>`
/// beneath a route with a different `T`). `CupertinoPageRoute.canTransitionTo`
/// has the same quirk and this route does not fix it: give Cupertino routes
/// beneath it a matching type argument, or use the theme builder.
class CnPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  /// Creates a fade-through page route.
  CnPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    this.maintainState = true,
    this.backgroundColor,
    @Deprecated('Has no effect; removed in 1.0.0')
    this.timing = CnRouteTiming.standard,
  }) : _transitions = CnFadeThroughPageTransitionsBuilder(
          backgroundColor: backgroundColor,
        );

  /// Builds the page content.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  /// Color painted behind the incoming page; defaults to the theme surface.
  final Color? backgroundColor;

  /// Has no effect; see [CnFadeThroughPageTransitionsBuilder.timing]. Removed
  /// in 1.0.0.
  @Deprecated('Has no effect; removed in 1.0.0')
  final CnRouteTiming timing;

  final CnFadeThroughPageTransitionsBuilder _transitions;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  Duration get transitionDuration => _transitions.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _transitions.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _transitions.delegatedTransition;

  /// Only opaque, non-fullscreen-dialog page routes pull this page's elements
  /// out. Dialogs, sheets and transparent overlay routes do not.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is PageRoute && nextRoute.opaque && !nextRoute.fullscreenDialog;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _transitions.buildTransitions<T>(
        this,
        context,
        animation,
        secondaryAnimation,
        child,
      );

  /// The route's type, followed by its name in parentheses when it has one.
  @override
  String get debugLabel {
    final String? name = settings.name;
    return name == null ? super.debugLabel : '${super.debugLabel}($name)';
  }
}
