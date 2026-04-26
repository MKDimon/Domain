class Page {
  final int id;
  final int communityId;
  final String title;
  final String slug;
  final String pageType;
  final String visibility;
  final int viewCount;
  final bool pinned;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? layoutConfig;
  final String createdAt;
  final String updatedAt;

  Page({
    required this.id,
    required this.communityId,
    required this.title,
    required this.slug,
    this.pageType = 'standard',
    this.visibility = 'public',
    this.viewCount = 0,
    this.pinned = false,
    this.imageUrl,
    this.metadata,
    this.layoutConfig,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory Page.fromJson(Map<String, dynamic> json) => Page(
    id: json['id'] as int,
    communityId: json['community_id'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    pageType: json['page_type'] as String? ?? 'standard',
    visibility: json['visibility'] as String? ?? 'public',
    viewCount: json['view_count'] as int? ?? 0,
    pinned: json['pinned'] as bool? ?? false,
    imageUrl: json['image_url'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>?,
    layoutConfig: json['layout_config'] as Map<String, dynamic>?,
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
  );
}

class Section {
  final int id;
  final int pageId;
  final String sectionType;
  final int order;
  final Map<String, dynamic> config;
  final Map<String, dynamic> data;

  Section({
    required this.id,
    required this.pageId,
    required this.sectionType,
    this.order = 0,
    this.config = const {},
    this.data = const {},
  });

  String get title => config['title'] as String? ?? '';
  List<dynamic> get blocks => data['blocks'] as List<dynamic>? ?? [];
  String get markdownContent => data['content'] as String? ?? '';
  String get contentMode => data['mode'] as String? ?? 'blocks';

  factory Section.fromJson(Map<String, dynamic> json) => Section(
    id: json['id'] as int,
    pageId: json['page_id'] as int? ?? 0,
    sectionType: json['section_type'] as String? ?? 'content',
    order: json['order'] as int? ?? 0,
    config: json['config'] as Map<String, dynamic>? ?? {},
    data: json['data'] as Map<String, dynamic>? ?? {},
  );
}
