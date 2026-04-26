import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exceptions.dart';

typedef SanctionedHandler = void Function(String code, String message, Map<String, dynamic>? details);
typedef UnauthorizedHandler = void Function();

class ApiClient {
  late final Dio _dio;
  String? _token;
  Completer<bool>? _refreshCompleter;
  UnauthorizedHandler? _onUnauthorized;
  SanctionedHandler? _onSanctioned;
  final SecureStorageService _storage;

  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      headers: {'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  void setToken(String? token) {
    _token = token;
  }

  /// Called after token refresh so ws_manager can update its own token.
  void Function(String newToken)? onTokenRefreshed;

  void setUnauthorizedHandler(UnauthorizedHandler handler) {
    _onUnauthorized = handler;
  }

  void setSanctionedHandler(SanctionedHandler handler) {
    _onSanctioned = handler;
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    options.headers['X-Client'] = 'native';
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response == null) {
      handler.reject(err);
      return;
    }

    if (response.statusCode == 401 && _token != null && err.requestOptions.extra['isRetry'] != true) {
      // ignore: avoid_print
      print('[auth] 401 on ${err.requestOptions.path} → trying refresh');
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $_token';
        opts.extra['isRetry'] = true;
        try {
          final retryResponse = await _dio.fetch(opts);
          handler.resolve(retryResponse);
          return;
        } on DioException catch (e) {
          handler.reject(e);
          return;
        }
      }
      if (_refreshTokenMissing) {
        // ignore: avoid_print
        print('[auth] refresh token missing — silently failing ${err.requestOptions.path} (no logout)');
        handler.reject(err);
        return;
      }
      // ignore: avoid_print
      print('[auth] refresh failed → calling unauthorized handler for ${err.requestOptions.path}');
      _onUnauthorized?.call();
      handler.reject(err);
      return;
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'] as Map<String, dynamic>?;
      final code = error?['code'] as String?;
      final message = error?['message'] as String? ?? 'Request failed';
      final details = error?['details'] as Map<String, dynamic>?;

      if (response.statusCode == 403 && (code == 'user_banned' || code == 'user_muted')) {
        _onSanctioned?.call(code!, message, details);
      }

      handler.reject(DioException(
        requestOptions: err.requestOptions,
        response: response,
        error: ApiException(
          message: message,
          code: code,
          details: details,
          statusCode: response.statusCode,
        ),
      ));
      return;
    }

    handler.reject(err);
  }

  int _lastRefreshAt = 0;

  Future<bool> tryRefreshPublic() => _tryRefresh();

  bool _refreshTokenMissing = false;

  Future<bool> _tryRefresh() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastRefreshAt > 0 && now - _lastRefreshAt < 10000) {
      // ignore: avoid_print
      print('[auth] _tryRefresh: skipped (within 10s dedup window)');
      return true;
    }

    if (_refreshCompleter != null) {
      // ignore: avoid_print
      print('[auth] _tryRefresh: waiting for in-flight refresh');
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        // ignore: avoid_print
        print('[auth] _tryRefresh: no refresh token in storage — skipping (not a hard failure)');
        _refreshTokenMissing = true;
        _refreshCompleter!.complete(false);
        return false;
      }

      // ignore: avoid_print
      print('[auth] _tryRefresh: calling /auth/refresh...');
      final response = await Dio(BaseOptions(
        baseUrl: AppConfig.apiBase,
        headers: {'Content-Type': 'application/json', 'X-Client': 'native'},
      )).post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final data = response.data;
      if (data['success'] == false) {
        // ignore: avoid_print
        print('[auth] _tryRefresh: server returned success=false');
        _refreshCompleter!.complete(false);
        return false;
      }

      final newToken = data['data']['token'] as String;
      final newRefreshToken = data['data']['refresh_token'] as String?;
      _token = newToken;
      await _storage.setAccessToken(newToken);
      if (newRefreshToken != null) {
        await _storage.setRefreshToken(newRefreshToken);
      }

      _lastRefreshAt = DateTime.now().millisecondsSinceEpoch;
      _refreshTokenMissing = false;
      onTokenRefreshed?.call(newToken);
      // ignore: avoid_print
      print('[auth] _tryRefresh: OK, new token set');
      _refreshCompleter!.complete(true);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[auth] _tryRefresh: FAILED: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<T> _request<T>(String method, String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
      );

      final body = response.data!;
      if (body['success'] == false) {
        final error = body['error'] as Map<String, dynamic>?;
        throw ApiException(
          message: error?['message'] as String? ?? 'Request failed',
          code: error?['code'] as String?,
          details: error?['details'] as Map<String, dynamic>?,
          statusCode: response.statusCode,
        );
      }

      return body['data'] as T;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      throw ApiException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _request<T>('GET', path, queryParameters: queryParameters);

  Future<T> post<T>(String path, {dynamic data}) =>
      _request<T>('POST', path, data: data);

  Future<T> put<T>(String path, {dynamic data}) =>
      _request<T>('PUT', path, data: data);

  Future<T> patch<T>(String path, {dynamic data}) =>
      _request<T>('PATCH', path, data: data);

  Future<T> delete<T>(String path) =>
      _request<T>('DELETE', path);

  Dio get dio => _dio;
}

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});
