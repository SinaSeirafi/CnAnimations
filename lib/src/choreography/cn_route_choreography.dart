import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Package defaults (owner decisions, design §10). Each is one named constant
// so a change is a one-line edit. They are package-internal: export the public
// types from this file with `show`, not these constants.
// ---------------------------------------------------------------------------

/// What reduced motion means when it applies and nothing overrides it
/// (design §10 Q2, decided: `fadeOnly`).
const CnReducedMotionMode kCnDefaultReducedMotionMode =
    CnReducedMotionMode.fadeOnly;

/// How the subject of a cover transition is detected when nothing overrides
/// it (design §10 Q3, decided: `pointer`).
const CnSubjectDetection kCnDefaultSubjectDetection =
    CnSubjectDetection.pointer;

/// How long a pointer-down on an element stays eligible to make that element
/// the subject of the next cover transition (design §3.5 / §10 Q3).
const Duration kCnPointerSubjectWindow = Duration(milliseconds: 700);

/// Whether `MediaQuery.disableAnimations` is honored when nothing overrides
/// it (0.1.0 name and default).
const bool kCnDefaultRespectReducedMotion = true;

// ---------------------------------------------------------------------------
// Configuration value types (design §2.1)
// ---------------------------------------------------------------------------

/// How route progress is sliced for element motion. All values are fractions
/// of the route's transition (0..1), so they scale with any route duration.
@immutable
class CnRouteTiming {
  const CnRouteTiming({
    this.exit = const Interval(0.0, 0.35),
    this.enter = const Interval(0.35, 1.0),
    this.uncover = const Interval(0.3, 0.65),
    this.exitStagger = 0.12,
    this.enterStagger = 0.25,
    this.exitCurve = Curves.easeIn,
    this.enterCurve = Curves.easeOutCubic,
    this.fallbackDuration = const Duration(milliseconds: 300),
  }) : assert(exitStagger >= 0 && exitStagger <= 1),
       assert(enterStagger >= 0 && enterStagger <= 1);

  /// Slice of progress during which an element leaves: when a page is pushed
  /// over this one (measured on the cover progress as it rises from 0), and
  /// when this page pops or is swiped back (measured from the start of
  /// leaving). A push over this page that is popped before it finishes plays
  /// this slice backwards. Bringing the element back after the page above
  /// pops uses [uncover] instead.
  ///
  /// Only `begin` and `end` are used; the curve comes from [exitCurve]. A
  /// curved `Interval` asserts in debug when an element uses this timing.
  final Interval exit;

  /// Slice during which an element arrives (push of this page).
  ///
  /// Only `begin` and `end` are used; the curve comes from [enterCurve]. A
  /// curved `Interval` asserts in debug when an element uses this timing.
  final Interval enter;

  /// Slice of the cover progress during which a covered element comes back,
  /// used while the cover progress falls from 1: the page above pops, or is
  /// dragged back by an interactive back gesture (Android predictive back,
  /// the iOS edge swipe).
  ///
  /// It is read on the cover progress as-is, like [exit] on the way in: the
  /// element is fully covered above `end` and at rest below `begin`, so it
  /// starts returning when the cover progress falls past `end`. The default,
  /// `Interval(0.3, 0.65)`, as long as the default [exit], starts the return
  /// as the top page's elements finish leaving (their exit ends at 65 % of
  /// progress, while the fade-through page fades out over the top 40 %),
  /// instead of a quarter of the pop later. Use
  /// `uncover: exit` (the default `exit` is `Interval(0.0, 0.35)`) to replay
  /// the exit slice backwards instead, as before 0.9.0.
  ///
  /// The choice between [exit] and [uncover] is locked by the rest the cover
  /// progress left, not by the animation's status: after leaving 0 (a push
  /// over this page) [exit] applies until the progress rests again, even if
  /// the push is reversed; after leaving 1 (a pop or back gesture) [uncover]
  /// applies, even if the gesture is cancelled and the progress climbs back
  /// to 1. So a reversal never jumps between the two slices.
  ///
  /// Stagger works as for [exit]: each element's slice is shifted later by up
  /// to [exitStagger] by its distance from the anchor. The curve comes from
  /// [exitCurve], so on the way back the element decelerates into place. Only
  /// `begin` and `end` are used; a curved `Interval` asserts in debug when an
  /// element uses this timing.
  final Interval uncover;

  /// Maximum extra start delay added to [exit] (and the matching shift of
  /// [uncover]) for the element farthest from the anchor (tapped item, or the
  /// viewport's leading edge). Bounds total time.
  final double exitStagger;

  /// Maximum extra start delay added to [enter] for the element farthest from
  /// the anchor.
  final double enterStagger;

  /// Curve applied within each element's [exit] and [uncover] slices.
  final Curve exitCurve;

  /// Curve applied within each element's enter slice.
  final Curve enterCurve;

  /// Duration of the timed entrance used when there is no progress to follow
  /// (no ModalRoute, first route of the app, zero-duration route, scroll
  /// reveal).
  final Duration fallbackDuration;

  /// Convenience: the default sliced for a 400 ms route (exit 140 ms, enter
  /// 260 ms).
  static const CnRouteTiming standard = CnRouteTiming();

  CnRouteTiming copyWith({
    Interval? exit,
    Interval? enter,
    Interval? uncover,
    double? exitStagger,
    double? enterStagger,
    Curve? exitCurve,
    Curve? enterCurve,
    Duration? fallbackDuration,
  }) {
    return CnRouteTiming(
      exit: exit ?? this.exit,
      enter: enter ?? this.enter,
      uncover: uncover ?? this.uncover,
      exitStagger: exitStagger ?? this.exitStagger,
      enterStagger: enterStagger ?? this.enterStagger,
      exitCurve: exitCurve ?? this.exitCurve,
      enterCurve: enterCurve ?? this.enterCurve,
      fallbackDuration: fallbackDuration ?? this.fallbackDuration,
    );
  }

  // `Interval` does not override `==`, so compare its fields.
  static bool _sameInterval(Interval a, Interval b) =>
      a.begin == b.begin && a.end == b.end && a.curve == b.curve;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CnRouteTiming &&
        _sameInterval(other.exit, exit) &&
        _sameInterval(other.enter, enter) &&
        _sameInterval(other.uncover, uncover) &&
        other.exitStagger == exitStagger &&
        other.enterStagger == enterStagger &&
        other.exitCurve == exitCurve &&
        other.enterCurve == enterCurve &&
        other.fallbackDuration == fallbackDuration;
  }

  @override
  int get hashCode => Object.hash(
    exit.begin,
    exit.end,
    exit.curve,
    enter.begin,
    enter.end,
    enter.curve,
    uncover.begin,
    uncover.end,
    uncover.curve,
    exitStagger,
    enterStagger,
    exitCurve,
    enterCurve,
    fallbackDuration,
  );
}

/// What "reduced motion" means when it applies.
enum CnReducedMotionMode {
  /// Opacity still follows progress; translation and scale are dropped.
  /// Default.
  fadeOnly,

  /// Elements render at their rest state immediately.
  none,
}

/// How the subject of a cover transition is detected.
enum CnSubjectDetection {
  /// The element that received the last pointer-down (within
  /// [kCnPointerSubjectWindow]) becomes the subject. Also honors
  /// [CnRouteChoreography.select] and `subject: true`.
  pointer,

  /// Only [CnRouteChoreography.select] and `subject: true` mark a subject.
  manual,

  /// No subject and no parting; every element exits as a plain element.
  off,
}

/// What the subject itself does while its siblings part.
enum CnSubjectBehavior {
  /// The subject stays put and fully visible.
  stay,

  /// The subject stays put and fades out as it is covered.
  fade,

  /// The subject stays put and grows to 1.04 times its size as it is
  /// covered. The factor is fixed and not configurable.
  grow,
}

/// How siblings move away from the tapped item.
@immutable
class CnPartingSpec {
  const CnPartingSpec({
    this.distance = const Offset(0, 0.6),
    this.distanceGrowth = 0.5,
    this.fadeSiblings = true,
    this.subjectBehavior = CnSubjectBehavior.stay,
  }) : assert(distanceGrowth >= 0);

  /// How far a sibling moves, as a fraction of the sibling's own size per
  /// axis. A sibling parting along x uses `distance.dx`, along y uses
  /// `distance.dy`; when that component is zero the other component's
  /// magnitude is used, so the default `(0, 0.6)` also parts horizontal lists
  /// and same-row grid cells (see `cnPartingOffset`).
  final Offset distance;

  /// Farther siblings move up to `(1 + distanceGrowth)` times [distance].
  final double distanceGrowth;

  /// Whether siblings fade while they part.
  final bool fadeSiblings;

  /// What the subject (the tapped item) does while its siblings part.
  final CnSubjectBehavior subjectBehavior;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CnPartingSpec &&
        other.distance == distance &&
        other.distanceGrowth == distanceGrowth &&
        other.fadeSiblings == fadeSiblings &&
        other.subjectBehavior == subjectBehavior;
  }

  @override
  int get hashCode =>
      Object.hash(distance, distanceGrowth, fadeSiblings, subjectBehavior);
}

/// Scroll reveal: timed entrance for elements first built while the page is at
/// rest. Off by default ([CnScrollReveal.off]).
@immutable
class CnScrollReveal {
  /// An enabled scroll reveal. A null [duration] or [curve] falls back to the
  /// resolved [CnRouteTiming.fallbackDuration] and [CnRouteTiming.enterCurve].
  const CnScrollReveal({
    this.duration,
    this.curve,
    this.offset = const Offset(0, 0.1),
  }) : enabled = true;

  const CnScrollReveal._off()
    : duration = null,
      curve = null,
      offset = Offset.zero,
      enabled = false;

  /// Scroll reveal disabled. The default.
  static const CnScrollReveal off = CnScrollReveal._off();

  /// Whether late mounts play a timed entrance at all.
  final bool enabled;

  /// Duration of the reveal; null uses the timing's fallback duration.
  final Duration? duration;

  /// Curve of the reveal; null uses the timing's enter curve.
  final Curve? curve;

  /// Start offset of the reveal, as a fraction of the element's size.
  ///
  /// Each element state reveals at most once; an item scrolled away and
  /// disposed by a lazy list reveals again when it is rebuilt.
  final Offset offset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CnScrollReveal &&
        other.enabled == enabled &&
        other.duration == duration &&
        other.curve == curve &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(enabled, duration, curve, offset);
}

// ---------------------------------------------------------------------------
// Resolved configuration
// ---------------------------------------------------------------------------

/// The configuration in effect at a [BuildContext]: every scope from the root
/// down merged field-by-field (inner non-null wins), over built-in defaults.
/// Returned by [CnRouteChoreography.of]; never null.
@immutable
class CnRouteChoreographyData {
  const CnRouteChoreographyData({
    this.timing = CnRouteTiming.standard,
    this.parting = const CnPartingSpec(),
    this.scrollReveal = CnScrollReveal.off,
    this.respectReducedMotion = kCnDefaultRespectReducedMotion,
    this.reducedMotionMode = kCnDefaultReducedMotionMode,
    this.axis = Axis.vertical,
    this.subjectDetection = kCnDefaultSubjectDetection,
    this.progress,
    this.coverProgress,
  });

  /// The built-in defaults, used where no scope sets a field.
  static const CnRouteChoreographyData fallback = CnRouteChoreographyData();

  final CnRouteTiming timing;
  final CnPartingSpec parting;
  final CnScrollReveal scrollReveal;
  final bool respectReducedMotion;
  final CnReducedMotionMode reducedMotionMode;

  /// Main axis for parting and stagger.
  final Axis axis;
  final CnSubjectDetection subjectDetection;

  /// Replaces `ModalRoute.animation` as the enter/exit source when non-null.
  final Animation<double>? progress;

  /// Replaces `ModalRoute.secondaryAnimation` as the cover source when
  /// non-null.
  final Animation<double>? coverProgress;

  /// The reduced-motion mode that applies to one element, or null when motion
  /// is not reduced. Precedence is widget override > scope > default:
  /// [respectReducedMotion] and [reducedMotionMode] are the element's own
  /// overrides; [disableAnimations] is `MediaQuery.disableAnimations`.
  CnReducedMotionMode? reducedMotionFor({
    required bool disableAnimations,
    bool? respectReducedMotion,
    CnReducedMotionMode? reducedMotionMode,
  }) {
    final bool respect = respectReducedMotion ?? this.respectReducedMotion;
    if (!respect || !disableAnimations) return null;
    return reducedMotionMode ?? this.reducedMotionMode;
  }

  CnRouteChoreographyData _overriddenBy(CnRouteChoreography scope) {
    return CnRouteChoreographyData(
      timing: scope.timing ?? timing,
      parting: scope.parting ?? parting,
      scrollReveal: scope.scrollReveal ?? scrollReveal,
      respectReducedMotion: scope.respectReducedMotion ?? respectReducedMotion,
      reducedMotionMode: scope.reducedMotionMode ?? reducedMotionMode,
      axis: scope.axis ?? axis,
      subjectDetection: scope.subjectDetection ?? subjectDetection,
      progress: scope.progress ?? progress,
      coverProgress: scope.coverProgress ?? coverProgress,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CnRouteChoreographyData &&
        other.timing == timing &&
        other.parting == parting &&
        other.scrollReveal == scrollReveal &&
        other.respectReducedMotion == respectReducedMotion &&
        other.reducedMotionMode == reducedMotionMode &&
        other.axis == axis &&
        other.subjectDetection == subjectDetection &&
        identical(other.progress, progress) &&
        identical(other.coverProgress, coverProgress);
  }

  @override
  int get hashCode => Object.hash(
    timing,
    parting,
    scrollReveal,
    respectReducedMotion,
    reducedMotionMode,
    axis,
    subjectDetection,
    progress,
    coverProgress,
  );
}

// ---------------------------------------------------------------------------
// select() hook
// ---------------------------------------------------------------------------

/// Package-internal hook between [CnRouteChoreography.select] and the element
/// widget. The `State` of `CnRouteAnimation` implements it; `select` calls
/// [selectAsSubject] on the nearest such state at or above the given context.
/// Not part of the public API: export this file with `show`.
abstract interface class CnRouteSubjectTarget {
  /// Record this element as the subject of the next cover transition of its
  /// route.
  void selectAsSubject();
}

// ---------------------------------------------------------------------------
// Scope widget (design §2.2)
// ---------------------------------------------------------------------------

/// Optional configuration scope. Put it in `MaterialApp.builder` for app-wide
/// defaults, or around one page/list to override. Nearest wins; unset fields
/// inherit from the next scope up, then from built-in defaults.
class CnRouteChoreography extends InheritedWidget {
  const CnRouteChoreography({
    super.key,
    required super.child,
    this.timing,
    this.parting,
    this.scrollReveal,
    this.respectReducedMotion,
    this.reducedMotionMode,
    this.axis,
    this.subjectDetection,
    this.progress,
    this.coverProgress,
  });

  final CnRouteTiming? timing;
  final CnPartingSpec? parting;
  final CnScrollReveal? scrollReveal;

  /// Default true (0.1.0 name).
  final bool? respectReducedMotion;

  /// Default [CnReducedMotionMode.fadeOnly].
  final CnReducedMotionMode? reducedMotionMode;

  /// Default [Axis.vertical]. Main axis for parting and stagger.
  final Axis? axis;

  /// Default [CnSubjectDetection.pointer].
  final CnSubjectDetection? subjectDetection;

  /// Replaces `ModalRoute.animation` for elements below.
  final Animation<double>? progress;

  /// Replaces `ModalRoute.secondaryAnimation` for elements below.
  final Animation<double>? coverProgress;

  /// Marks the nearest `CnRouteAnimation` at or above [context] as the subject
  /// of the next cover transition (for programmatic navigation / keyboard
  /// activation). Call it before `Navigator.push`.
  static void select(BuildContext context) {
    final CnRouteSubjectTarget? target = _nearestSubjectTarget(context);
    assert(() {
      if (target == null) {
        throw FlutterError(
          'CnRouteChoreography.select() found no CnRouteAnimation.\n'
          'The context passed to select() must be the context of a '
          'CnRouteAnimation or of a widget below one.',
        );
      }
      return true;
    }());
    target?.selectAsSubject();
  }

  static CnRouteSubjectTarget? _nearestSubjectTarget(BuildContext context) {
    CnRouteSubjectTarget? asTarget(Element element) {
      if (element is StatefulElement && element.state is CnRouteSubjectTarget) {
        return element.state as CnRouteSubjectTarget;
      }
      return null;
    }

    CnRouteSubjectTarget? found = context is Element ? asTarget(context) : null;
    if (found != null) return found;
    context.visitAncestorElements((Element ancestor) {
      found = asTarget(ancestor);
      return found == null;
    });
    return found;
  }

  /// The resolved configuration at [context]: every enclosing scope merged
  /// field-by-field (inner non-null wins) over the built-in defaults. Never
  /// null. Registers a dependency on every enclosing scope, so a change to
  /// any of them rebuilds the caller.
  static CnRouteChoreographyData of(BuildContext context) {
    final List<CnRouteChoreography> scopes = <CnRouteChoreography>[];
    InheritedElement? element = context
        .getElementForInheritedWidgetOfExactType<CnRouteChoreography>();
    while (element != null) {
      context.dependOnInheritedElement(element);
      scopes.add(element.widget as CnRouteChoreography);
      element = _enclosingScopeElement(element);
    }
    CnRouteChoreographyData data = CnRouteChoreographyData.fallback;
    for (final CnRouteChoreography scope in scopes.reversed) {
      data = data._overriddenBy(scope);
    }
    return data;
  }

  // An InheritedElement's own lookup table contains itself, so look the next
  // scope up from its parent element.
  static InheritedElement? _enclosingScopeElement(InheritedElement element) {
    Element? parent;
    element.visitAncestorElements((Element ancestor) {
      parent = ancestor;
      return false;
    });
    return parent
        ?.getElementForInheritedWidgetOfExactType<CnRouteChoreography>();
  }

  @override
  bool updateShouldNotify(CnRouteChoreography oldWidget) {
    return oldWidget.timing != timing ||
        oldWidget.parting != parting ||
        oldWidget.scrollReveal != scrollReveal ||
        oldWidget.respectReducedMotion != respectReducedMotion ||
        oldWidget.reducedMotionMode != reducedMotionMode ||
        oldWidget.axis != axis ||
        oldWidget.subjectDetection != subjectDetection ||
        !identical(oldWidget.progress, progress) ||
        !identical(oldWidget.coverProgress, coverProgress);
  }
}
