import 'package:flutter/material.dart';

final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();
RouteObserver<PageRoute> get routeObserver => _routeObserver;

/// ## Setup
/// Add routeObserver in material app (main)
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [routeObserver],
/// )
/// ```
class RouteAwareWidget extends StatefulWidget {
  const RouteAwareWidget({
    Key? key,
    required this.child,
    this.onPush,
    this.onPop,
    this.onPushNext,
    this.onPopNext,
  }) : super(key: key);

  final Widget child;

  /// This function will be called when this page is pushed, aka initState
  final Function? onPush;

  /// This function will be called when this page is poped
  final Function? onPop;

  /// This function will be called when next page is pushed
  final Function? onPushNext;

  /// This function will be called when next page is poped
  final Function? onPopNext;

  @override
  State<RouteAwareWidget> createState() => _RouteAwareWidgetState();
}

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

  void _run(Function? function) {
    if (function != null) function();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      routeObserver.subscribe(
          this, ModalRoute.of(context)! as PageRoute<dynamic>);
    } catch (e) {
      /// This might fail for opening modals
      /// as they are not subclass of PageRoute

      // print("Add Route Observer error: $e");
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);

    super.dispose();
  }
}
