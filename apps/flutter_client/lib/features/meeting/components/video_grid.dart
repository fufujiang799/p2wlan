// Video grid that displays all conference participants.
//
// Layout adapts to the number of peers:
//   1 peer  - single large tile
//   2-3 peels - 2x2 grid with one empty slot
//   4+ peels - responsive grid

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../meeting_store.dart';

class VideoGrid extends StatelessWidget {
  const VideoGrid({
    super.key,
    required this.peers,
    required this.localState,
    required this.onToggleVideo,
    required this.onToggleAudio,
    required this.onToggleScreen,
    required this.onQualityChange,
  });

  final List<MeetingPeer> peers;
  final MeetingLocalState localState;
  final Function(bool) onToggleVideo;
  final Function(bool) onToggleAudio;
  final Function() onToggleScreen;
  final Function(VideoQuality) onQualityChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Include local participant in the grid
    final allPeers = [
      MeetingPeer(
        nodeId: 'local',
        virtualIp: '',
        displayName: localState.displayName.isEmpty
            ? '本机'
            : localState.displayName,
        isLocal: true,
        audioEnabled: localState.audioEnabled,
        videoEnabled: localState.videoEnabled,
        isScreenSharing: localState.screenEnabled,
      ),
      ...peers.where((p) => p.isScreenSharing || p.videoEnabled),
    ];

    final gridSize = _gridSize(allPeers.length);
    final cells = <Widget>[];

    for (var i = 0; i < gridSize; i++) {
      if (i < allPeers.length) {
        cells.add(_PeerTile(peer: allPeers[i]));
      } else {
        cells.add(_EmptyTile(strings: _Strings.of(context)));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: gridSize == 1 ? 1 : gridSize == 2 ? 2 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: cells,
            ),
          ),
          const SizedBox(height: 16),
          // Quality selector row
          _QualitySelector(
            currentQuality: localState.quality,
            onSelect: onQualityChange,
          ),
        ],
      ),
    );
  }

  int _gridSize(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    return 3;
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer});

  final MeetingPeer peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Expanded(
            child: _VideoContent(peer: peer),
          ),
          _PeerInfoBar(peer: peer),
        ],
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.peer});

  final MeetingPeer peer;

  @override
  Widget build(BuildContext context) {
    if (peer.isScreenSharing) {
      return Stack(
        children: [
          Container(
            color: const Color(0xFF1a1a1a),
            child: const Center(
              child: Icon(Icons.monitor_rounded, size: 64, color: Colors.white54),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '屏幕共享',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }

    if (!peer.videoEnabled && !peer.isLocal) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              peer.displayName,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    // In a real implementation, this would display the MediaStream
    return Container(
      color: const Color(0xFF1a1a1a),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 64,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _PeerInfoBar extends StatelessWidget {
  const _PeerInfoBar({required this.peer});

  final MeetingPeer peer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              peer.displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (!peer.audioEnabled)
            const Icon(
              Icons mic_off_rounded,
              size: 16,
              color: Colors.red,
            ),
          if (peer.isLocal) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '我',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Center(
        child: Icon(
          Icons.add_rounded,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _QualitySelector extends StatelessWidget {
  const _QualitySelector({
    required this.currentQuality,
    required this.onSelect,
  });

  final VideoQuality currentQuality;
  final Function(VideoQuality) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: VideoQuality.values.map((quality) {
        final isSelected = quality == currentQuality;
        return FilledButton.tonal(
          onPressed: () => onSelect(quality),
          style: FilledButton.styleFrom(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            foregroundColor: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : null,
          ),
          child: Text(quality.label),
        );
      }).toList(),
    );
  }
}

extension _Strings on BuildContext {
  AppStrings get strings => AppStrings.fromCode(
    Localizations.of<AppStrings>(this, AppStrings)?.appLanguage.code ?? 'zh-Hans',
  );
}
