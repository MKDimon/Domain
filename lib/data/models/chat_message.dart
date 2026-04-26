class ChatAttachment {
  final int id;
  final String url;
  final String filename;
  final String type;
  final int size;

  const ChatAttachment({
    required this.id,
    required this.url,
    required this.filename,
    required this.type,
    required this.size,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    id: json['id'] as int? ?? 0,
    url: json['url'] as String,
    filename: json['filename'] as String,
    type: json['type'] as String,
    size: json['size'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'filename': filename,
    'type': type,
    'size': size,
  };
}

class ChatReplyRef {
  final int id;
  final String? text;
  final String? username;
  final String? displayName;
  final bool deleted;

  const ChatReplyRef({
    required this.id,
    this.text,
    this.username,
    this.displayName,
    this.deleted = false,
  });

  factory ChatReplyRef.fromJson(Map<String, dynamic> json) => ChatReplyRef(
    id: json['id'] as int? ?? 0,
    text: json['text'] as String?,
    username: json['username'] as String?,
    displayName: json['display_name'] as String?,
    deleted: json['deleted'] as bool? ?? false,
  );
}

class ChatMessage {
  final int id;
  final int sectionId;
  final int? conversationId;
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String text;
  final String createdAt;
  final List<ChatAttachment> attachments;
  final String? chatFont;
  final int? chatFontSize;
  final String? chatTextColor;
  final String? chatUsernameColor;
  final String? chatBubbleColor;
  final ChatReplyRef? replyTo;
  final String? messageType;
  final Map<String, dynamic>? meta;

  const ChatMessage({
    required this.id,
    required this.sectionId,
    this.conversationId,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.text,
    required this.createdAt,
    this.attachments = const [],
    this.chatFont,
    this.chatFontSize,
    this.chatTextColor,
    this.chatUsernameColor,
    this.chatBubbleColor,
    this.replyTo,
    this.messageType,
    this.meta,
  });

  String get authorName => displayName?.isNotEmpty == true ? displayName! : username;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int? ?? 0,
    sectionId: json['section_id'] as int? ?? 0,
    conversationId: json['conversation_id'] as int?,
    userId: json['user_id'] as int? ?? 0,
    username: json['username'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    text: json['text'] as String,
    createdAt: json['created_at'] as String,
    attachments: (json['attachments'] as List<dynamic>?)
        ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    chatFont: json['chat_font'] as String?,
    chatFontSize: json['chat_font_size'] as int?,
    chatTextColor: json['chat_text_color'] as String?,
    chatUsernameColor: json['chat_username_color'] as String?,
    chatBubbleColor: json['chat_bubble_color'] as String?,
    replyTo: json['reply_to'] != null
        ? ChatReplyRef.fromJson(json['reply_to'] as Map<String, dynamic>)
        : null,
    messageType: json['message_type'] as String?,
    meta: json['meta'] as Map<String, dynamic>?,
  );
}

class ChatConversation {
  final int id;
  final int sectionId;
  final int userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String createdAt;
  final String updatedAt;
  final String? lastMessageText;
  final String? lastMessageAt;
  final int messageCount;
  int unreadCount;

  ChatConversation({
    required this.id,
    required this.sectionId,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageText,
    this.lastMessageAt,
    required this.messageCount,
    this.unreadCount = 0,
  });

  String get authorName => displayName?.isNotEmpty == true ? displayName! : username;
  String get initial => authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
    id: json['id'] as int? ?? 0,
    sectionId: json['section_id'] as int? ?? 0,
    userId: json['user_id'] as int? ?? 0,
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    createdAt: json['created_at'] as String? ?? '',
    updatedAt: json['updated_at'] as String? ?? '',
    lastMessageText: json['last_message_text'] as String?,
    lastMessageAt: json['last_message_at'] as String?,
    messageCount: json['message_count'] as int? ?? 0,
    unreadCount: json['unread_count'] as int? ?? 0,
  );
}

class MessagesResponse {
  final List<ChatMessage> items;
  final int? total;
  final int? maxOtherReadId;

  const MessagesResponse({required this.items, this.total, this.maxOtherReadId});

  factory MessagesResponse.fromJson(Map<String, dynamic> json) => MessagesResponse(
    items: (json['items'] as List<dynamic>)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    total: json['total'] as int?,
    maxOtherReadId: json['max_other_read_id'] as int?,
  );
}

class UnreadEntry {
  final int sectionId;
  final int? conversationId;
  final int unreadCount;

  const UnreadEntry({required this.sectionId, this.conversationId, required this.unreadCount});

  factory UnreadEntry.fromJson(Map<String, dynamic> json) => UnreadEntry(
    sectionId: json['section_id'] as int? ?? 0,
    conversationId: json['conversation_id'] as int?,
    unreadCount: json['unread_count'] as int? ?? 0,
  );
}

class UnreadCounts {
  final List<UnreadEntry> counts;
  final Map<String, int> totalPerSection;

  const UnreadCounts({required this.counts, required this.totalPerSection});

  factory UnreadCounts.fromJson(Map<String, dynamic> json) => UnreadCounts(
    counts: (json['counts'] as List<dynamic>)
        .map((c) => UnreadEntry.fromJson(c as Map<String, dynamic>))
        .toList(),
    totalPerSection: (json['total_per_section'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as int)) ?? {},
  );
}
