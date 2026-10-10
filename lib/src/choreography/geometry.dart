/// Geometry for choreography (design §3.4, §3.5, §5 RTL).
///
/// Everything here is a side-effect-free function. [cnPlacement],
/// [cnStaggeredExit], [cnStaggeredUncover], [cnStaggeredEnter] and
/// [cnPartingOffset] are pure
/// arithmetic on rects and config values; [cnGlobalRect] and [cnViewportRect]
/// only read the current layout of a render object.
///
/// Package-internal: not exported from `package:cn_animations`.
library;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import 'cn_route_choreography.dart';

/// Where one element sits relative to the viewport and the subject.
///
/// - `onScreen`: the element's rect overlaps the viewport rect (touching an
///   edge does not count). Items built only for the cache extent are off
///   screen.
/// - `f`: stagger / distance factor in `[0, 1]`: main-axis distance from the
///   anchor to the element's center divided by the viewport's main extent.
///   Always 1 for off-screen elements: the same as the farthest on-screen
///   element, so the largest delay and parting distance.
/// - `direction`: logical parting direction away from the subject, one of
///   `(0, ±1)`, `(±1, 0)` or zero. Zero when there is no subject and for the
///   subject itself. The x component is in reading order (flipped for RTL),
///   matching `SlideTransition(textDirection:)`.
typedef CnPlacement = ({bool onScreen, double f, Offset direction});

/// Computes the [CnPlacement] of an element.
///
/// All rects are in the same (global) coordinate space. [axis] is the
/// choreography's main axis. The anchor is the [subject]'s center when there
/// is a subject, else the viewport's leading edge (top for vertical; left for
/// horizontal LTR, right for horizontal RTL).
///
/// With a subject, a sibling parts along the main axis by the sign of its
/// main-axis distance from the subject. A sibling whose main-axis distance is
/// under half the subject's main extent is in the subject's row (grids) and
/// parts along the cross axis instead.
CnPlacement cnPlacement({
  required Rect element,
  required Rect viewport,
  Axis axis = Axis.vertical,
  Rect? subject,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final bool vertical = axis == Axis.vertical;
  final bool rtl = textDirection == TextDirection.rtl;
  double main(Offset p) => vertical ? p.dy : p.dx;
  double cross(Offset p) => vertical ? p.dx : p.dy;

  final bool onScreen = element.overlaps(viewport);
  final double mainExtent = vertical ? viewport.height : viewport.width;

  final double anchor;
  if (subject != null) {
    anchor = main(subject.center);
  } else if (vertical) {
    anchor = viewport.top;
  } else {
    anchor = rtl ? viewport.right : viewport.left;
  }

  final double f =
      (onScreen && mainExtent > 0)
          ? ((main(element.center) - anchor).abs() / mainExtent).clamp(0.0, 1.0)
          : 1.0;

  Offset direction = Offset.zero;
  if (subject != null) {
    final double mainDistance = main(element.center) - main(subject.center);
    final double subjectMainExtent = vertical ? subject.height : subject.width;
    final bool sameRow = mainDistance.abs() < subjectMainExtent / 2;
    if (!sameRow) {
      final double s = mainDistance.sign;
      direction = vertical ? Offset(0, s) : Offset(s, 0);
    } else {
      final double s = (cross(element.center) - cross(subject.center)).sign;
      direction = vertical ? Offset(s, 0) : Offset(0, s);
    }
    if (rtl && direction.dx != 0) {
      direction = Offset(-direction.dx, direction.dy);
    }
  }

  return (onScreen: onScreen, f: f, direction: direction);
}

// `CnRouteTiming` is const, and a const constructor cannot read
// `Interval.curve` in an assert, so the check lives where the slices are
// built. The curves of `exit` / `enter` / `uncover` are ignored (review R9).
bool _linearIntervals(CnRouteTiming timing) =>
    timing.exit.curve == Curves.linear &&
    timing.enter.curve == Curves.linear &&
    timing.uncover.curve == Curves.linear;

const String _curvedIntervalMessage =
    'CnRouteTiming.exit, enter and uncover must be linear Intervals: their '
    'curves are ignored. Set exitCurve / enterCurve instead.';

/// The element's exit slice for stagger factor [f] (design §3.4):
/// `Interval(exit.begin + f·exitStagger, min(1, exit.end + f·exitStagger))`
/// with [CnRouteTiming.exitCurve]. Both ends are clamped to 1.
Interval cnStaggeredExit(CnRouteTiming timing, double f) {
  assert(_linearIntervals(timing), _curvedIntervalMessage);
  final double shift = f.clamp(0.0, 1.0) * timing.exitStagger;
  return Interval(
    (timing.exit.begin + shift).clamp(0.0, 1.0),
    (timing.exit.end + shift).clamp(0.0, 1.0),
    curve: timing.exitCurve,
  );
}

/// The element's uncover slice for stagger factor [f] (review R6):
/// [CnRouteTiming.uncover] shifted by `f·exitStagger`, with
/// [CnRouteTiming.exitCurve]: the same shift and curve as [cnStaggeredExit].
/// Both ends are clamped to 1.
Interval cnStaggeredUncover(CnRouteTiming timing, double f) {
  assert(_linearIntervals(timing), _curvedIntervalMessage);
  final double shift = f.clamp(0.0, 1.0) * timing.exitStagger;
  return Interval(
    (timing.uncover.begin + shift).clamp(0.0, 1.0),
    (timing.uncover.end + shift).clamp(0.0, 1.0),
    curve: timing.exitCurve,
  );
}

/// The element's enter slice for stagger factor [f] (design §3.4):
/// `Interval(enter.begin + f·enterStagger, 1.0)` with
/// [CnRouteTiming.enterCurve]. The end is pinned so every element is at rest
/// when the route is.
Interval cnStaggeredEnter(CnRouteTiming timing, double f) {
  assert(_linearIntervals(timing), _curvedIntervalMessage);
  final double shift = f.clamp(0.0, 1.0) * timing.enterStagger;
  return Interval(
    (timing.enter.begin + shift).clamp(0.0, 1.0),
    1.0,
    curve: timing.enterCurve,
  );
}

/// A sibling's exit vector, as a fraction of its own size (design §3.5):
/// `distance ⊙ direction × (1 + distanceGrowth·f)`.
///
/// A direction along x uses `distance.dx` and along y uses `distance.dy`;
/// when that component is zero the other component is used, so the default
/// `CnPartingSpec.distance` of `(0, 0.6)` also parts horizontal lists and
/// same-row grid cells. Zero [direction] gives zero.
Offset cnPartingOffset(CnPartingSpec spec, Offset direction, double f) {
  if (direction == Offset.zero) return Offset.zero;
  final double scale = 1 + spec.distanceGrowth * f.clamp(0.0, 1.0);
  final double dx = spec.distance.dx != 0 ? spec.distance.dx : spec.distance.dy;
  final double dy = spec.distance.dy != 0 ? spec.distance.dy : spec.distance.dx;
  return Offset(direction.dx * dx * scale, direction.dy * dy * scale);
}

/// The paint rect of [box] in global coordinates.
Rect cnGlobalRect(RenderBox box) {
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// The global paint rect of the nearest viewport enclosing [renderObject], or
/// [screen] when there is none (or it has no size yet).
Rect cnViewportRect(RenderObject renderObject, {required Rect screen}) {
  final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
    renderObject,
  );
  if (viewport is RenderBox && (viewport as RenderBox).hasSize) {
    return cnGlobalRect(viewport as RenderBox);
  }
  return screen;
}
