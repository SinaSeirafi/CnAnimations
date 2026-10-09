// TODO(slice F): replace with lib/src/progress/cn_directional_curved_animation.dart
import 'package:flutter/animation.dart';

/// Private stand-in for `CnDirectionalCurvedAnimation` (design §3.3).
///
/// The curve is chosen by which rest value (0 or 1) the parent last left, not
/// by the parent's status. The lock is tracked inside [value], so every read
/// is consistent regardless of listener order.
class DirectionalCurveCopy extends Animation<double>
    with AnimationWithParentMixin<double> {
  DirectionalCurveCopy(this.parent, {required this.enter, required this.exit});

  @override
  final Animation<double> parent;
  final Curve enter;
  final Curve exit;

  // 0 or 1: the last rest value seen. Starts at 0 (enter) until proven otherwise.
  double _lastRest = 0;

  @override
  double get value {
    final double v = parent.value;
    if (v == 0.0 || v == 1.0) {
      _lastRest = v;
      return v;
    }
    return (_lastRest == 0.0 ? enter : exit).transform(v);
  }
}
