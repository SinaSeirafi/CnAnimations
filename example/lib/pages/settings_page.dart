import 'package:cn_animations/cn_animations.dart';
import 'package:example/settings.dart';
import 'package:flutter/material.dart';

/// Every switch applies app-wide, immediately.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsModel s = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: const Text('Respect reduced motion'),
            subtitle: const Text('Follows the OS accessibility setting'),
            value: s.respectReducedMotion,
            onChanged: (v) => s.respectReducedMotion = v,
          ),
          SwitchListTile(
            title: const Text('Reduced motion: none'),
            subtitle: const Text('Off = fade only, on = no motion at all'),
            value: s.reducedMotionMode == CnReducedMotionMode.none,
            onChanged:
                (v) =>
                    s.reducedMotionMode =
                        v
                            ? CnReducedMotionMode.none
                            : CnReducedMotionMode.fadeOnly,
          ),
          SwitchListTile(
            title: const Text('Scroll reveal'),
            subtitle: const Text('Items built while scrolling fade in'),
            value: s.scrollReveal,
            onChanged: (v) => s.scrollReveal = v,
          ),
          _choice<CnSubjectDetection>(
            title: 'Subject detection',
            values: CnSubjectDetection.values,
            selected: s.subjectDetection,
            onSelected: (v) => s.subjectDetection = v,
          ),
          _choice<CnSubjectBehavior>(
            title: 'Subject behavior',
            values: CnSubjectBehavior.values,
            selected: s.subjectBehavior,
            onSelected: (v) => s.subjectBehavior = v,
          ),
          SwitchListTile(
            title: const Text('Cn fade-through route'),
            subtitle: const Text(
              'Off = platform default: covered pages are hidden under '
              'Zoom/Cupertino transitions, so their exits are invisible',
            ),
            value: s.useFadeThrough,
            onChanged: (v) => s.useFadeThrough = v,
          ),
          SwitchListTile(
            title: const Text('Slow motion (x4)'),
            subtitle: const Text('Sets timeDilation, for inspection'),
            value: s.slowMotion,
            onChanged: (v) => s.slowMotion = v,
          ),
        ],
      ),
    );
  }

  Widget _choice<T extends Enum>({
    required String title,
    required List<T> values,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SegmentedButton<T>(
          segments: [
            for (final T v in values)
              ButtonSegment<T>(value: v, label: Text(v.name)),
          ],
          selected: {selected},
          onSelectionChanged: (set) => onSelected(set.first),
        ),
      ),
    );
  }
}
