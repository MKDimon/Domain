import '../../core/api/api_client.dart';
import '../models/community.dart';

class MembersApi {
  final ApiClient _client;
  MembersApi(this._client);

  Future<List<Member>> list(int communityId, {int page = 1, int limit = 50, String? search, String? role}) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/members?$qs');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Member.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add(int communityId, {required int userId, String role = 'member', List<String> permissions = const []}) =>
      _client.post('/communities/$communityId/members', data: {
        'user_id': userId,
        'role': role,
        'permissions': permissions,
      });

  Future<void> update(int communityId, int userId, {required String role, List<String> permissions = const []}) =>
      _client.patch('/communities/$communityId/members/$userId', data: {
        'role': role,
        'permissions': permissions,
      });

  Future<void> remove(int communityId, int userId) =>
      _client.delete('/communities/$communityId/members/$userId');
}
