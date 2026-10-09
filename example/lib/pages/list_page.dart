import 'package:cn_animations/cn_animations.dart';
import 'package:example/pages/detail_page.dart';
import 'package:flutter/material.dart';

/// 40 cards. Tap one: the others part away from it while the detail page
/// arrives. Swipe back (or use predictive back) to scrub the siblings.
class ListPage extends StatelessWidget {
  const ListPage({super.key});

  static const int itemCount = 40;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('List')),
      body: ListView.builder(
        itemCount: itemCount + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            // A header is never the subject: a tap on it never parts the list.
            return const CnRouteAnimation(
              subject: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tap a card, then swipe back.'),
              ),
            );
          }
          final int index = i - 1;
          return CnRouteAnimation(
            key: ValueKey('list-item-$index'),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: heroThumb(index, size: 40),
                title: Text('Item $index'),
                subtitle: const Text('Tap to open'),
                onTap: () => openDetail(context, index),
              ),
            ),
          );
        },
      ),
    );
  }
}
