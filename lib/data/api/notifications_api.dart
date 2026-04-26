import '../../core/api/api_client.dart';

class AppNotification {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final String? readAt;
  final String createdAt;

  bool get isRead => readAt != null;

  AppNotification({required this.id, required this.type, this.payload = const {}, this.readAt, this.createdAt = ''});

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as int,
    type: json['type'] as String? ?? 'system',
    payload: json['payload'] as Map<String, dynamic>? ?? {},
    readAt: json['read_at'] as String?,
    createdAt: json['created_at'] as String? ?? '',
  );
}

class NotificationPref {
  final String eventKey;
  final bool inApp;
  final bool email;

  NotificationPref({required this.eventKey, this.inApp = true, this.email = false});

  factory NotificationPref.fromJson(Map<String, dynamic> json) => NotificationPref(
    eventKey: json['event_key'] as String,
    inApp: json['in_app'] as bool? ?? true,
    email: json['email'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'event_key': eventKey, 'in_app': inApp, 'email': email};
}

class NotificationsApi {
  final ApiClient _client;
  NotificationsApi(this._client);

  Future<List<AppNotification>> list({int page = 1, int limit = 20, bool unreadOnly = false}) async {
    final qs = 'page=$page&limit=$limit${unreadOnly ? '&unread=true' : ''}';
    final data = await _client.get<Map<String, dynamic>>('/notifications?$qs');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final data = await _client.get<Map<String, dynamic>>('/notifications/unread-count');
    return data['count'] as int? ?? 0;
  }

  Future<void> markRead(int id) => _client.post('/notifications/$id/read');

  Future<int> markAllRead() async {
    final data = await _client.post<Map<String, dynamic>>('/notifications/read-all');
    return data['count'] as int? ?? 0;
  }

  Future<List<NotificationPref>> listPrefs() async {
    final data = await _client.get<dynamic>('/users/me/notification-prefs');
    final items = data is List ? data : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return items.map((e) => NotificationPref.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updatePref(NotificationPref pref) =>
      _client.patch('/users/me/notification-prefs', data: pref.toJson());
}
