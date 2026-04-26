import '../../core/api/api_client.dart';
import '../models/user.dart';

class SessionsApi {
  final ApiClient _client;
  SessionsApi(this._client);

  Future<List<UserSession>> list() async {
    final data = await _client.get<Map<String, dynamic>>('/users/me/sessions');
    final items = data['items'] as List<dynamic>;
    return items.map((e) => UserSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revoke(String id) =>
      _client.delete('/users/me/sessions/$id');

  Future<void> revokeAll() =>
      _client.delete('/users/me/sessions');
}
