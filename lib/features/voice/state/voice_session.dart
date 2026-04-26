import 'dart:async';
import 'dart:io';
import 'package:domain_audio/domain_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/websocket/ws_manager.dart';
import '../../../providers/auth_provider.dart';
import '../utils/voice_sfx.dart';
import 'voice_settings.dart';


/// Voice chat session — 1:1 port of web's useVoiceSession.ts (MVP slice).
///
/// Design notes:
///   - Mesh topology: one RTCPeerConnection per remote user.
///   - Offerer is the numerically-lower user_id. Answerer waits for offer.
///   - Offerer pre-allocates audio transceiver with direction='sendrecv',
///     then replaceTrack with local mic. Answerer mirrors by iterating
///     getTransceivers() after setRemoteDescription and explicitly forcing
///     direction='sendrecv' (otherwise Chrome bakes recvonly into the answer).
///   - joinedPageId is set BEFORE sending voice.join (optimistic) so the
///     first roster event isn't dropped as "not joined here".

class VoiceMember {
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isMuted;
  final bool isVideo;
  final bool isScreenSharing;

  const VoiceMember({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.isMuted = false,
    this.isVideo = false,
    this.isScreenSharing = false,
  });

  factory VoiceMember.fromJson(Map<String, dynamic> j) => VoiceMember(
    userId: j['user_id'] as int? ?? 0,
    username: j['username'] as String? ?? '',
    displayName: j['display_name'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    isMuted: j['is_muted'] as bool? ?? false,
    isVideo: j['is_video'] as bool? ?? false,
    isScreenSharing: j['is_screen_sharing'] as bool? ?? false,
  );
}

class VoiceSessionState {
  final int? joinedPageId;
  final String? joinedPageTitle;
  final String? joinedCommunitySlug;
  final Map<int, List<VoiceMember>> rosters;
  final bool isMuted;
  final bool isVideo;
  final bool isScreenSharing;
  final bool isJoining;
  final String? error;
  final Set<int> speakingUserIds;
  final bool isFullscreen;

  const VoiceSessionState({
    this.joinedPageId,
    this.joinedPageTitle,
    this.joinedCommunitySlug,
    this.rosters = const {},
    this.isMuted = false,
    this.isVideo = false,
    this.isScreenSharing = false,
    this.isJoining = false,
    this.error,
    this.speakingUserIds = const {},
    this.isFullscreen = false,
  });

  bool get inCall => joinedPageId != null;
  List<VoiceMember> membersOn(int pageId) => rosters[pageId] ?? const [];

  VoiceSessionState copyWith({
    int? joinedPageId, bool clearJoined = false,
    String? joinedPageTitle,
    String? joinedCommunitySlug,
    Map<int, List<VoiceMember>>? rosters,
    bool? isMuted,
    bool? isVideo,
    bool? isScreenSharing,
    bool? isJoining,
    String? error, bool clearError = false,
    Set<int>? speakingUserIds,
    bool? isFullscreen,
  }) => VoiceSessionState(
    joinedPageId: clearJoined ? null : (joinedPageId ?? this.joinedPageId),
    joinedPageTitle: clearJoined ? null : (joinedPageTitle ?? this.joinedPageTitle),
    joinedCommunitySlug: clearJoined ? null : (joinedCommunitySlug ?? this.joinedCommunitySlug),
    rosters: rosters ?? this.rosters,
    isMuted: isMuted ?? this.isMuted,
    isVideo: isVideo ?? this.isVideo,
    isScreenSharing: isScreenSharing ?? this.isScreenSharing,
    isJoining: isJoining ?? this.isJoining,
    error: clearError ? null : (error ?? this.error),
    speakingUserIds: speakingUserIds ?? this.speakingUserIds,
    isFullscreen: isFullscreen ?? this.isFullscreen,
  );
}

class _PeerBundle {
  final RTCPeerConnection pc;
  RTCRtpTransceiver? audioTx;
  RTCRtpTransceiver? cameraTx;
  RTCRtpTransceiver? screenTx;
  bool remoteDescSet = false;
  final List<RTCIceCandidate> pendingCandidates = [];

  _PeerBundle({required this.pc, this.audioTx, this.cameraTx, this.screenTx});
}

class PeerQuality {
  final int rttMs;
  final int jitterMs;
  final double lossPct;
  final String quality; // 'good' | 'ok' | 'bad'

  const PeerQuality({this.rttMs = 0, this.jitterMs = 0, this.lossPct = 0, this.quality = 'good'});
}

class VoiceSessionNotifier extends StateNotifier<VoiceSessionState> {
  final Ref _ref;
  VoiceSessionNotifier(this._ref) : super(const VoiceSessionState()) {
    _attachListener();
    _ref.listen<VoiceSettings>(voiceSettingsProvider, (prev, next) {
      if (!state.inCall) {
        return;
      }
      // ignore: avoid_print
      print('[voice] settings changed inCall=true');
      if (prev?.activationMode == 'ptt' && next.activationMode != 'ptt') {
        // ignore: avoid_print
        print('[voice] PTT→VAD, enabling mic');
        _pttHeld = false;
        _setMicEnabled(!state.isMuted);
      }
      if (prev?.activationMode != 'ptt' && next.activationMode == 'ptt') {
        // ignore: avoid_print
        print('[voice] →PTT, disabling mic');
        _pttHeld = false;
        _setMicEnabled(false);
      }
      if (prev?.echoCancellation != next.echoCancellation ||
          prev?.noiseSuppression != next.noiseSuppression) {
        // ignore: avoid_print
        print('[voice] constraints changed, reacquiring ec=${next.echoCancellation} ns=${next.noiseSuppression}');
        _reacquireLocalStream();
      }
      if (prev?.inputDeviceId != next.inputDeviceId) {
        // ignore: avoid_print
        print('[voice] input device changed → ${next.inputDeviceId}');
        _reacquireLocalStream();
      }
      if (prev?.inputVolume != next.inputVolume) {
        // ignore: avoid_print
        print('[voice] input volume → ${next.inputVolume}');
        _applyMicVolume();
      }
      if (prev?.outputVolume != next.outputVolume) {
        // ignore: avoid_print
        print('[voice] output volume → ${next.outputVolume}');
        _applyAllRemoteVolumes();
      }
      if (prev?.muteKey != next.muteKey) {
        _registerMuteHotKey();
      }
      // VAD config changed → update native noise gate
      if (prev?.activationMode != next.activationMode ||
          prev?.vadSensitivity != next.vadSensitivity ||
          prev?.autoVad != next.autoVad) {
        _applyVadConfig();
      }
    });
  }

  MediaStream? _localStream;
  MediaStream? _cameraStream;
  MediaStream? _screenStream;
  String? _screenSourceId;
  final Map<int, _PeerBundle> _peers = {};
  final Map<int, MediaStreamTrack> _remoteTracks = {};
  final Map<int, MediaStreamTrack> _remoteCameraTracks = {};
  final Map<int, MediaStreamTrack> _remoteScreenTracks = {};
  final Map<int, MediaStream> _remoteVideoStreams = {}; // camera streams
  final Map<int, MediaStream> _remoteScreenStreams = {}; // screen streams
  final Map<int, int> _userVolumes = {};
  final Set<int> _userLocallyMuted = {};
  int? _myUserId;
  int? get myUserId => _myUserId;

  final Map<int, RTCVideoRenderer> _remoteRenderers = {};

  /// Get or create renderer for a remote user's video. Returns null if no video track.
  // Track which track ID the current renderer is bound to, so we can
  // detect when a switch from camera→screen (or vice versa) is needed.
  final Map<int, String> _rendererTrackId = {};

  /// Create renderer for remote user. Prefers screen track over camera.
  /// [userId] is the renderer key: positive=camera, negative=screen (negate to get real uid).
  Future<RTCVideoRenderer?> ensureRemoteRenderer(int userId, {bool preferScreen = false}) async {
    final realUid = userId < 0 ? -userId : userId;
    final screenTrack = _remoteScreenTracks[realUid];
    final cameraTrack = _remoteCameraTracks[realUid];
    final track = preferScreen ? screenTrack : (cameraTrack ?? screenTrack);
    // ignore: avoid_print
    print('[voice] ensureRenderer uid=$userId cam=${cameraTrack != null} scr=${screenTrack != null} prefer=$preferScreen trackId=${track?.id}');
    // Get the proper remote MediaStream (from onAddStream, not createLocalMediaStream)
    final stream = preferScreen ? _remoteScreenStreams[realUid] : _remoteVideoStreams[realUid];
    // ignore: avoid_print
    print('[voice] ensureRenderer track=${track?.id} stream=${stream?.id}');
    if (stream == null && track == null) {
      return null;
    }
    final existingTrackId = _rendererTrackId[userId];
    if (existingTrackId != null && track != null && existingTrackId != track.id) {
      _disposeRemoteRenderer(userId);
    }
    if (_remoteRenderers.containsKey(userId)) {
      return _remoteRenderers[userId];
    }
    try {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      if (stream != null) {
        renderer.srcObject = stream;
      } else if (track != null) {
        // No remote stream available (flutter_webrtc Windows unified-plan bug).
        // Create stream with peerConnectionId as ownerTag so the native renderer
        // can find the track in the correct peer connection context.
        String pcId = 'local';
        try { pcId = (track as dynamic).peerConnectionId as String? ?? 'local'; } catch (_) {}
        // ignore: avoid_print
        print('[voice] creating stream with pcId=$pcId for track=${track.id}');
        final ms = await createLocalMediaStream('rv_${userId}_${track.id}');
        ms.addTrack(track);
        renderer.srcObject = ms;
      }
      _remoteRenderers[userId] = renderer;
      if (track != null) _rendererTrackId[userId] = track.id!;
      // ignore: avoid_print
      print('[voice] renderer created uid=$userId stream=${renderer.srcObject?.id}');
      return renderer;
    } catch (e) {
      // ignore: avoid_print
      print('[voice] renderer FAILED uid=$userId: $e');
      return null;
    }
  }

  RTCVideoRenderer? getRemoteRenderer(int userId) => _remoteRenderers[userId];

  /// Self-preview renderer for local camera/screen.
  RTCVideoRenderer? _selfRenderer;

  RTCVideoRenderer? getSelfRenderer() {
    final stream = _screenStream ?? _cameraStream;
    if (stream == null) {
      if (_selfRenderer != null) {
        _selfRenderer!.srcObject = null;
        _selfRenderer!.dispose();
        _selfRenderer = null;
      }
      return null;
    }
    if (_selfRenderer == null) {
      _selfRenderer = RTCVideoRenderer();
      _selfRenderer!.initialize().then((_) {
        _selfRenderer!.srcObject = stream;
        notifyUi();
      });
      return null; // will show on next rebuild after init
    }
    // Update srcObject if stream changed
    if (_selfRenderer!.srcObject?.id != stream.id) {
      _selfRenderer!.srcObject = stream;
    }
    return _selfRenderer;
  }

  /// Force UI rebuild (e.g. after async renderer creation).
  void notifyUi() {
    state = state.copyWith(speakingUserIds: Set.from(state.speakingUserIds));
  }

  void setFullscreen(bool v) {
    state = state.copyWith(isFullscreen: v);
  }
  String? _listenerKey;

  // PTT state
  bool _pttHeld = false;
  HotKey? _registeredMuteHotKey;

  // ── Phase 2: quality + speaking ──
  Timer? _qualityTimer;
  Timer? _speakingTimer;
  final Map<int, ({int lost, int received})> _lossCounters = {};
  final Map<int, PeerQuality> peerQuality = {};
  // Audio energy per-peer (cumulative from getStats totalAudioEnergy).
  final Map<int, double> _prevEnergy = {};
  final Map<int, int> _lastSpokeAt = {}; // epoch millis
  static const _speakHoldMs = 300;
  bool _selfEnergyChecked = false;

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  void _attachListener() {
    // ignore: avoid_print
    print('[voice] _attachListener');
    final ws = _ref.read(wsManagerProvider);
    // Single callback that inspects event.type and routes itself. This
    // avoids any fragility of the addListener/on() chaining pattern.
    _listenerKey = ws.addListener((event) {
      switch (event.type) {
        case WsEventType.voiceRoster:
          _onRosterEvent(event);
        case WsEventType.voiceSignal:
          _onSignalEvent(event);
        case WsEventType.voiceError:
          _onErrorEvent(event);
        case WsEventType.reconnected:
          _onReconnected(event);
        default: break;
      }
    });
    // ignore: avoid_print
    print('[voice] listener key=$_listenerKey');
  }

  void subscribePages(List<int> pageIds) {
    if (pageIds.isEmpty) return;
    _ref.read(wsManagerProvider).subscribeVoicePages(pageIds);
  }

  void unsubscribePages(List<int> pageIds) {
    if (pageIds.isEmpty) return;
    _ref.read(wsManagerProvider).unsubscribeVoicePages(pageIds);
  }

  // ─── Room membership ─────────────────────────────────────────────────

  Future<void> join(int pageId, {String? pageTitle, String? communitySlug}) async {
    // ignore: avoid_print
    print('[voice] join pageId=$pageId alreadyIn=${state.joinedPageId}');
    if (state.joinedPageId == pageId) return;
    if (state.joinedPageId != null) {
      await leave();
    }
    state = state.copyWith(isJoining: true, clearError: true);

    _myUserId = _ref.read(authProvider).user?.id;

    // Init native audio processor (no-op on mobile)
    await DomainAudio.init();
    // ignore: avoid_print
    print('[voice] join myUserId=$_myUserId');

    // Load per-user volume prefs.
    await _loadUserAudioPrefs();

    // Acquire mic with settings-based constraints + selected device.
    final voiceSettings = _ref.read(voiceSettingsProvider);
    final audioConstraints = <String, dynamic>{
      'echoCancellation': voiceSettings.echoCancellation,
      'noiseSuppression': voiceSettings.noiseSuppression,
      // AGC off — native libwebrtc AGC modifies system mic volume and causes
      // other apps to sound muted. Web does the same (see useVoiceSession.ts:492).
      'autoGainControl': false,
    };
    if (voiceSettings.inputDeviceId.isNotEmpty) {
      audioConstraints['deviceId'] = voiceSettings.inputDeviceId;
    }
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': audioConstraints,
        'video': false,
      });
      // ignore: avoid_print
      print('[voice] got mic tracks=${_localStream?.getAudioTracks().length}');
    } catch (e) {
      // ignore: avoid_print
      print('[voice] mic ERROR: $e');
      state = state.copyWith(isJoining: false, error: 'Не удалось получить доступ к микрофону: $e');
      return;
    }

    // Respect pre-existing mute preference + apply mic volume + VAD config.
    for (final t in _localStream!.getAudioTracks()) { t.enabled = !state.isMuted; }
    _applyMicVolume();
    _applyVadConfig();

    // Set joined state BEFORE sending voice.join so the first roster event
    // that arrives isn't dropped by the "not joined here" guard.
    state = state.copyWith(
      joinedPageId: pageId,
      joinedPageTitle: pageTitle,
      joinedCommunitySlug: communitySlug,
      isJoining: false,
    );

    final ws = _ref.read(wsManagerProvider);
    ws.subscribeVoicePages([pageId]);
    ws.sendRaw({
      'action': 'voice.join',
      'page_id': pageId,
      'is_muted': state.isMuted,
      'is_video': false,
    });

    _startPolling();
    VoiceSfx().playSelfJoin();
  }

  Future<void> leave() async {
    final pageId = state.joinedPageId;
    if (pageId == null) return;

    _stopPolling();
    DomainAudio.dispose();

    _ref.read(wsManagerProvider).sendRaw({'action': 'voice.leave', 'page_id': pageId});

    for (final bundle in _peers.values) {
      try { await bundle.pc.close(); } catch (_) {}
    }
    _peers.clear();

    if (_localStream != null) {
      for (final t in _localStream!.getTracks()) { try { await t.stop(); } catch (_) {} }
      try { await _localStream!.dispose(); } catch (_) {}
      _localStream = null;
    }
    if (_cameraStream != null) {
      for (final t in _cameraStream!.getTracks()) { try { await t.stop(); } catch (_) {} }
      try { await _cameraStream!.dispose(); } catch (_) {}
      _cameraStream = null;
    }
    if (_screenStream != null) {
      for (final t in _screenStream!.getTracks()) { try { await t.stop(); } catch (_) {} }
      _screenStream = null;
    }
    for (final uid in _remoteRenderers.keys.toList()) { _disposeRemoteRenderer(uid); }
    if (_selfRenderer != null) {
      try { _selfRenderer!.srcObject = null; _selfRenderer!.dispose(); } catch (_) {}
      _selfRenderer = null;
    }
    _remoteCameraTracks.clear();
    _remoteScreenTracks.clear();
    _remoteVideoStreams.clear();
    _remoteScreenStreams.clear();
    _rendererTrackId.clear();

    state = state.copyWith(clearJoined: true, speakingUserIds: {}, isVideo: false, isScreenSharing: false);
    VoiceSfx().playSelfLeave();
  }

  void toggleMute() {
    final newMuted = !state.isMuted;
    state = state.copyWith(isMuted: newMuted);
    _applyPttGate();
    if (newMuted) VoiceSfx().playMute(); else VoiceSfx().playUnmute();
    final pageId = state.joinedPageId;
    if (pageId != null) {
      Future(() {
        _ref.read(wsManagerProvider).sendRaw({
          'action': 'voice.state',
          'page_id': pageId,
          'is_muted': newMuted,
          'is_video': state.isVideo,
          'is_screen_sharing': state.isScreenSharing,
        });
      });
    }
  }

  // ─── Event handlers ──────────────────────────────────────────────────

  void _onRosterEvent(WsEvent event) {
    final raw = event.data;
    // ignore: avoid_print
    print('[voice] _onRosterEvent rawKeys=${raw?.keys.toList()} page=${raw?['page_id']} dataType=${raw?['data']?.runtimeType}');
    if (raw == null) return;
    final pageId = raw['page_id'] as int? ?? 0;

    // Backend sends members under `data` (matches web: `(evt.data || []) as VoiceMember[]`).
    final rawList = raw['data'];
    final items = (rawList is List) ? rawList : const [];
    final members = items
        .whereType<Map>()
        .map((m) => VoiceMember.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    // ignore: avoid_print
    print('[voice] roster parsed page=$pageId count=${members.length} joined=${state.joinedPageId} my=$_myUserId');

    final prevMembers = state.rosters[pageId] ?? const [];
    final newRosters = Map<int, List<VoiceMember>>.from(state.rosters);
    newRosters[pageId] = members;
    state = state.copyWith(rosters: newRosters);

    if (pageId == state.joinedPageId && _myUserId != null) {
      final prevIds = prevMembers.map((m) => m.userId).where((id) => id != _myUserId).toSet();
      final newIds = members.map((m) => m.userId).where((id) => id != _myUserId).toSet();
      for (final id in newIds) {
        if (!prevIds.contains(id)) VoiceSfx().playUserJoin();
      }
      for (final id in prevIds) {
        if (!newIds.contains(id)) VoiceSfx().playUserLeave();
      }
    }

    if (pageId != state.joinedPageId) return;
    _myUserId ??= _ref.read(authProvider).user?.id;
    if (_myUserId == null) return;

    final remoteIds = members.map((m) => m.userId).where((id) => id != _myUserId).toSet();

    // Initiate to new members (as offerer if our id is numerically lower).
    for (final id in remoteIds) {
      if (_peers.containsKey(id)) continue;
      if (_myUserId! < id) {
        _initiateTo(id);
      }
    }

    // Close peers for members who left.
    for (final existingId in _peers.keys.toList()) {
      if (!remoteIds.contains(existingId)) {
        _closePeer(existingId);
      }
    }
  }

  void _onSignalEvent(WsEvent event) {
    final raw = event.data;
    if (raw == null) return;
    final pageId = raw['page_id'] as int? ?? 0;
    if (pageId != state.joinedPageId) return;

    final fromUserId = raw['from_user_id'] as int? ?? 0;
    if (fromUserId == _myUserId) return;

    final payload = raw['payload'] as Map<String, dynamic>? ?? {};
    final type = payload['type'] as String? ?? '';

    switch (type) {
      case 'offer': _handleOffer(fromUserId, payload);
      case 'answer': _handleAnswer(fromUserId, payload);
      case 'candidate': _handleCandidate(fromUserId, payload);
    }
  }

  void _onErrorEvent(WsEvent event) {
    final code = event.data?['code'] as String? ?? '';
    if (state.joinedPageId != null && code != 'ALREADY_IN_ROOM') {
      state = state.copyWith(error: 'Ошибка: $code');
    }
  }

  void _onReconnected(WsEvent _) {
    final pageId = state.joinedPageId;
    if (pageId == null) return;
    // WS came back — drop all peers and re-announce join (SDP restarts clean).
    for (final b in _peers.values) {
      try { b.pc.close(); } catch (_) {}
    }
    _peers.clear();
    _ref.read(wsManagerProvider).sendRaw({
      'action': 'voice.join',
      'page_id': pageId,
      'is_muted': state.isMuted,
      'is_video': false,
    });
  }

  // ─── Peer lifecycle ──────────────────────────────────────────────────

  Future<_PeerBundle> _getOrCreatePeer(int userId, {required bool isOfferer}) async {
    final existing = _peers[userId];
    if (existing != null) return existing;

    final pc = await createPeerConnection(_iceConfig);

    pc.onIceCandidate = (candidate) {
      _sendSignal(userId, {
        'type': 'candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        },
      });
    };

    pc.onTrack = (event) {
      final track = event.track;
      final stream = event.streams.isNotEmpty ? event.streams.first : null;
      // ignore: avoid_print
      print('[voice] onTrack uid=$userId kind=${track.kind} streams=${event.streams.length} stream=${stream?.id}');
      if (track.kind == 'audio') {
        _remoteTracks[userId] = track;
        _applyRemoteVolume(userId);
      } else if (track.kind == 'video') {
        if (!_remoteCameraTracks.containsKey(userId)) {
          _remoteCameraTracks[userId] = track;
          if (stream != null) _remoteVideoStreams[userId] = stream;
          print('[voice] stored CAMERA uid=$userId stream=${stream?.id}');
        } else {
          _remoteScreenTracks[userId] = track;
          if (stream != null) _remoteScreenStreams[userId] = stream;
          print('[voice] stored SCREEN uid=$userId stream=${stream?.id}');
        }
        notifyUi();
      }
    };

    pc.onConnectionState = (st) {
      if (st == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Only offerer re-offers to avoid a simultaneous race.
        if (_myUserId != null && _myUserId! < userId) {
          _peers.remove(userId);
          try { pc.close(); } catch (_) {}
          Future.delayed(const Duration(milliseconds: 500), () {
            if (state.joinedPageId == null) return;
            final stillIn = state.membersOn(state.joinedPageId!)
                .any((m) => m.userId == userId);
            if (stillIn) _initiateTo(userId);
          });
        }
      }
    };

    RTCRtpTransceiver? audioTx;
    RTCRtpTransceiver? cameraTx;
    RTCRtpTransceiver? screenTx;
    if (isOfferer) {
      audioTx = await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      cameraTx = await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      screenTx = await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      if (_localStream != null) {
        final at = _localStream!.getAudioTracks();
        if (at.isNotEmpty) await audioTx.sender.replaceTrack(at.first);
      }
      if (_cameraStream != null) {
        final vt = _cameraStream!.getVideoTracks();
        if (vt.isNotEmpty) await cameraTx.sender.replaceTrack(vt.first);
      }
      if (_screenStream != null) {
        final st = _screenStream!.getVideoTracks();
        if (st.isNotEmpty) await screenTx.sender.replaceTrack(st.first);
      }
    }

    final bundle = _PeerBundle(pc: pc, audioTx: audioTx, cameraTx: cameraTx, screenTx: screenTx);
    _peers[userId] = bundle;
    return bundle;
  }

  Future<void> _initiateTo(int userId) async {
    if (_myUserId == null || _myUserId! >= userId) return;
    if (state.joinedPageId == null) return;
    try {
      final bundle = await _getOrCreatePeer(userId, isOfferer: true);
      final offer = await bundle.pc.createOffer();
      await bundle.pc.setLocalDescription(offer);
      _sendSignal(userId, {'type': 'offer', 'sdp': offer.sdp});
    } catch (_) {
      await _closePeer(userId);
    }
  }

  Future<void> _handleOffer(int userId, Map<String, dynamic> payload) async {
    try {
      final bundle = await _getOrCreatePeer(userId, isOfferer: false);
      final pc = bundle.pc;
      await pc.setRemoteDescription(
        RTCSessionDescription(payload['sdp'] as String?, 'offer'),
      );
      bundle.remoteDescSet = true;

      final txs = await pc.getTransceivers();
      for (var i = 0; i < txs.length; i++) {
        final tx = txs[i];
        try { await tx.setDirection(TransceiverDirection.SendRecv); } catch (_) {}
        if (i == 0) {
          bundle.audioTx = tx;
          if (_localStream != null) {
            final at = _localStream!.getAudioTracks();
            if (at.isNotEmpty) await tx.sender.replaceTrack(at.first);
          }
        } else if (i == 1) {
          bundle.cameraTx = tx;
          if (_cameraStream != null) {
            final vt = _cameraStream!.getVideoTracks();
            if (vt.isNotEmpty) await tx.sender.replaceTrack(vt.first);
          }
        } else if (i == 2) {
          bundle.screenTx = tx;
          if (_screenStream != null) {
            final st = _screenStream!.getVideoTracks();
            if (st.isNotEmpty) await tx.sender.replaceTrack(st.first);
          }
        }
      }

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignal(userId, {'type': 'answer', 'sdp': answer.sdp});

      for (final cand in bundle.pendingCandidates) {
        try { await pc.addCandidate(cand); } catch (_) {}
      }
      bundle.pendingCandidates.clear();
    } catch (_) {
      await _closePeer(userId);
    }
  }

  Future<void> _handleAnswer(int userId, Map<String, dynamic> payload) async {
    final bundle = _peers[userId];
    if (bundle == null) return;
    try {
      await bundle.pc.setRemoteDescription(
        RTCSessionDescription(payload['sdp'] as String?, 'answer'),
      );
      bundle.remoteDescSet = true;
      for (final cand in bundle.pendingCandidates) {
        try { await bundle.pc.addCandidate(cand); } catch (_) {}
      }
      bundle.pendingCandidates.clear();
    } catch (_) {}
  }

  Future<void> _handleCandidate(int userId, Map<String, dynamic> payload) async {
    final c = payload['candidate'];
    if (c is! Map) return;
    final candidate = RTCIceCandidate(
      c['candidate'] as String?,
      c['sdpMid'] as String?,
      (c['sdpMLineIndex'] as num?)?.toInt(),
    );

    final bundle = _peers[userId];
    if (bundle == null) return;

    if (bundle.remoteDescSet) {
      try { await bundle.pc.addCandidate(candidate); } catch (_) {}
    } else {
      bundle.pendingCandidates.add(candidate);
    }
  }

  Future<void> _closePeer(int userId) async {
    final bundle = _peers.remove(userId);
    _remoteTracks.remove(userId);
    _remoteCameraTracks.remove(userId);
    _remoteScreenTracks.remove(userId);
    _remoteVideoStreams.remove(userId);
    _remoteScreenStreams.remove(userId);
    _rendererTrackId.remove(userId);
    _rendererTrackId.remove(-userId);
    _disposeRemoteRenderer(userId);
    _disposeRemoteRenderer(-userId);
    if (bundle == null) return;
    try { await bundle.pc.close(); } catch (_) {}
  }


  void _disposeRemoteRenderer(int userId) {
    final r = _remoteRenderers.remove(userId);
    if (r != null) {
      try { r.srcObject = null; r.dispose(); } catch (_) {}
    }
  }

  void _sendSignal(int targetUserId, Map<String, dynamic> payload) {
    final pageId = state.joinedPageId;
    if (pageId == null) return;
    Future(() {
      _ref.read(wsManagerProvider).sendRaw({
        'action': 'voice.signal',
        'page_id': pageId,
        'target_user_id': targetUserId,
        'payload': payload,
      });
    });
  }

  // ─── Phase 3.5: Volume + VAD + per-user control ────────────────────

  Future<void> _applyVadConfig() async {
    final s = _ref.read(voiceSettingsProvider);
    final enabled = s.activationMode == 'vad';
    await DomainAudio.setVadConfig(
      enabled: enabled,
      threshold: s.vadSensitivity,
      autoVad: s.autoVad,
    );
  }

  Future<void> _applyMicVolume() async {
    if (_localStream == null) return;
    final vol = _ref.read(voiceSettingsProvider).inputVolume;
    final gain = vol / 100.0; // 0-200% → 0.0-2.0

    if (DomainAudio.isDesktop) {
      final ok = await DomainAudio.setInputGain(gain);
      // ignore: avoid_print
      print('[voice] DomainAudio.setInputGain($gain) → $ok');
    } else {
      // Mobile: Helper.setVolume works natively (Android AudioTrack, iOS AVAudio)
      final nativeGain = (vol / 25.0).clamp(0.0, 10.0);
      for (final t in _localStream!.getAudioTracks()) {
        try { await Helper.setVolume(nativeGain, t); } catch (_) {}
      }
    }
  }

  Future<void> _applyRemoteVolume(int userId) async {
    final track = _remoteTracks[userId];
    if (track == null) return;
    final masterVol = _ref.read(voiceSettingsProvider).outputVolume;
    final userVol = _userVolumes[userId] ?? 100;
    final muted = _userLocallyMuted.contains(userId);
    final effective = muted ? 0.0 : (masterVol / 100.0) * (userVol / 100.0);

    if (DomainAudio.isDesktop) {
      final ok = await DomainAudio.setOutputVolume(effective);
      // ignore: avoid_print
      print('[voice] DomainAudio.setOutputVolume($effective) → $ok');
    } else {
      try { await Helper.setVolume(effective.clamp(0.0, 10.0), track); } catch (_) {}
    }
  }

  void _applyAllRemoteVolumes() {
    for (final uid in _remoteTracks.keys) {
      _applyRemoteVolume(uid);
    }
  }

  /// Set per-user volume (0-100). Persisted in SharedPreferences.
  void setUserVolume(int userId, int pct) {
    _userVolumes[userId] = pct.clamp(0, 100);
    _applyRemoteVolume(userId);
    SharedPreferences.getInstance().then((p) => p.setInt('voice.uv.$userId', pct));
  }

  /// Locally mute/unmute a specific remote user.
  void setUserLocallyMuted(int userId, bool muted) {
    if (muted) { _userLocallyMuted.add(userId); } else { _userLocallyMuted.remove(userId); }
    _applyRemoteVolume(userId);
    SharedPreferences.getInstance().then((p) =>
        p.setStringList('voice.locally_muted', _userLocallyMuted.map((e) => '$e').toList()));
  }

  int getUserVolume(int userId) => _userVolumes[userId] ?? 100;
  bool isUserLocallyMuted(int userId) => _userLocallyMuted.contains(userId);

  Future<void> _loadUserAudioPrefs() async {
    final p = await SharedPreferences.getInstance();
    for (final key in p.getKeys()) {
      if (key.startsWith('voice.uv.')) {
        final uid = int.tryParse(key.substring('voice.uv.'.length));
        if (uid != null) _userVolumes[uid] = p.getInt(key) ?? 100;
      }
    }
    final mutedList = p.getStringList('voice.locally_muted');
    if (mutedList != null) {
      for (final s in mutedList) {
        final uid = int.tryParse(s);
        if (uid != null) _userLocallyMuted.add(uid);
      }
    }
  }

  // ─── Phase 2: Polling (quality stats + speaking detection) ─────────

  void _startPolling() {
    _stopPolling();
    _qualityTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollQuality());
    _speakingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _pollSpeaking());
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _registerMuteHotKey();
  }

  void _stopPolling() {
    _qualityTimer?.cancel(); _qualityTimer = null;
    _speakingTimer?.cancel(); _speakingTimer = null;
    _lossCounters.clear();
    peerQuality.clear();
    _prevEnergy.clear();
    _lastSpokeAt.clear();
    _pttHeld = false;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _unregisterMuteHotKey();
  }

  bool _muteViaKeyboard = false;

  void _registerMuteHotKey() {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    _unregisterMuteHotKey();
    final muteKey = _ref.read(voiceSettingsProvider).muteKey;
    if (muteKey.isEmpty) return;

    if (_isModifierOnlyKey(muteKey)) {
      _muteViaKeyboard = true;
      return;
    }

    final hk = _parseHotKey(muteKey);
    if (hk == null) return;
    _registeredMuteHotKey = hk;
    hotKeyManager.register(hk, keyDownHandler: (_) => toggleMute());
  }

  void _unregisterMuteHotKey() {
    _muteViaKeyboard = false;
    if (_registeredMuteHotKey != null) {
      hotKeyManager.unregister(_registeredMuteHotKey!);
      _registeredMuteHotKey = null;
    }
  }

  void updateMuteHotKey() {
    if (state.inCall) _registerMuteHotKey();
  }

  static bool _isModifierOnlyKey(String key) =>
      const {'Control Left', 'Control Right', 'Shift Left', 'Shift Right',
             'Alt Left', 'Alt Right', 'Meta Left', 'Meta Right'}.contains(key);

  static HotKey? _parseHotKey(String keyStr) {
    final parts = keyStr.split('+');
    if (parts.isEmpty) return null;
    final mainKeyStr = parts.last;
    final modifiers = <HotKeyModifier>[];
    for (final p in parts) {
      switch (p) {
        case 'Ctrl': modifiers.add(HotKeyModifier.control);
        case 'Shift': modifiers.add(HotKeyModifier.shift);
        case 'Alt': modifiers.add(HotKeyModifier.alt);
      }
    }
    final physical = _resolvePhysicalKey(mainKeyStr);
    if (physical == null) return null;
    return HotKey(key: physical, modifiers: modifiers, scope: HotKeyScope.system);
  }

  static final _physicalKeyMap = <String, PhysicalKeyboardKey>{
    'Space': PhysicalKeyboardKey.space,
    'F1': PhysicalKeyboardKey.f1,
    'F2': PhysicalKeyboardKey.f2,
    'F3': PhysicalKeyboardKey.f3,
    'F4': PhysicalKeyboardKey.f4,
    'F5': PhysicalKeyboardKey.f5,
    'F6': PhysicalKeyboardKey.f6,
    'F7': PhysicalKeyboardKey.f7,
    'F8': PhysicalKeyboardKey.f8,
    'F9': PhysicalKeyboardKey.f9,
    'F10': PhysicalKeyboardKey.f10,
    'F11': PhysicalKeyboardKey.f11,
    'F12': PhysicalKeyboardKey.f12,
    'Escape': PhysicalKeyboardKey.escape,
    'Pause': PhysicalKeyboardKey.pause,
    'Scroll Lock': PhysicalKeyboardKey.scrollLock,
    'Insert': PhysicalKeyboardKey.insert,
    'Delete': PhysicalKeyboardKey.delete,
    'Home': PhysicalKeyboardKey.home,
    'End': PhysicalKeyboardKey.end,
    'Page Up': PhysicalKeyboardKey.pageUp,
    'Page Down': PhysicalKeyboardKey.pageDown,
    'Num Lock': PhysicalKeyboardKey.numLock,
  };

  static PhysicalKeyboardKey? _resolvePhysicalKey(String label) {
    final mapped = _physicalKeyMap[label];
    if (mapped != null) return mapped;
    if (label.length == 1) {
      final upper = label.toUpperCase();
      final code = upper.codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        return PhysicalKeyboardKey.findKeyByCode(0x00070004 + (code - 65));
      }
      if (code >= 48 && code <= 57) {
        return PhysicalKeyboardKey.findKeyByCode(code == 48 ? 0x00070027 : 0x0007001e + (code - 49));
      }
    }
    return null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!state.inCall) return false;
    if (event is KeyRepeatEvent) return false;

    if (_muteViaKeyboard && event is KeyDownEvent) {
      final muteKey = _ref.read(voiceSettingsProvider).muteKey;
      if (muteKey.isNotEmpty && event.logicalKey.keyLabel == muteKey) {
        toggleMute();
        return false;
      }
    }

    final settings = _ref.read(voiceSettingsProvider);
    if (!settings.isPtt) return false;
    final pttKey = settings.pttKey;
    if (pttKey.isEmpty) return false;
    if (!_matchesPttKey(event, pttKey)) return false;

    if (event is KeyDownEvent) {
      if (!_pttHeld) {
        _pttHeld = true;
        _setMicEnabled(!state.isMuted);
      }
    } else if (event is KeyUpEvent) {
      if (_pttHeld) {
        _pttHeld = false;
        _setMicEnabled(false);
      }
    }
    return false;
  }

  bool _matchesPttKey(KeyEvent event, String pttKey) {
    final parts = pttKey.split('+');
    final mainKey = parts.last;
    final needCtrl = parts.contains('Ctrl');
    final needShift = parts.contains('Shift');
    final needAlt = parts.contains('Alt');

    final keyboard = HardwareKeyboard.instance;
    if (needCtrl && !keyboard.isControlPressed) return false;
    if (needShift && !keyboard.isShiftPressed) return false;
    if (needAlt && !keyboard.isAltPressed) return false;

    // Match by label (case-insensitive) or known aliases.
    final label = event.logicalKey.keyLabel;
    if (mainKey == 'Space') return event.logicalKey == LogicalKeyboardKey.space;
    return label.toUpperCase() == mainKey.toUpperCase();
  }

  /// Hot-swap mic when audio constraints or device changes.
  Future<void> _reacquireLocalStream() async {
    if (_localStream == null) return;
    final settings = _ref.read(voiceSettingsProvider);
    final audioConstraints = <String, dynamic>{
      'echoCancellation': settings.echoCancellation,
      'noiseSuppression': settings.noiseSuppression,
      // AGC off — native libwebrtc AGC modifies system mic volume and causes
      // other apps to sound muted. Web does the same (see useVoiceSession.ts:492).
      'autoGainControl': false,
    };
    if (settings.inputDeviceId.isNotEmpty) {
      audioConstraints['deviceId'] = settings.inputDeviceId;
    }
    try {
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': audioConstraints,
        'video': false,
      });
      // Stop old tracks
      for (final t in _localStream!.getAudioTracks()) { try { await t.stop(); } catch (_) {} }
      try { await _localStream!.dispose(); } catch (_) {}
      _localStream = newStream;
      // Replace track in all peers
      final newTrack = newStream.getAudioTracks().first;
      for (final bundle in _peers.values) {
        final tx = bundle.audioTx;
        if (tx != null) {
          await tx.sender.replaceTrack(newTrack);
        }
      }
      _applyMicVolume();
      _applyPttGate();
      // ignore: avoid_print
      print('[voice] reacquire OK ec=${settings.echoCancellation} ns=${settings.noiseSuppression} dev=${settings.inputDeviceId}');
    } catch (e) {
      // ignore: avoid_print
      print('[voice] reacquire FAILED: $e');
    }
  }

  // ─── Camera + Screen-share (Phase 4) ──────────────────────────────

  Future<void> toggleCamera() async {
    if (!state.inCall) return;
    if (_cameraStream != null) {
      await _stopCamera();
    } else {
      await _startCamera();
    }
  }

  Future<void> _startCamera() async {
    // ignore: avoid_print
    print('[voice] _startCamera peers=${_peers.length}');
    try {
      _cameraStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
          'frameRate': {'ideal': 30},
        },
      });
      // ignore: avoid_print
      print('[voice] camera stream got ${_cameraStream!.getVideoTracks().length} tracks');
      state = state.copyWith(isVideo: true);
      final track = _cameraStream!.getVideoTracks().first;
      for (final entry in _peers.entries) {
        final bundle = entry.value;
        // ignore: avoid_print
        print('[voice] replaceTrack camera for peer ${entry.key}, cameraTx=${bundle.cameraTx != null}');
        if (bundle.cameraTx != null) {
          await bundle.cameraTx!.sender.replaceTrack(track);
        }
      }
      _broadcastVoiceState();
    } catch (e) {
      // ignore: avoid_print
      print('[voice] camera FAILED: $e');
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraStream == null) return;
    for (final t in _cameraStream!.getTracks()) { try { await t.stop(); } catch (_) {} }
    try { await _cameraStream!.dispose(); } catch (_) {}
    _cameraStream = null;
    state = state.copyWith(isVideo: false);
    for (final bundle in _peers.values) {
      if (bundle.cameraTx != null) {
        try { await bundle.cameraTx!.sender.replaceTrack(null); } catch (_) {}
      }
    }
    _broadcastVoiceState();
  }

  Future<void> toggleScreenShare() async {
    if (!state.inCall) return;
    if (_screenStream != null) {
      await _stopScreenShare();
    }
    // Caller should use startScreenShareWithSource(sourceId) after picker
  }

  /// Start screen share with a specific source ID (from ScreenSourcePicker).
  Future<void> startScreenShareWithSource(String sourceId, {VoiceSettings? settings}) async {
    if (!state.inCall || _screenStream != null) return;
    _screenSourceId = sourceId;
    final fps = settings?.shareFramerate.toDouble() ?? 30.0;
    final res = settings?.shareResolution ?? 'auto';
    final mandatory = <String, dynamic>{'frameRate': fps};
    // ignore: avoid_print
    print('[voice] startScreenShare sourceId=$sourceId fps=$fps res=$res mandatory=$mandatory');
    try {
      _screenStream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'video': {
          'deviceId': {'exact': sourceId},
          'mandatory': mandatory,
        },
      });

      state = state.copyWith(isScreenSharing: true);
      final track = _screenStream!.getVideoTracks().first;
      track.onEnded = () => _stopScreenShare();
      for (final bundle in _peers.values) {
        if (bundle.screenTx != null) {
          await bundle.screenTx!.sender.replaceTrack(track);
        }
      }
      _broadcastVoiceState();
    } catch (e) {
      // ignore: avoid_print
      print('[voice] screen share failed: $e');
    }
  }

  Future<void> applyScreenShareSettings(VoiceSettings settings) async {
    if (_screenStream == null || _screenSourceId == null) return;
    final sid = _screenSourceId!;
    await _stopScreenShare(keepSourceId: true);
    await startScreenShareWithSource(sid, settings: settings);
  }

  Future<void> _stopScreenShare({bool keepSourceId = false}) async {
    if (_screenStream == null) return;
    final stream = _screenStream!;
    _screenStream = null;
    if (!keepSourceId) _screenSourceId = null;
    state = state.copyWith(isScreenSharing: false);
    for (final bundle in _peers.values) {
      if (bundle.screenTx != null) {
        try { await bundle.screenTx!.sender.replaceTrack(null); } catch (_) {}
      }
    }
    _broadcastVoiceState();
    for (final t in stream.getTracks()) {
      try { await t.stop(); } catch (_) {}
    }
  }

  void _broadcastVoiceState() {
    final pageId = state.joinedPageId;
    if (pageId == null) return;
    final muted = state.isMuted;
    final video = state.isVideo;
    final screen = state.isScreenSharing;
    Future(() {
      _ref.read(wsManagerProvider).sendRaw({
        'action': 'voice.state',
        'page_id': pageId,
        'is_muted': muted,
        'is_video': video,
        'is_screen_sharing': screen,
      });
    });
  }

  void _setMicEnabled(bool enabled) {
    if (_localStream == null) return;
    for (final t in _localStream!.getAudioTracks()) {
      t.enabled = enabled;
    }
  }

  /// Recalculate whether mic should transmit based on mute + PTT state.
  void _applyPttGate() {
    final settings = _ref.read(voiceSettingsProvider);
    final shouldTransmit = !state.isMuted && (!settings.isPtt || _pttHeld);
    _setMicEnabled(shouldTransmit);
  }

  Future<void> _pollQuality() async {
    for (final entry in _peers.entries) {
      final uid = entry.key;
      final pc = entry.value.pc;
      try {
        final stats = await pc.getStats();
        int rttMs = 0;
        int jitterMs = 0;
        int totalLost = 0;
        int totalReceived = 0;
        for (final r in stats) {
          final v = r.values;
          if (r.type == 'candidate-pair') {
            final rtt = v['currentRoundTripTime'];
            if (rtt is num && (v['nominated'] == true || v['state'] == 'succeeded')) {
              rttMs = (rtt * 1000).round();
            }
          } else if (r.type == 'inbound-rtp' && v['kind'] == 'audio') {
            final j = v['jitter'];
            if (j is num) jitterMs = (j * 1000).round().clamp(0, 999);
            final lost = v['packetsLost'];
            if (lost is num) totalLost += lost.toInt();
            final recv = v['packetsReceived'];
            if (recv is num) totalReceived += recv.toInt();
          }
        }
        final prev = _lossCounters[uid] ?? (lost: 0, received: 0);
        final lostD = (totalLost - prev.lost).clamp(0, 999999);
        final recvD = (totalReceived - prev.received).clamp(0, 999999);
        final denom = lostD + recvD;
        final lossPct = denom > 0 ? (lostD / denom) * 100 : 0.0;
        _lossCounters[uid] = (lost: totalLost, received: totalReceived);

        final quality = rttMs > 300 || lossPct > 5 ? 'bad'
            : rttMs > 150 || lossPct > 2 ? 'ok'
            : 'good';
        peerQuality[uid] = PeerQuality(
          rttMs: rttMs,
          jitterMs: jitterMs,
          lossPct: (lossPct * 10).roundToDouble() / 10,
          quality: quality,
        );
      } catch (_) {}
    }
  }

  Future<void> _pollSpeaking() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final newSpeaking = <int>{};
    _selfEnergyChecked = false;

    for (final entry in _peers.entries) {
      final uid = entry.key;
      final pc = entry.value.pc;
      try {
        final stats = await pc.getStats();
        double inEnergy = 0;
        double outEnergy = 0;
        for (final r in stats) {
          if (r.type == 'inbound-rtp' && r.values['kind'] == 'audio') {
            final e = r.values['totalAudioEnergy'];
            if (e is num) inEnergy = e.toDouble();
          }
          if (r.type == 'outbound-rtp' && r.values['kind'] == 'audio') {
            final e = r.values['totalAudioEnergy'];
            if (e is num && e > 0) outEnergy = e.toDouble();
          }
          // Fallback: media-source stats often have audioLevel/totalAudioEnergy
          // even when outbound-rtp doesn't.
          if (r.type == 'media-source' && r.values['kind'] == 'audio' && outEnergy == 0) {
            final e = r.values['totalAudioEnergy'];
            if (e is num && e > 0) outEnergy = e.toDouble();
            // Instant level (0..1) — convert to cumulative-like by using raw value.
            if (outEnergy == 0) {
              final lvl = r.values['audioLevel'];
              if (lvl is num && lvl > 0) outEnergy = lvl.toDouble() * 10000;
            }
          }
        }

        // Remote user speaking (inbound)
        final prevIn = _prevEnergy[uid] ?? 0.0;
        _prevEnergy[uid] = inEnergy;
        if (inEnergy - prevIn > 0.0005) {
          _lastSpokeAt[uid] = nowMs;
        }
        if (nowMs - (_lastSpokeAt[uid] ?? 0) < _speakHoldMs) {
          newSpeaking.add(uid);
        }

        // Local user speaking (outbound) — check from any peer's outbound-rtp or media-source
        if (_myUserId != null && outEnergy > 0 && !_selfEnergyChecked) {
          _selfEnergyChecked = true; // Only take from the first peer to avoid double-counting
          final myKey = -_myUserId!;
          final prevOut = _prevEnergy[myKey] ?? 0.0;
          _prevEnergy[myKey] = outEnergy;
          final delta = outEnergy - prevOut;
          // Threshold adapts: totalAudioEnergy deltas are ~0.001 range,
          // audioLevel×10000 deltas are ~10+ range, bytesSent deltas are ~1000+ range.
          final threshold = prevOut < 100 ? 0.0003 : 50.0;
          if (delta > threshold && !state.isMuted) {
            _lastSpokeAt[_myUserId!] = nowMs;
          }
        }
      } catch (_) {}
    }

    // Check local speaking hold
    if (_myUserId != null && nowMs - (_lastSpokeAt[_myUserId!] ?? 0) < _speakHoldMs && !state.isMuted) {
      newSpeaking.add(_myUserId!);
    }

    if (!_setEquals(newSpeaking, state.speakingUserIds)) {
      state = state.copyWith(speakingUserIds: newSpeaking);
    }
  }

  static bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  // ─── Phase 2: SFX (Web Audio style oscillator tones) ──────────────

  // No native oscillator on desktop — left as placeholder for now.
  // SFX will be hooked up in Phase 2.5 with a tone-gen package or raw PCM.

  @override
  void dispose() {
    _stopPolling();
    leave();
    final key = _listenerKey;
    if (key != null) {
      try { _ref.read(wsManagerProvider).removeListener(key); } catch (_) {}
    }
    super.dispose();
  }
}

final voiceSessionProvider =
    StateNotifierProvider<VoiceSessionNotifier, VoiceSessionState>((ref) {
  return VoiceSessionNotifier(ref);
});
