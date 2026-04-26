import '../../core/api/api_client.dart';

class FeedbackAttachment {
  final String url;
  final String filename;
  final String type;
  final int size;

  FeedbackAttachment({required this.url, required this.filename, this.type = '', this.size = 0});

  factory FeedbackAttachment.fromJson(Map<String, dynamic> json) => FeedbackAttachment(
    url: json['url'] as String? ?? '',
    filename: json['filename'] as String? ?? '',
    type: json['type'] as String? ?? '',
    size: json['size'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'filename': filename,
    'type': type,
    'size': size,
  };
}

class FeedbackResponse {
  final int id;
  final int feedbackId;
  final int userId;
  final String username;
  final String? avatarUrl;
  final String body;
  final List<FeedbackAttachment> attachments;
  final String createdAt;

  FeedbackResponse({
    required this.id, required this.feedbackId, required this.userId,
    required this.username, this.avatarUrl,
    required this.body, this.attachments = const [], this.createdAt = '',
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) => FeedbackResponse(
    id: json['id'] as int,
    feedbackId: json['feedback_id'] as int? ?? 0,
    userId: json['user_id'] as int? ?? 0,
    username: json['username'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    body: json['body'] as String? ?? '',
    attachments: (json['attachments'] as List<dynamic>?)
        ?.map((a) => FeedbackAttachment.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: json['created_at'] as String? ?? '',
  );
}

class FeedbackItem {
  final int id;
  final int communityId;
  final int userId;
  final String username;
  final String? avatarUrl;
  final String feedbackType; // 'complaint' | 'suggestion' | 'question'
  final String status; // 'new' | 'in_progress' | 'resolved' | 'declined'
  final String body;
  final List<FeedbackAttachment> attachments;
  final int? pageId;
  final String? pageTitle;
  final int responseCount;
  final List<FeedbackResponse> responses;
  final String createdAt;
  final String updatedAt;

  FeedbackItem({
    required this.id, required this.communityId, required this.userId,
    required this.username, this.avatarUrl,
    required this.feedbackType, required this.status, required this.body,
    this.attachments = const [], this.pageId, this.pageTitle,
    this.responseCount = 0, this.responses = const [],
    this.createdAt = '', this.updatedAt = '',
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) => FeedbackItem(
    id: json['id'] as int,
    communityId: json['community_id'] as int? ?? 0,
    userId: json['user_id'] as int? ?? 0,
    username: json['username'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    feedbackType: json['feedback_type'] as String? ?? 'question',
    status: json['status'] as String? ?? 'new',
    body: json['body'] as String? ?? '',
    attachments: (json['attachments'] as List<dynamic>?)
        ?.map((a) => FeedbackAttachment.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    pageId: json['page_id'] as int?,
    pageTitle: json['page_title'] as String?,
    responseCount: json['response_count'] as int? ?? 0,
    responses: (json['responses'] as List<dynamic>?)
        ?.map((r) => FeedbackResponse.fromJson(r as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
  );
}

class FeedbackListResponse {
  final List<FeedbackItem> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final int newCount;
  final int activeCount;
  final int maxActive;

  FeedbackListResponse({
    required this.items, required this.total, required this.page,
    required this.limit, required this.totalPages,
    this.newCount = 0, this.activeCount = 0, this.maxActive = 3,
  });

  factory FeedbackListResponse.fromJson(Map<String, dynamic> json) => FeedbackListResponse(
    items: (json['items'] as List<dynamic>?)
        ?.map((i) => FeedbackItem.fromJson(i as Map<String, dynamic>))
        .toList() ?? [],
    total: json['total'] as int? ?? 0,
    page: json['page'] as int? ?? 1,
    limit: json['limit'] as int? ?? 20,
    totalPages: json['total_pages'] as int? ?? 1,
    newCount: json['new_count'] as int? ?? 0,
    activeCount: json['active_count'] as int? ?? 0,
    maxActive: json['max_active'] as int? ?? 3,
  );
}

class FeedbackApi {
  final ApiClient _client;
  FeedbackApi(this._client);

  /// Moderator view — list all feedback with filters.
  Future<FeedbackListResponse> list(int communityId, {
    int page = 1, int limit = 20, String? feedbackType, String? status,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (feedbackType != null && feedbackType.isNotEmpty) params['feedback_type'] = feedbackType;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/feedback?$qs');
    return FeedbackListResponse.fromJson(data);
  }

  Future<FeedbackItem> get(int communityId, int feedbackId) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/feedback/$feedbackId');
    return FeedbackItem.fromJson(data);
  }

  Future<FeedbackItem> updateStatus(int communityId, int feedbackId, String status) async {
    final data = await _client.patch<Map<String, dynamic>>(
      '/communities/$communityId/feedback/$feedbackId/status',
      data: {'status': status},
    );
    return FeedbackItem.fromJson(data);
  }

  /// User — create new feedback ticket.
  Future<FeedbackItem> create(int communityId, {
    required String feedbackType,
    required String body,
    int? pageId,
    List<FeedbackAttachment> attachments = const [],
  }) async {
    final data = await _client.post<Map<String, dynamic>>('/communities/$communityId/feedback', data: {
      'feedback_type': feedbackType,
      'body': body,
      if (pageId != null) 'page_id': pageId,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    });
    return FeedbackItem.fromJson(data);
  }

  /// User — list own tickets.
  Future<FeedbackListResponse> listMy(int communityId, {int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/communities/$communityId/feedback/my?page=$page&limit=$limit',
    );
    return FeedbackListResponse.fromJson(data);
  }

  /// Both — post a response.
  Future<FeedbackItem> respond(int communityId, int feedbackId, String body, {
    List<FeedbackAttachment> attachments = const [],
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/communities/$communityId/feedback/$feedbackId/responses',
      data: {
        'body': body,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      },
    );
    return FeedbackItem.fromJson(data);
  }
}
