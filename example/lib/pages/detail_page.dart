import 'package:cn_animations/cn_animations.dart';
import 'package:flutter/material.dart';

Color _colorFor(int index) =>
    Colors.primaries[index % Colors.primaries.length].shade400;

/// A coloured square that flies to the detail page. The Hero is the tapped
/// item, so it keeps the `stay` role while its siblings part.
Widget heroThumb(int index, {required double size}) {
  return Hero(
    tag: 'card-$index',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFor(index),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.white),
    ),
  );
}

void openDetail(BuildContext context, int index) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => DetailPage(index: index)),
  );
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detail $index')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(child: heroThumb(index, size: 160)),
          const SizedBox(height: 16),
          for (int p = 0; p < 3; p++)
            CnRouteAnimation(
              key: ValueKey('detail-paragraph-$p'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Paragraph $p. Elements on this page enter staggered, from '
                  'below, once the previous page has finished leaving.',
                ),
              ),
            ),
          CnRouteAnimation(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('A dialog'),
                      content: const Text(
                          'Dialogs do not cover the page: nothing exits.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Open dialog'),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.push(
                    context,
                    // Counter-demo: a transparent overlay does not cover this
                    // page, so its elements stay. Neither a theme-installed
                    // Material page (this one) nor a CnPageRoute lets a plain
                    // PageRouteBuilder drive its exits; only a page that is
                    // itself a plain PageRouteBuilder would.
                    PageRouteBuilder<void>(
                      opaque: false,
                      barrierColor: Colors.black54,
                      pageBuilder: (context, _, _) => Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close overlay'),
                            ),
                          ),
                        ),
                      ),
                      transitionsBuilder: (_, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  ),
                  child: const Text('Overlay (elements stay)'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    CnPageRoute<void>(
                      builder: (_) => DetailPage(index: index + 1),
                    ),
                  ),
                  child: const Text('Replace'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Pop to root'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
