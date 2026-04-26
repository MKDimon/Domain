class Community {
  final int id;
  final String name;
  final String slug;
  final int ownerId;
  final String? description;
  final String? avatarUrl;
  final String? categorySlug;
  final bool isPublic;
  final int memberCount;
  final int pageCount;
  final String createdAt;
  final Map<String, dynamic> settings;
  final String? myRole;
  final int views30d;
  final int unreadCount;
  final String? lastVisitedAt;

  Community({
    required this.id,
    required this.name,
    required this.slug,
    required this.ownerId,
    this.description,
    this.avatarUrl,
    this.categorySlug,
    this.isPublic = true,
    this.memberCount = 0,
    this.pageCount = 0,
    this.createdAt = '',
    this.settings = const {},
    this.myRole,
    this.views30d = 0,
    this.unreadCount = 0,
    this.lastVisitedAt,
  });

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  Community copyWith({
    int? id, String? name, String? slug, int? ownerId, String? description,
    String? avatarUrl, String? categorySlug, bool? isPublic,
    int? memberCount, int? pageCount, String? createdAt, Map<String, dynamic>? settings,
    String? myRole, int? views30d, int? unreadCount, String? lastVisitedAt,
  }) => Community(
    id: id ?? this.id,
    name: name ?? this.name,
    slug: slug ?? this.slug,
    ownerId: ownerId ?? this.ownerId,
    description: description ?? this.description,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    categorySlug: categorySlug ?? this.categorySlug,
    isPublic: isPublic ?? this.isPublic,
    memberCount: memberCount ?? this.memberCount,
    pageCount: pageCount ?? this.pageCount,
    createdAt: createdAt ?? this.createdAt,
    settings: settings ?? this.settings,
    myRole: myRole ?? this.myRole,
    views30d: views30d ?? this.views30d,
    unreadCount: unreadCount ?? this.unreadCount,
    lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
  );

  factory Community.fromJson(Map<String, dynamic> json) => Community(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    ownerId: json['owner_id'] as int? ?? 0,
    description: (json['settings'] as Map<String, dynamic>?)?['description'] as String?,
    avatarUrl: (json['settings'] as Map<String, dynamic>?)?['avatar_url'] as String?,
    categorySlug: json['category_slug'] as String?,
    isPublic: (json['settings'] as Map<String, dynamic>?)?['public'] as bool? ?? true,
    memberCount: json['member_count'] as int? ?? 0,
    pageCount: json['page_count'] as int? ?? 0,
    createdAt: json['created_at'] as String? ?? '',
    settings: json['settings'] as Map<String, dynamic>? ?? {},
    myRole: json['my_role'] as String?,
    views30d: json['views_30d'] as int? ?? 0,
    unreadCount: json['unread_count'] as int? ?? 0,
    lastVisitedAt: json['last_visited_at'] as String?,
  );
}

class RecentVisit {
  final int communityId;
  final String communitySlug;
  final String communityName;
  final Map<String, dynamic>? communitySettings;
  final int? pageId;
  final String? pageSlug;
  final String? pageTitle;
  final String? pageType;
  final String visitedAt;

  RecentVisit({
    required this.communityId, required this.communitySlug, required this.communityName,
    this.communitySettings, this.pageId, this.pageSlug, this.pageTitle, this.pageType,
    required this.visitedAt,
  });

  String? get communityAvatarUrl => communitySettings?['avatar_url'] as String?;

  factory RecentVisit.fromJson(Map<String, dynamic> json) {
    final settings = json['community_settings'];
    Map<String, dynamic>? parsedSettings;
    if (settings is Map<String, dynamic>) {
      parsedSettings = settings;
    } else if (settings is String && settings.isNotEmpty) {
      try { parsedSettings = Map<String, dynamic>.from(Uri.splitQueryString(settings)); } catch (_) {}
    }
    return RecentVisit(
      communityId: json['community_id'] as int? ?? 0,
      communitySlug: json['community_slug'] as String? ?? '',
      communityName: json['community_name'] as String? ?? '',
      communitySettings: parsedSettings,
      pageId: json['page_id'] as int?,
      pageSlug: json['page_slug'] as String?,
      pageTitle: json['page_title'] as String?,
      pageType: json['page_type'] as String?,
      visitedAt: json['visited_at'] as String? ?? '',
    );
  }
}

class Category {
  final int id;
  final String name;
  final String slug;
  final String icon;
  final int sortOrder;

  Category({required this.id, required this.name, required this.slug, this.icon = '', this.sortOrder = 0});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    icon: json['icon'] as String? ?? '',
    sortOrder: json['sort_order'] as int? ?? 0,
  );
}

class PageSummary {
  final int id;
  final String title;
  final String slug;
  final String pageType;
  final int viewCount;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  final String? visibility;
  final bool isPinned;
  final String? updatedAt;
  final int? chatSectionId;

  PageSummary({
    required this.id,
    required this.title,
    required this.slug,
    this.pageType = 'standard',
    this.viewCount = 0,
    this.imageUrl,
    this.metadata,
    this.visibility,
    this.isPinned = false,
    this.updatedAt,
    this.chatSectionId,
  });

  String? get iconEmoji => metadata?['icon'] as String?;
  String? get iconType => metadata?['icon_type'] as String?;
  bool get isDefaultChat => metadata?['is_default_chat'] == true;

  PageSummary copyWith({
    int? id, String? title, String? slug, String? pageType, int? viewCount,
    String? imageUrl, Map<String, dynamic>? metadata, String? visibility,
    bool? isPinned, String? updatedAt, int? chatSectionId,
  }) => PageSummary(
    id: id ?? this.id,
    title: title ?? this.title,
    slug: slug ?? this.slug,
    pageType: pageType ?? this.pageType,
    viewCount: viewCount ?? this.viewCount,
    imageUrl: imageUrl ?? this.imageUrl,
    metadata: metadata ?? this.metadata,
    visibility: visibility ?? this.visibility,
    isPinned: isPinned ?? this.isPinned,
    updatedAt: updatedAt ?? this.updatedAt,
    chatSectionId: chatSectionId ?? this.chatSectionId,
  );

  factory PageSummary.fromJson(Map<String, dynamic> json) => PageSummary(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    pageType: json['page_type'] as String? ?? 'standard',
    viewCount: json['metric_count'] as int? ?? json['view_count'] as int? ?? 0,
    imageUrl: json['image_url'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>?,
    visibility: json['visibility'] as String?,
    isPinned: json['is_pinned'] as bool? ?? false,
    updatedAt: json['updated_at'] as String?,
    chatSectionId: json['chat_section_id'] as int?,
  );
}

class Member {
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final List<String> permissions;

  Member({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.role = 'member',
    this.permissions = const [],
  });

  String get effectiveName => (displayName?.isNotEmpty == true) ? displayName! : username;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    userId: json['user_id'] as int,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    role: json['role'] as String? ?? 'member',
    permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ?? [],
  );
}
