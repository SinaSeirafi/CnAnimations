import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

/// In-memory settings bound to the app-wide [CnRouteChoreography]. Changing a
/// value rebuilds the app immediately; nothing is persisted.
class SettingsModel extends ChangeNotifier {
  bool _respectReducedMotion = true;
  CnReducedMotionMode _reducedMotionMode = CnReducedMotionMode.fadeOnly;
  bool _scrollReveal = false;
  CnSubjectDetection _subjectDetection = CnSubjectDetection.pointer;
  CnSubjectBehavior _subjectBehavior = CnSubjectBehavior.stay;
  bool _useFadeThrough = true;
  bool _slowMotion = false;

  bool get respectReducedMotion => _respectReducedMotion;
  CnReducedMotionMode get reducedMotionMode => _reducedMotionMode;
  bool get scrollReveal => _scrollReveal;
  CnSubjectDetection get subjectDetection => _subjectDetection;
  CnSubjectBehavior get subjectBehavior => _subjectBehavior;

  /// Cn fade-through route (true) or the platform default transition (false).
  bool get useFadeThrough => _useFadeThrough;

  /// Slow motion multiplies every animation duration by 4 via [timeDilation].
  bool get slowMotion => _slowMotion;

  set respectReducedMotion(bool v) => _set(() => _respectReducedMotion = v);
  set reducedMotionMode(CnReducedMotionMode v) =>
      _set(() => _reducedMotionMode = v);
  set scrollReveal(bool v) => _set(() => _scrollReveal = v);
  set subjectDetection(CnSubjectDetection v) =>
      _set(() => _subjectDetection = v);
  set subjectBehavior(CnSubjectBehavior v) => _set(() => _subjectBehavior = v);
  set useFadeThrough(bool v) => _set(() => _useFadeThrough = v);
  set slowMotion(bool v) => _set(() {
        _slowMotion = v;
        timeDilation = v ? 4.0 : 1.0;
      });

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    timeDilation = 1.0;
    super.dispose();
  }
}

/// Makes the [SettingsModel] reachable from every page.
class SettingsScope extends InheritedNotifier<SettingsModel> {
  const SettingsScope({
    super.key,
    required SettingsModel model,
    required super.child,
  }) : super(notifier: model);

  static SettingsModel of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SettingsScope>()!
        .notifier!;
  }
}
