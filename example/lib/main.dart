import 'package:cn_animations/cn_animations.dart';

import 'package:cn_animations/route_aware_widget.dart';
import 'package:example/restart_widget.dart';
import 'package:flutter/material.dart';

// import 'package:cn_animations/cn_animations.dart';

void main() {
  runApp(
    RestartWidget(
      child: MaterialApp(
        home: const MyHomePage(),
        theme: ThemeData(primarySwatch: Colors.teal),
        navigatorObservers: [routeObserver],
      ),
    ),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cn Animations Example"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CnFade(
              duration: animationDuration,
              child: _buildChild("Fade"),
            ),
            CnScale(
              duration: const Duration(milliseconds: 2000),
              child: _buildChild("Scale"),
            ),
            CnSlide(
              begin: const Offset(-0.1, 0),
              duration: animationDuration,
              child: _buildChild("Slide"),
            ),

            /// You can chain animations together
            /// Use first animation duration as the second one's delay and so on
            ///
            /// make sure to cancel previous values
            ///
            /// This is probably very inefficient
            CnSlide(
              begin: const Offset(-0.2, 0),
              end: const Offset(0.03, 0),
              duration: animationDuration,
              child: CnSlide(
                begin: const Offset(0.03, 0),

                /// to cancel the other animation end value
                end: const Offset(-0.03, 0),
                delay: animationDuration,
                duration: const Duration(milliseconds: 450),
                child: _buildChild("Chained"),
              ),
            ),

            /// You can combine different animations easily
            ///
            /// If you use a combination a lot,
            /// extract as a widget and just add that widget
            CnFade(
              duration: animationDuration,
              delayInMilliseconds: 100,
              child: CnSlide(
                begin: const Offset(0, 0.2),
                duration: animationDuration,
                delayInMilliseconds: 200,
                child: CnScale(
                  duration: const Duration(milliseconds: 3000),
                  begin: 0.7,
                  child: _buildChild("Combined"),
                ),
              ),
            ),
          ],
        ),
      ),

      /// To replay the animations after saving changes
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.replay_rounded),
        onPressed: () => RestartWidget.restartApp(context),
      ),
    );
  }

  Duration animationDuration = const Duration(milliseconds: 1000);

  Widget _buildChild(String title) {
    return Container(
      height: 100,
      width: 100,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
