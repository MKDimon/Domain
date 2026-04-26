import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

typedef WsCallback = void Function(WsEvent event);

enum WsEventType {
  messageCreated,
  messageDeleted,
  readStatusUpdated,
  unreadChanged,
  conversationUpdated,
  reconnected,
  typing,
  presenceUpdate,
  presenceBulk,
  voiceRoster,
  voiceError,
  voiceSignal,
  dmMessage,
  dmMessageDeleted,
  dmRead,
  dmTyping,
  dmRequestStatus,
}

WsEventType? wsEventTypeFromString(String s) => switch (s) {
  'message.created' => WsEventType.messageCreated,
  'message.deleted' => WsEventType.messageDeleted,
  'read_status.updated' => WsEventType.readStatusUpdated,
  'unread.changed' => WsEventType.unreadChanged,
  'conversation.updated' => WsEventType.conversationUpdated,
  'reconnected' => WsEventType.reconnected,
  'typing' => WsEventType.typing,
  'presence.update' => WsEventType.presenceUpdate,
  'presence.bulk' => WsEventType.presenceBulk,
  'voice.roster' => WsEventType.voiceRoster,
  'voice.error' => WsEventType.voiceError,
  'voice.signal' => WsEventType.voiceSignal,
  'dm.message' => WsEventType.dmMessage,
  'dm.message.deleted' => WsEventType.dmMessageDeleted,
  'dm.read' => WsEventType.dmRead,
  'dm.typing' => WsEventType.dmTyping,
  'dm.request_status' => WsEventType.dmRequestStatus,
  _ => null,
};

class WsEvent {
  final WsEventType type;
  final String rawType;
  final int sectionId;
  final int? conversationId;
  final Map<String, dynamic>? data;

  const WsEvent({required this.type, this.rawType = '', required this.sectionId, this.conversationId, this.data});

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? '';
    final type = wsEventTypeFromString(typeStr) ?? WsEventType.messageCreated;
    return WsEvent(
      type: type,
      rawType: typeStr,
      sectionId: json['section_id'] as int? ?? 0,
      conversationId: json['conversation_id'] as int?,
      data: json,
    );
  }
}

class WsManager {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectDelay = 1000;
  static const _maxReconnectDelay = 30000;
  bool _isConnected = false;
  bool _pongReceived = true;
  bool _disposed = false;
  bool _wasConnected = false;

  String? _token;
  String _username = '';
  String _displayName = '';
  String _avatarUrl = '';

  final _callbacks = <String, Set<WsCallback>>{};
  final _sectionRefCounts = <int, int>{};
  final _voicePageRefCounts = <int, int>{};
  final _connectionController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  WsManager();

  void setUserInfo({required String token, required String username, String displayName = '', String avatarUrl = ''}) {
    _token = token;
    _username = username;
    _displayName = displayName;
    _avatarUrl = avatarUrl;
  }

  void connect() {
    if (_disposed) return;
    if (_channel != null) return;
    if (_token == null || _token!.isEmpty) return;

    try {
      final wsUrl = '${AppConfig.wsBase}/';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _subscription = _channel!.stream.listen(
      _onMessage,
      onDone: _onClose,
      onError: (_) => _channel?.sink.close(),
    );

    // Server expects {action: "auth"} as first message — it does NOT send
    // auth_required, unlike what the earlier branch assumes. The web client
    // sends auth immediately in socket.onopen; do the same here. The sink
    // queues until the underlying TCP/WS handshake completes.
    _sendJson({
      'action': 'auth',
      'token': _token,
      'username': _username,
      'display_name': _displayName,
      'avatar_url': _avatarUrl,
    });
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      if (type == 'pong') {
        _pongReceived = true;
        return;
      }

      if (type == 'connected') {
        _isConnected = true;
        _connectionController.add(true);
        _reconnectDelay = 1000;
        _startHeartbeat();
        for (final sectionId in _sectionRefCounts.keys) {
          _sendJson({'action': 'subscribe', 'section_id': sectionId});
        }
        final voiceIds = _voicePageRefCounts.keys.toList();
        if (voiceIds.isNotEmpty) {
          _sendJson({'action': 'voice.subscribe', 'page_ids': voiceIds});
        }
        if (_wasConnected) {
          _dispatch(const WsEvent(type: WsEventType.reconnected, sectionId: 0));
        }
        _wasConnected = true;
        return;
      }

      if (type == 'error') return;
      if (type == 'auth_required') {
        _sendJson({
          'action': 'auth',
          'token': _token,
          'username': _username,
          'display_name': _displayName,
          'avatar_url': _avatarUrl,
        });
        return;
      }

      final eventType = wsEventTypeFromString(type);
      if (type.startsWith('voice.') || type.startsWith('call.')) {
        // ignore: avoid_print
        print('[ws] RX $type pageId=${msg['page_id']} listeners=${_callbacks.values.fold<int>(0, (a, s) => a + s.length)}');
      }
      _dispatch(WsEvent(
        type: eventType ?? WsEventType.messageCreated,
        rawType: type,
        sectionId: msg['section_id'] as int? ?? 0,
        conversationId: msg['conversation_id'] as int?,
        data: msg,
      ));
    } catch (_) {}
  }

  void _onClose() {
    _isConnected = false;
    _connectionController.add(false);
    _channel = null;
    _subscription = null;
    _stopHeartbeat();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_reconnectTimer != null) return;
    if (_token == null || _token!.isEmpty) return;

    _reconnectTimer = Timer(Duration(milliseconds: _reconnectDelay), () {
      _reconnectTimer = null;
      connect();
      _reconnectDelay = (_reconnectDelay * 2).clamp(1000, _maxReconnectDelay);
    });
  }

  void reconnectNow() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectDelay = 1000;
    if (_isConnected) return;
    disconnect(clearState: false);
    connect();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _pongReceived = true;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_isConnected) return;
      if (!_pongReceived) {
        _channel?.sink.close();
        return;
      }
      _pongReceived = false;
      _sendJson({'action': 'ping'});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _sendJson(Map<String, dynamic> obj) {
    try {
      final action = obj['action'] as String?;
      if (action != null && (action.startsWith('voice.') || action.startsWith('call.'))) {
        // ignore: avoid_print
        print('[ws] TX $action ${{...obj}..remove('action')}');
      }
      _channel?.sink.add(jsonEncode(obj));
    } catch (_) {}
  }

  void _dispatch(WsEvent event) {
    for (final cbSet in _callbacks.values) {
      for (final cb in cbSet) {
        try { cb(event); } catch (_) {}
      }
    }
  }

  String subscribe(int sectionId) {
    final count = _sectionRefCounts[sectionId] ?? 0;
    _sectionRefCounts[sectionId] = count + 1;
    if (count == 0 && _isConnected) {
      _sendJson({'action': 'subscribe', 'section_id': sectionId});
    }
    connect();
    return sectionId.toString();
  }

  void unsubscribe(int sectionId) {
    final count = _sectionRefCounts[sectionId] ?? 0;
    if (count <= 1) {
      _sectionRefCounts.remove(sectionId);
      if (_isConnected) {
        _sendJson({'action': 'unsubscribe', 'section_id': sectionId});
      }
    } else {
      _sectionRefCounts[sectionId] = count - 1;
    }
  }

  void subscribeVoicePages(List<int> pageIds) {
    if (pageIds.isEmpty) return;
    final newIds = <int>[];
    for (final id in pageIds) {
      final count = _voicePageRefCounts[id] ?? 0;
      _voicePageRefCounts[id] = count + 1;
      if (count == 0) newIds.add(id);
    }
    // ignore: avoid_print
    print('[ws] subscribeVoicePages input=$pageIds new=$newIds connected=$_isConnected');
    if (newIds.isNotEmpty && _isConnected) {
      _sendJson({'action': 'voice.subscribe', 'page_ids': newIds});
    }
  }

  void unsubscribeVoicePages(List<int> pageIds) {
    if (pageIds.isEmpty) return;
    final toDrop = <int>[];
    for (final id in pageIds) {
      final count = _voicePageRefCounts[id] ?? 0;
      if (count <= 1) {
        _voicePageRefCounts.remove(id);
        toDrop.add(id);
      } else {
        _voicePageRefCounts[id] = count - 1;
      }
    }
    if (toDrop.isNotEmpty && _isConnected) {
      _sendJson({'action': 'voice.unsubscribe', 'page_ids': toDrop});
    }
  }

  String addListener(WsCallback cb) {
    final key = DateTime.now().microsecondsSinceEpoch.toString();
    _callbacks[key] = {cb};
    return key;
  }

  WsCallback on(String listenerKey, WsEventType type, WsCallback cb) {
    wrapped(WsEvent event) {
      if (event.type == type) cb(event);
    }
    _callbacks.putIfAbsent(listenerKey, () => {});
    _callbacks[listenerKey]!.add(wrapped);
    return wrapped;
  }

  void onAny(String listenerKey, WsCallback cb) {
    _callbacks.putIfAbsent(listenerKey, () => {});
    _callbacks[listenerKey]!.add(cb);
  }

  void off(String listenerKey, WsCallback handle) {
    _callbacks[listenerKey]?.remove(handle);
  }

  void removeListener(String key) {
    _callbacks.remove(key);
  }

  void sendTyping(int sectionId, String username, {int? conversationId, bool stop = false}) {
    final msg = <String, dynamic>{
      'action': 'typing',
      'section_id': sectionId,
      'username': username,
    };
    if (conversationId != null) msg['conversation_id'] = conversationId;
    if (stop) msg['stop'] = true;
    _sendJson(msg);
  }

  void sendDmTyping(int conversationId, int targetUserId, {bool stop = false}) {
    final msg = <String, dynamic>{
      'action': 'dm.typing',
      'conversation_id': conversationId,
      'target_user_id': targetUserId,
    };
    if (stop) msg['stop'] = true;
    _sendJson(msg);
  }

  void sendRaw(Map<String, dynamic> obj) => _sendJson(obj);

  void disconnect({bool clearState = true}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    _subscription?.cancel();
    _subscription = null;
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _isConnected = false;
    _connectionController.add(false);
    if (clearState) {
      _wasConnected = false;
      _callbacks.clear();
      _sectionRefCounts.clear();
      _voicePageRefCounts.clear();
      _reconnectDelay = 1000;
      _token = null;
    }
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _connectionController.close();
  }
}

final wsManagerProvider = Provider<WsManager>((ref) {
  final manager = WsManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});
