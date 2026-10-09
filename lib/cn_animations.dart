library;

export 'cn_fade.dart';
export 'cn_slide.dart';
export 'cn_scale.dart';
export 'cn_route_aware_animation.dart';
export 'route_aware_widget.dart' hide routeObserver;

// Navigation-driven choreography. geometry.dart, route_progress.dart and the
// kCn* constants / CnRouteSubjectTarget are package-internal and not exported.
export 'src/progress/cn_directional_curved_animation.dart'
    show CnDirectionalCurvedAnimation;
export 'src/choreography/cn_route_choreography.dart'
    show
        CnRouteTiming,
        CnReducedMotionMode,
        CnSubjectDetection,
        CnSubjectBehavior,
        CnPartingSpec,
        CnScrollReveal,
        CnRouteChoreographyData,
        CnRouteChoreography;
export 'src/route/cn_fade_through_page_transitions_builder.dart'
    show CnFadeThroughPageTransitionsBuilder;
export 'src/route/cn_page_route.dart' show CnPageRoute;

// TODO(slice F part 2): export src/choreography/cn_route_animation.dart show CnRouteAnimation, CnElementProgress, CnElementRole, CnRouteAnimationBuilder
