import 'package:flutter/material.dart';

/// Kept for backwards compatibility. Returns the same instance as
/// [RouteAwareWidget.routeObserver].
@Deprecated('No longer needed by cn_animations; removed in 1.0.0')
RouteObserver<PageRoute> get routeObserver => RouteAwareWidget.routeObserver;

/// ## Setup
/// Add routeObserver in material app (main)
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [RouteAwareWidget.routeObserver],
/// )
/// ```
///
/// Inside routes that are not a [PageRoute] (dialogs, bottom sheets), only
/// [onPush] is called, once.
@Deprecated(
    'No longer needed by cn_animations; removed in 1.0.0. If you rely on its onPush* callbacks, copy it into your app')
class RouteAwareWidget extends StatefulWidget {
  const RouteAwareWidget({
    super.key,
    required this.child,
    this.onPush,
    this.onPop,
    this.onPushNext,
    this.onPopNext,
  });

  static final RouteObserver<PageRoute> _routeObserver =
      RouteObserver<PageRoute>();

  /// Add this to `MaterialApp.navigatorObservers`.
  @Deprecated(
      'No longer needed by cn_animations; removed in 1.0.0. If you rely on its onPush* callbacks, copy it into your app')
  static RouteObserver<PageRoute> get routeObserver => _routeObserver;

  final Widget child;

  /// This function will be called when this page is pushed, aka initState
  final VoidCallback? onPush;

  /// This function will be called when this page is poped
  final VoidCallback? onPop;

  /// This function will be called when next page is pushed
  final VoidCallback? onPushNext;

  /// This function will be called when next page is poped
  final VoidCallback? onPopNext;

  @override
  State<RouteAwareWidget> createState() => _RouteAwareWidgetState();
}

// ignore: deprecated_member_use_from_same_package
class _RouteAwareWidgetState extends State<RouteAwareWidget> with RouteAware {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void didPush() => _run(widget.onPush);

  @override
  void didPop() => _run(widget.onPop);

  @override
  void didPushNext() => _run(widget.onPushNext);

  @override
  void didPopNext() => _run(widget.onPopNext);

  void _run(VoidCallback? function) {
    if (function != null) function();
  }

  /// Whether [_route] has been resolved at least once.
  bool _hasResolvedRoute = false;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (_hasResolvedRoute && route == _route) return;

    _hasResolvedRoute = true;
    _route = route;
    // ignore: deprecated_member_use_from_same_package
    RouteAwareWidget.routeObserver.unsubscribe(this);

    if (route is PageRoute) {
      // Calls didPush once for this route.
      // ignore: deprecated_member_use_from_same_package
      RouteAwareWidget.routeObserver.subscribe(this, route);
    } else {
      // Dialogs, bottom sheets and other non-page routes are not tracked by
      // the observer, so treat this widget as pushed, once per route.
      didPush();
    }
  }

  @override
  void dispose() {
    // ignore: deprecated_member_use_from_same_package
    RouteAwareWidget.routeObserver.unsubscribe(this);

    super.dispose();
  }
}
