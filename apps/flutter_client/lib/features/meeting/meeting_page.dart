// Conference page that wires together [MeetingStore], [MeetingService],
// and the three sub-panels: video grid, controls, and chat.
//
// The page assumes a peer-to-peer signalling channel has already been
// established (or is being established) through the existing P2WLAN data
// path. In a room-backed deployment, each peer exchanges WebRTC SDP/candidates
// inside the existing room message stream; in ad-hoc mode they dial each
// other directly over the virtual IP.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/state/status_store.dart';
import '../../core/state/settings_store.dart';
import '../../app/app_strings.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/layout/app_breakpoints.dart';
import 'meeting_store.dart';
import 'meeting_service.dart';
import 'components/video_grid.dart';
import 'components/media_controls.dart';
import 'components/chat_panel.dart';
import 'components/quality_settings.dart';

class MeetingPage extends StatefulWidget {
  const MeetingPage({
    super.key,
    required this.settingsStore,
    required this.statusStore,
    this.roomId,
    this.targetPeers,
  });

  final SettingsStore settingsStore;
  final StatusStore statusStore;

  /// If present, scope the meeting to the given room's members.
  final String? roomId;

  /// Explicit list of peer node IDs to invite. Null means "all online peers".
  final List<String>? targetPeers;

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  late final MeetingStore _store;
  late final MeetingService _service;
  late final AppStrings _strings;

  // Control references
  final _chatFocusNode = FocusNode();
  final _chatController = TextEditingController();
  Timer? _healthPollTimer;

  @override
  void initState() {
    super.initState();
    _store = MeetingStore(
      settingsStore: widget.settingsStore,
      statusStore: widget.statusStore,
    );
    _service = MeetingService(
      store: _store,
      localNodeId: widget.statusStore.snapshot?.nodeId ?? '',
      localVirtualIp: widget.statusStore.snapshot?.virtualIp ?? '',
      onSignalling: _onSignalling,
      onMediaStateChanged: _onMediaStateChanged,
    );
    _strings = AppStrings.fromCode(widget.settingsStore.settings.languageCode);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _store.initDatabase();
      _startHealthPolling();
    });
  }

  @override
  void dispose() {
    _healthPollTimer?.cancel();
    _chatController.dispose();
    _chatFocusNode.dispose();
    _store.dispose();
    super.dispose();
  }

  void _startHealthPolling() {
    _healthPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollNetworkHealth();
    });
  }

  Future<void> _pollNetworkHealth() async {
    final snap = widget.statusStore.snapshot;
    if (snap == null) return;
    // Use the average RTT across all peers as a proxy for network health
    final rttValues = snap.peers
        .map((p) => p.latencyMs)
        .where((rtt) => rtt != null)
        .toList();
    final avgRtt = rttValues.isEmpty ? null : rttValues.reduce((a, b) => a + b) ~/ rttValues.length;
    _store.updateNetworkHealth(rttMs: avgRtt, packetLossPct: 0.0);
  }

  Future<void> _onSignalling(String type, Map<String, dynamic> payload) async {
    // In a real implementation, this would send the signal through the
    // existing P2P channel. For now, we just log it.
    debugPrint('Signalling: $type');
  }

  Future<void> _onMediaStateChanged() async {
    setState(() {});
  }

  Future<void> _joinMeeting() async {
    final peers = widget.targetPeers ??
        widget.statusStore.snapshot?.peers
            .map((p) => p.nodeId)
            .where((id) => id != widget.statusStore.snapshot?.nodeId)
            .toList() ??
        [];

    if (peers.isNotEmpty) {
      await _service.startCall(peers);
    }
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final msg = MeetingChatMessage(
      senderNodeId: _store.local.displayName.isEmpty
          ? _service.localNodeId
          : _store.local.displayName,
      senderName: _store.local.displayName.isEmpty
          ? _strings.thisDeviceTitle
          : _store.local.displayName,
      text: text,
      timestamp: DateTime.now(),
      isLocal: true,
    );

    _store.appendChatMessage(msg);
    _service.sendChatMessage(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: _strings.meetingTitle,
      subtitle: _strings.meetingSubtitle,
      showHeader: true,
      children: [
        AnimatedBuilder(
          animation: _store,
          builder: (context, _) => _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final layout = MediaQuery.sizeOf(context).width >= 900
        ? _MeetingLayout.desktop
        : _MeetingLayout.mobile;

    return Column(
      children: [
        // Video grid takes most of the space
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (layout == _MeetingLayout.desktop) {
                return Row(
                  children: [
                    Expanded(
                      child: VideoGrid(
                        peers: _store.peers,
                        localState: _store.local,
                        onToggleVideo: _service.toggleVideo,
                        onToggleAudio: _service.toggleAudio,
                        onToggleScreen: _toggleScreenShare,
                        onQualityChange: _service.setVideoQuality,
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: ChatPanel(
                        messages: _store.chatHistory,
                        localDisplayName: _store.local.displayName,
                        onSend: _sendChatMessage,
                        controller: _chatController,
                        focusNode: _chatFocusNode,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(
                      child: VideoGrid(
                        peers: _store.peers,
                        localState: _store.local,
                        onToggleVideo: _service.toggleVideo,
                        onToggleAudio: _service.toggleAudio,
                        onToggleScreen: _toggleScreenShare,
                        onQualityChange: _service.setVideoQuality,
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 200,
                      child: ChatPanel(
                        messages: _store.chatHistory,
                        localDisplayName: _store.local.displayName,
                        onSend: _sendChatMessage,
                        controller: _chatController,
                        focusNode: _chatFocusNode,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
        // Controls bar at the bottom
        MediaControlsBar(
          localState: _store.local,
          networkSeverity: _store.networkSeverity,
          onToggleVideo: _service.toggleVideo,
          onToggleAudio: _service.toggleAudio,
          onToggleScreen: _toggleScreenShare,
          onLeave: _leaveMeeting,
          onQualityChange: _service.setVideoQuality,
          onDowngradePrompt: _showDowngradePrompt,
        ),
      ],
    );
  }

  Future<void> _toggleScreenShare() async {
    if (_service.isScreenSharing) {
      await _service.stopScreenShare();
    } else {
      await _service.startScreenShare();
    }
  }

  Future<void> _leaveMeeting() async {
    await _service.leave();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showDowngradePrompt() {
    final strings = AppStrings.fromCode(
      widget.settingsStore.settings.languageCode,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.meetingNetworkDegradeTitle),
        content: Text(strings.meetingNetworkDegradeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _service.setVideoQuality(VideoQuality.vga360);
              _store.markDowngradeSuggested();
            },
            child: Text(strings.meetingDowngradeConfirm),
          ),
        ],
      ),
    );
  }
}

enum _MeetingLayout { desktop, mobile }
