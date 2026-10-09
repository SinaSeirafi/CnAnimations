import 'dart:async';

import 'package:flutter/material.dart';

class CnFade extends StatefulWidget {
  final Widget child;
  final Duration duration;

  /// Overrides [duration] when non-null.
  @Deprecated('Use duration instead')
  final int? durationInMilliseconds;
  final bool forward;
  final Curve? curve;
  final double fadeStartValue;
  final double fadeEndValue;
  final int delayInMilliseconds;
  final Duration? delay;
  final AnimationController? controller;

  /// When true (default) and the platform asks to reduce motion
  /// ([MediaQuery.disableAnimations]), the final state is shown immediately.
  /// Set to false to animate regardless of that setting.
  ///
  /// Applies only when [controller] is null. With an external [controller]
  /// the widget always follows that controller.
  final bool respectReducedMotion;

  const CnFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    @Deprecated('Use duration instead') this.durationInMilliseconds,
    this.forward = true,
    this.fadeStartValue = 0,
    this.fadeEndValue = 1,
    this.delay,
    this.delayInMilliseconds = 10,
    this.controller,
    this.respectReducedMotion = true,
    this.curve,
  });

  @override
  State<CnFade> createState() => _CnFadeState();
}

class _CnFadeState extends State<CnFade> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _snapToEnd
          ? AlwaysStoppedAnimation<double>(_finalValue)
          : _fadeAnimation,
      child: widget.child,
    );
  }

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  CurvedAnimation? _curvedAnimation;
  Timer? _delayTimer;

  Duration get _duration {
    // ignore: deprecated_member_use_from_same_package
    final int? milliseconds = widget.durationInMilliseconds;
    return milliseconds != null
        ? Duration(milliseconds: milliseconds)
        : widget.duration;
  }

  double get _finalValue =>
      widget.forward ? widget.fadeEndValue : widget.fadeStartValue;

  bool get _reduceMotion =>
      widget.respectReducedMotion &&
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// Only the internal controller is snapped; an external [controller] means
  /// the app owns the motion, so it is always followed.
  bool get _snapToEnd => widget.controller == null && _reduceMotion;

  @override
  void didUpdateWidget(covariant CnFade oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_controller.duration != _duration) _controller.duration = _duration;

    if (widget.controller != oldWidget.controller) {
      if (widget.controller == null) {
        _startInternalController();
      } else {
        _delayTimer?.cancel();
      }
    }

    if (widget.forward != oldWidget.forward ||
        widget.fadeStartValue != oldWidget.fadeStartValue ||
        widget.fadeEndValue != oldWidget.fadeEndValue ||
        widget.controller != oldWidget.controller ||
        widget.curve != oldWidget.curve) {
      _updateFadeAnimation();
    }
  }

  void _updateFadeAnimation() {
    _curvedAnimation?.dispose();
    _curvedAnimation = CurvedAnimation(
      parent: widget.controller ?? _controller,
      curve: widget.curve ?? Curves.easeInOut,
    );

    _fadeAnimation = Tween<double>(
      begin: widget.forward ? widget.fadeStartValue : widget.fadeEndValue,
      end: widget.forward ? widget.fadeEndValue : widget.fadeStartValue,
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
      duration: _duration,
      vsync: this,
    );

    _updateFadeAnimation();

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
