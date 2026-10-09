import 'package:flutter/material.dart';

import 'cn_fade_through_page_transitions_builder.dart';

/// Standalone route using [CnFadeThroughPageTransitionsBuilder], for apps that
/// do not want to touch their theme.
///
/// Mixes in [MaterialRouteTransitionMixin] so Material routes beneath it
/// recognize it by type, independent of the generic-type quirk in
/// `MaterialRouteTransitionMixin.canTransitionTo` (`MaterialPageRoute<int>`
/// beneath a route with a different `T`).
class CnPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  /// Creates a fade-through page route.
  // TODO(slice F): add `timing = CnRouteTiming.standard` once CnRouteTiming is merged.
  CnPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    this.maintainState = true,
    this.backgroundColor,
  }) : _transitions = CnFadeThroughPageTransitionsBuilder(
          backgroundColor: backgroundColor,
        );

  /// Builds the page content.
  final WidgetBuilder builder;

  @override
  final bool maintainState;

  /// Color painted behind the incoming page; defaults to the theme surface.
  final Color? backgroundColor;

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

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}
