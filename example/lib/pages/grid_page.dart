import 'package:cn_animations/cn_animations.dart';
import 'package:example/pages/detail_page.dart';
import 'package:flutter/material.dart';

/// Three columns: cells in the tapped row part sideways, other rows vertically.
class GridPage extends StatelessWidget {
  const GridPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grid')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: 30,
        itemBuilder:
            (context, index) => CnRouteAnimation(
              key: ValueKey('grid-item-$index'),
              child: Card(
                child: InkWell(
                  onTap: () => openDetail(context, index),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        heroThumb(index, size: 40),
                        const SizedBox(height: 6),
                        Text('Cell $index'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
