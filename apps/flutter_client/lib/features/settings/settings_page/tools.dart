part of '../settings_page.dart';

/// Network tools settings section.
class _ToolsSection extends StatelessWidget {
  const _ToolsSection({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroup(
          title: strings.toolsTitle,
          children: [
            _PreferenceRow(
              label: strings.toolsHttpServer,
              subtitle: strings.toolsHttpServerSubtitle,
              trailing: Switch(
                value: false,
                onChanged: (_) {},
              ),
            ),
            const SizedBox(height: 16),
            _PreferenceRow(
              label: strings.toolsFileTransfer,
              subtitle: strings.toolsFileTransferSubtitle,
              trailing: const Icon(Icons.file_download_rounded),
            ),
            const SizedBox(height: 16),
            _PreferenceRow(
              label: strings.toolsSpeedTest,
              subtitle: strings.toolsSpeedTestSubtitle,
              trailing: const Icon(Icons.speed_rounded),
            ),
          ],
        ),
        _SettingsGroup(
          title: strings.toolsHttpConfig,
          children: [
            _PreferenceRow(
              label: strings.toolsHttpPort,
              subtitle: strings.toolsHttpPortSubtitle,
              trailing: const Text('8080'),
            ),
            const SizedBox(height: 16),
            _PreferenceRow(
              label: strings.toolsHttpSharePath,
              subtitle: strings.toolsHttpSharePathSubtitle,
              trailing: const Text('/tmp/p2wlan-share'),
            ),
          ],
        ),
      ],
    );
  }
}

extension on AppStrings {
  String get toolsHttpServerSubtitle => isZh ? '开启后其他设备可通过浏览器访问' : 'Others can access via browser';
  String get toolsFileTransferSubtitle => isZh ? '点对点文件直传' : 'Peer-to-peer file transfer';
  String get toolsSpeedTestSubtitle => isZh ? '测试与对端的 P2P 带宽' : 'Test P2P bandwidth to peers';
  String get toolsHttpConfig => isZh ? 'HTTP 服务配置' : 'HTTP Server Config';
  String get toolsHttpPortSubtitle => isZh ? '监听端口' : 'Listen port';
  String get toolsHttpSharePathSubtitle => isZh ? '共享目录路径' : 'Share directory path';
}
