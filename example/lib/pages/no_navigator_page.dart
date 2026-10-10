import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';

/// Elements driven by a swipe instead of a route: each page of a [PageView]
/// gets a [CnRouteChoreography] whose `progress` and `coverProgress` are
/// derived from the controller, so the same [CnRouteAnimation] widgets work
/// with no Navigator involved.
class NoNavigatorPage extends StatefulWidget {
  const NoNavigatorPage({super.key});

  @override
  State<NoNavigatorPage> createState() => _NoNavigatorPageState();
}

class _NoNavigatorPageState extends State<NoNavigatorPage> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('No navigator')),
      body: PageView(
        controller: _controller,
        children: [
          for (int i = 0; i < 3; i++) _Pane(index: i, controller: _controller),
        ],
      ),
    );
  }
}

class _Pane extends StatefulWidget {
  const _Pane({required this.index, required this.controller});

  final int index;
  final PageController controller;

  @override
  State<_Pane> createState() => _PaneState();
}

class _PaneState extends State<_Pane> {
  late final _PageAnimation _enter = _PageAnimation(
    widget.controller,
    widget.index,
    entering: true,
  );
  late final _PageAnimation _cover = _PageAnimation(
    widget.controller,
    widget.index,
    entering: false,
  );

  @override
  Widget build(BuildContext context) {
    return CnRouteChoreography(
      progress: _enter,
      coverProgress: _cover,
      axis: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CnRouteAnimation(
              child: Text(
                'Pane ${widget.index + 1}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            for (int j = 0; j < 3; j++)
              CnRouteAnimation(
                child: Card(child: ListTile(title: Text('Element $j'))),
              ),
          ],
        ),
      ),
    );
  }
}

/// Maps a [PageController] position to a 0..1 progress for one page.
/// Entering: 0 a page away on the right, 1 when centered. Covering: 0 when
/// centered, 1 a page away on the left.
class _PageAnimation extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  _PageAnimation(this._controller, this._index, {required this.entering});

  final PageController _controller;
  final int _index;
  final bool entering;
  int _listeners = 0;

  @override
  double get value {
    final double page =
        _controller.hasClients
            ? (_controller.page ?? _controller.initialPage.toDouble())
            : _controller.initialPage.toDouble();
    final double raw = entering ? 1 - (_index - page) : page - _index;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  @override
  AnimationStatus get status {
    final double v = value;
    if (v >= 1) return AnimationStatus.completed;
    if (v <= 0) return AnimationStatus.dismissed;
    return AnimationStatus.forward;
  }

  void _tick() {
    notifyListeners();
    notifyStatusListeners(status);
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listeners++ == 0) _controller.addListener(_tick);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (--_listeners == 0) _controller.removeListener(_tick);
  }

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}
}
