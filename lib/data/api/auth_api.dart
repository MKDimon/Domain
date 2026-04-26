import '../../core/api/api_client.dart';

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  Future<Map<String, dynamic>> login(String username, String password) =>
      _client.post('/auth/login', data: {'username': username, 'password': password});

  Future<Map<String, dynamic>> register(String username, String email, String password) =>
      _client.post('/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });

  Future<Map<String, dynamic>> refresh() =>
      _client.post('/auth/refresh');

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } catch (_) {}
  }

  Future<void> resendVerification() =>
      _client.post('/auth/resend-verification');
}
