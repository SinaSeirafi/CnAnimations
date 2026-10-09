import 'package:cn_animations/cn_animations.dart';
import 'package:example/pages/grid_page.dart';
import 'package:example/pages/list_page.dart';
import 'package:example/pages/no_navigator_page.dart';
import 'package:example/pages/settings_page.dart';
import 'package:example/restart_widget.dart';
import 'package:flutter/material.dart';

/// The simple widgets (unchanged from 0.0.x) plus entry points to the
/// route-driven demos.
class BasicsPage extends StatelessWidget {
  const BasicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cn Animations Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: <Widget>[
              CnFade(
                duration: const Duration(milliseconds: 1000),
                child: _box('Fade'),
              ),
              CnScale(
                duration: const Duration(milliseconds: 500),
                child: _box('Scale'),
              ),
              CnSlide(
                begin: const Offset(-0.1, 0),
                duration: const Duration(milliseconds: 500),
                child: _box('Slide'),
              ),

              /// Chain animations: the first one's duration is the second one's
              /// delay. Cancel the previous end value in the second animation.
              CnSlide(
                begin: const Offset(-0.3, 0),
                end: const Offset(0.03, 0),
                duration: const Duration(milliseconds: 300),
                child: CnSlide(
                  begin: const Offset(0.03, 0),
                  end: const Offset(-0.03, 0),
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 200),
                  child: _box('Chained'),
                ),
              ),

              /// Combine different animations; extract a widget if you use a
              /// combination a lot.
              CnFade(
                duration: const Duration(milliseconds: 700),
                child: CnSlide(
                  begin: const Offset(0, 0.2),
                  delayInMilliseconds: 100,
                  child: CnScale(
                    duration: const Duration(milliseconds: 500),
                    begin: 0.7,
                    child: _box('Combined'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Route-driven demos'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  _nav(context, 'List', const ListPage()),
                  _nav(context, 'Grid', const GridPage()),
                  _nav(context, 'Settings', const SettingsPage()),
                  _nav(context, 'No navigator', const NoNavigatorPage()),
                ],
              ),
            ],
          ),
        ),
      ),

      /// Replays the animations above.
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.replay_rounded),
        onPressed: () => RestartWidget.restartApp(context),
      ),
    );
  }

  Widget _nav(BuildContext context, String label, Widget page) {
    return FilledButton.tonal(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      ),
      child: Text(label),
    );
  }

  Widget _box(String text) {
    return Container(
      height: 100,
      width: 100,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
