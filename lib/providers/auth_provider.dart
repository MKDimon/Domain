import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/preferences.dart';
import '../core/theme/theme_provider.dart';
import '../core/utils/permissions.dart';
import '../data/api/auth_api.dart';
import '../data/api/users_api.dart';
import '../core/websocket/ws_manager.dart';
import '../data/models/user.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isRestoringSession;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isRestoringSession = true,
    this.error,
  });

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?.isAdmin ?? false;
  bool get isSuperAdmin => user?.isSuperAdmin ?? false;
  bool get emailVerified => user?.emailVerified ?? false;

  bool hasPermission(Permission perm) => roleHasPermission(user?.role, perm);

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isRestoringSession,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) => AuthState(
    user: clearUser ? null : (user ?? this.user),
    isLoading: isLoading ?? this.isLoading,
    isRestoringSession: isRestoringSession ?? this.isRestoringSession,
    error: clearError ? null : (error ?? this.error),
  );
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthApi _authApi;
  late final UsersApi _usersApi;
  late final ApiClient _apiClient;
  late final SecureStorageService _storage;
  late final PreferencesService _prefs;
  late final WsManager _wsManager;
  Timer? _profileRefreshTimer;

  @override
  AuthState build() {
    _apiClient = ref.watch(apiClientProvider);
    _storage = ref.watch(secureStorageProvider);
    _prefs = ref.watch(preferencesProvider);
    _wsManager = ref.watch(wsManagerProvider);
    _authApi = AuthApi(_apiClient);
    _usersApi = UsersApi(_apiClient);

    _apiClient.onTokenRefreshed = (newToken) {
      _wsManager.setUserInfo(
        token: newToken,
        username: state.user?.username ?? '',
        displayName: state.user?.displayName ?? '',
        avatarUrl: state.user?.avatarUrl ?? '',
      );
    };

    Future.microtask(() => _restoreSession());

    return const AuthState();
  }

  Future<void> _restoreSession() async {
    // ignore: avoid_print
    print('[auth] _restoreSession start');
    final savedJson = _prefs.getString('user');
    User? cachedUser;
    if (savedJson != null) {
      try {
        cachedUser = User.fromJson(jsonDecode(savedJson) as Map<String, dynamic>);
      } catch (_) {
        _prefs.remove('user');
      }
    }

    if (cachedUser == null) {
      // ignore: avoid_print
      print('[auth] no cached user → not restoring');
      state = state.copyWith(isRestoringSession: false);
      return;
    }

    state = state.copyWith(user: cachedUser);

    final token = await _storage.getAccessToken();
    // ignore: avoid_print
    print('[auth] accessToken=${token != null ? "${token.substring(0, 10)}..." : "NULL"}');
    if (token != null) {
      _apiClient.setToken(token);
      try {
        final profile = await _usersApi.getMe();
        // ignore: avoid_print
        print('[auth] getMe OK → restored as ${profile.username}');
        _persistUser(profile);
        _connectWs(token, profile);
        _installUnauthorizedHandler();
        _startPeriodicRefresh();
        state = state.copyWith(user: profile, isRestoringSession: false);
        final hasRefresh = await _storage.getRefreshToken();
        if (hasRefresh == null) {
          // ignore: avoid_print
          print('[auth] WARNING: access token works but refresh token is missing — session will expire without renewal');
        }
        return;
      } catch (e) {
        // ignore: avoid_print
        print('[auth] getMe FAILED: $e');
      }
    }

    // ignore: avoid_print
    print('[auth] trying refresh...');
    final refreshed = await _apiClient.tryRefreshPublic();
    // ignore: avoid_print
    print('[auth] refresh result=$refreshed');
    if (!refreshed) {
      await _storage.clearTokens();
      _prefs.remove('user');
      _apiClient.setToken(null);
      // ignore: avoid_print
      print('[auth] refresh failed → logged out');
      state = state.copyWith(isRestoringSession: false, clearUser: true);
      return;
    }

    try {
      final newToken = await _storage.getAccessToken();
      final profile = await _usersApi.getMe();
      // ignore: avoid_print
      print('[auth] refresh+getMe OK → restored as ${profile.username}');
      _persistUser(profile);
      _connectWs(newToken!, profile);
      _installUnauthorizedHandler();
      _startPeriodicRefresh();
      state = state.copyWith(user: profile, isRestoringSession: false);
    } catch (e) {
      await _storage.clearTokens();
      _prefs.remove('user');
      _apiClient.setToken(null);
      // ignore: avoid_print
      print('[auth] refresh OK but getMe failed: $e → logged out');
      state = state.copyWith(isRestoringSession: false, clearUser: true);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _authApi.login(username, password);
      final token = res['token'] as String;
      final refreshToken = res['refresh_token'] as String?;
      await _storage.setAccessToken(token);
      if (refreshToken != null) await _storage.setRefreshToken(refreshToken);
      _apiClient.setToken(token);

      final profile = await _usersApi.getMe();
      _persistUser(profile);
      _connectWs(token, profile);
      _installUnauthorizedHandler();
      _startPeriodicRefresh();
      state = state.copyWith(user: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _authApi.register(username, email, password);
      final token = res['token'] as String?;
      final refreshToken = res['refresh_token'] as String?;

      if (token != null) {
        await _storage.setAccessToken(token);
        if (refreshToken != null) await _storage.setRefreshToken(refreshToken);
        _apiClient.setToken(token);

        try {
          final profile = await _usersApi.getMe();
          _persistUser(profile);
          state = state.copyWith(user: profile, isLoading: false);
        } catch (_) {
          final userData = res['user'] as Map<String, dynamic>?;
          if (userData != null) {
            final user = User.fromJson(userData);
            _persistUser(user);
            state = state.copyWith(user: user, isLoading: false);
          }
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    // ignore: avoid_print
    print('[auth] logout() called');
    // ignore: avoid_print
    print(StackTrace.current.toString().split('\n').take(5).join('\n'));
    _stopPeriodicRefresh();
    _wsManager.disconnect();
    _authApi.logout();
    await _storage.clearTokens();
    _prefs.remove('user');
    _apiClient.setToken(null);
    state = const AuthState(isRestoringSession: false);
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await _usersApi.getMe();
      _persistUser(profile);
      state = state.copyWith(user: profile);
    } catch (_) {}
  }

  void _startPeriodicRefresh() {
    _profileRefreshTimer?.cancel();
    _profileRefreshTimer = Timer.periodic(const Duration(seconds: 120), (_) => refreshProfile());
  }

  void _stopPeriodicRefresh() {
    _profileRefreshTimer?.cancel();
    _profileRefreshTimer = null;
  }

  Future<void> resendVerification() => _authApi.resendVerification();

  void _installUnauthorizedHandler() {
    _apiClient.setUnauthorizedHandler(() => logout());
  }

  void _connectWs(String token, User user) {
    _wsManager.setUserInfo(
      token: token,
      username: user.username,
      displayName: user.displayName ?? '',
      avatarUrl: user.avatarUrl,
    );
    _wsManager.connect();
  }

  void _persistUser(User user) {
    _prefs.setString('user', jsonEncode(user.toJson()));
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider));
});

final usersApiProvider = Provider<UsersApi>((ref) {
  return UsersApi(ref.watch(apiClientProvider));
});

final sessionsApiProvider = Provider((ref) {
  return ref; // placeholder — SessionsApi created in security tab
});

final uploadsApiProvider = Provider((ref) {
  return ref; // placeholder
});
