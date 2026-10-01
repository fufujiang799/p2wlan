// Device list panel showing online peers with their status.

import 'package:flutter/material.dart';
import '../../core/models/diagnostics_models.dart';
import '../../app/app_strings.dart';

class DeviceList extends StatelessWidget {
  const DeviceList({
    super.key,
    required this.peers,
    required this.strings,
    this.onSpeedTest,
    this.onFileTransfer,
    this.onHttpShare,
  });

  final List<PeerSnapshot> peers;
  final AppStrings strings;
  final Function(PeerSnapshot)? onSpeedTest;
  final Function(PeerSnapshot)? onFileTransfer;
  final Function(PeerSnapshot)? onHttpShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (peers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.devices_other_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                strings.toolsNoDevices,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${strings.toolsOnlineDevices} · ${peers.length}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: peers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final peer = peers[index];
              return _DeviceTile(
                peer: peer,
                strings: strings,
                onSpeedTest: onSpeedTest,
                onFileTransfer: onFileTransfer,
                onHttpShare: onHttpShare,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.peer,
    required this.strings,
    this.onSpeedTest,
    this.onFileTransfer,
    this.onHttpShare,
  });

  final PeerSnapshot peer;
  final AppStrings strings;
  final Function(PeerSnapshot)? onSpeedTest;
  final Function(PeerSnapshot)? onFileTransfer;
  final Function(PeerSnapshot)? onHttpShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: peer.online
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                peer.displayName.isNotEmpty
                    ? peer.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: peer.online
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        peer.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (peer.online)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  peer.virtualIp,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                if (peer.latencyMs != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${peer.latencyMs} ms',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSpeedTest != null && peer.online)
                IconButton(
                  icon: const Icon(Icons.speed_rounded, size: 20),
                  onPressed: () => onSpeedTest!(peer),
                  tooltip: strings.toolsSpeedTest,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                  ),
                ),
              if (onFileTransfer != null && peer.online)
                IconButton(
                  icon: const Icon(Icons.file_download_rounded, size: 20),
                  onPressed: () => onFileTransfer!(peer),
                  tooltip: strings.toolsFileTransfer,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.tertiaryContainer,
                    foregroundColor: colorScheme.onTertiaryContainer,
                  ),
                ),
              if (onHttpShare != null && peer.online)
                IconButton(
                  icon: const Icon(Icons.http_rounded, size: 20),
                  onPressed: () => onHttpShare!(peer),
                  tooltip: strings.toolsHttpShare,
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
