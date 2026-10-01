// Media controls bar shown at the bottom of the meeting page.
// Contains toggle buttons for video, audio, screen share, quality selector,
// and a network-health indicator that triggers the downgrade prompt.

import 'package:flutter/material.dart';
import '../../app/app_strings.dart';
import '../meeting_store.dart';

class MediaControlsBar extends StatelessWidget {
  const MediaControlsBar({
    super.key,
    required this.localState,
    required this.networkSeverity,
    required this.onToggleVideo,
    required this.onToggleAudio,
    required this.onToggleScreen,
    required this.onLeave,
    required this.onQualityChange,
    required this.onDowngradePrompt,
  });

  final MeetingLocalState localState;
  final NetworkHealthSeverity networkSeverity;
  final Function(bool) onToggleVideo;
  final Function(bool) onToggleAudio;
  final Function() onToggleScreen;
  final Future<void> Function() onLeave;
  final Function(VideoQuality) onQualityChange;
  final VoidCallback onDowngradePrompt;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.fromCode(
      Localizations.of<AppStrings>(context, AppStrings)!.appLanguage.code,
    );
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Video toggle
          _ControlButton(
            icon: localState.videoEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: strings.meetingVideo,
            isActive: localState.videoEnabled,
            onPressed: () => onToggleVideo(!localState.videoEnabled),
          ),
          const SizedBox(width: 8),
          // Audio toggle
          _ControlButton(
            icon: localState.audioEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            label: strings.meetingAudio,
            isActive: localState.audioEnabled,
            onPressed: () => onToggleAudio(!localState.audioEnabled),
          ),
          const SizedBox(width: 8),
          // Screen share
          _ControlButton(
            icon: localState.screenEnabled
                ? Icons.screen_share_rounded
                : Icons.desktop_windows_rounded,
            label: strings.meetingScreenShare,
            isActive: localState.screenEnabled,
            onPressed: onToggleScreen,
          ),
          const SizedBox(width: 8),
          // Quality selector
          _QualityChip(
            current: localState.quality,
            onSelect: onQualityChange,
          ),
          const Spacer(),
          // Network health indicator
          if (networkSeverity != NetworkHealthSeverity.good)
            _NetworkHealthBadge(
              severity: networkSeverity,
              strings: strings,
              onTap: onDowngradePrompt,
            ),
          if (networkSeverity != NetworkHealthSeverity.good)
            const SizedBox(width: 8),
          // Leave button
          _ControlButton(
            icon: Icons.call_end_rounded,
            label: strings.meetingLeave,
            isActive: false,
            isDestructive: true,
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive
            ? theme.colorScheme.errorContainer
            : isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: isDestructive
            ? theme.colorScheme.onErrorContainer
            : isActive
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _QualityChip extends StatefulWidget {
  const _QualityChip({
    required this.current,
    required this.onSelect,
  });

  final VideoQuality current;
  final Function(VideoQuality) onSelect;

  @override
  State<_QualityChip> createState() => _QualityChipState();
}

class _QualityChipState extends State<_QualityChip> {
  bool _showMenu = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<VideoQuality>(
      initialValue: widget.current,
      onSelected: widget.onSelect,
      itemBuilder: (_) => VideoQuality.values.map((q) {
        return PopupMenuItem(
          value: q,
          child: Row(
            children: [
              if (q == widget.current)
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              const SizedBox(width: 8),
              Text(q.label),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 16),
            const SizedBox(width: 4),
            Text(
              widget.current.label,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkHealthBadge extends StatelessWidget {
  const _NetworkHealthBadge({
    required this.severity,
    required this.strings,
    required this.onTap,
  });

  final NetworkHealthSeverity severity;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: severity == NetworkHealthSeverity.critical
              ? colorScheme.errorContainer
              : colorScheme.warningContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              severity == NetworkHealthSeverity.critical
                  ? Icons.warning_rounded
                  : Icons.info_rounded,
              size: 16,
              color: severity == NetworkHealthSeverity.critical
                  ? colorScheme.onErrorContainer
                  : colorScheme.onWarningContainer,
            ),
            const SizedBox(width: 4),
            Text(
              severity == NetworkHealthSeverity.critical
                  ? strings.meetingNetworkCritical
                  : strings.meetingNetworkWarning,
              style: TextStyle(
                fontSize: 12,
                color: severity == NetworkHealthSeverity.critical
                    ? colorScheme.onErrorContainer
                    : colorScheme.onWarningContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
