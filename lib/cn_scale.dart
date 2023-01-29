import 'dart:async';

import 'package:flutter/material.dart';

class CnScale extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve? curve;
  final double intervalBegin;
  final double intervalEnd;
  final bool forward;
  final Duration? delay;
  final int delayInMilliseconds;

  const CnScale({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve,
    this.intervalBegin = 0.7,
    this.intervalEnd = 1.0,
    this.forward = true,
    this.delay,
    this.delayInMilliseconds = 0,
  });

  @override
  _CnScaleState createState() => _CnScaleState();
}

class _CnScaleState extends State<CnScale> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: widget.curve ?? Curves.easeInOut,
      ),
      child: widget.child,
    );
  }

  late AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      duration: widget.duration,
      value: widget.forward ? widget.intervalBegin : widget.intervalEnd,
      vsync: this,
    );

    Future.delayed(
      widget.delay ?? Duration(milliseconds: widget.delayInMilliseconds),
      () {
        if (!mounted) return;

        widget.forward ? _controller.forward() : _controller.reverse();
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
