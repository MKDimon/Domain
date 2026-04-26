import '../../core/api/api_client.dart';

class FriendUser {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? lastSeenAt;

  FriendUser({required this.id, required this.username, this.displayName, this.avatarUrl, this.lastSeenAt});

  String get effectiveName => (displayName?.isNotEmpty == true) ? displayName! : username;

  factory FriendUser.fromJson(Map<String, dynamic> json) => FriendUser(
    id: json['id'] as int,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    lastSeenAt: json['last_seen_at'] as String?,
  );
}

class FriendListEntry {
  final int friendshipId;
  final String friendSince;
  final FriendUser user;

  FriendListEntry({required this.friendshipId, required this.friendSince, required this.user});

  factory FriendListEntry.fromJson(Map<String, dynamic> json) => FriendListEntry(
    friendshipId: json['friendship_id'] as int,
    friendSince: json['friend_since'] as String,
    user: FriendUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class FriendRequestEntry {
  final int friendshipId;
  final String createdAt;
  final FriendUser user;

  FriendRequestEntry({required this.friendshipId, required this.createdAt, required this.user});

  factory FriendRequestEntry.fromJson(Map<String, dynamic> json) => FriendRequestEntry(
    friendshipId: json['friendship_id'] as int,
    createdAt: json['created_at'] as String,
    user: FriendUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class FriendsApi {
  final ApiClient _client;
  FriendsApi(this._client);

  Future<List<FriendListEntry>> list() async {
    final data = await _client.get<Map<String, dynamic>>('/friends');
    final items = data['items'] as List<dynamic>;
    return items.map((e) => FriendListEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FriendRequestEntry>> incoming() async {
    final data = await _client.get<Map<String, dynamic>>('/friends/requests/incoming');
    final items = data['items'] as List<dynamic>;
    return items.map((e) => FriendRequestEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FriendRequestEntry>> outgoing() async {
    final data = await _client.get<Map<String, dynamic>>('/friends/requests/outgoing');
    final items = data['items'] as List<dynamic>;
    return items.map((e) => FriendRequestEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> incomingCount() async {
    final data = await _client.get<Map<String, dynamic>>('/friends/incoming-count');
    return data['count'] as int? ?? 0;
  }

  Future<void> sendRequest(int targetId) =>
      _client.post('/friends/request/$targetId');

  Future<void> accept(int friendshipId) =>
      _client.post('/friends/$friendshipId/accept');

  Future<void> reject(int friendshipId) =>
      _client.post('/friends/$friendshipId/reject');

  Future<void> unfriend(int otherUserId) =>
      _client.delete('/friends/$otherUserId');

  Future<({String status, int? friendshipId})> statusWith(int otherUserId) async {
    final data = await _client.get<Map<String, dynamic>>('/friends/status/$otherUserId');
    return (
      status: data['status'] as String? ?? 'none',
      friendshipId: data['friendship_id'] as int?,
    );
  }
}
