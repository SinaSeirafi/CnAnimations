import 'dart:async';

import 'package:flutter/material.dart';

class CnFade extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final int? durationInMilliseconds;
  final bool forward;
  final double fadeStartValue;
  final double fadeEndValue;
  final int delayInMilliseconds;
  final Duration? delay;
  final AnimationController? controller;

  const CnFade({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.durationInMilliseconds,
    this.forward = true,
    this.fadeStartValue = 0,
    this.fadeEndValue = 1,
    this.delay,
    this.delayInMilliseconds = 10,
    this.controller,
  }) : super(key: key);

  @override
  _CnFadeState createState() => _CnFadeState();
}

class _CnFadeState extends State<CnFade> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );
  }

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: widget.forward ? widget.fadeStartValue : widget.fadeEndValue,
      end: widget.forward ? widget.fadeEndValue : widget.fadeStartValue,
    ).animate(
      widget.controller ?? _controller,
    );

    Future.delayed(
      widget.delay ?? Duration(milliseconds: widget.delayInMilliseconds),
      () {
        if (mounted) _controller.forward();
      },
    );

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
