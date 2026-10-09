/// Progress sources and per-route shared state for route-driven element
/// motion.
///
/// **Package-internal.** Nothing in this file is exported from
/// `package:cn_animations/cn_animations.dart`; the types are public only so
/// other files in this package can use them. Do not add them to the export
/// barrel.
///
/// What lives here:
///
/// * [CnRouteProgress]: resolves an element's primary source (this page's
///   enter/exit) and cover source (a page pushed over it) from the
///   [ModalRoute] or from scope overrides, and classifies a mount as
///   [CnMountKind.following], [CnMountKind.initial], [CnMountKind.late] or
///   [CnMountKind.untracked].
/// * [CnRouteRecord]: state shared by every element of one page, held in an
///   [Expando] keyed by the route (weak: nothing to dispose, nothing retained
///   after the route is gone).
/// * [CnTimedFallbackMixin]: the one [AnimationController] an element owns
///   when there is no progress to follow; created lazily and disposed with
///   its owner [State].
/// * [staggeredExitInterval] / [staggeredEnterInterval]: the per-element
///   slices of progress.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../choreography/cn_route_choreography.dart'
    show kCnPointerSubjectWindow;

// ---------------------------------------------------------------------------
// Per-element slices of progress
// ---------------------------------------------------------------------------

/// The exit slice for one element: `exit` delayed by `factor · stagger`, with
/// its end pushed by the same amount but never past `1.0`.
///
/// [factor] is the element's stagger factor (0 nearest the anchor, 1 farthest
/// or off-screen) and is clamped to `[0, 1]`. The slice is measured in
/// progress from the start of leaving; for a source that runs `1.0 → 0.0`
/// while leaving, wrap the result in [FlippedCurve] before handing it to
/// `CnDirectionalCurvedAnimation`.
///
/// Package-internal.
Interval staggeredExitInterval(
  Interval exit, {
  required double factor,
  required double stagger,
  Curve curve = Curves.linear,
}) {
  final double delay = factor.clamp(0.0, 1.0) * stagger;
  final double end = math.min(1.0, exit.end + delay);
  final double begin = math.min(exit.begin + delay, end);
  return Interval(begin, end, curve: curve);
}

/// The enter slice for one element: `enter` with its begin delayed by
/// `factor · stagger` and its end pinned to `1.0`, so every element is at
/// rest when the route is.
///
/// [factor] is clamped to `[0, 1]`. Package-internal.
Interval staggeredEnterInterval(
  Interval enter, {
  required double factor,
  required double stagger,
  Curve curve = Curves.linear,
}) {
  final double delay = factor.clamp(0.0, 1.0) * stagger;
  final double begin = math.min(enter.begin + delay, 1.0);
  return Interval(begin, 1.0, curve: curve);
}

// ---------------------------------------------------------------------------
// Shared per-route record
// ---------------------------------------------------------------------------

/// The element that last received a pointer-down on a page, and when.
///
/// Package-internal.
class CnPointerDown {
  CnPointerDown._(this.owner);

  /// The element state that received the pointer-down.
  final State owner;

  /// [SchedulerBinding.currentSystemFrameTimeStamp] of the first frame after
  /// the pointer-down, or null until that frame has started. Pointer events
  /// arrive between frames, when the last frame's stamp may be arbitrarily
  /// old, so the stamp is taken at the next frame instead.
  Duration? get timeStamp => _timeStamp;
  Duration? _timeStamp;
}

/// State shared by every element of one page (or one scope `progress`
/// source when there is no route).
///
/// Obtain it with [CnRouteRecord.of]; records are held in an [Expando] keyed
/// by the route object, so a record lives exactly as long as its route and
/// needs no disposal. The record holds no reference to its key.
///
/// It carries:
///
/// * the last pointer-down ([recordPointerDown], [pointerSubject]);
/// * an explicit selection ([select], [takeSelection]) for programmatic or
///   keyboard navigation;
/// * the current cover segment: [beginCoverSegment] / [endCoverSegment],
///   the resolved [subject], its [subjectRect] and a free-form
///   [segmentCache], all cleared when the segment ends;
/// * the initial-mount window used by [CnRouteProgress.classifyMount].
///
/// Package-internal.
class CnRouteRecord {
  CnRouteRecord._();

  static final Expando<CnRouteRecord> _records = Expando<CnRouteRecord>(
    'CnRouteRecord',
  );

  /// The record for [key], created on first use.
  ///
  /// [key] is normally the element's [ModalRoute]; with no route, use the
  /// scope's `progress` animation. It must be a type [Expando] accepts (not
  /// a number, string, boolean, record or null).
  static CnRouteRecord of(Object key) {
    return _records[key] ??= CnRouteRecord._();
  }

  /// The record for [key] if one has been created, else null. Never creates.
  static CnRouteRecord? maybeOf(Object key) => _records[key];

  // -- Pointer-down -------------------------------------------------------

  /// The most recent pointer-down on this page, if any.
  CnPointerDown? get lastPointerDown => _lastPointerDown;
  CnPointerDown? _lastPointerDown;

  /// Records that [owner] received a pointer-down. The time stamp is taken
  /// at the start of the next frame (see [CnPointerDown.timeStamp]).
  void recordPointerDown(State owner) {
    final CnPointerDown down = CnPointerDown._(owner);
    _lastPointerDown = down;
    SchedulerBinding.instance.scheduleFrameCallback((Duration _) {
      down._timeStamp = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    });
  }

  /// The owner of [lastPointerDown] if it is still mounted and no older than
  /// [maxAge], measured against the current frame; else null.
  ///
  /// A pointer-down whose frame has not started yet counts as age zero.
  /// Call this during a frame (for example from the cover source's tick, when
  /// it leaves `0.0`); between frames the last frame's stamp may be stale,
  /// which makes the check lenient, never strict.
  State? pointerSubject({Duration maxAge = kCnPointerSubjectWindow}) {
    final CnPointerDown? down = _lastPointerDown;
    if (down == null || !down.owner.mounted) return null;
    final Duration? stamp = down.timeStamp;
    if (stamp == null) return down.owner;
    final Duration age =
        SchedulerBinding.instance.currentSystemFrameTimeStamp - stamp;
    return age <= maxAge ? down.owner : null;
  }

  // -- Explicit selection -------------------------------------------------

  /// Marks [context] as the origin of the next cover transition's subject.
  ///
  /// The scope's `select()` calls this with the context it was given; the
  /// element resolves it to the nearest element state above that context.
  void select(BuildContext context) {
    _selection = context;
  }

  /// The context passed to [select], if it is still mounted. Clears it.
  BuildContext? takeSelection() {
    final BuildContext? selection = _selection;
    _selection = null;
    return (selection != null && selection.mounted) ? selection : null;
  }

  /// Forgets the selection if it is still [context]. An element calls this
  /// when it is disposed, so the record does not keep it alive until the next
  /// cover transition.
  void clearSelection(BuildContext context) {
    if (identical(_selection, context)) _selection = null;
  }

  /// Whether a selection is stored (it may no longer be mounted). For tests.
  @visibleForTesting
  bool get hasSelection => _selection != null;

  BuildContext? _selection;

  // -- Cover segment ------------------------------------------------------

  /// Whether a cover segment is in progress: the cover source has left `0.0`
  /// and has not yet returned to it.
  bool get inCoverSegment => _inCoverSegment;
  bool _inCoverSegment = false;

  /// Increments each time a cover segment begins. Elements can store it to
  /// tell whether their cached geometry belongs to the current segment.
  int get coverSegment => _coverSegment;
  int _coverSegment = 0;

  /// Starts a cover segment if none is in progress.
  ///
  /// Returns true only for the call that started it; that caller resolves
  /// [subject] and [subjectRect] once for the segment. Later callers in the
  /// same segment get false and read the cached values.
  bool beginCoverSegment() {
    if (_inCoverSegment) return false;
    _inCoverSegment = true;
    _coverSegment += 1;
    return true;
  }

  /// Ends the current cover segment (the cover source is back at `0.0`) and
  /// clears [subject], [subjectRect] and [segmentCache]. Idempotent.
  void endCoverSegment() {
    if (!_inCoverSegment) return;
    _inCoverSegment = false;
    subject = null;
    subjectRect = null;
    segmentCache.clear();
  }

  /// The subject resolved for the current cover segment, or null for none.
  State? subject;

  /// The subject's global paint rect at segment start, for elements that
  /// are built during the segment after the subject is gone or offstage.
  Rect? subjectRect;

  /// Anything else an element wants to share for the current segment.
  final Map<Object, Object?> segmentCache = <Object, Object?>{};

  // -- Initial-mount window -----------------------------------------------

  bool _bindSeen = false;
  bool _initialWindowOpen = false;

  /// Opens the initial-mount window on the first bind to this record and
  /// reports whether it is still open.
  ///
  /// The window opens when the first element binds and closes at the end of
  /// that frame (a post-frame callback). This is the "same frame time stamp"
  /// rule of design §3.6, phrased so it also holds for a tree built before
  /// the first frame, when [SchedulerBinding.currentFrameTimeStamp] is not
  /// yet available.
  bool _bindAndCheckInitialWindow() {
    if (!_bindSeen) {
      _bindSeen = true;
      _initialWindowOpen = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _initialWindowOpen = false;
      }, debugLabel: 'CnRouteRecord.initialWindow');
    }
    return _initialWindowOpen;
  }
}

// ---------------------------------------------------------------------------
// Progress sources
// ---------------------------------------------------------------------------

/// How an element should start when it binds to its progress sources.
///
/// Package-internal.
enum CnMountKind {
  /// No primary source (no [ModalRoute], no scope `progress`): play the timed
  /// entrance once on mount; cover never happens unless a cover source
  /// exists.
  untracked,

  /// The primary source is not at `1.0`: follow progress from here.
  following,

  /// The primary source is at `1.0` and this element binds in the same frame
  /// as the first element of its route (first route of a navigator, a
  /// restored route, a zero-duration push): play the timed entrance.
  initial,

  /// The primary source is at `1.0` and the route's first elements bound on
  /// an earlier frame (lazy list item, scroll, rebuild): render at rest, or
  /// play the timed entrance if scroll reveal is enabled.
  late,
}

/// An element's resolved progress sources.
///
/// [primary] drives this page's enter/exit (`shown`); [cover] drives the
/// page pushed over it (`covered`). Scope overrides win over the route.
/// Both route sources are stable [ProxyAnimation]s for the route's
/// lifetime, so two values compare equal (by identity of route and sources)
/// unless something actually changed; an element can rebind only when
/// `newProgress != oldProgress`.
///
/// Package-internal.
@immutable
class CnRouteProgress {
  const CnRouteProgress._({this.route, this.primary, this.cover});

  /// Resolves sources from [route] and the scope overrides [progress] and
  /// [coverProgress]: `primary = progress ?? route?.animation`,
  /// `cover = coverProgress ?? route?.secondaryAnimation`.
  factory CnRouteProgress.resolve({
    ModalRoute<Object?>? route,
    Animation<double>? progress,
    Animation<double>? coverProgress,
  }) {
    return CnRouteProgress._(
      route: route,
      primary: progress ?? route?.animation,
      cover: coverProgress ?? route?.secondaryAnimation,
    );
  }

  /// Resolves sources for [context] from `ModalRoute.of(context)` and the
  /// scope overrides. Creates a dependency on the route, so call it from
  /// `didChangeDependencies`.
  factory CnRouteProgress.of(
    BuildContext context, {
    Animation<double>? progress,
    Animation<double>? coverProgress,
  }) {
    return CnRouteProgress.resolve(
      route: ModalRoute.of(context),
      progress: progress,
      coverProgress: coverProgress,
    );
  }

  /// The nearest [ModalRoute], or null when the element is not inside one.
  final ModalRoute<Object?>? route;

  /// This page's enter/exit source, or null when there is none.
  final Animation<double>? primary;

  /// The cover source (a page pushed over this one), or null when there is
  /// none.
  final Animation<double>? cover;

  /// The key for [CnRouteRecord]: the route, else the scope's primary
  /// source, else null.
  Object? get recordKey => route ?? primary;

  /// The shared record for this page, or null when there is no [recordKey].
  CnRouteRecord? get record {
    final Object? key = recordKey;
    return key == null ? null : CnRouteRecord.of(key);
  }

  /// Classifies a mount. Call once, when the element first binds.
  ///
  /// The first call for a record opens its initial-mount window for the rest
  /// of the current frame, whatever the primary value is, so a page that was
  /// pushed with a transition never classifies its later mounts as initial.
  ///
  /// A route that is [ModalRoute.offstage] is in the Hero measuring frame of
  /// a push: its `animation` reads `1.0` for that one frame, but the page is
  /// about to run its entrance, so the mount is [CnMountKind.following].
  CnMountKind classifyMount() {
    final Animation<double>? primary = this.primary;
    if (primary == null) return CnMountKind.untracked;
    final bool initialWindow = record!._bindAndCheckInitialWindow();
    // First frame of a push under a HeroController: the route is built
    // offstage and its animation reads 1.0 (kAlwaysCompleteAnimation) for
    // that frame only. The real progress starts at 0.0 on the next frame.
    final ModalRoute<Object?>? route = this.route;
    if (route != null &&
        route.offstage &&
        identical(primary, route.animation)) {
      return CnMountKind.following;
    }
    if (primary.value < 1.0) return CnMountKind.following;
    return initialWindow ? CnMountKind.initial : CnMountKind.late;
  }

  @override
  bool operator ==(Object other) {
    return other is CnRouteProgress &&
        identical(other.route, route) &&
        identical(other.primary, primary) &&
        identical(other.cover, cover);
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(route),
        identityHashCode(primary),
        identityHashCode(cover),
      );

  @override
  String toString() =>
      'CnRouteProgress(route: $route, primary: $primary, cover: $cover)';
}

// ---------------------------------------------------------------------------
// Timed fallback
// ---------------------------------------------------------------------------

/// Gives a [State] the timed fallback controller: the one
/// [AnimationController] an element owns when there is no progress to follow
/// (untracked, initial and scroll-reveal mounts).
///
/// The controller is created lazily on the first [ensureTimedFallback] call
/// (the route-driven path never creates one) and disposed with the owner in
/// [dispose].
///
/// ```dart
/// class _S extends State<W>
///     with SingleTickerProviderStateMixin, CnTimedFallbackMixin<W> { ... }
/// ```
///
/// Package-internal.
mixin CnTimedFallbackMixin<T extends StatefulWidget>
    on State<T>, TickerProvider {
  AnimationController? _timedFallback;

  /// The fallback controller, or null if none has been created.
  AnimationController? get timedFallback => _timedFallback;

  /// Returns the fallback controller, creating it on first use. An existing
  /// controller gets [duration] as its new duration.
  AnimationController ensureTimedFallback({required Duration duration}) {
    final AnimationController? existing = _timedFallback;
    if (existing != null) {
      existing.duration = duration;
      return existing;
    }
    return _timedFallback = AnimationController(
      vsync: this,
      duration: duration,
      debugLabel: 'CnTimedFallback',
    );
  }

  /// Plays the timed entrance from `0.0` over [duration] and returns the
  /// controller. With [Duration.zero] it completes synchronously.
  AnimationController playTimedFallback({required Duration duration}) {
    final AnimationController controller = ensureTimedFallback(
      duration: duration,
    );
    controller.forward(from: 0.0);
    return controller;
  }

  @override
  void dispose() {
    _timedFallback?.dispose();
    _timedFallback = null;
    super.dispose();
  }
}
