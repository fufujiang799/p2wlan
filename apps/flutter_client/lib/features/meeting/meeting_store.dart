// Conference state holder.
//
// Glues together the three sub-systems the meeting feature needs:
//   1. A local [MeetingLocalState] (camera/mic/screen quality).
//   2. A peer roster ([MeetingPeer] list) mirrored from the current
//      DiagnosticsSnapshot where possible, supplemented with live
//      WebRTC MediaStream objects.
//   3. A text-chat backlog persisted to SQLite on every append.
//
// Nothing in here opens or closes a WebRTC peer connection; that is left
// to [MeetingService] so the store remains UI-agnostic and testable.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as path;

import '../../core/models/diagnostics_models.dart';
import '../../core/state/settings_store.dart';
import '../../app/app_strings.dart';

part 'models.dart';

class MeetingStore extends ChangeNotifier {
  MeetingStore({
    required this.settingsStore,
    required this.statusStore,
  }) {
    statusStore.addListener(_onStatusChanged);
  }

  final SettingsStore settingsStore;
  final StatusStore statusStore;

  // ---- Local participant ----
  MeetingLocalState _local = const MeetingLocalState();
  MeetingLocalState get local => _local;

  // ---- Remote peers ----
  final Map<String, MeetingPeer> _peers = {};
  UnmodifiableListView<MeetingPeer> get peers =>
      UnmodifiableListView(_peers.values);

  // ---- Chat backlog ----
  final List<MeetingChatMessage> _chatHistory = [];
  UnmodifiableListView<MeetingChatMessage> get chatHistory =>
      UnmodifiableListView(_chatHistory);

  // ---- Network health ----
  var _networkSeverity = NetworkHealthSeverity.good;
  NetworkHealthSeverity get networkSeverity => _networkSeverity;
  final NetworkHealthThresholds healthThresholds =
      const NetworkHealthThresholds();
  DateTime? _lastDowngradeSuggestedAt;

  // ---- SQLite path for chat persistence ----
  String? _dbPath;

  Future<void> initDatabase() async {
    if (_dbPath != null) return;
    final dir = await getApplicationSupportDirectory();
    _dbPath = path.join(dir.path, 'p2wlan_meeting_chat.db');
    final db = await sqflite.openDatabase(
      _dbPath!,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_node_id TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            text TEXT NOT NULL,
            timestamp_ms INTEGER NOT NULL,
            is_local INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_ts ON messages(timestamp_ms)',
        );
      },
    );
    await _loadChatHistory(db);
  }

  Future<void> _loadChatHistory(sqflite.Database db) async {
    final rows = await db.query(
      'messages',
      orderBy: 'timestamp_ms ASC',
      limit: 500,
    );
    _chatHistory.clear();
    for (final row in rows) {
      _chatHistory.add(MeetingChatMessage(
        senderNodeId: row['sender_node_id'] as String,
        senderName: row['sender_name'] as String,
        text: row['text'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          row['timestamp_ms'] as int,
        ),
        isLocal: (row['is_local'] as int) == 1,
      ));
    }
    notifyListeners();
  }

  Future<void> appendChatMessage(MeetingChatMessage msg) async {
    if (_dbPath == null) return;
    final db = await sqflite.openDatabase(_dbPath!);
    await db.insert(
      'messages',
      {
        'sender_node_id': msg.senderNodeId,
        'sender_name': msg.senderName,
        'text': msg.text,
        'timestamp_ms': msg.timestamp.millisecondsSinceEpoch,
        'is_local': msg.isLocal ? 1 : 0,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
    _chatHistory.add(msg);
    notifyListeners();
  }

  // ---- Peer management ----
  void updatePeerFromSnapshot(PeerSnapshot snap) {
    final existing = _peers[snap.nodeId];
    if (existing == null) {
      _peers[snap.nodeId] = MeetingPeer(
        nodeId: snap.nodeId,
        virtualIp: snap.virtualIp,
        displayName: snap.displayName,
        latencyMs: snap.latencyMs,
      );
    } else if (existing.latencyMs != snap.latencyMs) {
      _peers[snap.nodeId] = existing.copyWith(latencyMs: snap.latencyMs);
    }
    notifyListeners();
  }

  void setPeerMediaStream(String nodeId, MediaStream? stream) {
    final peer = _peers[nodeId];
    if (peer == null) return;
    _peers[nodeId] = peer.copyWith(mediaStream: stream);
    notifyListeners();
  }

  void setPeerScreenSharing(String nodeId, bool sharing) {
    final peer = _peers[nodeId];
    if (peer == null) return;
    _peers[nodeId] = peer.copyWith(isScreenSharing: sharing);
    notifyListeners();
  }

  void setPeerAudioEnabled(String nodeId, bool enabled) {
    final peer = _peers[nodeId];
    if (peer == null) return;
    _peers[nodeId] = peer.copyWith(audioEnabled: enabled);
    notifyListeners();
  }

  void setPeerVideoEnabled(String nodeId, bool enabled) {
    final peer = _peers[nodeId];
    if (peer == null) return;
    _peers[nodeId] = peer.copyWith(videoEnabled: enabled);
    notifyListeners();
  }

  void removePeer(String nodeId) {
    _peers.remove(nodeId);
    notifyListeners();
  }

  // ---- Local media controls ----
  void setLocalVideoEnabled(bool enabled) {
    _local = MeetingLocalState(
      displayName: _local.displayName,
      videoEnabled: enabled,
      audioEnabled: _local.audioEnabled,
      screenEnabled: _local.screenEnabled,
      quality: _local.quality,
      localVideoStream: _local.localVideoStream,
      localAudioStream: _local.localAudioStream,
      screenStream: _local.screenStream,
    );
    notifyListeners();
  }

  void setLocalAudioEnabled(bool enabled) {
    _local = MeetingLocalState(
      displayName: _local.displayName,
      videoEnabled: _local.videoEnabled,
      audioEnabled: enabled,
      screenEnabled: _local.screenEnabled,
      quality: _local.quality,
      localVideoStream: _local.localVideoStream,
      localAudioStream: _local.localAudioStream,
      screenStream: _local.screenStream,
    );
    notifyListeners();
  }

  void setLocalScreenEnabled(bool enabled) {
    _local = MeetingLocalState(
      displayName: _local.displayName,
      videoEnabled: _local.videoEnabled,
      audioEnabled: _local.audioEnabled,
      screenEnabled: enabled,
      quality: _local.quality,
      localVideoStream: _local.localVideoStream,
      localAudioStream: _local.localAudioStream,
      screenStream: enabled ? _local.screenStream : null,
    );
    notifyListeners();
  }

  void setLocalQuality(VideoQuality quality) {
    _local = MeetingLocalState(
      displayName: _local.displayName,
      videoEnabled: _local.videoEnabled,
      audioEnabled: _local.audioEnabled,
      screenEnabled: _local.screenEnabled,
      quality: quality,
      localVideoStream: _local.localVideoStream,
      localAudioStream: _local.localAudioStream,
      screenStream: _local.screenStream,
    );
    notifyListeners();
  }

  void setLocalDisplayName(String name) {
    _local = MeetingLocalState(
      displayName: name,
      videoEnabled: _local.videoEnabled,
      audioEnabled: _local.audioEnabled,
      screenEnabled: _local.screenEnabled,
      quality: _local.quality,
      localVideoStream: _local.localVideoStream,
      localAudioStream: _local.localAudioStream,
      screenStream: _local.screenStream,
    );
    notifyListeners();
  }

  // ---- Network health ----
  void updateNetworkHealth({
    required int? rttMs,
    required double packetLossPct,
  }) {
    final severity = healthThresholds.assess(
      rttMs: rttMs,
      packetLossPct: packetLossPct,
    );
    if (severity != _networkSeverity) {
      _networkSeverity = severity;
      notifyListeners();
    }
  }

  /// Returns true if the caller should show the "auto-downgrade" prompt.
  bool shouldSuggestDowngrade() {
    if (_networkSeverity != NetworkHealthSeverity.critical) return false;
    final now = DateTime.now();
    final last = _lastDowngradeSuggestedAt;
    if (last == null) return true;
    return now.difference(last).inSeconds >= healthThresholds.cooldownSeconds;
  }

  void markDowngradeSuggested() {
    _lastDowngradeSuggestedAt = DateTime.now();
  }

  // ---- Status store integration ----
  void _onStatusChanged() {
    final snap = statusStore.snapshot;
    if (snap == null) return;
    for (final peer in snap.peers) {
      updatePeerFromSnapshot(peer);
    }
  }

  @override
  void dispose() {
    statusStore.removeListener(_onStatusChanged);
    super.dispose();
  }
}
