// Meeting data models for the p2wlan conferencing feature.
//
// These types flow between the Flutter UI, the local DiagnosticsApi, and
// (optionally) the Go control plane when a room-backed signalling path is
// used. The shapes deliberately avoid leaking WireGuard/crypto specifics so
// future alternatives (e.g. a dedicated SFU) can swap in without touching
// the UI layer.

part of 'meeting_store.dart';

// ---------------------------------------------------------------------------
// Conference lifecycle
// ---------------------------------------------------------------------------

/// Quality preset that controls the webcam encoder resolution and target
/// bitrate. The enum values map directly to a pair of
/// [resolutionPixels] / [maxBitrateBps] used by
/// [RTCRtpSender.setParameters].
enum VideoQuality {
  auto(label: '自动', resolutionPixels: 0, maxBitrateBps: 0),
  hd720(label: '720p', resolutionPixels: 720, maxBitrateBps: 1500000),
  vga480(label: '480p', resolutionPixels: 480, maxBitrateBps: 800000),
  vga360(label: '360p', resolutionPixels: 360, maxBitrateBps: 300000);

  const VideoQuality({
    required this.label,
    required this.resolutionPixels,
    required this.maxBitrateBps,
  });

  final String label;

  /// Target scan-line height in pixels. Zero means "let the OS pick".
  final int resolutionPixels;

  /// Maximum average video bitrate in bits per second. Zero means unlimited.
  final int maxBitrateBps;

  bool get isAuto => resolutionPixels == 0 && maxBitrateBps == 0;
}

/// Local participant state – owns camera/mic permissions plus the sender
/// tracks we can mutate at runtime.
class MeetingLocalState {
  const MeetingLocalState({
    this.displayName = '',
    this.videoEnabled = false,
    this.audioEnabled = true,
    this.screenEnabled = false,
    this.quality = VideoQuality.auto,
    this.localVideoStream,
    this.localAudioStream,
    this.screenStream,
  });

  final String displayName;
  bool videoEnabled;
  bool audioEnabled;
  bool screenEnabled;
  VideoQuality quality;

  /// Raw media streams obtained from the device cameras/screenshare sources.
  final MediaStream? localVideoStream;
  final MediaStream? localAudioStream;
  final MediaStream? screenStream;
}

/// A remote peer in the conference. One entry per participant, including
/// the local user once the call is joined.
class MeetingPeer {
  const MeetingPeer({
    required this.nodeId,
    required this.virtualIp,
    required this.displayName,
    this.mediaStream,
    this.audioEnabled = true,
    this.videoEnabled = true,
    this.isScreenSharing = false,
    this.isLocal = false,
    this.latencyMs,
    this.bytesReceived = 0,
    this.bytesSent = 0,
  });

  final String nodeId;
  final String virtualIp;
  final String displayName;
  final MediaStream? mediaStream;
  bool audioEnabled;
  bool videoEnabled;
  bool isScreenSharing;
  final bool isLocal;
  final int? latencyMs;
  int bytesReceived;
  int bytesSent;

  MeetingPeer copyWith({
    MediaStream? mediaStream,
    bool? audioEnabled,
    bool? videoEnabled,
    bool? isScreenSharing,
    int? latencyMs,
  }) =>
      MeetingPeer(
        nodeId: nodeId,
        virtualIp: virtualIp,
        displayName: displayName,
        mediaStream: mediaStream ?? this.mediaStream,
        audioEnabled: audioEnabled ?? this.audioEnabled,
        videoEnabled: videoEnabled ?? this.videoEnabled,
        isScreenSharing: isScreenSharing ?? this.isScreenSharing,
        isLocal: isLocal,
        latencyMs: latencyMs ?? this.latencyMs,
      );
}

// ---------------------------------------------------------------------------
// Text chat
// ---------------------------------------------------------------------------

/// A single chat message flowing through the conference text channel.
class MeetingChatMessage {
  const MeetingChatMessage({
    required this.senderNodeId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isLocal = false,
  });

  final String senderNodeId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isLocal;
}

// ---------------------------------------------------------------------------
// Network health & auto-downgrade
// ---------------------------------------------------------------------------

/// Thresholds that drive the "suggest downgrade" prompt. Tuned to the
/// existing P2WLAN path-observability cadence (25 s probe interval).
class NetworkHealthThresholds {
  const NetworkHealthThresholds({
    this.rttWarningMs = 150,
    this.rttCriticalMs = 300,
    this.packetLossWarningPct = 2.0,
    this.packetLossCriticalPct = 5.0,
    this.cooldownSeconds = 30,
  });

  /// Above this RTT we show a warning; past [rttCriticalMs] we suggest
  /// dropping one quality step automatically after the cooldown elapses.
  final int rttWarningMs;
  final int rttCriticalMs;
  final double packetLossWarningPct;
  final double packetLossCriticalPct;
  final int cooldownSeconds;

  NetworkHealthSeverity assess({
    required int? rttMs,
    required double packetLossPct,
  }) {
    final rtt = rttMs ?? 0;
    if (rtt >= rttCriticalMs || packetLossPct >= packetLossCriticalPct) {
      return NetworkHealthSeverity.critical;
    }
    if (rtt >= rttWarningMs || packetLossPct >= packetLossWarningPct) {
      return NetworkHealthSeverity.warning;
    }
    return NetworkHealthSeverity.good;
  }
}

enum NetworkHealthSeverity { good, warning, critical }

// ---------------------------------------------------------------------------
// Internal signalling payloads (WebRTC / room relay)
// ---------------------------------------------------------------------------

/// One end-to-end message carried over the existing P2WLAN node-to-node
/// channel. Uses the same serialisation style as the control-plane
/// [ControlMessage] so it can ride the same secured overlay.
class MeetingSignallingPayload {
  MeetingSignallingPayload({
    required this.type,
    this.sdp,
    this.candidate,
    this.payload,
    this.metadata,
  });

  final String type;
  final String? sdp;
  final dynamic candidate;
  final Map<String, dynamic>? payload;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (sdp != null) 'sdp': sdp,
    if (candidate != null) 'candidate': candidate,
    if (payload != null) 'payload': payload,
    if (metadata != null) 'metadata': metadata,
  };

  factory MeetingSignallingPayload.fromJson(Map<String, dynamic> json) =>
      MeetingSignallingPayload(
        type: json['type'] as String? ?? '',
        sdp: json['sdp'] as String?,
        candidate: json['candidate'],
        payload: json['payload'] as Map<String, dynamic>?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// Meeting-specific signal types exchanged between peers.
abstract class MeetingSignalType {
  static const String offer = 'meeting_offer';
  static const String answer = 'meeting_answer';
  static const String iceCandidate = 'meeting_ice_candidate';
  static const String participantJoin = 'meeting_participant_join';
  static const String participantLeave = 'meeting_participant_leave';
  static const String mediaStateChange = 'meeting_media_state_change';
  static const String chatMessage = 'meeting_chat_message';
  static const String screenShareRequest = 'meeting_screen_share_request';
  static const String screenShareGrant = 'meeting_screen_share_grant';
  static const String screenShareStop = 'meeting_screen_share_stop';
  static const String qualityChange = 'meeting_quality_change';
  static const String networkHealth = 'meeting_network_health';
}
