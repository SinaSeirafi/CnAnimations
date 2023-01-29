// ignore_for_file: library_private_types_in_public_api

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
  });

  @override
  _CnScaleState createState() => _CnScaleState();
}

class _CnScaleState extends State<CnScale> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
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
