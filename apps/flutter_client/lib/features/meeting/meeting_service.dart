// Meeting service that owns the WebRTC lifecycle.
//
// The service is deliberately decoupled from the UI and the store: it only
// talks to [MeetingStore] through mutations and receives user intents via
// callback parameters. The actual P2P transport is assumed to be wired in
// by the caller (see [MeetingPage] for the concrete wiring).

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../meeting_store.dart';
import 'package:http/http.dart' as http;

class MeetingService {
  MeetingService({
    required this.store,
    required this.localNodeId,
    required this.localVirtualIp,
    required this.onSignalling,
    required this.onMediaStateChanged,
  });

  final MeetingStore store;
  final String localNodeId;
  final String localVirtualIp;

  /// Called whenever a local state change should be broadcast to peers.
  final Future<void> Function(String type, Map<String, dynamic> payload)
      onSignalling;

  /// Called when local media (camera/mic/screen) state changes.
  final Future<void> Function() onMediaStateChanged;

  // ---- WebRTC state ----
  RTCPeerConnection? _pc;
  MediaStream? _localVideoStream;
  MediaStream? _localAudioStream;
  MediaStream? _screenStream;
  bool _isInitiator = false;

  // ---- Call state ----
  bool get isJoined => _pc != null;
  bool get hasLocalVideo => _localVideoStream != null;
  bool get hasLocalAudio => _localAudioStream != null;
  bool get isScreenSharing => _screenStream != null;

  // ----ICEServer config (STUN/TURN) ----
  // Uses the existing p2wlan relay server list from settings.
  List<Map<String, dynamic>> get _iceServers => [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  /// Start a new conference call with the given peers.
  Future<void> startCall(List<String> peerNodeIds) async {
    _isInitiator = true;
    await _createPeerConnection();

    // Add local tracks
    await _addLocalTracks();

    // Create and send offer
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await onSignalling(MeetingSignalType.offer, {
      'node_id': localNodeId,
      'virtual_ip': localVirtualIp,
      'sdp': offer.sdp,
      'type': offer.type,
      'peers': peerNodeIds,
    });
  }

  /// Handle an incoming offer from a peer.
  Future<void> handleOffer(Map<String, dynamic> data) async {
    _isInitiator = false;
    await _createPeerConnection();
    await _addLocalTracks();

    await _pc!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], data['type']),
    );

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    await onSignalling(MeetingSignalType.answer, {
      'node_id': localNodeId,
      'virtual_ip': localVirtualIp,
      'sdp': answer.sdp,
      'type': answer.type,
      'from': data['node_id'],
    });
  }

  /// Handle an incoming answer.
  Future<void> handleAnswer(Map<String, dynamic> data) async {
    await _pc!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], data['type']),
    );
  }

  /// Handle incoming ICE candidates.
  Future<void> handleIceCandidate(Map<String, dynamic> data) async {
    await _pc!.addCandidate(
      RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      ),
    );
  }

  /// Toggle local video.
  Future<void> toggleVideo(bool enabled) async {
    if (_localVideoStream == null) {
      if (enabled) {
        await _startCamera();
      }
    } else {
      _localVideoStream!.getVideoTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
    store.setLocalVideoEnabled(enabled);
    await onMediaStateChanged();
    await onSignalling(MeetingSignalType.mediaStateChange, {
      'node_id': localNodeId,
      'type': 'video',
      'enabled': enabled,
    });
  }

  /// Toggle local audio.
  Future<void> toggleAudio(bool enabled) async {
    if (_localAudioStream == null) {
      if (enabled) {
        await _startMicrophone();
      }
    } else {
      _localAudioStream!.getAudioTracks().forEach((track) {
        track.enabled = enabled;
      });
    }
    store.setLocalAudioEnabled(enabled);
    await onMediaStateChanged();
    await onSignalling(MeetingSignalType.mediaStateChange, {
      'node_id': localNodeId,
      'type': 'audio',
      'enabled': enabled,
    });
  }

  /// Start screen sharing.
  Future<void> startScreenShare() async {
    try {
      _screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });

      // Add screen track to peer connection
      _screenStream!.getVideoTracks().forEach((track) {
        _pc!.addTrack(track, _screenStream!);
      });

      store.setLocalScreenEnabled(true);
      await onSignalling(MeetingSignalType.screenShareRequest, {
        'node_id': localNodeId,
        'virtual_ip': localVirtualIp,
      });
    } catch (e) {
      print('Screen share failed: $e');
    }
  }

  /// Stop screen sharing.
  Future<void> stopScreenShare() async {
    if (_screenStream != null) {
      _screenStream!.getTracks().forEach((track) => track.stop());
      _screenStream = null;
    }
    store.setLocalScreenEnabled(false);
    await onSignalling(MeetingSignalType.screenShareStop, {
      'node_id': localNodeId,
    });
  }

  /// Change video quality.
  Future<void> setVideoQuality(VideoQuality quality) async {
    store.setLocalQuality(quality);
    await _applyQualitySettings(quality);
    await onSignalling(MeetingSignalType.qualityChange, {
      'node_id': localNodeId,
      'quality': quality.label,
      'resolution': quality.resolutionPixels,
      'bitrate': quality.maxBitrateBps,
    });
  }

  /// Send a chat message to all peers.
  Future<void> sendChatMessage(String text) async {
    await onSignalling(MeetingSignalType.chatMessage, {
      'node_id': localNodeId,
      'virtual_ip': localVirtualIp,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Leave the conference.
  Future<void> leave() async {
    await _pc?.close();
    _pc = null;
    _localVideoStream = null;
    _localAudioStream = null;
    _screenStream = null;
    _isInitiator = false;

    await onSignalling(MeetingSignalType.participantLeave, {
      'node_id': localNodeId,
      'virtual_ip': localVirtualIp,
    });

    store.setLocalVideoEnabled(false);
    store.setLocalAudioEnabled(false);
    store.setLocalScreenEnabled(false);
  }

  // ---- Private helpers ----

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection({
      'iceServers': _iceServers,
    });

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      onSignalling(MeetingSignalType.iceCandidate, {
        'node_id': localNodeId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      // Handle incoming remote streams
      final remoteStream = event.streams[0];
      final sender = event.sender;
      // Identify the peer by tracking which track belongs to which peer
      // (in a real implementation, you'd maintain a map of peerId -> stream)
    };

    _pc!.onConnectionStateChange = (String state) {
      switch (state) {
        case 'connected':
        case 'connecting':
          break;
        case 'disconnected':
        case 'failed':
        case 'closed':
          _pc = null;
          break;
      }
    };
  }

  Future<void> _addLocalTracks() async {
    // Video track
    if (store.local.videoEnabled) {
      await _startCamera();
    }
    // Audio track
    if (store.local.audioEnabled) {
      await _startMicrophone();
    }
  }

  Future<void> _startCamera() async {
    try {
      _localVideoStream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'width': 1280,
          'height': 720,
          'frameRate': 30,
        },
        'audio': false,
      });

      // Add video track to peer connection
      _localVideoStream!.getVideoTracks().forEach((track) {
        _pc!.addTrack(track, _localVideoStream!);
      });
    } catch (e) {
      print('Failed to start camera: $e');
    }
  }

  Future<void> _startMicrophone() async {
    try {
      _localAudioStream = await navigator.mediaDevices.getUserMedia({
        'video': false,
        'audio': true,
      });

      // Add audio track to peer connection
      _localAudioStream!.getAudioTracks().forEach((track) {
        _pc!.addTrack(track, _localAudioStream!);
      });
    } catch (e) {
      print('Failed to start microphone: $e');
    }
  }

  Future<void> _applyQualitySettings(VideoQuality quality) async {
    if (_localVideoStream == null) return;

    final sender = _pc!.getSenders()
        .firstWhere((s) => s.track?.kind == 'video', orElse: () => null);
    if (sender == null) return;

    final params = sender.parameters;
    if (quality.resolutionPixels > 0) {
      params.encodings = [
        RTCRtpEncoding(
          rid: 'f',
          maxBitrate: quality.maxBitrateBps,
          scaleResolutionDownBy: quality.isAuto ? 1.0 : _scaleFactor(quality),
        )
      ];
    } else {
      params.encodings = [
        RTCRtpEncoding(maxBitrate: quality.maxBitrateBps)
      ];
    }
    await sender.setParameters(params);
  }

  double _scaleFactor(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.hd720:
        return 1.0;
      case VideoQuality.vga480:
        return 1.5;
      case VideoQuality.vga360:
        return 2.0;
      default:
        return 1.0;
    }
  }
}
