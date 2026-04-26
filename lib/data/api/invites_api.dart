import '../../core/api/api_client.dart';

class Invite {
  final int id;
  final String token;
  final String? inviteeUsername;
  final String? inviterUsername;
  final String createdAt;

  Invite({required this.id, required this.token, this.inviteeUsername, this.inviterUsername, this.createdAt = ''});

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
    id: json['id'] as int,
    token: json['token'] as String? ?? '',
    inviteeUsername: json['invitee_username'] as String?,
    inviterUsername: json['inviter_username'] as String? ?? json['inviter_name'] as String?,
    createdAt: json['created_at'] as String? ?? '',
  );
}

class InvitesApi {
  final ApiClient _client;
  InvitesApi(this._client);

  Future<Invite> create(int communityId, {int expiresInHours = 168}) async {
    final data = await _client.post<Map<String, dynamic>>('/communities/$communityId/invites', data: {
      'expires_in_hours': expiresInHours,
    });
    return Invite.fromJson(data);
  }

  Future<void> inviteUser(int communityId, String query) =>
      _client.post('/communities/$communityId/invites/user', data: {'query': query});

  Future<List<Invite>> list(int communityId) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/invites');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Invite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revoke(int communityId, int inviteId) =>
      _client.delete('/communities/$communityId/invites/$inviteId');

  Future<void> joinByToken(String token) => _client.post('/invites/$token/join');
  Future<void> joinPublic(int communityId) => _client.post('/communities/$communityId/join');
  Future<void> leave(int communityId) => _client.post('/communities/$communityId/leave');
}
