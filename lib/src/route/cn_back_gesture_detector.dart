import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;

/// Width of the iOS edge strip that starts a swipe-back, as in Cupertino.
const double _kEdgeWidth = 20.0;

/// Release speed, in page widths per second, above which a swipe-back flings.
const double _kMinFlingVelocity = 1.0;

/// Duration of the settle after an iOS swipe-back is released.
const Duration _kSettleDuration = Duration(milliseconds: 350);

/// Gives a page wrapped by the fade-through the platform's interactive back
/// input, which Flutter otherwise only wires inside its own page transitions.
///
/// * Android predictive back: registers a [WidgetsBindingObserver] that claims
///   the system `flutter/backgesture` messages while [route] is current and
///   [ModalRoute.popGestureEnabled], and forwards them to the route's
///   [PredictiveBackRoute] methods. This reproduces the private observer in
///   [PredictiveBackPageTransitionsBuilder]. The engine only sends these
///   messages on Android, so the observer is inert elsewhere.
/// * iOS and macOS (by [ThemeData.platform]): adds the Cupertino edge strip.
///   A horizontal drag that starts on it moves the route's animation with the
///   finger and, on release, settles or pops like [CupertinoPageRoute]. Not
///   added for [PageRoute.fullscreenDialog] routes, as in Cupertino.
///
/// Both paths drive only the route's own `animation`; the page and its
/// elements follow that value through the fade-through and the choreography.
/// [ModalRoute.popGestureEnabled] gates both, so `PopScope(canPop: false)`,
/// [ModalRoute.willHandlePopInternally], the first route and a route that is
/// still animating all refuse the gesture, as they do for the stock routes.
class CnBackGestureDetector<T> extends StatefulWidget {
  /// Wraps [child], the page content of [route].
  const CnBackGestureDetector({
    super.key,
    required this.route,
    required this.child,
  });

  /// The route the gestures pop.
  final PageRoute<T> route;

  /// The page content.
  final Widget child;

  @override
  State<CnBackGestureDetector<T>> createState() =>
      _CnBackGestureDetectorState<T>();
}

class _CnBackGestureDetectorState<T> extends State<CnBackGestureDetector<T>>
    with WidgetsBindingObserver {
  late final HorizontalDragGestureRecognizer _recognizer;

  /// The edge swipe in progress, from drag start to release.
  _EdgeSwipe? _swipe;

  /// The navigator whose user gesture this state started and has not yet
  /// handed back to the route (predictive back between start and its end).
  NavigatorState? _predictiveNavigator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recognizer.dispose();
    // Disposed mid-gesture (the route was removed): release the navigator's
    // user-gesture flag after this frame, as the Cupertino detector does.
    final NavigatorState? navigator = _swipe?.navigator ?? _predictiveNavigator;
    _swipe = null;
    _predictiveNavigator = null;
    if (navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && navigator.userGestureInProgress) {
          navigator.didStopUserGesture();
        }
      });
    }
    super.dispose();
  }

  bool get _gestureAllowed =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  // Android predictive back (WidgetsBindingObserver).

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || _swipe != null || !_gestureAllowed) {
      return false;
    }
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    _predictiveNavigator = widget.route.navigator;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    _predictiveNavigator = null;
    _settlePredictive(commit: false);
  }

  @override
  void handleCommitBackGesture() {
    _predictiveNavigator = null;
    _settlePredictive(commit: true);
  }

  /// Settles a released predictive back gesture from where the finger let
  /// go, as `TransitionRoute._handleDragEnd` did through Flutter 3.32.
  ///
  /// Not delegated to [PredictiveBackRoute.handleCommitBackGesture]: since
  /// Flutter 3.35 (flutter/flutter#154718) the route's commit restarts its
  /// controller at 1.0 and plays the whole reverse, which Flutter's own
  /// predictive-back transition hides by remapping its animations on commit.
  /// Here it would bring the page back to fully shown, and part the page
  /// below's elements again, before the pop. Cancel is settled here too, so
  /// release behaves the same on every supported Flutter version.
  void _settlePredictive({required bool commit}) {
    final PageRoute<T> route = widget.route;
    final NavigatorState? navigator = route.navigator;
    // The route's own controller, as Flutter's _handleDragEnd uses it.
    // ignore: invalid_use_of_protected_member
    final AnimationController controller = route.controller!;
    if (route.isCurrent) {
      // These timings are Flutter's (eyeballed against Android API 34): the
      // closer the page is to its target, the shorter the settle.
      if (commit) {
        navigator?.pop();
        // The pop may already have finished if the value reached 0.
        if (controller.isAnimating) {
          controller.animateBack(
            0.0,
            duration: Duration(
              milliseconds: ui.lerpDouble(0, 800, controller.value)!.floor(),
            ),
            curve: Curves.fastLinearToSlowEaseIn,
          );
        }
      } else {
        controller.animateTo(
          1.0,
          duration: Duration(
            milliseconds: math.min(
              ui.lerpDouble(800, 0, controller.value)!.floor(),
              300,
            ),
          ),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      }
    }
    _stopUserGestureWhenSettled(navigator, controller);
  }

  // iOS edge swipe.

  void _handlePointerDown(PointerDownEvent event) {
    if (_predictiveNavigator == null && _gestureAllowed) {
      _recognizer.addPointer(event);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    assert(_swipe == null);
    // Re-checked: the route may have changed since the pointer went down.
    if (!_gestureAllowed) return;
    _swipe = _EdgeSwipe(widget.route);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _swipe?.dragUpdate(_toLogical(details.primaryDelta! / _width));
  }

  void _handleDragEnd(DragEndDetails details) {
    _swipe?.dragEnd(_toLogical(details.velocity.pixelsPerSecond.dx / _width));
    _swipe = null;
  }

  void _handleDragCancel() {
    // Also called for a pointer that never started a drag.
    _swipe?.dragEnd(0.0);
    _swipe = null;
  }

  double get _width => context.size!.width;

  double _toLogical(double value) => switch (Directionality.of(context)) {
    TextDirection.rtl => -value,
    TextDirection.ltr => value,
  };

  bool get _edgeSwipeOn {
    if (widget.route.fullscreenDialog) return false;
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack with the page first, so turning the strip on or off
    // (a platform change) keeps the page's state.
    final List<Widget> children = <Widget>[widget.child];
    if (_edgeSwipeOn) {
      final TextDirection direction = Directionality.of(context);
      final EdgeInsets padding = MediaQuery.paddingOf(context);
      final double safeArea = switch (direction) {
        TextDirection.rtl => padding.right,
        TextDirection.ltr => padding.left,
      };
      children.add(
        PositionedDirectional(
          start: 0.0,
          width: math.max(safeArea, _kEdgeWidth),
          top: 0.0,
          bottom: 0.0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      );
    }
    return Stack(fit: StackFit.passthrough, children: children);
  }
}

/// One iOS swipe-back, from drag start to release. Mirrors Flutter's private
/// `_CupertinoBackGestureController`: the finger sets the route's controller,
/// and release either settles back to 1 or pops.
class _EdgeSwipe {
  _EdgeSwipe(PageRoute<dynamic> route)
    : navigator = route.navigator!,
      // The route's own controller, as CupertinoRouteTransitionMixin uses
      // it. It is protected on TransitionRoute; no public API settles a
      // released drag with the Cupertino timing or handles a route that is
      // no longer current at release.
      // ignore: invalid_use_of_protected_member
      controller = route.controller!,
      _isCurrent = (() => route.isCurrent),
      _isActive = (() => route.isActive) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;
  final ValueGetter<bool> _isCurrent;
  final ValueGetter<bool> _isActive;

  /// The finger moved by [delta] page widths (positive toward the far edge).
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// The finger lifted at [velocity] page widths per second.
  void dragEnd(double velocity) {
    const Curve curve = Curves.fastEaseInToSlowEaseOut;
    final bool isCurrent = _isCurrent();
    final bool settleBack;
    if (!isCurrent) {
      // Navigation happened mid-drag: a route pushed above keeps this one
      // (settle back to fully shown); a programmatic pop already reversed it.
      settleBack = _isActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      settleBack = velocity <= 0;
    } else {
      settleBack = controller.value > 0.5;
    }

    if (settleBack) {
      controller.animateTo(1.0, duration: _kSettleDuration, curve: curve);
    } else {
      if (isCurrent) navigator.pop();
      // The pop may already have finished if the value reached 0.
      if (controller.isAnimating) {
        controller.animateBack(0.0, duration: _kSettleDuration, curve: curve);
      }
    }

    _stopUserGestureWhenSettled(navigator, controller);
  }
}

/// Ends the user gesture [navigator] started, once [controller] has settled:
/// at its next status change if it is animating, otherwise now. Keeping
/// `userGestureInProgress` through the settle is what Flutter's routes do.
void _stopUserGestureWhenSettled(
  NavigatorState? navigator,
  AnimationController controller,
) {
  if (controller.isAnimating) {
    late final AnimationStatusListener onStatus;
    onStatus = (AnimationStatus status) {
      navigator?.didStopUserGesture();
      controller.removeStatusListener(onStatus);
    };
    controller.addStatusListener(onStatus);
  } else {
    navigator?.didStopUserGesture();
  }
}
