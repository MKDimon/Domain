import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../storage/secure_storage.dart';
import '../../providers/auth_provider.dart';

class OAuthHandler {
  final Ref _ref;
  StreamSubscription? _sub;

  OAuthHandler(this._ref);

  void init() {
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen(_handleUri);
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void dispose() {
    _sub?.cancel();
  }

  Future<void> _handleUri(Uri uri) async {
    if (uri.scheme != 'domain' || uri.host != 'oauth-callback') return;

    final refreshToken = uri.queryParameters['refresh_token'];
    if (refreshToken == null || refreshToken.isEmpty) return;

    try {
      final storage = _ref.read(secureStorageProvider);
      await storage.setRefreshToken(refreshToken);

      final apiClient = _ref.read(apiClientProvider);
      final ok = await apiClient.tryRefreshPublic();
      if (ok) {
        await _ref.read(authProvider.notifier).refreshProfile();
      }
    } catch (_) {}
  }
}

final oauthHandlerProvider = Provider<OAuthHandler>((ref) {
  final handler = OAuthHandler(ref);
  handler.init();
  ref.onDispose(() => handler.dispose());
  return handler;
});
