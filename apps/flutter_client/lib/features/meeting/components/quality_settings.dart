// Placeholder for quality settings dialog.
// In the current implementation, quality is selected via the chip in [MediaControlsBar].
// This widget is kept for potential future expansion.

import 'package:flutter/material.dart';
import '../meeting_store.dart';

class QualitySettingsDialog extends StatelessWidget {
  const QualitySettingsDialog({
    super.key,
    required this.currentQuality,
    required this.onSelect,
  });

  final VideoQuality currentQuality;
  final Function(VideoQuality) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(theme.textTheme.titleMedium?.text ?? '画质设置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: VideoQuality.values.map((quality) {
          final isSelected = quality == currentQuality;
          return RadioListTile<VideoQuality>(
            title: Text(quality.label),
            value: quality,
            groupValue: currentQuality,
            onChanged: (v) {
              if (v != null) onSelect(v);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
