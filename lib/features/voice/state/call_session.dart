import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/ws_manager.dart';
import '../utils/voice_sfx.dart';
import 'voice_session.dart';

enum CallStatus { idle, outgoing, incoming, connecting, active, ended }

class CallPeer {
  final int userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  CallPeer({required this.userId, this.username, this.displayName, this.avatarUrl});

  String get name => (displayName?.isNotEmpty == true ? displayName! : username) ?? '';

  factory CallPeer.fromMap(Map<String, dynamic> m) => CallPeer(
    userId: m['user_id'] as int? ?? 0,
    username: m['username'] as String?,
    displayName: m['display_name'] as String?,
    avatarUrl: m['avatar_url'] as String?,
  );
}

class CallState {
  final CallStatus status;
  final String? callId;
  final CallPeer? peer;
  final int? voicePageId;
  final bool withVideo;
  final String? errorCode;

  const CallState({
    this.status = CallStatus.idle,
    this.callId,
    this.peer,
    this.voicePageId,
    this.withVideo = false,
    this.errorCode,
  });

  CallState copyWith({
    CallStatus? status, String? callId, CallPeer? peer,
    int? voicePageId, bool? withVideo, String? errorCode,
    bool clearCallId = false, bool clearPeer = false, bool clearPageId = false, bool clearError = false,
  }) => CallState(
    status: status ?? this.status,
    callId: clearCallId ? null : (callId ?? this.callId),
    peer: clearPeer ? null : (peer ?? this.peer),
    voicePageId: clearPageId ? null : (voicePageId ?? this.voicePageId),
    withVideo: withVideo ?? this.withVideo,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
  );
}

class CallSessionNotifier extends StateNotifier<CallState> {
  final WsManager _ws;
  final Ref _ref;
  String _listenerKey = '';

  CallSessionNotifier(this._ws, this._ref) : super(const CallState()) {
    _setupWs();
  }

  void _setupWs() {
    _listenerKey = _ws.addListener((_) {});

    _ws.onAny(_listenerKey, (event) {
      final type = event.rawType;
      final data = event.data ?? {};

      if (type == 'call.ringing') {
        state = state.copyWith(callId: data['call_id'] as String?);
      } else if (type == 'call.incoming') {
        if (state.status != CallStatus.idle) {
          _ws.sendRaw({'action': 'call.reject', 'call_id': data['call_id']});
          return;
        }
        state = state.copyWith(
          status: CallStatus.incoming,
          callId: data['call_id'] as String?,
          peer: data['from'] is Map<String, dynamic> ? CallPeer.fromMap(data['from']) : null,
          withVideo: data['with_video'] as bool? ?? false,
        );
        VoiceSfx().playRingtone();
      } else if (type == 'call.started') {
        VoiceSfx().stopLoop();
        final pageId = data['page_id'] as int? ?? 0;
        var p = state.peer;
        if (data['peer'] is Map<String, dynamic> && (p == null || p.username == null)) {
          p = CallPeer.fromMap(data['peer']);
        }
        state = state.copyWith(
          status: CallStatus.active,
          voicePageId: pageId,
          peer: p,
          withVideo: data['with_video'] as bool? ?? state.withVideo,
        );
        _joinVoiceRoom(pageId);
      } else if (type == 'call.ended') {
        VoiceSfx().stopLoop();
        final reason = data['reason'] as String? ?? 'ended';
        if (state.status == CallStatus.outgoing) {
          state = state.copyWith(errorCode: reason);
          Future.delayed(const Duration(milliseconds: 2500), _resetToIdle);
        } else {
          _leaveVoiceRoom();
          state = state.copyWith(status: CallStatus.ended, errorCode: reason);
          Future.delayed(const Duration(milliseconds: 1500), _resetToIdle);
        }
      } else if (type == 'call.resume') {
        final isActive = data['active'] as bool? ?? false;
        state = state.copyWith(
          callId: data['call_id'] as String?,
          voicePageId: data['page_id'] as int?,
          peer: data['peer'] is Map<String, dynamic> ? CallPeer.fromMap(data['peer']) : null,
          status: isActive ? CallStatus.active : CallStatus.incoming,
          withVideo: data['with_video'] as bool? ?? false,
        );
        if (!isActive) VoiceSfx().playRingtone();
      } else if (type == 'call.error') {
        VoiceSfx().stopLoop();
        final code = data['code'] as String? ?? 'CALL_ERROR';
        if (state.status == CallStatus.outgoing) {
          state = state.copyWith(errorCode: code);
          Future.delayed(const Duration(milliseconds: 2500), _resetToIdle);
        } else if (state.status != CallStatus.active) {
          _resetToIdle();
        } else {
          state = state.copyWith(errorCode: code);
        }
      }
    });
  }

  void startCall(int targetUserId, {CallPeer? peerHint, bool video = false}) {
    if (state.status != CallStatus.idle) return;
    state = state.copyWith(
      status: CallStatus.outgoing,
      peer: peerHint ?? CallPeer(userId: targetUserId),
      withVideo: video,
      clearError: true,
    );
    _ws.sendRaw({'action': 'call.invite', 'target_user_id': targetUserId, 'with_video': video});
    VoiceSfx().playOutgoing();
  }

  void acceptCall() {
    if (state.status != CallStatus.incoming || state.callId == null) return;
    VoiceSfx().stopLoop();
    state = state.copyWith(status: CallStatus.connecting);
    _ws.sendRaw({'action': 'call.accept', 'call_id': state.callId});
  }

  void rejectCall() {
    if (state.status != CallStatus.incoming || state.callId == null) return;
    VoiceSfx().stopLoop();
    _ws.sendRaw({'action': 'call.reject', 'call_id': state.callId});
    _resetToIdle();
  }

  void leaveCall() {
    if (state.status == CallStatus.idle) return;
    _leaveVoiceRoom();
    state = state.copyWith(status: CallStatus.active);
  }

  void endCall() {
    if (state.status == CallStatus.idle) return;
    VoiceSfx().stopLoop();
    if (state.callId != null) {
      _ws.sendRaw({'action': 'call.end', 'call_id': state.callId});
    }
    _leaveVoiceRoom();
    _resetToIdle();
  }

  void _joinVoiceRoom(int pageId) {
    if (pageId <= 0) return;
    final voiceNotifier = _ref.read(voiceSessionProvider.notifier);
    final peerName = state.peer?.name ?? 'Звонок';
    voiceNotifier.join(pageId, pageTitle: peerName, communitySlug: '');
  }

  void _leaveVoiceRoom() {
    try {
      _ref.read(voiceSessionProvider.notifier).leave();
    } catch (_) {}
  }

  void _resetToIdle() {
    state = const CallState();
  }

  @override
  void dispose() {
    _ws.removeListener(_listenerKey);
    super.dispose();
  }
}

final callSessionProvider = StateNotifierProvider<CallSessionNotifier, CallState>((ref) {
  final ws = ref.watch(wsManagerProvider);
  return CallSessionNotifier(ws, ref);
});
