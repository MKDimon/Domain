import '../../core/api/api_client.dart';

// ─── Models ───────────────────────────────────────────────────────

class AdminUser {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? email;
  final String role;
  final bool isBanned;
  final int communityLimit;
  final Map<String, dynamic> restrictions;
  final String? bio;
  final String createdAt;
  final int activeWarningsCount;
  final String? mutedUntil;
  final String? bannedUntil;

  AdminUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.email,
    this.role = 'user',
    this.isBanned = false,
    this.communityLimit = 3,
    this.restrictions = const {},
    this.bio,
    this.createdAt = '',
    this.activeWarningsCount = 0,
    this.mutedUntil,
    this.bannedUntil,
  });

  String get effectiveName =>
      (displayName?.isNotEmpty == true) ? displayName! : username;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String? ?? 'user',
        isBanned: json['is_banned'] as bool? ?? false,
        communityLimit: json['community_limit'] as int? ?? 3,
        restrictions: (json['restrictions'] as Map<String, dynamic>?) ?? {},
        bio: json['bio'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        activeWarningsCount: json['active_warnings_count'] as int? ?? 0,
        mutedUntil: json['muted_until'] as String?,
        bannedUntil: json['banned_until'] as String?,
      );
}

class Pagination {
  final int currentPage;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  Pagination({
    this.currentPage = 1,
    this.perPage = 20,
    this.totalItems = 0,
    this.totalPages = 1,
    this.hasNext = false,
    this.hasPrevious = false,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        currentPage: json['current_page'] as int? ?? 1,
        perPage: json['per_page'] as int? ?? 20,
        totalItems: json['total_items'] as int? ?? 0,
        totalPages: json['total_pages'] as int? ?? 1,
        hasNext: json['has_next'] as bool? ?? false,
        hasPrevious: json['has_previous'] as bool? ?? false,
      );
}

class PaginatedUsers {
  final List<AdminUser> items;
  final Pagination pagination;

  PaginatedUsers({required this.items, required this.pagination});

  factory PaginatedUsers.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return PaginatedUsers(
      items: list
          .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
          json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class AdminCommunity {
  final int id;
  final String name;
  final String slug;
  final int? ownerId;
  final String? ownerUsername;
  final int memberCount;
  final int pageCount;
  final String? deletedAt;
  final String createdAt;

  AdminCommunity({
    required this.id,
    required this.name,
    required this.slug,
    this.ownerId,
    this.ownerUsername,
    this.memberCount = 0,
    this.pageCount = 0,
    this.deletedAt,
    this.createdAt = '',
  });

  bool get isClosed => deletedAt != null;

  factory AdminCommunity.fromJson(Map<String, dynamic> json) =>
      AdminCommunity(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        ownerId: json['owner_id'] as int?,
        ownerUsername: json['owner_username'] as String?,
        memberCount: json['member_count'] as int? ?? 0,
        pageCount: json['page_count'] as int? ?? 0,
        deletedAt: json['deleted_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class AdminPage {
  final int id;
  final String title;
  final String slug;
  final String pageType;
  final String visibility;
  final int viewCount;
  final int? communityId;
  final String? communityName;
  String? communitySlug;
  final bool isHidden;
  final String createdAt;

  AdminPage({
    required this.id,
    required this.title,
    required this.slug,
    this.pageType = 'standard',
    this.visibility = 'public',
    this.viewCount = 0,
    this.communityId,
    this.communityName,
    this.communitySlug,
    this.isHidden = false,
    this.createdAt = '',
  });

  factory AdminPage.fromJson(Map<String, dynamic> json) => AdminPage(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        pageType: json['page_type'] as String? ?? 'standard',
        visibility: json['visibility'] as String? ?? 'public',
        viewCount: json['view_count'] as int? ?? 0,
        communityId: json['community_id'] as int?,
        communityName: json['community_name'] as String?,
        communitySlug: json['community_slug'] as String?,
        isHidden: json['is_hidden'] as bool? ?? false,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class PlatformStats {
  final int userCount;
  final int adminCount;
  final int bannedCount;
  final int communityCount;
  final int pageCount;

  PlatformStats({
    this.userCount = 0,
    this.adminCount = 0,
    this.bannedCount = 0,
    this.communityCount = 0,
    this.pageCount = 0,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) => PlatformStats(
        userCount: json['user_count'] as int? ?? 0,
        adminCount: json['admin_count'] as int? ?? 0,
        bannedCount: json['banned_count'] as int? ?? 0,
        communityCount: json['community_count'] as int? ?? 0,
        pageCount: json['page_count'] as int? ?? 0,
      );
}

class Category {
  final int id;
  final String name;
  final String slug;
  final String? icon;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        icon: json['icon'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class SettingEntry {
  final String key;
  final String type;
  final String group;
  final dynamic defaultValue;
  final dynamic value;
  final bool isDefault;

  SettingEntry({
    required this.key,
    required this.type,
    required this.group,
    this.defaultValue,
    this.value,
    this.isDefault = true,
  });

  factory SettingEntry.fromJson(String key, Map<String, dynamic> json) =>
      SettingEntry(
        key: key,
        type: json['type'] as String? ?? 'string',
        group: json['group'] as String? ?? 'other',
        defaultValue: json['default'],
        value: json['value'],
        isDefault: json['is_default'] as bool? ?? true,
      );
}

class PluginInfo {
  final String type;
  final String name;
  final String version;
  final String? description;
  final int communitiesUsing;
  final int sectionsCount;
  final bool loaded;

  PluginInfo({
    required this.type,
    required this.name,
    required this.version,
    this.description,
    this.communitiesUsing = 0,
    this.sectionsCount = 0,
    this.loaded = false,
  });

  factory PluginInfo.fromJson(Map<String, dynamic> json) => PluginInfo(
        type: json['type'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '',
        description: json['description'] as String?,
        communitiesUsing: json['communities_using'] as int? ?? 0,
        sectionsCount: json['sections_count'] as int? ?? 0,
        loaded: json['loaded'] as bool? ?? false,
      );
}

// ─── Analytics Models ─────────────────────────────────────────────

class AnalyticsKpis {
  final int mau;
  final int dau;
  final int newUsers;
  final int newCommunities;
  final int? paying;
  final double? mrr;
  final double? arr;

  AnalyticsKpis({
    this.mau = 0,
    this.dau = 0,
    this.newUsers = 0,
    this.newCommunities = 0,
    this.paying,
    this.mrr,
    this.arr,
  });

  factory AnalyticsKpis.fromJson(Map<String, dynamic> json) => AnalyticsKpis(
        mau: json['mau'] as int? ?? 0,
        dau: json['dau'] as int? ?? 0,
        newUsers: json['new_users'] as int? ?? 0,
        newCommunities: json['new_communities'] as int? ?? 0,
        paying: json['paying'] as int?,
        mrr: (json['mrr'] as num?)?.toDouble(),
        arr: (json['arr'] as num?)?.toDouble(),
      );
}

class FunnelStep {
  final String key;
  final int? count;
  final double? pct;

  FunnelStep({required this.key, this.count, this.pct});

  factory FunnelStep.fromJson(Map<String, dynamic> json) => FunnelStep(
        key: json['key'] as String? ?? '',
        count: json['count'] as int?,
        pct: (json['pct'] as num?)?.toDouble(),
      );
}

class AcquisitionFunnel {
  final int cohortSize;
  final List<FunnelStep> steps;

  AcquisitionFunnel({this.cohortSize = 0, this.steps = const []});

  factory AcquisitionFunnel.fromJson(Map<String, dynamic> json) =>
      AcquisitionFunnel(
        cohortSize: json['cohort_size'] as int? ?? 0,
        steps: (json['steps'] as List<dynamic>? ?? [])
            .map((e) => FunnelStep.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TopCommunityRow {
  final int rank;
  final int id;
  final String name;
  final String slug;
  final String ownerUsername;
  final String createdAt;
  final int totalViews;
  final int activeUsers;
  final int messages;
  final String tier;

  TopCommunityRow({
    this.rank = 0,
    required this.id,
    required this.name,
    required this.slug,
    this.ownerUsername = '',
    this.createdAt = '',
    this.totalViews = 0,
    this.activeUsers = 0,
    this.messages = 0,
    this.tier = 'free',
  });

  factory TopCommunityRow.fromJson(Map<String, dynamic> json) =>
      TopCommunityRow(
        rank: json['rank'] as int? ?? 0,
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        ownerUsername: json['owner_username'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        totalViews: json['total_views'] as int? ?? 0,
        activeUsers: json['active_users'] as int? ?? 0,
        messages: json['messages'] as int? ?? 0,
        tier: json['tier'] as String? ?? 'free',
      );
}

class PluginUsage {
  final int totalCommunities;
  final List<PluginUsageItem> plugins;

  PluginUsage({this.totalCommunities = 0, this.plugins = const []});

  factory PluginUsage.fromJson(Map<String, dynamic> json) => PluginUsage(
        totalCommunities: json['total_communities'] as int? ?? 0,
        plugins: (json['plugins'] as List<dynamic>? ?? [])
            .map((e) => PluginUsageItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PluginUsageItem {
  final String name;
  final int usageCount;

  PluginUsageItem({required this.name, this.usageCount = 0});

  factory PluginUsageItem.fromJson(Map<String, dynamic> json) =>
      PluginUsageItem(
        name: json['name'] as String? ?? '',
        usageCount: json['usage_count'] as int? ?? 0,
      );
}

class ChurnMetrics {
  final bool pending;
  final double? monthlyChurn;
  final int lapsed30d;
  final int activePaying;
  final double? nrr;
  final double? trialToPaid;

  ChurnMetrics({
    this.pending = false,
    this.monthlyChurn,
    this.lapsed30d = 0,
    this.activePaying = 0,
    this.nrr,
    this.trialToPaid,
  });

  factory ChurnMetrics.fromJson(Map<String, dynamic> json) => ChurnMetrics(
        pending: json['pending'] as bool? ?? false,
        monthlyChurn: (json['monthly_churn'] as num?)?.toDouble(),
        lapsed30d: json['lapsed_30d'] as int? ?? 0,
        activePaying: json['active_paying'] as int? ?? 0,
        nrr: (json['nrr'] as num?)?.toDouble(),
        trialToPaid: (json['trial_to_paid'] as num?)?.toDouble(),
      );
}

class RevenuePoint {
  final String date;
  final double amount;

  RevenuePoint({required this.date, this.amount = 0});

  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        date: json['date'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}

class RevenueSeries {
  final bool pending;
  final List<RevenuePoint> points;
  final double total30d;
  final int succeededCount30d;

  RevenueSeries({
    this.pending = false,
    this.points = const [],
    this.total30d = 0,
    this.succeededCount30d = 0,
  });

  factory RevenueSeries.fromJson(Map<String, dynamic> json) => RevenueSeries(
        pending: json['pending'] as bool? ?? false,
        points: (json['points'] as List<dynamic>? ?? [])
            .map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        total30d: (json['total_30d'] as num?)?.toDouble() ?? 0,
        succeededCount30d: json['succeeded_count_30d'] as int? ?? 0,
      );
}

class AnalyticsOverview {
  final int rangeDays;
  final AnalyticsKpis kpis;
  final AcquisitionFunnel funnel;
  final List<TopCommunityRow> topCommunities;
  final PluginUsage pluginUsage;
  final ChurnMetrics churn;
  final RevenueSeries revenue;

  AnalyticsOverview({
    this.rangeDays = 30,
    required this.kpis,
    required this.funnel,
    this.topCommunities = const [],
    required this.pluginUsage,
    required this.churn,
    required this.revenue,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) =>
      AnalyticsOverview(
        rangeDays: json['range_days'] as int? ?? 30,
        kpis:
            AnalyticsKpis.fromJson(json['kpis'] as Map<String, dynamic>? ?? {}),
        funnel: AcquisitionFunnel.fromJson(
            json['funnel'] as Map<String, dynamic>? ?? {}),
        topCommunities: (json['top_communities'] as List<dynamic>? ?? [])
            .map((e) => TopCommunityRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        pluginUsage: PluginUsage.fromJson(
            json['plugin_usage'] as Map<String, dynamic>? ?? {}),
        churn: ChurnMetrics.fromJson(
            json['churn'] as Map<String, dynamic>? ?? {}),
        revenue: RevenueSeries.fromJson(
            json['revenue'] as Map<String, dynamic>? ?? {}),
      );
}

// ─── Complaints Models ────────────────────────────────────────────

class Complaint {
  final int id;
  final int reporterId;
  final String reporterUsername;
  final String reporterAvatar;
  final String targetType;
  final int targetId;
  final Map<String, dynamic> targetSnapshot;
  final String reason;
  final String comment;
  final String status;
  final String resolutionNote;
  final int? resolvedBy;
  final String? resolvedAt;
  final String createdAt;

  Complaint({
    required this.id,
    required this.reporterId,
    this.reporterUsername = '',
    this.reporterAvatar = '',
    required this.targetType,
    required this.targetId,
    this.targetSnapshot = const {},
    required this.reason,
    this.comment = '',
    this.status = 'new',
    this.resolutionNote = '',
    this.resolvedBy,
    this.resolvedAt,
    this.createdAt = '',
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as int,
        reporterId: json['reporter_id'] as int? ?? 0,
        reporterUsername: json['reporter_username'] as String? ?? '',
        reporterAvatar: json['reporter_avatar'] as String? ?? '',
        targetType: json['target_type'] as String? ?? '',
        targetId: json['target_id'] as int? ?? 0,
        targetSnapshot:
            (json['target_snapshot'] as Map<String, dynamic>?) ?? {},
        reason: json['reason'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
        status: json['status'] as String? ?? 'new',
        resolutionNote: json['resolution_note'] as String? ?? '',
        resolvedBy: json['resolved_by'] as int?,
        resolvedAt: json['resolved_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class ComplaintListResponse {
  final List<Complaint> items;
  final int total;
  final Map<String, int> counts;

  ComplaintListResponse({
    this.items = const [],
    this.total = 0,
    this.counts = const {},
  });

  factory ComplaintListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    final countsRaw = json['counts'] as Map<String, dynamic>? ?? {};
    return ComplaintListResponse(
      items: list
          .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      counts:
          countsRaw.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
    );
  }
}

// ─── Moderation Models ────────────────────────────────────────────

class ModerationAction {
  final int id;
  final int userId;
  final int? issuedBy;
  final int? communityId;
  final String actionType;
  final int severity;
  final String reason;
  final List<String> evidenceUrls;
  final String? internalNote;
  final String visibility;
  final String? expiresAt;
  final String? revokedAt;
  final int? revokedBy;
  final String? revokeReason;
  final String createdAt;

  ModerationAction({
    required this.id,
    required this.userId,
    this.issuedBy,
    this.communityId,
    required this.actionType,
    this.severity = 1,
    required this.reason,
    this.evidenceUrls = const [],
    this.internalNote,
    this.visibility = 'mods',
    this.expiresAt,
    this.revokedAt,
    this.revokedBy,
    this.revokeReason,
    this.createdAt = '',
  });

  factory ModerationAction.fromJson(Map<String, dynamic> json) =>
      ModerationAction(
        id: json['id'] as int,
        userId: json['user_id'] as int? ?? 0,
        issuedBy: json['issued_by'] as int?,
        communityId: json['community_id'] as int?,
        actionType: json['action_type'] as String? ?? '',
        severity: json['severity'] as int? ?? 1,
        reason: json['reason'] as String? ?? '',
        evidenceUrls: (json['evidence_urls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        internalNote: json['internal_note'] as String?,
        visibility: json['visibility'] as String? ?? 'mods',
        expiresAt: json['expires_at'] as String?,
        revokedAt: json['revoked_at'] as String?,
        revokedBy: json['revoked_by'] as int?,
        revokeReason: json['revoke_reason'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class ModerationAppeal {
  final int id;
  final int actionId;
  final String userMessage;
  final String status;
  final int? reviewedBy;
  final String? reviewerNote;
  final String createdAt;
  final String? reviewedAt;
  final int? actionUserId;
  final int? actionCommunityId;
  final String? actionActionType;
  final int? actionSeverity;
  final String? actionReason;
  final List<String>? actionEvidenceUrls;
  final String? actionExpiresAt;
  final String? actionCreatedAt;
  final String? userUsername;
  final String? userDisplayName;
  final String? userAvatarUrl;
  final String? issuerUsername;

  ModerationAppeal({
    required this.id,
    required this.actionId,
    required this.userMessage,
    this.status = 'pending',
    this.reviewedBy,
    this.reviewerNote,
    this.createdAt = '',
    this.reviewedAt,
    this.actionUserId,
    this.actionCommunityId,
    this.actionActionType,
    this.actionSeverity,
    this.actionReason,
    this.actionEvidenceUrls,
    this.actionExpiresAt,
    this.actionCreatedAt,
    this.userUsername,
    this.userDisplayName,
    this.userAvatarUrl,
    this.issuerUsername,
  });

  String get effectiveName =>
      (userDisplayName?.isNotEmpty == true) ? userDisplayName! : (userUsername ?? '');

  factory ModerationAppeal.fromJson(Map<String, dynamic> json) =>
      ModerationAppeal(
        id: json['id'] as int,
        actionId: json['action_id'] as int? ?? 0,
        userMessage: json['user_message'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        reviewedBy: json['reviewed_by'] as int?,
        reviewerNote: json['reviewer_note'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        reviewedAt: json['reviewed_at'] as String?,
        actionUserId: json['action_user_id'] as int?,
        actionCommunityId: json['action_community_id'] as int?,
        actionActionType: json['action_action_type'] as String?,
        actionSeverity: json['action_severity'] as int?,
        actionReason: json['action_reason'] as String?,
        actionEvidenceUrls: (json['action_evidence_urls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        actionExpiresAt: json['action_expires_at'] as String?,
        actionCreatedAt: json['action_created_at'] as String?,
        userUsername: json['user_username'] as String?,
        userDisplayName: json['user_display_name'] as String?,
        userAvatarUrl: json['user_avatar_url'] as String?,
        issuerUsername: json['issuer_username'] as String?,
      );
}

class ModerationTemplate {
  final int id;
  final String label;
  final String body;
  final String? defaultType;
  final int? defaultDays;
  final int? communityId;

  ModerationTemplate({
    required this.id,
    required this.label,
    required this.body,
    this.defaultType,
    this.defaultDays,
    this.communityId,
  });

  factory ModerationTemplate.fromJson(Map<String, dynamic> json) =>
      ModerationTemplate(
        id: json['id'] as int,
        label: json['label'] as String? ?? '',
        body: json['body'] as String? ?? '',
        defaultType: json['default_type'] as String?,
        defaultDays: json['default_days'] as int?,
        communityId: json['community_id'] as int?,
      );
}

// ─── API ──────────────────────────────────────────────────────────

class AdminApi {
  final ApiClient _client;
  AdminApi(this._client);

  // ── Stats ──

  Future<PlatformStats> stats() async {
    final data = await _client.get<Map<String, dynamic>>('/admin/stats');
    return PlatformStats.fromJson(data);
  }

  // ── Users ──

  Future<PaginatedUsers> listUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
    String? isBanned,
  }) async {
    final params = <String>['page=$page', 'limit=$limit'];
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (role != null && role.isNotEmpty) params.add('role=$role');
    if (isBanned != null && isBanned.isNotEmpty) {
      params.add('is_banned=$isBanned');
    }
    final data = await _client
        .get<Map<String, dynamic>>('/admin/users?${params.join('&')}');
    return PaginatedUsers.fromJson(data);
  }

  Future<AdminUser> updateUser(int id, Map<String, dynamic> updates) async {
    final data = await _client
        .patch<Map<String, dynamic>>('/admin/users/$id', data: updates);
    return AdminUser.fromJson(data);
  }

  // ── Communities ──

  Future<List<AdminCommunity>> listCommunities() async {
    final data = await _client.get<dynamic>('/admin/communities');
    final list = data is List
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => AdminCommunity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteCommunity(int id) =>
      _client.delete('/admin/communities/$id');

  Future<void> restoreCommunity(int id) =>
      _client.post('/admin/communities/$id/restore', data: {});

  // ── Pages ──

  Future<List<AdminPage>> listPages({int? communityId}) async {
    final q = communityId != null ? '?community_id=$communityId' : '';
    final data = await _client.get<dynamic>('/admin/pages$q');
    final list = data is List
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => AdminPage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePage(int id) => _client.delete('/admin/pages/$id');

  // ── Categories ──

  Future<List<Category>> listCategories() async {
    final data = await _client.get<dynamic>('/categories');
    final list = data is List
        ? data
        : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory(
      {required String name, required String slug, int? sortOrder}) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/admin/categories',
      data: {
        'name': name,
        'slug': slug,
        if (sortOrder != null) 'sort_order': sortOrder,
      },
    );
    return Category.fromJson(data);
  }

  Future<void> deleteCategory(int id) =>
      _client.delete('/admin/categories/$id');

  // ── Settings ──

  Future<Map<String, SettingEntry>> getSettings() async {
    final data =
        await _client.get<Map<String, dynamic>>('/admin/settings');
    final items = data['items'] as Map<String, dynamic>? ?? {};
    return items.map((k, v) =>
        MapEntry(k, SettingEntry.fromJson(k, v as Map<String, dynamic>)));
  }

  Future<void> updateSettings(Map<String, dynamic> settings) =>
      _client.patch('/admin/settings', data: settings);

  // ── Plugins ──

  Future<List<PluginInfo>> listPlugins() async {
    final data = await _client.get<dynamic>('/admin/plugins');
    List list;
    if (data is List) {
      list = data;
    } else {
      list =
          (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    }
    return list
        .map((e) => PluginInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Analytics ──

  Future<AnalyticsOverview> getAnalyticsOverview(
      {String range = '30d'}) async {
    final data = await _client.get<Map<String, dynamic>>(
        '/admin/analytics/overview?range=$range');
    return AnalyticsOverview.fromJson(data);
  }

  // ── Complaints ──

  Future<void> createComplaint({
    required String targetType,
    required int targetId,
    required String reason,
    String? comment,
  }) =>
      _client.post('/complaints', data: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  Future<ComplaintListResponse> listComplaints({
    String? status,
    String? reason,
    String? targetType,
    int? page,
    int limit = 50,
  }) async {
    final params = <String>['limit=$limit'];
    if (status != null && status != 'all') params.add('status=$status');
    if (reason != null && reason != 'all') params.add('reason=$reason');
    if (targetType != null && targetType != 'all') {
      params.add('target_type=$targetType');
    }
    if (page != null) params.add('page=$page');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final data = await _client
        .get<Map<String, dynamic>>('/admin/complaints$qs');
    return ComplaintListResponse.fromJson(data);
  }

  Future<void> updateComplaintStatus(
    int id, {
    required String status,
    String? resolutionNote,
  }) =>
      _client.patch('/admin/complaints/$id', data: {
        'status': status,
        if (resolutionNote != null) 'resolution_note': resolutionNote,
      });

  // ── User Moderation ──

  Future<ModerationAction> issueModeration(
    int userId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.post<Map<String, dynamic>>(
        '/admin/users/$userId/moderation',
        data: payload);
    return ModerationAction.fromJson(data);
  }

  Future<List<ModerationAction>> listUserModeration(int userId) async {
    final data = await _client
        .get<dynamic>('/admin/users/$userId/moderation');
    List list;
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      list = data['items'] as List<dynamic>? ?? [];
    } else {
      list = [];
    }
    return list
        .map((e) => ModerationAction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeModeration(int actionId, {String? reason}) =>
      _client.post('/admin/moderation/$actionId/revoke',
          data: {'reason': reason ?? ''});

  // ── Appeals ──

  Future<({List<ModerationAppeal> items, int totalPending})>
      listAppeals({int limit = 50, int offset = 0}) async {
    final data = await _client.get<Map<String, dynamic>>(
        '/admin/moderation/appeals?limit=$limit&offset=$offset');
    final list = data['items'] as List<dynamic>? ?? [];
    return (
      items: list
          .map((e) => ModerationAppeal.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPending: data['total_pending'] as int? ?? 0,
    );
  }

  Future<void> reviewAppeal(
    int appealId, {
    required String status,
    String? note,
  }) =>
      _client.post('/admin/moderation/appeals/$appealId/review', data: {
        'status': status,
        if (note != null) 'note': note,
      });

  // ── Moderation Templates ──

  Future<List<ModerationTemplate>> listTemplates({int? communityId}) async {
    final q = communityId != null ? '?community_id=$communityId' : '';
    final data =
        await _client.get<dynamic>('/moderation/templates$q');
    final list = data is List ? data : [];
    return list
        .map((e) => ModerationTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Billing (admin) ──

  Future<void> grantSubscription(int userId, int days) =>
      _client.post('/admin/users/$userId/subscription', data: {'days': days});

  Future<void> revokeSubscription(int userId) =>
      _client.delete('/admin/users/$userId/subscription');
}
