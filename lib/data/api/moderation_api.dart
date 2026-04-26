import '../../core/api/api_client.dart';

class BannedWord {
  final int id;
  final String word;
  final bool matchSubstring;
  final bool caseSensitive;

  BannedWord({required this.id, required this.word, this.matchSubstring = true, this.caseSensitive = false});

  factory BannedWord.fromJson(Map<String, dynamic> json) => BannedWord(
    id: json['id'] as int,
    word: json['word'] as String,
    matchSubstring: json['match_substring'] as bool? ?? true,
    caseSensitive: json['case_sensitive'] as bool? ?? false,
  );
}

class ActionLogEntry {
  final int id;
  final String action;
  final String? targetType;
  final String? targetTitle;
  final int? targetId;
  final String username;
  final String? avatarUrl;
  final String? details;
  final String createdAt;

  ActionLogEntry({
    required this.id, required this.action, this.targetType, this.targetTitle,
    this.targetId, required this.username, this.avatarUrl, this.details, this.createdAt = '',
  });

  factory ActionLogEntry.fromJson(Map<String, dynamic> json) => ActionLogEntry(
    id: json['id'] as int,
    action: json['action'] as String? ?? '',
    targetType: json['target_type'] as String?,
    targetTitle: json['target_title'] as String?,
    targetId: json['target_id'] as int?,
    username: json['username'] as String? ?? json['user_name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    details: json['details'] as String?,
    createdAt: json['created_at'] as String? ?? '',
  );
}

class ActionLogStats {
  final int total;
  final int edits;
  final int creates;
  final int deletes;

  ActionLogStats({this.total = 0, this.edits = 0, this.creates = 0, this.deletes = 0});

  factory ActionLogStats.fromJson(Map<String, dynamic> json) => ActionLogStats(
    total: json['total'] as int? ?? 0,
    edits: json['edits'] as int? ?? 0,
    creates: json['creates'] as int? ?? 0,
    deletes: json['deletes'] as int? ?? 0,
  );
}

class ActionLogListResponse {
  final List<ActionLogEntry> items;
  final int total;
  final int page;
  final int totalPages;

  ActionLogListResponse({required this.items, required this.total, required this.page, required this.totalPages});

  factory ActionLogListResponse.fromJson(Map<String, dynamic> json) => ActionLogListResponse(
    items: (json['items'] as List<dynamic>?)
        ?.map((e) => ActionLogEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    total: json['total'] as int? ?? 0,
    page: json['page'] as int? ?? 1,
    totalPages: json['total_pages'] as int? ?? 1,
  );
}

class ModerationApi {
  final ApiClient _client;
  ModerationApi(this._client);

  Future<List<BannedWord>> listBannedWords(int communityId) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/moderation/banned-words');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => BannedWord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BannedWord> addBannedWord(int communityId, String word, {bool matchSubstring = true, bool caseSensitive = false}) async {
    final data = await _client.post<Map<String, dynamic>>('/communities/$communityId/moderation/banned-words', data: {
      'word': word,
      'match_substring': matchSubstring,
      'case_sensitive': caseSensitive,
    });
    return BannedWord.fromJson(data);
  }

  Future<void> removeBannedWord(int communityId, int wordId) =>
      _client.delete('/communities/$communityId/moderation/banned-words/$wordId');

  Future<ActionLogListResponse> listActions(int communityId, {
    int page = 1, int limit = 20, String? action, String? search, String? from, String? to,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (action != null && action.isNotEmpty) params['action'] = action;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/moderation/log?$qs');
    return ActionLogListResponse.fromJson(data);
  }

  Future<ActionLogStats> statsActions(int communityId) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/moderation/log/stats');
    return ActionLogStats.fromJson(data);
  }
}
