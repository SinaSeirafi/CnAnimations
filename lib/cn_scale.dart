import 'dart:async';

import 'package:flutter/material.dart';

class CnScale extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve? curve;
  final double begin;
  final double end;
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

  const CnScale({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve,
    this.begin = 0.7,
    this.end = 1.0,
    this.forward = true,
    this.delay,
    this.delayInMilliseconds = 0,
    this.controller,
    this.respectReducedMotion = true,
  });

  @override
  State<CnScale> createState() => _CnScaleState();
}

class _CnScaleState extends State<CnScale> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _snapToEnd
          ? AlwaysStoppedAnimation<double>(_finalValue)
          : _scaleAnimation,
      child: widget.child,
    );
  }

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  CurvedAnimation? _curvedAnimation;
  Timer? _delayTimer;

  double get _finalValue => widget.forward ? widget.end : widget.begin;

  bool get _reduceMotion =>
      widget.respectReducedMotion &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// Only the internal controller is snapped; an external [controller] means
  /// the app owns the motion, so it is always followed.
  bool get _snapToEnd => widget.controller == null && _reduceMotion;

  @override
  void didUpdateWidget(covariant CnScale oldWidget) {
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
        widget.curve != oldWidget.curve) {
      _updateScaleAnimation();
    }
  }

  void _updateScaleAnimation() {
    _curvedAnimation?.dispose();
    _curvedAnimation = CurvedAnimation(
      parent: widget.controller ?? _controller,
      curve: widget.curve ?? Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.forward ? widget.begin : widget.end,
      end: widget.forward ? widget.end : widget.begin,
    ).animate(_curvedAnimation!);
  }

  /// Runs the internal controller forward after the delay.
  ///
  /// `forward: false` is handled by the swapped tween, so the controller
  /// always runs forward.
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

    _updateScaleAnimation();

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
