/// The element widget of the route choreography (design §2.2, §3.2–§3.6).
///
/// [CnRouteAnimation], [CnElementProgress], [CnElementRole] and
/// [CnRouteAnimationBuilder] are public API; everything else in this file is
/// private.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../progress/cn_directional_curved_animation.dart';
import '../progress/route_progress.dart';
import 'cn_route_choreography.dart';
import 'geometry.dart';

/// Builds custom rendering for a [CnRouteAnimation] from the element's
/// resolved [progress] for the current frame.
///
/// [child] is the widget's `child`, passed through so it is not rebuilt on
/// every frame.
// dart format off
typedef CnRouteAnimationBuilder = Widget Function(
  BuildContext context,
  CnElementProgress progress,
  Widget? child,
);
// dart format on

/// The part an element plays in the current cover transition.
enum CnElementRole {
  /// The element that led to the navigation (the tapped item, or the one
  /// marked with `CnRouteChoreography.select` or `subject: true`).
  subject,

  /// Another element on the same page while there is a subject: it parts
  /// away from the subject.
  sibling,

  /// No subject in this transition (or none yet): the element exits on its
  /// own `exitOffset`.
  plain,
}

/// The resolved state of one [CnRouteAnimation] for one frame, as handed to
/// a `builder:`.
@immutable
class CnElementProgress {
  /// Creates a progress value.
  const CnElementProgress({
    required this.shown,
    required this.covered,
    this.role = CnElementRole.plain,
    this.partingDirection = Offset.zero,
  });

  /// The rest state: fully shown, not covered, plain.
  static const CnElementProgress rest = CnElementProgress(
    shown: 1.0,
    covered: 0.0,
  );

  /// 0 hidden .. 1 shown: this page's enter and exit, after curves and
  /// stagger. Also carries the timed entrance when there is no progress to
  /// follow (first route, no route, scroll reveal).
  final double shown;

  /// 0 uncovered .. 1 covered: a page pushed over this one, after curves and
  /// stagger.
  final double covered;

  /// The element's role in the current cover transition.
  final CnElementRole role;

  /// Logical direction away from the subject, one of `(0, ±1)`, `(±1, 0)`;
  /// zero for the subject and for plain elements. The x component is in
  /// reading order (flip it for right-to-left text, as `SlideTransition`
  /// does with its `textDirection`).
  final Offset partingDirection;

  @override
  bool operator ==(Object other) {
    return other is CnElementProgress &&
        other.shown == shown &&
        other.covered == covered &&
        other.role == role &&
        other.partingDirection == partingDirection;
  }

  @override
  int get hashCode => Object.hash(shown, covered, role, partingDirection);

  @override
  String toString() =>
      'CnElementProgress(shown: ${shown.toStringAsFixed(3)}, '
      'covered: ${covered.toStringAsFixed(3)}, role: ${role.name}, '
      'partingDirection: $partingDirection)';
}

/// Animates its [child] with the route it lives in: in when the page is
/// pushed, out when it is popped or covered by another page, scrubbing with
/// interactive back gestures. Replaces `CnRouteAwareAnimation`; it needs no
/// `RouteObserver`.
///
/// ```dart
/// CnRouteAnimation(child: ListTile(title: const Text('Hello')))
/// ```
///
/// **Progress.** The element follows its `ModalRoute`'s `animation` (this
/// page's enter and exit) and `secondaryAnimation` (a page pushed over this
/// one). A [CnRouteChoreography] above can replace either with its
/// `progress` / `coverProgress`. Each source is sliced per element by the
/// resolved [CnRouteTiming]: entrances use [CnRouteTiming.enter] with
/// [CnRouteTiming.enterCurve], exits and covers use [CnRouteTiming.exit], and
/// uncovers (the page above pops) use [CnRouteTiming.uncover], the exit and
/// uncover slices both with [CnRouteTiming.exitCurve]. A curve set on the
/// `enter`, `exit` or `uncover` [Interval] itself is ignored.
///
/// **Timed entrance.** When there is no progress to follow, the element plays
/// one entrance over [CnRouteTiming.fallbackDuration]: with no route and no
/// scope `progress`, on the first route of a navigator (or a restored or
/// zero-duration route), and for elements built later on a page at rest when
/// [scrollReveal] is enabled (off by default; each element state reveals at
/// most once). This is the only path that creates an `AnimationController`.
///
/// **Parting.** A pointer-down on an element (within 700 ms of the push),
/// `CnRouteChoreography.select(context)` or `subject: true` makes it the
/// subject of the next cover transition. The subject stays (see
/// [CnPartingSpec.subjectBehavior]); other elements on the page part away from it
/// along the scope's axis, nearer ones first, and same-row grid cells part
/// sideways. Without a subject every element slides to [exitOffset] and
/// fades. Stagger and distance come from layout geometry, so
/// `ListView.builder` and grids need no index bookkeeping.
///
/// **Reduced motion.** When `MediaQuery.disableAnimations` is set and
/// [respectReducedMotion] resolves to true (widget, then scope, then `true`),
/// [CnReducedMotionMode.fadeOnly] keeps opacity following progress and drops
/// translation and scale; [CnReducedMotionMode.none] shows the child at rest.
///
/// The widget tree below this widget keeps one shape across [enabled] and
/// reduced-motion changes, so the child's state survives them.
class CnRouteAnimation extends StatefulWidget {
  /// Creates a route-driven element animation.
  const CnRouteAnimation({
    super.key,
    required this.child,
    this.enterOffset = const Offset(0, 0.1),
    this.exitOffset,
    this.fade = true,
    this.scale,
    this.enabled = true,
    this.enter = true,
    this.cover = true,
    this.subject,
    this.timing,
    this.respectReducedMotion,
    this.reducedMotionMode,
    this.scrollReveal,
    this.builder,
  });

  /// The widget to animate.
  final Widget child;

  /// Where the element comes from when it enters (and goes to when this page
  /// pops), as a fraction of its own size. Defaults to slightly below,
  /// `Offset(0, 0.1)`. The x component is logical (flipped for RTL).
  final Offset enterOffset;

  /// Where the element goes when the page is covered and there is no subject,
  /// as a fraction of its own size. Null (the default) mirrors [enterOffset]:
  /// `-enterOffset`, so with the defaults covered content moves up while the
  /// incoming page rises from below, and comes back down from above on
  /// uncover (the Material shared-axis convention).
  final Offset? exitOffset;

  /// Whether opacity changes at all (enter, exit and cover).
  final bool fade;

  /// Scale the element enters from (for example `0.95`); null means no
  /// scale.
  final double? scale;

  /// When false the child is shown as-is, at rest.
  final bool enabled;

  /// Whether the element takes part in this page's enter and exit (the
  /// route's `animation`) and in the timed entrance. With false it is always
  /// shown while the page is.
  final bool enter;

  /// Whether the element takes part in cover and uncover (the route's
  /// `secondaryAnimation`).
  final bool cover;

  /// `true` makes this element the subject of every cover transition (unless
  /// `CnRouteChoreography.select` names another); `false` keeps it from ever
  /// being the subject (a header, a row of action buttons). Null: decided by
  /// pointer-down or `select`.
  final bool? subject;

  /// Overrides the scope's [CnRouteTiming].
  final CnRouteTiming? timing;

  /// Overrides the scope's `respectReducedMotion` (default true).
  final bool? respectReducedMotion;

  /// Overrides the scope's `reducedMotionMode` (default
  /// [CnReducedMotionMode.fadeOnly]).
  final CnReducedMotionMode? reducedMotionMode;

  /// Overrides the scope's [CnScrollReveal] (default off).
  final CnScrollReveal? scrollReveal;

  /// Custom rendering. When non-null the widget does not apply its own fade,
  /// slide and scale; the builder gets the resolved [CnElementProgress] on
  /// every frame instead. Under [CnReducedMotionMode.none] and with
  /// [enabled] false it gets [CnElementProgress.rest]; under
  /// [CnReducedMotionMode.fadeOnly] it gets the live progress (check
  /// `MediaQuery.disableAnimationsOf` to drop motion yourself).
  final CnRouteAnimationBuilder? builder;

  @override
  State<CnRouteAnimation> createState() => _CnRouteAnimationState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Elements with `subject: true`, per page record. Weak on the record.
final Expando<List<_CnRouteAnimationState>> _forcedSubjects =
    Expando<List<_CnRouteAnimationState>>('CnRouteAnimation.forcedSubjects');

enum _Fallback { entrance, reveal }

enum _Slot { enter, exit, cover, uncover }

bool _isRest(double v) => v <= 0.0 || v >= 1.0;

class _CnRouteAnimationState extends State<CnRouteAnimation>
    with SingleTickerProviderStateMixin, CnTimedFallbackMixin<CnRouteAnimation>
    implements CnRouteSubjectTarget {
  /// Fired after every source tick, once the element's own bookkeeping for
  /// that tick is done. The transitions listen to this, never to the sources,
  /// so they always read values computed with the current role and geometry.
  final _Hub _hub = _Hub();

  // Resolved environment (didChangeDependencies).
  CnRouteChoreographyData _config = CnRouteChoreographyData.fallback;
  bool _disableAnimations = false;
  Rect _screen = Rect.zero;
  TextDirection _textDirection = TextDirection.ltr;

  // Sources.
  CnRouteProgress? _progress;
  CnDirectionalCurvedAnimation? _primary;
  CnDirectionalCurvedAnimation? _cover;
  double _lastPrimary = 1.0;
  double _lastCover = 0.0;
  bool _classified = false;

  // Timed fallback: which kind is playing, if any.
  _Fallback? _fallback;

  // Geometry. f is the stagger factor (0 nearest the anchor, 1 farthest, off
  // screen or unknown); 1 is the largest delay (and parting distance), used
  // until layout is known.
  double _primaryF = 1.0;
  double _coverF = 1.0;
  CnElementRole _role = CnElementRole.plain;
  Offset _direction = Offset.zero;
  bool _insideSubject = false;
  int _placementSegment = -1;
  bool _measureScheduled = false;

  // Slices for the current timing and stagger factors.
  Interval _enterSlice = const Interval(0.35, 1.0);
  Interval _exitSlice = const Interval(0.0, 0.35);
  Interval _coverSlice = const Interval(0.0, 0.35);
  Interval _uncoverSlice = const Interval(0.3, 0.65);
  Interval _fallbackSlice = const Interval(0.0, 1.0);

  CnRouteTiming get _timing => widget.timing ?? _config.timing;

  CnScrollReveal get _reveal => widget.scrollReveal ?? _config.scrollReveal;

  CnReducedMotionMode? get _reducedMode => _config.reducedMotionFor(
    disableAnimations: _disableAnimations,
    respectReducedMotion: widget.respectReducedMotion,
    reducedMotionMode: widget.reducedMotionMode,
  );

  /// The page record, if any. Never creates one.
  CnRouteRecord? get _record {
    final Object? key = _progress?.recordKey;
    return key == null ? null : CnRouteRecord.maybeOf(key);
  }

  // -- Lifecycle ----------------------------------------------------------

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _config = CnRouteChoreography.of(context);
    _disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Size? size = MediaQuery.maybeSizeOf(context);
    _screen = size == null ? Rect.zero : Offset.zero & size;
    _textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _updateSlices();
    final CnRouteProgress next = CnRouteProgress.of(
      context,
      progress: _config.progress,
      coverProgress: _config.coverProgress,
    );
    if (next != _progress) _bind(next);
  }

  @override
  void didUpdateWidget(CnRouteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject != widget.subject) _updateForcedSubject();
    _updateSlices();
    // No notification here: build() hands the transitions fresh value
    // adapters, so they re-read with the new configuration.
  }

  @override
  void dispose() {
    // Release a pending select() of this element (review R19).
    _record?.clearSelection(context);
    _unbind();
    timedFallback?.removeListener(_hub.notify);
    _hub.dispose();
    super.dispose();
  }

  void _bind(CnRouteProgress next) {
    _unbind();
    _progress = next;
    final Animation<double>? primary = next.primary;
    if (primary != null) {
      final Animation<double> source = _guardRouteSource(
        primary,
        next.route?.animation,
      );
      _lastPrimary = source.value;
      _primary = CnDirectionalCurvedAnimation(
        source,
        enter: _SliceCurve(this, _Slot.enter),
        exit: _SliceCurve(this, _Slot.exit),
      )..addListener(_handlePrimaryTick);
    }
    final Animation<double>? cover = next.cover;
    if (cover != null) {
      final Animation<double> source = _guardRouteSource(
        cover,
        next.route?.secondaryAnimation,
      );
      _lastCover = source.value;
      // Rest-locked like the primary: the exit slice after the cover leaves 0
      // (a page pushed over this one), the uncover slice after it leaves 1
      // (the page above pops or is dragged back), so a reversal or a
      // cancelled gesture keeps its slice and never jumps (review R6).
      _cover = CnDirectionalCurvedAnimation(
        source,
        enter: _SliceCurve(this, _Slot.cover),
        exit: _SliceCurve(this, _Slot.uncover),
      )..addListener(_handleCoverTick);
    }
    if (!_classified) {
      _classified = true;
      // Classifying also creates the page record (when there is a key) and
      // opens its initial-mount window.
      _startFallback(next.classifyMount());
      _scheduleMeasure();
    } else if (_lastCover > 0.0) {
      _scheduleMeasure();
    }
    _updateForcedSubject();
  }

  /// Wraps [source] in a [_ReverseRestartGuard] when it is the route's own
  /// animation ([routeSource]). Scope overrides pass through unchanged.
  static Animation<double> _guardRouteSource(
    Animation<double> source,
    Animation<double>? routeSource,
  ) => identical(source, routeSource) ? _ReverseRestartGuard(source) : source;

  void _unbind() {
    _primary?.removeListener(_handlePrimaryTick);
    _primary = null;
    _cover?.removeListener(_handleCoverTick);
    _cover = null;
    _forcedList(_record)?.remove(this);
  }

  void _startFallback(CnMountKind kind) {
    if (!widget.enabled ||
        !widget.enter ||
        _reducedMode == CnReducedMotionMode.none) {
      return;
    }
    final Duration duration;
    switch (kind) {
      case CnMountKind.untracked:
      case CnMountKind.initial:
        _fallback = _Fallback.entrance;
        duration = _timing.fallbackDuration;
      case CnMountKind.late:
        final CnScrollReveal reveal = _reveal;
        if (!reveal.enabled) return;
        _fallback = _Fallback.reveal;
        duration = reveal.duration ?? _timing.fallbackDuration;
      case CnMountKind.following:
        return;
    }
    final AnimationController controller = ensureTimedFallback(
      duration: duration,
    )..addListener(_hub.notify);
    controller.forward(from: 0.0);
  }

  // -- Subject ------------------------------------------------------------

  List<_CnRouteAnimationState>? _forcedList(CnRouteRecord? record) =>
      record == null ? null : _forcedSubjects[record];

  void _updateForcedSubject() {
    final CnRouteRecord? record = _record;
    if (record == null) return;
    final List<_CnRouteAnimationState> list =
        _forcedSubjects[record] ??= <_CnRouteAnimationState>[];
    list.remove(this);
    if (widget.subject == true) list.add(this);
  }

  /// `CnRouteChoreography.select(context)` lands here for the nearest
  /// element; the page record keeps the selection until the next cover
  /// transition starts.
  @override
  void selectAsSubject() {
    final Object? key = _progress?.recordKey;
    if (key == null) return;
    CnRouteRecord.of(key).select(context);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_config.subjectDetection != CnSubjectDetection.pointer) return;
    final Object? key = _progress?.recordKey;
    if (key == null) return;
    CnRouteRecord.of(key).recordPointerDown(this);
  }

  /// Resolves the subject once per cover segment. Priority: `select()`,
  /// then `subject: true`, then the last pointer-down (pointer detection
  /// only). Candidates with `subject: false` are skipped.
  void _resolveSubject(CnRouteRecord record) {
    final BuildContext? selection = record.takeSelection();
    record.subject = null;
    record.subjectRect = null;
    final CnSubjectDetection detection = _config.subjectDetection;
    if (detection == CnSubjectDetection.off) return;
    final List<_CnRouteAnimationState?> candidates = <_CnRouteAnimationState?>[
      _elementStateOf(selection),
      ...?_forcedList(record),
      if (detection == CnSubjectDetection.pointer)
        _asElementState(record.pointerSubject(maxAge: kCnPointerSubjectWindow)),
    ];
    for (final _CnRouteAnimationState? candidate in candidates) {
      if (candidate == null || !candidate.mounted) continue;
      if (candidate.widget.subject == false) continue;
      record.subject = candidate;
      record.subjectRect = candidate._globalRect();
      return;
    }
  }

  static _CnRouteAnimationState? _asElementState(State? state) =>
      state is _CnRouteAnimationState ? state : null;

  static _CnRouteAnimationState? _elementStateOf(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    if (context is StatefulElement && context.state is _CnRouteAnimationState) {
      return context.state as _CnRouteAnimationState;
    }
    return context.findAncestorStateOfType<_CnRouteAnimationState>();
  }

  // -- Ticks --------------------------------------------------------------

  void _handlePrimaryTick() {
    final CnDirectionalCurvedAnimation primary = _primary!;
    final double v = primary.parent.value;
    // Read through the curve every tick so its rest lock stays current even
    // on frames where nothing paints this element.
    primary.value;
    final double previous = _lastPrimary;
    _lastPrimary = v;
    // A segment starts when the source leaves a rest: read geometry now.
    if (_isRest(previous) && !_isRest(v)) _measurePrimary();
    _hub.notify();
  }

  void _handleCoverTick() {
    final CnDirectionalCurvedAnimation cover = _cover!;
    final double v = cover.parent.value;
    cover.value;
    final double previous = _lastCover;
    _lastCover = v;
    final CnRouteRecord? record = _record;
    if (v > 0.0) {
      _ensureCoverPlacement(record);
    } else if (previous > 0.0) {
      record?.endCoverSegment();
      _clearCoverPlacement();
    }
    _hub.notify();
  }

  // -- Geometry -----------------------------------------------------------

  /// The element's untransformed global rect, or null when it has no layout
  /// to read (not laid out yet, or a frame's build/layout/paint is running).
  Rect? _globalRect() {
    final RenderBox? box = _readableBox();
    return box == null ? null : cnGlobalRect(box);
  }

  RenderBox? _readableBox() {
    if (!mounted) return null;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return null;
    }
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    return object;
  }

  /// Measures the primary stagger factor (anchor: the viewport's leading
  /// edge). Returns false and schedules a retry when layout is unavailable.
  bool _measurePrimary({bool retry = true}) {
    final RenderBox? box = _readableBox();
    if (box == null) {
      if (retry) _scheduleMeasure();
      return false;
    }
    final CnPlacement placement = cnPlacement(
      element: cnGlobalRect(box),
      viewport: cnViewportRect(box, screen: _screen),
      axis: _config.axis,
      textDirection: _textDirection,
    );
    _primaryF = placement.f;
    _updateSlices();
    return true;
  }

  void _ensureCoverPlacement(CnRouteRecord? record) {
    if (record != null && !record.inCoverSegment) {
      if (record.beginCoverSegment()) _resolveSubject(record);
    }
    final int segment = record?.coverSegment ?? 0;
    if (_placementSegment == segment) return;
    final RenderBox? box = _readableBox();
    if (box == null) {
      // Built during the segment, or mid-frame: plain with no stagger until
      // the post-frame measure (a monotonic one-frame correction).
      _setRole(CnElementRole.plain, Offset.zero, 1.0, inside: false);
      _scheduleMeasure();
      return;
    }
    final _CnRouteAnimationState? subject = _asElementState(record?.subject);
    if (record != null && subject != null && record.subjectRect == null) {
      record.subjectRect = subject._globalRect();
    }
    final Rect element = cnGlobalRect(box);
    final Rect viewport = cnViewportRect(box, screen: _screen);
    final Rect? subjectRect = record?.subjectRect;
    final bool parting =
        _config.subjectDetection != CnSubjectDetection.off &&
        subject != null &&
        subjectRect != null;
    if (parting && identical(subject, this)) {
      _setRole(CnElementRole.subject, Offset.zero, 0.0, inside: false);
    } else if (parting && _isNestedWith(subject)) {
      // Inside the subject, or wrapping it: moving would move the subject.
      _setRole(CnElementRole.subject, Offset.zero, 0.0, inside: true);
    } else if (parting) {
      final CnPlacement placement = cnPlacement(
        element: element,
        viewport: viewport,
        axis: _config.axis,
        subject: subjectRect,
        textDirection: _textDirection,
      );
      _setRole(
        CnElementRole.sibling,
        placement.direction,
        placement.f,
        inside: false,
      );
    } else {
      final CnPlacement placement = cnPlacement(
        element: element,
        viewport: viewport,
        axis: _config.axis,
        textDirection: _textDirection,
      );
      _setRole(CnElementRole.plain, Offset.zero, placement.f, inside: false);
    }
    _placementSegment = segment;
  }

  bool _isNestedWith(_CnRouteAnimationState other) {
    bool found = false;
    context.visitAncestorElements((Element ancestor) {
      found = ancestor is StatefulElement && identical(ancestor.state, other);
      return !found;
    });
    if (found) return true;
    if (!other.mounted) return false;
    other.context.visitAncestorElements((Element ancestor) {
      found = ancestor is StatefulElement && identical(ancestor.state, this);
      return !found;
    });
    return found;
  }

  void _setRole(
    CnElementRole role,
    Offset direction,
    double f, {
    required bool inside,
  }) {
    _role = role;
    _direction = direction;
    _insideSubject = inside;
    _coverF = f;
    _updateSlices();
  }

  void _clearCoverPlacement() {
    _placementSegment = -1;
    _setRole(CnElementRole.plain, Offset.zero, 1.0, inside: false);
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _measureScheduled = false;
      if (!mounted) return;
      // One retry per scheduling: an element that never gets a layout keeps
      // f = 1 (no stagger) rather than polling every frame.
      if (!_measurePrimary(retry: false)) return;
      if (_cover != null && _lastCover > 0.0) _ensureCoverPlacement(_record);
      _hub.notify();
    }, debugLabel: 'CnRouteAnimation.measure');
  }

  void _updateSlices() {
    final CnRouteTiming timing = _timing;
    _enterSlice = cnStaggeredEnter(timing, _primaryF);
    _exitSlice = cnStaggeredExit(timing, _primaryF);
    _coverSlice = cnStaggeredExit(timing, _coverF);
    _uncoverSlice = cnStaggeredUncover(timing, _coverF);
    _fallbackSlice = Interval(
      _primaryF.clamp(0.0, 1.0) * timing.enterStagger,
      1.0,
      curve: timing.enterCurve,
    );
  }

  double _transform(_Slot slot, double t) {
    switch (slot) {
      case _Slot.enter:
        return _enterSlice.transform(t);
      case _Slot.exit:
        // The primary source runs 1 -> 0 while leaving; flip so the exit
        // slice is measured from the start of leaving.
        return 1.0 - _exitSlice.transform(1.0 - t);
      case _Slot.cover:
        return _coverSlice.transform(t);
      case _Slot.uncover:
        // Read on the cover progress as-is, like the cover slice: the
        // element returns as the progress falls from uncover.end.
        return _uncoverSlice.transform(t);
    }
  }

  // -- Values -------------------------------------------------------------

  /// Whether the element moves at all right now.
  bool get _animating =>
      widget.enabled && _reducedMode != CnReducedMotionMode.none;

  bool get _fadeOnly => _reducedMode == CnReducedMotionMode.fadeOnly;

  /// The timed entrance (1 when none is playing).
  double get _fallbackShown {
    final AnimationController? controller = timedFallback;
    final _Fallback? fallback = _fallback;
    if (fallback == null || controller == null) return 1.0;
    final double t = controller.value;
    switch (fallback) {
      case _Fallback.entrance:
        return _fallbackSlice.transform(t);
      case _Fallback.reveal:
        return (_reveal.curve ?? _timing.enterCurve).transform(t);
    }
  }

  /// This page's enter/exit (1 with no primary source).
  double get _routeShown => _primary?.value ?? 1.0;

  double get _shown =>
      (_animating && widget.enter) ? _fallbackShown * _routeShown : 1.0;

  double get _covered =>
      (_animating && widget.cover) ? (_cover?.value ?? 0.0) : 0.0;

  CnElementProgress _elementProgress() {
    if (!_animating) return CnElementProgress.rest;
    return CnElementProgress(
      shown: _shown,
      covered: _covered,
      role: _role,
      partingDirection:
          _role == CnElementRole.sibling ? _direction : Offset.zero,
    );
  }

  double _opacity() {
    if (!_animating || !widget.fade) return 1.0;
    final double covered = _covered;
    final double coverFactor;
    switch (_role) {
      case CnElementRole.subject:
        coverFactor =
            (!_insideSubject &&
                    _config.parting.subjectBehavior == CnSubjectBehavior.fade)
                ? 1.0 - covered
                : 1.0;
      case CnElementRole.sibling:
        coverFactor = _config.parting.fadeSiblings ? 1.0 - covered : 1.0;
      case CnElementRole.plain:
        coverFactor = 1.0 - covered;
    }
    return (_shown * coverFactor).clamp(0.0, 1.0);
  }

  Offset _offset() {
    if (!_animating || _fadeOnly) return Offset.zero;
    Offset offset = Offset.zero;
    if (widget.enter) {
      final _Fallback? fallback = _fallback;
      if (fallback != null) {
        final Offset from =
            fallback == _Fallback.reveal ? _reveal.offset : widget.enterOffset;
        offset += from * (1.0 - _fallbackShown);
      }
      offset += widget.enterOffset * (1.0 - _routeShown);
    }
    final double covered = _covered;
    if (covered > 0.0) offset += _exitVector * covered;
    return offset;
  }

  Offset get _exitVector {
    switch (_role) {
      case CnElementRole.subject:
        return Offset.zero;
      case CnElementRole.sibling:
        return cnPartingOffset(_config.parting, _direction, _coverF);
      case CnElementRole.plain:
        return widget.exitOffset ?? -widget.enterOffset;
    }
  }

  double _scale() {
    if (!_animating || _fadeOnly) return 1.0;
    double scale = 1.0;
    final double? from = widget.scale;
    if (from != null && widget.enter) {
      scale *= from + (1.0 - from) * _shown;
    }
    if (_role == CnElementRole.subject &&
        !_insideSubject &&
        _config.parting.subjectBehavior == CnSubjectBehavior.grow) {
      scale *= 1.0 + 0.04 * _covered;
    }
    return scale;
  }

  // -- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final CnRouteAnimationBuilder? builder = widget.builder;
    final Widget content;
    if (builder != null) {
      content = ListenableBuilder(
        listenable: _hub,
        builder:
            (BuildContext context, Widget? child) =>
                builder(context, _elementProgress(), child),
        child: widget.child,
      );
    } else {
      // One shape for every configuration (enabled, reduced motion), so the
      // child's state survives changes. Fresh adapters per build make the
      // transitions re-read after a configuration change.
      content = FadeTransition(
        opacity: _HubValue<double>(_hub, _opacity),
        child: SlideTransition(
          position: _HubValue<Offset>(_hub, _offset),
          textDirection: _textDirection,
          child: ScaleTransition(
            scale: _HubValue<double>(_hub, _scale),
            child: widget.child,
          ),
        ),
      );
    }
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _handlePointerDown,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// A curve that reads the element's current slice for [slot], so stagger
/// can change without replacing the rest-locked animation.
class _SliceCurve extends Curve {
  const _SliceCurve(this.state, this.slot);

  final _CnRouteAnimationState state;
  final _Slot slot;

  @override
  double transformInternal(double t) => state._transform(slot, t);
}

/// The element's tick notifier.
class _Hub extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// An [Animation] view of one value computed by the element, notified by
/// its [_Hub]. Owns nothing; status is not meaningful.
class _HubValue<T> extends Animation<T> {
  _HubValue(this._hub, this._read);

  final Listenable _hub;
  final ValueGetter<T> _read;

  @override
  void addListener(VoidCallback listener) => _hub.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _hub.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  T get value => _read();
}

/// Keeps a route source from jumping back up when its reverse restarts from
/// the top.
///
/// On Flutter 3.35+ (flutter/flutter#154718) a committed predictive back
/// through the stock `PredictiveBackPageTransitionsBuilder` pops the route
/// and then calls `reverse(from: upperBound)`: the route's animation, and the
/// page below's secondary animation, go from the release value (say 0.5) to
/// 1.0 and play the whole reverse. Flutter remaps only its own page
/// transforms; elements reading the raw value would snap back to fully shown
/// (this page) or fully covered (the page below).
///
/// Rule: while the source reverses, this value never rises. On a rise it
/// scales the source by `k = last / source`, so it continues from the last
/// value it gave and still reaches 0.0 with the source. If the source turns
/// forward while scaled, the map is re-anchored so it reaches 1.0 with the
/// source; a rest (0.0 or 1.0) restores the identity. Paths that never rise
/// in reverse (Flutter 3.29–3.32, the package's back-gesture detector, the
/// iOS swipe, a plain pop) pass through unchanged.
///
/// The restart notifies 1.0 with status completed between the two reverses
/// (`value = from` lands on the bound before the reverse starts). A rest
/// keeps the reverse anchor only for a reverse that starts in the same
/// frame; a rest seen in a later frame is a real one.
///
/// Listens to its parent only while it has listeners of its own, and
/// updates its map before notifying them.
class _ReverseRestartGuard extends Animation<double>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  _ReverseRestartGuard(this.parent);

  final Animation<double> parent;

  // value = _a + _b * parent.value; the identity is (0, 1).
  double _a = 0.0;
  double _b = 1.0;

  AnimationStatus? _lastStatus;

  // The last observation while the parent was reversing (null when there is
  // none since the last forward or dismissed).
  double? _reverseRaw;
  double _reverseShown = 0.0;
  Duration _reverseFrame = Duration.zero;
  bool _restSinceReverse = false;

  bool get _isIdentity => _a == 0.0 && _b == 1.0;

  @override
  AnimationStatus get status => parent.status;

  @override
  double get value => _map(parent.value);

  double _map(double t) => (_a + _b * t).clamp(0.0, 1.0);

  @override
  void didStartListening() {
    _reset();
    parent.addListener(_handleValue);
    parent.addStatusListener(_handleStatus);
  }

  @override
  void didStopListening() {
    parent.removeListener(_handleValue);
    parent.removeStatusListener(_handleStatus);
    _reset();
  }

  void _reset() {
    _a = 0.0;
    _b = 1.0;
    _lastStatus = null;
    _reverseRaw = null;
    _restSinceReverse = false;
  }

  void _handleValue() {
    _observe();
    notifyListeners();
  }

  void _handleStatus(AnimationStatus status) {
    _observe();
    notifyStatusListeners(status);
  }

  void _observe() {
    final double t = parent.value;
    final AnimationStatus status = parent.status;
    final Duration frame =
        SchedulerBinding.instance.currentSystemFrameTimeStamp;
    final bool turned = _lastStatus != null && status != _lastStatus;
    switch (status) {
      case AnimationStatus.reverse:
        final double? previous = _reverseRaw;
        if (previous != null &&
            t > previous + 1e-9 &&
            (!_restSinceReverse || frame == _reverseFrame)) {
          // Restarted from above: continue from the last value given.
          _a = 0.0;
          _b = _reverseShown / t;
        } else if (turned && !_isIdentity && t > 0.0) {
          // Turned back while remapped: aim the map at 0.0.
          final double shown = _map(t);
          _a = 0.0;
          _b = shown / t;
        }
        _reverseRaw = t;
        _reverseShown = _map(t);
        _reverseFrame = frame;
        _restSinceReverse = false;
      case AnimationStatus.forward:
        if (turned && !_isIdentity && t < 1.0) {
          // Turned forward while remapped: aim the map at 1.0.
          final double shown = _map(t);
          _b = (1.0 - shown) / (1.0 - t);
          _a = 1.0 - _b;
        }
        _reverseRaw = null;
      case AnimationStatus.completed:
        _a = 0.0;
        _b = 1.0;
        _restSinceReverse = true;
      case AnimationStatus.dismissed:
        _a = 0.0;
        _b = 1.0;
        _reverseRaw = null;
    }
    _lastStatus = status;
  }
}
