import 'dart:async';

import 'package:flutter/material.dart';

import 'cn_animations.dart';
import 'route_aware_widget.dart';

/// ### Setup
/// Requires adding RouteObserver in Material App to work
/// Otherwise only push will work
class CnRouteAwareAnimation extends StatefulWidget {
  const CnRouteAwareAnimation({
    Key? key,
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
  }) : super(key: key);

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

  @override
  State<CnRouteAwareAnimation> createState() => _CnRouteAwareAnimationState();
}

class _CnRouteAwareAnimationState extends State<CnRouteAwareAnimation>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    if (!widget.animate ||
        (!widget.showPush &&
            !widget.showPop &&
            !widget.showPushNext &&
            !widget.showPopNext)) {
      return widget.child;
    }

    return RouteAwareWidget(
      onPush: () {
        if (widget.showPush) {
          _emitSame();
          _controllersForward();
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
        }
      },
      child: StreamBuilder<_AnimationValues>(
        stream: streamController.stream,
        initialData: initialData,
        builder: (context, snapshot) {
          return _fadeAnimation(
            controller: fadeController,
            fadeStart: snapshot.data!.fadeStart,
            fadeEnd: snapshot.data!.fadeEnd,
            child: _slideAnimation(
              controller: slideController,
              begin: snapshot.data!.begin,
              end: snapshot.data!.end,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }

  _AnimationValues get initialData => _AnimationValues(
        begin: widget.beginSamePage,
        end: widget.endSamePage,
        fadeStart: widget.fadeStartSamePage,
        fadeEnd: widget.fadeEndSamePage,
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

  _setControllerValues(double val) {
    fadeController.value = val;
    slideController.value = val;
  }

  _controllersForward() {
    _setControllerValues(0);
    _handleDelay(widget.fadeDelayInMilliseconds, fadeController.forward);
    _handleDelay(widget.slideDelayInMilliseconds, slideController.forward);
  }

  _controllersReverse() {
    _setControllerValues(1);
    _handleDelay(widget.fadeDelayInMilliseconds, fadeController.reverse);
    _handleDelay(widget.slideDelayInMilliseconds, slideController.reverse);
  }

  _emitSame() {
    streamController.add(
      _AnimationValues(
        begin: widget.beginSamePage,
        end: widget.endSamePage,
        fadeStart: widget.fadeStartSamePage,
        fadeEnd: widget.fadeEndSamePage,
      ),
    );
  }

  _emitNext() {
    streamController.add(
      _AnimationValues(
        begin: widget.beginNextPage ?? widget.endSamePage,
        end: widget.endNextPage ?? widget.beginSamePage,
        fadeStart: widget.fadeStartNextPage ?? widget.fadeEndSamePage,
        fadeEnd: widget.fadeEndNextPage ?? widget.fadeStartSamePage,
      ),
    );
  }

  _handleDelay(int delayInMilliseconds, Function function) {
    Future.delayed(
      Duration(milliseconds: delayInMilliseconds),
      () {
        if (mounted) function();
      },
    );
  }

  late AnimationController fadeController;

  late AnimationController slideController;

  StreamController<_AnimationValues> streamController =
      StreamController<_AnimationValues>();

  @override
  void initState() {
    super.initState();

    fadeController =
        AnimationController(vsync: this, duration: widget.fadeDuration);

    slideController =
        AnimationController(vsync: this, duration: widget.slideDuration);
  }

  @override
  void dispose() {
    fadeController.dispose();
    slideController.dispose();

    super.dispose();
  }
}

class _AnimationValues {
  final Offset begin;
  final Offset end;
  final double fadeStart;
  final double fadeEnd;

  _AnimationValues({
    required this.begin,
    required this.end,
    required this.fadeStart,
    required this.fadeEnd,
  });
}
