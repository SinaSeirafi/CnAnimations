import 'dart:async';

import 'package:flutter/material.dart';

class CnSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset begin;
  final Offset end;
  final Curve? curve;
  final double intervalBegin;
  final double intervalEnd;
  final bool forward;
  final Duration? delay;
  final int delayInMilliseconds;
  final AnimationController? controller;
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
    this.reverseControllerValue = false,
    Key? key,
  }) : super(key: key);

  @override
  State<CnSlide> createState() => _CnSlideState();
}

class _CnSlideState extends State<CnSlide> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: widget.child,
    );
  }

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.forward ? widget.begin : widget.end,
      end: widget.forward ? widget.end : widget.begin,
    ).animate(
      CurvedAnimation(
        parent: widget.controller ?? _controller,
        curve: widget.curve ?? Curves.easeInOut,
      ),
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
