import 'package:cn_animations/cn_animations.dart';
import 'package:example/pages/basics_page.dart';
import 'package:example/restart_widget.dart';
import 'package:example/settings.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const RestartWidget(child: ExampleApp()));
}

/// Note what is missing: there is no `navigatorObservers` line. Route-driven
/// choreography reads the route's own animations, so nothing has to be wired
/// into the Navigator.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final SettingsModel _settings = SettingsModel();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      model: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp(
          title: 'Cn Animations Example',
          theme: ThemeData(
            colorSchemeSeed: Colors.teal,
            useMaterial3: true,
            pageTransitionsTheme: _settings.useFadeThrough
                ? PageTransitionsTheme(builders: {
                    for (final platform in TargetPlatform.values)
                      platform: const CnFadeThroughPageTransitionsBuilder(),
                  })
                : null,
          ),
          // App-wide defaults for every CnRouteAnimation below the Navigator.
          builder: (context, child) => CnRouteChoreography(
            respectReducedMotion: _settings.respectReducedMotion,
            reducedMotionMode: _settings.reducedMotionMode,
            scrollReveal: _settings.scrollReveal
                ? const CnScrollReveal()
                : CnScrollReveal.off,
            subjectDetection: _settings.subjectDetection,
            parting: CnPartingSpec(subject: _settings.subjectBehavior),
            child: child!,
          ),
          home: const BasicsPage(),
        ),
      ),
    );
  }
}
