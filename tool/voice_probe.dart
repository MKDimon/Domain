// Standalone console script to probe the voice WebSocket protocol.
//
// Usage:
//   dart tool/voice_probe.dart <email> <password> <community_slug> [page_slug]
//
// Connects as the given user, subscribes to voice rosters in the community,
// optionally sends voice.join to the named voice page, and prints every
// frame it receives for diagnosis.
//
// Does NOT open a microphone or create peer connections — purely signaling.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

const _apiBase = 'http://localhost:8070/api/v1';
// WS runs on a separate port (HTTP port + 1). Docker maps 8071->8072 on host.
const _wsBase = 'ws://localhost:8072';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('usage: dart tool/voice_probe.dart <email> <password> <community_slug> [voice_page_slug]');
    exit(64);
  }
  final email = args[0];
  final password = args[1];
  final slug = args[2];
  final voicePageSlug = args.length > 3 ? args[3] : null;

  // 1) Login — get token + me
  // API login takes `username` (may be email-like or username).
  final loginResp = await _post('$_apiBase/auth/login', {
    'username': email,
    'password': password,
  });
  if (loginResp.statusCode != 200) {
    stderr.writeln('login failed: ${loginResp.statusCode} ${loginResp.body}');
    exit(1);
  }
  final loginBody = jsonDecode(loginResp.body) as Map<String, dynamic>;
  // API envelope: { data: { token, user }, error: null, meta: {...}, success: true }
  final loginData = (loginBody['data'] as Map<String, dynamic>?) ?? loginBody;
  final token = loginData['token'] as String?
      ?? loginData['access_token'] as String?;
  if (token == null) {
    stderr.writeln('no token in login response: $loginBody');
    exit(1);
  }
  stdout.writeln('[probe] logged in, token len=${token.length}');

  Map<String, dynamic> unwrap(String body) {
    final parsed = jsonDecode(body) as Map<String, dynamic>;
    final data = parsed['data'];
    return (data is Map<String, dynamic>) ? data : parsed;
  }

  final meResp = await _get('$_apiBase/users/me', token);
  final me = unwrap(meResp.body);
  final myId = me['id'] as int?;
  final myUsername = me['username'] as String? ?? '';
  final myDisplayName = me['display_name'] as String? ?? myUsername;
  final myAvatarUrl = me['avatar_url'] as String? ?? '';
  stdout.writeln('[probe] me id=$myId username=$myUsername');

  // 2) Resolve community & pages
  final commResp = await _get('$_apiBase/communities/by-slug/$slug', token);
  if (commResp.statusCode != 200) {
    stderr.writeln('community not found: ${commResp.statusCode} ${commResp.body}');
    exit(1);
  }
  final comm = unwrap(commResp.body);
  final commId = comm['id'] as int;
  stdout.writeln('[probe] community id=$commId name=${comm['name']}');

  final pagesResp = await _get('$_apiBase/communities/$commId/pages', token);
  final pagesBody = jsonDecode(pagesResp.body);
  List<dynamic> pagesList;
  if (pagesBody is List) {
    pagesList = pagesBody;
  } else if (pagesBody is Map<String, dynamic>) {
    final inner = pagesBody['data'] ?? pagesBody['items'] ?? pagesBody;
    if (inner is List) {
      pagesList = inner;
    } else if (inner is Map<String, dynamic>) {
      pagesList = (inner['items'] as List<dynamic>?) ?? [];
    } else {
      pagesList = [];
    }
  } else {
    pagesList = [];
  }
  final voicePages = pagesList
      .whereType<Map<String, dynamic>>()
      .where((p) => p['page_type'] == 'voice')
      .toList();
  stdout.writeln('[probe] voice pages: ${voicePages.map((p) => '${p['id']}/${p['slug']}').join(', ')}');

  int? joinPageId;
  if (voicePageSlug != null) {
    final target = voicePages.firstWhere(
      (p) => p['slug'] == voicePageSlug,
      orElse: () => {},
    );
    if (target.isEmpty) {
      stderr.writeln('voice page slug "$voicePageSlug" not found');
      exit(1);
    }
    joinPageId = target['id'] as int;
  }

  // 3) Connect WebSocket
  final ws = IOWebSocketChannel.connect(Uri.parse(_wsBase));
  stdout.writeln('[probe] ws connecting to $_wsBase');

  // Server expects `auth` as the first message (no auth_required handshake).
  _send(ws, {
    'action': 'auth',
    'token': token,
    'username': myUsername,
    'display_name': myDisplayName,
    'avatar_url': myAvatarUrl,
  });

  final completer = Completer<void>();
  ws.stream.listen(
    (raw) {
      _handleMessage(ws, raw, token, myUsername, myDisplayName, myAvatarUrl, voicePages, joinPageId);
    },
    onDone: () {
      stdout.writeln('[probe] ws closed');
      if (!completer.isCompleted) completer.complete();
    },
    onError: (err) {
      stderr.writeln('[probe] ws error: $err');
      if (!completer.isCompleted) completer.completeError(err);
    },
  );

  // Keep process alive so we see roster updates, signals, etc.
  // Ctrl+C to exit.
  ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('[probe] bye');
    if (joinPageId != null) {
      _send(ws, {'action': 'voice.leave', 'page_id': joinPageId});
    }
    ws.sink.close();
    exit(0);
  });

  await completer.future;
}

void _handleMessage(
  IOWebSocketChannel ws,
  dynamic raw,
  String token,
  String myUsername,
  String myDisplayName,
  String myAvatarUrl,
  List<Map<String, dynamic>> voicePages,
  int? joinPageId,
) {
  try {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = msg['type'] as String? ?? '';
    final preview = jsonEncode(msg).replaceAll('\n', ' ');
    stdout.writeln('[rx] $type  ${preview.length > 400 ? '${preview.substring(0, 400)}…' : preview}');

    // (No auth_required — server expects auth as first client message.)
    if (type == 'connected') {
      // Subscribe to all voice pages in the community
      final ids = voicePages.map((p) => p['id'] as int).toList();
      if (ids.isNotEmpty) {
        _send(ws, {'action': 'voice.subscribe', 'page_ids': ids});
      }
      if (joinPageId != null) {
        // Delay join so server can process subscribe first — mirrors the
        // UI flow (user subscribes when opening community, then clicks join).
        Timer(const Duration(seconds: 1), () {
          _send(ws, {
            'action': 'voice.join',
            'page_id': joinPageId,
            'is_muted': false,
            'is_video': false,
          });
        });
      }
      return;
    }
  } catch (e) {
    stderr.writeln('[probe] parse error: $e  raw=$raw');
  }
}

void _send(IOWebSocketChannel ws, Map<String, dynamic> obj) {
  final enc = jsonEncode(obj);
  stdout.writeln('[tx] $enc');
  ws.sink.add(enc);
}

Future<HttpClientResponseBuf> _get(String url, String token) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('Authorization', 'Bearer $token');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    return HttpClientResponseBuf(resp.statusCode, body);
  } finally {
    client.close();
  }
}

Future<HttpClientResponseBuf> _post(String url, Map<String, dynamic> body) async {
  final client = HttpClient();
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set('Content-Type', 'application/json');
    req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close();
    final bodyStr = await resp.transform(utf8.decoder).join();
    return HttpClientResponseBuf(resp.statusCode, bodyStr);
  } finally {
    client.close();
  }
}

class HttpClientResponseBuf {
  final int statusCode;
  final String body;
  HttpClientResponseBuf(this.statusCode, this.body);
}
