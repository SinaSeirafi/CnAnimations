import 'dart:async';

import 'package:flutter/material.dart';

class CnSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset begin;
  final Offset end;
  final Curve? curve;

  /// Start of the animation within [duration], from 0.0 to 1.0.
  final double intervalBegin;

  /// End of the animation within [duration], from 0.0 to 1.0.
  final double intervalEnd;
  final bool forward;
  final Duration? delay;
  final int delayInMilliseconds;
  final AnimationController? controller;

  /// When true (default) and the platform asks to reduce motion
  /// ([MediaQuery.disableAnimations]), the final state is shown immediately.
  /// Set to false to animate regardless of that setting.
  ///
  /// Applies only when [controller] is null. With an external [controller]
  /// the widget always follows that controller.
  final bool respectReducedMotion;

  @Deprecated('Has no effect and will be removed in a future release')
  final bool reverseControllerValue;

  const CnSlide({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.begin = const Offset(0, 0.5),
    this.end = Offset.zero,
    this.curve,
    this.intervalBegin = 0.0,
    this.intervalEnd = 1.0,
    this.forward = true,
    this.delay,
    this.delayInMilliseconds = 0,
    this.controller,
    this.respectReducedMotion = true,
    @Deprecated('Has no effect and will be removed in a future release')
    this.reverseControllerValue = false,
    super.key,
  });

  @override
  State<CnSlide> createState() => _CnSlideState();
}

class _CnSlideState extends State<CnSlide> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _snapToEnd
          ? AlwaysStoppedAnimation<Offset>(_finalValue)
          : _slideAnimation,
      child: widget.child,
    );
  }

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  CurvedAnimation? _curvedAnimation;
  Timer? _delayTimer;

  Offset get _finalValue => widget.forward ? widget.end : widget.begin;

  bool get _reduceMotion =>
      widget.respectReducedMotion &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// Only the internal controller is snapped; an external [controller] means
  /// the app owns the motion, so it is always followed.
  bool get _snapToEnd => widget.controller == null && _reduceMotion;

  @override
  void didUpdateWidget(covariant CnSlide oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_controller.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.controller != oldWidget.controller) {
      if (widget.controller == null) {
        _startInternalController();
      } else {
        _delayTimer?.cancel();
      }
    }

    if (widget.forward != oldWidget.forward ||
        widget.begin != oldWidget.begin ||
        widget.end != oldWidget.end ||
        widget.controller != oldWidget.controller ||
        widget.curve != oldWidget.curve ||
        widget.intervalBegin != oldWidget.intervalBegin ||
        widget.intervalEnd != oldWidget.intervalEnd) {
      _updateSlideAnimation();
    }
  }

  void _updateSlideAnimation() {
    _curvedAnimation?.dispose();
    _curvedAnimation = CurvedAnimation(
      parent: widget.controller ?? _controller,
      curve: Interval(
        widget.intervalBegin,
        widget.intervalEnd,
        curve: widget.curve ?? Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.forward ? widget.begin : widget.end,
      end: widget.forward ? widget.end : widget.begin,
    ).animate(_curvedAnimation!);
  }

  /// Runs the internal controller forward after the delay.
  void _startInternalController() {
    _delayTimer?.cancel();
    _delayTimer = Timer(
      widget.delay ?? Duration(milliseconds: widget.delayInMilliseconds),
      () {
        if (!mounted) return;

        if (_reduceMotion) {
          _controller.value = 1;
        } else {
          _controller.forward();
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _updateSlideAnimation();

    if (widget.controller == null) _startInternalController();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _curvedAnimation?.dispose();
    _controller.dispose();
    super.dispose();
  }
}
