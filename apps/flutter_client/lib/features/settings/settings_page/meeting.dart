part of '../settings_page.dart';

/// Meeting settings section.
class _MeetingSection extends StatelessWidget {
  const _MeetingSection({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroup(
          title: strings.settingsSectionMeeting,
          children: [
            _PreferenceRow(
              label: strings.meetingVideo,
              subtitle: strings.meetingVideoSubtitle,
              trailing: const Icon(Icons.videocam_rounded),
            ),
            const SizedBox(height: 16),
            _PreferenceRow(
              label: strings.meetingAudio,
              subtitle: strings.meetingAudioSubtitle,
              trailing: const Icon(Icons.mic_rounded),
            ),
            const SizedBox(height: 16),
            _PreferenceRow(
              label: strings.meetingQuality,
              subtitle: strings.meetingQualitySubtitle,
              trailing: DropdownButton<String>(
                value: 'auto',
                items: [
                  for (final q in VideoQuality.values)
                    DropdownMenuItem(
                      value: q.label,
                      child: Text(q.label),
                    ),
                ],
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: strings.meetingNetwork,
          children: [
            _PreferenceRow(
              label: strings.meetingNetworkAdaptive,
              subtitle: strings.meetingNetworkAdaptiveSubtitle,
              trailing: Switch(
                value: true,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

extension on AppStrings {
  String get meetingVideoSubtitle => isZh ? '开启或关闭摄像头' : 'Toggle camera';
  String get meetingAudioSubtitle => isZh ? '开启或关闭麦克风' : 'Toggle microphone';
  String get meetingQuality => isZh ? '视频画质' : 'Video Quality';
  String get meetingQualitySubtitle => isZh ? '手动选择分辨率和码率' : 'Manual resolution and bitrate';
  String get meetingNetwork => isZh ? '网络优化' : 'Network Optimization';
  String get meetingNetworkAdaptive => isZh ? '自适应画质' : 'Adaptive Quality';
  String get meetingNetworkAdaptiveSubtitle => isZh ? '网络差时自动降低画质' : 'Auto-reduce quality when network is poor';
}
