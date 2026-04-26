import '../../core/api/api_client.dart';
import '../models/user.dart';

class UsersApi {
  final ApiClient _client;
  UsersApi(this._client);

  Future<User> getMe() async {
    final data = await _client.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(data);
  }

  Future<PublicProfile> getProfile(int id) async {
    final data = await _client.get<Map<String, dynamic>>('/users/$id');
    return PublicProfile.fromJson(data);
  }

  Future<PublicProfile> getProfileByUsername(String username) async {
    final data = await _client.get<Map<String, dynamic>>('/users/${Uri.encodeComponent(username)}');
    return PublicProfile.fromJson(data);
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final data = await _client.patch<Map<String, dynamic>>('/users/me', data: updates);
    return User.fromJson(data);
  }

  Future<void> changePassword(String oldPassword, String newPassword) =>
      _client.post('/users/me/password', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

  Future<void> deleteMe() => _client.delete('/users/me');

  Future<Map<String, dynamic>> exportMe() =>
      _client.get<Map<String, dynamic>>('/users/me/export');

  /// Autocomplete search for users by username/email.
  Future<List<PublicProfile>> search(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];
    final data = await _client.get<Map<String, dynamic>>(
      '/users/search?q=${Uri.encodeComponent(query)}&limit=$limit',
    );
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => PublicProfile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> getPresenceVisibility() async {
    final data = await _client.get<Map<String, dynamic>>('/users/me/presence-visibility');
    return data['presence_visibility'] as String? ?? 'visible';
  }

  Future<void> setPresenceVisibility(String visibility) =>
      _client.put('/users/me/presence-visibility', data: {
        'presence_visibility': visibility,
      });
}
