import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// An [Animation] that applies [enter] or [exit] to its [parent]'s value,
/// choosing the curve by the rest state the parent last left rather than by
/// its [AnimationStatus].
///
/// When the parent's value is exactly `0.0` or `1.0` it is at rest; that rest
/// is recorded and the value passes through unchanged. While the value is
/// strictly between the two, the curve is [enter] if the last rest was `0.0`
/// and [exit] if it was `1.0`. The choice holds until the parent reaches a
/// rest again, so a cancelled gesture (leave `1.0`, come back to `1.0`) plays
/// the exit backwards, and a push that is popped halfway (leave `0.0`, come
/// back to `0.0`) plays the entrance backwards.
///
/// Why not [CurvedAnimation.reverseCurve]: [CurvedAnimation] picks its curve
/// by status. During an interactive back gesture (iOS swipe-back, Android
/// predictive back) a route's animation drops from `1.0` while its status
/// stays [AnimationStatus.forward], so a status-keyed curve would play the
/// entrance window backwards for a gesture-driven exit.
///
/// Curves are applied to the parent's value as-is: `value =
/// curve.transform(parent.value)`. For a parent that runs `1.0 → 0.0` while
/// leaving (a route's `animation` on pop), an [exit] of `Interval(0.6, 1.0)`
/// therefore acts during the *first* 40 % of the pop. To express an exit
/// slice measured in elapsed time from the start of leaving, pass
/// `FlippedCurve(slice)`.
///
/// [status], [isCompleted] and [isDismissed] delegate to the parent. The
/// object owns no resources and needs no disposal. While it has listeners
/// of its own it also listens to the parent's status, so a rest is recorded
/// even if no one reads [value] on the frame the parent reached it (for
/// example a covered page that goes offstage in that same frame, or a
/// route's animation proxy switching from its first-frame `1.0` to the
/// controller at `0.0`).
class CnDirectionalCurvedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  /// Creates an animation that curves [parent] with [enter] after it leaves
  /// `0.0` and with [exit] after it leaves `1.0`.
  ///
  /// If [parent] is mid-flight when this object is created, the last rest is
  /// inferred from its status: [AnimationStatus.reverse] means it left `1.0`,
  /// anything else means it left `0.0`.
  CnDirectionalCurvedAnimation(
    this.parent, {
    required this.enter,
    required this.exit,
  }) : _leftUpperRest = _initialRest(parent);

  @override
  final Animation<double> parent;

  /// The curve used while the parent is between rests after leaving `0.0`.
  final Curve enter;

  /// The curve used while the parent is between rests after leaving `1.0`.
  final Curve exit;

  /// Whether the last rest the parent was observed at is `1.0`.
  bool _leftUpperRest;

  int _listenerCount = 0;

  static bool _initialRest(Animation<double> parent) {
    final double t = parent.value;
    if (t >= 1.0) return true;
    if (t <= 0.0) return false;
    return parent.status == AnimationStatus.reverse;
  }

  @override
  double get value {
    final double t = parent.value;
    if (t <= 0.0) {
      _leftUpperRest = false;
      return t;
    }
    if (t >= 1.0) {
      _leftUpperRest = true;
      return t;
    }
    return (_leftUpperRest ? exit : enter).transform(t);
  }

  // Records a rest on any status change that lands on one. Besides
  // completed/dismissed this covers a ProxyAnimation swapping its parent:
  // on the first frame of a push, ModalRoute.animation reads
  // kAlwaysCompleteAnimation (1.0, Hero measuring frame) and then switches to
  // the controller at 0.0 with status forward.
  void _handleParentStatus(AnimationStatus status) {
    final double t = parent.value;
    if (t <= 0.0) {
      _leftUpperRest = false;
    } else if (t >= 1.0) {
      _leftUpperRest = true;
    }
  }

  void _didAddListener() {
    if (_listenerCount == 0) {
      parent.addStatusListener(_handleParentStatus);
    }
    _listenerCount += 1;
  }

  void _didRemoveListener() {
    if (_listenerCount == 0) return;
    _listenerCount -= 1;
    if (_listenerCount == 0) {
      parent.removeStatusListener(_handleParentStatus);
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _didAddListener();
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _didRemoveListener();
  }

  @override
  void addStatusListener(AnimationStatusListener listener) {
    _didAddListener();
    super.addStatusListener(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    super.removeStatusListener(listener);
    _didRemoveListener();
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'CnDirectionalCurvedAnimation')}'
        '($parent, ${_leftUpperRest ? 'exit' : 'enter'}: '
        '${_leftUpperRest ? exit : enter})';
  }
}
