import 'dart:async';

import 'package:flutter/material.dart';

import 'cn_animations.dart';

/// ### Setup
/// Requires adding RouteObserver in Material App to work
/// Otherwise only push will work
///
/// ### Migrating to `CnRouteAnimation`
/// - `beginSamePage` -> `enterOffset`
/// - `endNextPage` -> `exitOffset`
/// - `showFadeAnimation` -> `fade`
/// - `animate` -> `enabled`
/// - `showPush` / `showPop` -> `enter`
/// - `showPushNext` / `showPopNext` -> `cover`
/// - `respectReducedMotion` -> `respectReducedMotion`
/// - `fadeDuration`, `slideDuration` and the `*Delay*` values -> `CnRouteTiming`
///   (slices of the route transition, not durations)
@Deprecated('Use CnRouteAnimation; it needs no RouteObserver')
class CnRouteAwareAnimation extends StatefulWidget {
  const CnRouteAwareAnimation({
    super.key,
    required this.child,
    this.showFadeAnimation = true,
    this.fadeStartSamePage = 0,
    this.fadeEndSamePage = 1,
    this.fadeStartNextPage,
    this.fadeEndNextPage,
    this.showSlideAnimation = true,
    this.beginSamePage = const Offset(0, -0.1),
    this.endSamePage = const Offset(0, 0),
    this.beginNextPage,
    this.endNextPage,
    this.animate = true,
    this.showPush = true,
    this.showPop = true,
    this.showPushNext = true,
    this.showPopNext = true,
    this.fadeDuration = const Duration(milliseconds: 500),
    this.fadeDelayInMilliseconds = 0,
    this.slideDuration = const Duration(milliseconds: 300),
    this.slideDelayInMilliseconds = 0,
    this.respectReducedMotion = true,
  });

  final Widget child;

  /// Use to cancel animations all together
  final bool animate;

  /// Whether to show [push] animation or not
  final bool showPush;

  /// Whether to show [pop] animation or not
  final bool showPop;

  /// Whether to show [pushNext] animation or not
  final bool showPushNext;

  /// Whether to show [popNext] animation or not
  final bool showPopNext;

  // --- Fade animation values

  /// Whether to show [fade] animations or not
  /// This effects all of the navigation events animations
  final bool showFadeAnimation;

  /// Fade animation [start] value for the [SamePage] animations
  final double fadeStartSamePage;

  /// Fade animation [end] value for the [SamePage] animations
  final double fadeEndSamePage;

  /// Fade animation [start] value for the [NextPage] animations
  final double? fadeStartNextPage;

  /// Fade animation [end] value for the [NextPage] animations
  final double? fadeEndNextPage;

  /// Duration of the [fade] animations
  final Duration fadeDuration;

  /// [Delay] before starting the [fade] animations in milliseconds
  final int fadeDelayInMilliseconds;

  // --- Slide animation values

  /// Whether to show [slide] animations or not
  /// This effects all of the navigation events animations
  final bool showSlideAnimation;

  /// Slide animation [begin] value for the [SamePage] animations
  final Offset beginSamePage;

  /// Slide animation [end] value for the [SamePage] animations
  final Offset endSamePage;

  /// Slide animation [begin] value for the [NextPage] animations
  final Offset? beginNextPage;

  /// Slide animation [end] value for the [NextPage] animations
  final Offset? endNextPage;

  /// Duration of the [slide] animations
  final Duration slideDuration;

  /// [Delay] before starting the [slide] animations in milliseconds
  final int slideDelayInMilliseconds;

  /// When true (default) and the platform asks to reduce motion
  /// ([MediaQuery.disableAnimations]), navigation events jump straight to
  /// their end state instead of animating. The widget tree is the same in
  /// both modes, so toggling the setting keeps the child's state.
  /// Set to false to animate regardless of that setting.
  final bool respectReducedMotion;

  @override
  State<CnRouteAwareAnimation> createState() => _CnRouteAwareAnimationState();
}

// ignore: deprecated_member_use_from_same_package
class _CnRouteAwareAnimationState extends State<CnRouteAwareAnimation>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    _reduceMotion = widget.respectReducedMotion &&
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    if (!widget.animate ||
        (!widget.showPush &&
            !widget.showPop &&
            !widget.showPushNext &&
            !widget.showPopNext)) {
      return widget.child;
    }

    // ignore: deprecated_member_use_from_same_package
    return RouteAwareWidget(
      onPush: () {
        if (widget.showPush) {
          _emitSame();
          _controllersForward();
        } else {
          _controllersShown();
        }
      },
      onPop: () {
        if (widget.showPop) {
          _emitSame();
          _controllersReverse();
        }
      },
      onPushNext: () {
        if (widget.showPushNext) {
          _emitNext();
          _controllersForward();
        }
      },
      onPopNext: () {
        if (widget.showPopNext) {
          _emitNext();
          _controllersReverse();
        } else {
          // Nothing else would bring this page back after pushNext.
          _controllersShown();
        }
      },
      // onPush can run while this subtree is building (from
      // RouteAwareWidget.didChangeDependencies), where setState on this state
      // is not allowed. The listener lives below RouteAwareWidget, so updating
      // the notifier there is safe.
      child: ValueListenableBuilder<_AnimationValues>(
        valueListenable: _values,
        builder: (context, values, _) {
          return _fadeAnimation(
            controller: fadeController,
            fadeStart: values.fadeStart,
            fadeEnd: values.fadeEnd,
            child: _slideAnimation(
              controller: slideController,
              begin: values.begin,
              end: values.end,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }

  _AnimationValues get _sameValues => _AnimationValues(
        begin: widget.beginSamePage,
        end: widget.endSamePage,
        fadeStart: widget.fadeStartSamePage,
        fadeEnd: widget.fadeEndSamePage,
      );

  _AnimationValues get _nextValues => _AnimationValues(
        begin: widget.beginNextPage ?? widget.endSamePage,
        end: widget.endNextPage ?? widget.beginSamePage,
        fadeStart: widget.fadeStartNextPage ?? widget.fadeEndSamePage,
        fadeEnd: widget.fadeEndNextPage ?? widget.fadeStartSamePage,
      );

  Widget _fadeAnimation({
    required Widget child,
    required AnimationController controller,
    required double fadeStart,
    required double fadeEnd,
  }) {
    if (!widget.showFadeAnimation) return child;

    return CnFade(
      controller: controller,
      fadeStartValue: fadeStart,
      fadeEndValue: fadeEnd,
      child: child,
    );
  }

  Widget _slideAnimation({
    required Widget child,
    required AnimationController controller,
    required Offset begin,
    required Offset end,
  }) {
    if (!widget.showSlideAnimation) return child;

    return CnSlide(
      controller: controller,
      begin: begin,
      end: end,
      child: child,
    );
  }

  void _setControllerValues(double val) {
    fadeController.value = val;
    slideController.value = val;
  }

  void _controllersForward() {
    _cancelTimers();
    if (_reduceMotion) return _setControllerValues(1);

    _setControllerValues(0);
    _fadeTimer =
        _handleDelay(widget.fadeDelayInMilliseconds, fadeController.forward);
    _slideTimer =
        _handleDelay(widget.slideDelayInMilliseconds, slideController.forward);
  }

  void _controllersReverse() {
    _cancelTimers();
    if (_reduceMotion) return _setControllerValues(0);

    _setControllerValues(1);
    _fadeTimer =
        _handleDelay(widget.fadeDelayInMilliseconds, fadeController.reverse);
    _slideTimer =
        _handleDelay(widget.slideDelayInMilliseconds, slideController.reverse);
  }

  /// Push animation is not played: sit at the shown (completed) state.
  void _controllersShown() {
    _cancelTimers();
    _emitSame();
    _setControllerValues(1);
  }

  void _emitSame() => _values.value = _sameValues;

  void _emitNext() => _values.value = _nextValues;

  Timer _handleDelay(int delayInMilliseconds, VoidCallback function) {
    return Timer(
      Duration(milliseconds: delayInMilliseconds),
      () {
        if (mounted) function();
      },
    );
  }

  /// Each navigation event replaces the pending delayed callbacks of the
  /// previous one, so they cannot run out of order.
  void _cancelTimers() {
    _fadeTimer?.cancel();
    _slideTimer?.cancel();
  }

  /// Read from [MediaQuery] in build. Under reduced motion, navigation events
  /// jump the controllers to their target instead of animating.
  bool _reduceMotion = false;

  late AnimationController fadeController;

  late AnimationController slideController;

  late final ValueNotifier<_AnimationValues> _values;

  Timer? _fadeTimer;

  Timer? _slideTimer;

  @override
  void initState() {
    super.initState();

    // When push is not played, start at the shown (completed) state.
    final double initialValue = widget.showPush ? 0 : 1;

    fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
      value: initialValue,
    );

    slideController = AnimationController(
      vsync: this,
      duration: widget.slideDuration,
      value: initialValue,
    );

    _values = ValueNotifier<_AnimationValues>(_sameValues);
  }

  @override
  // ignore: deprecated_member_use_from_same_package
  void didUpdateWidget(covariant CnRouteAwareAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (fadeController.duration != widget.fadeDuration) {
      fadeController.duration = widget.fadeDuration;
    }
    if (slideController.duration != widget.slideDuration) {
      slideController.duration = widget.slideDuration;
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    fadeController.dispose();
    slideController.dispose();
    _values.dispose();

    super.dispose();
  }
}

@immutable
class _AnimationValues {
  final Offset begin;
  final Offset end;
  final double fadeStart;
  final double fadeEnd;

  const _AnimationValues({
    required this.begin,
    required this.end,
    required this.fadeStart,
    required this.fadeEnd,
  });

  @override
  bool operator ==(Object other) =>
      other is _AnimationValues &&
      other.begin == begin &&
      other.end == end &&
      other.fadeStart == fadeStart &&
      other.fadeEnd == fadeEnd;

  @override
  int get hashCode => Object.hash(begin, end, fadeStart, fadeEnd);
}
