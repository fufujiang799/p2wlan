// Network tools page for the p2wlan toolbox.
// Shows online devices, speed test entry points, and quick actions.

import 'package:flutter/material.dart';
import '../../core/state/status_store.dart';
import '../../core/state/settings_store.dart';
import '../../app/app_strings.dart';
import '../../shared/widgets/page_scaffold.dart';
import 'components/device_list.dart';
import 'components/file_transfer.dart';
import 'components/http_server.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({
    super.key,
    required this.settingsStore,
    required this.statusStore,
  });

  final SettingsStore settingsStore;
  final StatusStore statusStore;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  late final AppStrings _strings;

  @override
  void initState() {
    super.initState();
    _strings = AppStrings.fromCode(widget.settingsStore.settings.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: _strings.toolsTitle,
      subtitle: _strings.toolsSubtitle,
      showHeader: true,
      children: [
        AnimatedBuilder(
          animation: widget.statusStore,
          builder: (context, _) => _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final snapshot = widget.statusStore.snapshot;
    final peers = snapshot?.peers ?? const [];
    final onlinePeers = peers.where((p) => p.online).toList();

    return Column(
      children: [
        // Quick actions
        _QuickActions(
          strings: _strings,
          onlineCount: onlinePeers.length,
          localIp: snapshot?.virtualIp ?? '',
        ),
        const SizedBox(height: 16),
        // Device list
        Expanded(
          child: DeviceList(
            peers: onlinePeers,
            strings: _strings,
            onSpeedTest: null, // Would be wired to existing speed test
            onFileTransfer: null,
            onHttpShare: null,
          ),
        ),
        const SizedBox(height: 16),
        // HTTP file server toggle
        HttpServerPanel(
          strings: _strings,
          localIp: snapshot?.virtualIp ?? '',
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.strings,
    required this.onlineCount,
    required this.localIp,
  });

  final AppStrings strings;
  final int onlineCount;
  final String localIp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.toolsQuickActions,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionChip(
                icon: Icons.devices_rounded,
                label: '$onlineCount ${strings.toolsOnlineDevices}',
                onTap: () {},
              ),
              _QuickActionChip(
                icon: Icons.speed_rounded,
                label: strings.toolsSpeedTest,
                onTap: () {},
              ),
              _QuickActionChip(
                icon: Icons.file_download_rounded,
                label: strings.toolsFileTransfer,
                onTap: () {},
              ),
              _QuickActionChip(
                icon: Icons.http_rounded,
                label: strings.toolsHttpServer,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
