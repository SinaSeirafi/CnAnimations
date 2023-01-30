import 'package:cn_animations/cn_animations.dart';

import 'package:cn_animations/route_aware_widget.dart';
import 'package:example/restart_widget.dart';
import 'package:flutter/material.dart';

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
              duration: const Duration(milliseconds: 1000),
              child: _buildChild(0, "Fade"),
            ),
            CnScale(
              duration: const Duration(milliseconds: 500),
              child: _buildChild(1, "Scale"),
            ),
            CnSlide(
              begin: const Offset(-0.1, 0),
              duration: const Duration(milliseconds: 500),
              child: _buildChild(2, "Slide"),
            ),

            /// You can chain animations together
            /// Use first animation duration as the second one's delay and so on
            ///
            /// make sure to cancel previous values
            ///
            /// This is probably very inefficient
            CnSlide(
              begin: const Offset(-0.3, 0),
              end: const Offset(0.03, 0),
              duration: const Duration(milliseconds: 300),
              child: CnSlide(
                begin: const Offset(0.03, 0),

                /// to cancel the other animation end value
                end: const Offset(-0.03, 0),
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 200),
                child: _buildChild(3, "Chained"),
              ),
            ),

            /// You can combine different animations easily
            ///
            /// If you use a combination a lot,
            /// extract as a widget and just add that widget
            CnFade(
              duration: const Duration(milliseconds: 700),
              // curve: Curves.,
              child: CnSlide(
                begin: const Offset(0, 0.2),
                delayInMilliseconds: 100,
                child: CnScale(
                  duration: const Duration(milliseconds: 500),
                  begin: 0.7,
                  child: _buildChild(4, "Combined"),
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

  Widget _buildChild(int index, String title) {
    /// Tap on any item on home screen to navigate forward
    navigate() async {
      await Future.delayed(Duration(seconds: 1));

      Navigator.push(
        context,

        /// Best way to use CnRouteAwareAnimation
        /// is to use FadeTransition in navigation
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const NewPage(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );
    }

    return CnRouteAwareAnimation(
      showPush: false, // to disable initial push animation

      /// By using index, different items move to different end points
      /// With the same animation duration
      /// Therefore they move more rapidly
      endNextPage: Offset(0.15 + index * 0.1, 0),
      child: _buildButton(title, onTap: navigate),
    );
  }
}

/// To show the effect of [CnRouteAwareAnimation] upon items of the first page
class NewPage extends StatelessWidget {
  const NewPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 1), () {
      Navigator.pop(context);
    });

    return Scaffold(
      appBar: AppBar(title: const Text("New Page")),
      body: Center(
        child: CnRouteAwareAnimation(
          beginSamePage: const Offset(0, -0.5),
          child: _buildButton(
            "Back",
            height: 50,
            width: 200,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}

Widget _buildButton(String text,
    {double height = 100, double width = 100, required Function onTap}) {
  return GestureDetector(
    onTap: () => onTap(),
    child: Container(
      height: height,
      width: width,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.teal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}
