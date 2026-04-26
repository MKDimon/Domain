class DmOtherUser {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? lastSeenAt;

  DmOtherUser({required this.id, required this.username, this.displayName, this.avatarUrl, this.lastSeenAt});

  String get name => (displayName?.isNotEmpty == true) ? displayName! : username;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory DmOtherUser.fromJson(Map<String, dynamic> json) => DmOtherUser(
    id: json['id'] as int? ?? 0,
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    lastSeenAt: json['last_seen_at'] as String?,
  );
}

class DmLastMessage {
  final int id;
  final String text;
  final int userId;
  final String? createdAt;
  final String? messageType;
  final int attachmentCount;
  final int imageCount;

  DmLastMessage({required this.id, this.text = '', required this.userId, this.createdAt, this.messageType, this.attachmentCount = 0, this.imageCount = 0});

  factory DmLastMessage.fromJson(Map<String, dynamic> json) => DmLastMessage(
    id: json['id'] as int? ?? 0,
    text: json['text'] as String? ?? '',
    userId: json['user_id'] as int? ?? 0,
    createdAt: json['created_at'] as String?,
    messageType: json['message_type'] as String?,
    attachmentCount: json['attachment_count'] as int? ?? 0,
    imageCount: json['image_count'] as int? ?? 0,
  );
}

class DmConversation {
  final int id;
  final DmOtherUser other;
  final int unreadCount;
  final int? myLastReadId;
  final String? lastMessageAt;
  final String createdAt;
  final DmLastMessage? lastMessage;
  final String requestStatus;

  DmConversation({
    required this.id,
    required this.other,
    this.unreadCount = 0,
    this.myLastReadId,
    this.lastMessageAt,
    this.createdAt = '',
    this.lastMessage,
    this.requestStatus = 'none',
  });

  bool get isPending => requestStatus == 'pending';
  bool get isRejected => requestStatus == 'rejected';

  DmConversation copyWith({
    int? id, DmOtherUser? other, int? unreadCount, int? myLastReadId,
    String? lastMessageAt, String? createdAt, DmLastMessage? lastMessage, String? requestStatus,
  }) => DmConversation(
    id: id ?? this.id,
    other: other ?? this.other,
    unreadCount: unreadCount ?? this.unreadCount,
    myLastReadId: myLastReadId ?? this.myLastReadId,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    createdAt: createdAt ?? this.createdAt,
    lastMessage: lastMessage ?? this.lastMessage,
    requestStatus: requestStatus ?? this.requestStatus,
  );

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    final otherMap = json['other'] as Map<String, dynamic>?;
    final other = otherMap != null
        ? DmOtherUser.fromJson(otherMap)
        : DmOtherUser(
            id: json['other_id'] as int? ?? 0,
            username: json['other_username'] as String? ?? '',
            displayName: json['other_display_name'] as String?,
            avatarUrl: json['other_avatar_url'] as String?,
            lastSeenAt: json['other_last_seen'] as String?,
          );

    final lastMsgMap = json['last_message'] as Map<String, dynamic>?;
    final lastMessage = lastMsgMap != null
        ? DmLastMessage.fromJson(lastMsgMap)
        : (json['last_message_text'] != null || json['last_message_user_id'] != null || json['last_message_type'] != null)
            ? DmLastMessage(
                id: 0,
                text: json['last_message_text'] as String? ?? '',
                userId: json['last_message_user_id'] as int? ?? 0,
                createdAt: json['last_message_created'] as String?,
                messageType: json['last_message_type'] as String?,
                attachmentCount: json['last_message_att_count'] as int? ?? 0,
                imageCount: json['last_message_img_count'] as int? ?? 0,
              )
            : null;

    return DmConversation(
      id: json['id'] as int? ?? 0,
      other: other,
      unreadCount: json['unread_count'] as int? ?? 0,
      myLastReadId: json['my_last_read_id'] as int?,
      lastMessageAt: json['last_message_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      lastMessage: lastMessage,
      requestStatus: json['request_status'] as String? ?? 'none',
    );
  }
}
