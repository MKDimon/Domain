import '../../core/api/api_client.dart';
import '../models/chat_message.dart';

class ChatApi {
  final ApiClient _client;
  ChatApi(this._client);

  Future<MessagesResponse> getMessages(int sectionId, {int limit = 50, int before = 0, int conversationId = 0}) async {
    final params = <String, dynamic>{'limit': limit};
    if (before > 0) params['before'] = before;
    if (conversationId > 0) params['conversation_id'] = conversationId;
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/messages',
      queryParameters: params,
    );
    return MessagesResponse.fromJson(data);
  }

  Future<ChatMessage> sendMessage(
    int sectionId,
    String text, {
    int conversationId = 0,
    List<Map<String, dynamic>>? attachments,
    int replyToMessageId = 0,
    Map<String, dynamic>? styles,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (conversationId > 0) body['conversation_id'] = conversationId;
    if (attachments != null && attachments.isNotEmpty) body['attachments'] = attachments;
    if (replyToMessageId > 0) body['reply_to_message_id'] = replyToMessageId;
    if (styles != null) body.addAll(styles);
    final data = await _client.post<Map<String, dynamic>>('/sections/$sectionId/messages', data: body);
    return ChatMessage.fromJson(data);
  }

  Future<MessagesResponse> pollMessages(int sectionId, int afterId, {int conversationId = 0}) async {
    final params = <String, dynamic>{'after_id': afterId};
    if (conversationId > 0) params['conversation_id'] = conversationId;
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/messages/poll',
      queryParameters: params,
    );
    return MessagesResponse.fromJson(data);
  }

  Future<void> deleteMessage(int sectionId, int messageId) async {
    await _client.delete<dynamic>('/sections/$sectionId/messages/$messageId');
  }

  Future<List<ChatMessage>> searchMessages(int sectionId, String query, {int limit = 20, int before = 0, int conversationId = 0}) async {
    final params = <String, dynamic>{'q': query, 'limit': limit};
    if (before > 0) params['before'] = before;
    if (conversationId > 0) params['conversation_id'] = conversationId;
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/messages/search',
      queryParameters: params,
    );
    return (data['items'] as List<dynamic>)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getMessagesAround(int sectionId, int anchorId, {int conversationId = 0}) async {
    final params = <String, dynamic>{'anchor_id': anchorId};
    if (conversationId > 0) params['conversation_id'] = conversationId;
    return await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/messages/around',
      queryParameters: params,
    );
  }

  Future<int> findMessageByDate(int sectionId, String date, {int conversationId = 0}) async {
    final params = <String, dynamic>{'date': date};
    if (conversationId > 0) params['conversation_id'] = conversationId;
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/messages/date-jump',
      queryParameters: params,
    );
    return data['anchor_id'] as int;
  }

  Future<List<ChatConversation>> getConversations(int sectionId, {int limit = 50, int before = 0}) async {
    final params = <String, dynamic>{'limit': limit};
    if (before > 0) params['before'] = before;
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/conversations',
      queryParameters: params,
    );
    return (data['items'] as List<dynamic>? ?? [])
        .map((c) => ChatConversation.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<ChatConversation> getConversation(int sectionId, int conversationId) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/conversations/$conversationId',
    );
    return ChatConversation.fromJson(data);
  }

  Future<void> markAsRead(int sectionId, int lastReadMessageId, {int conversationId = 0}) async {
    final body = <String, dynamic>{'last_read_message_id': lastReadMessageId};
    if (conversationId > 0) body['conversation_id'] = conversationId;
    await _client.post<dynamic>('/sections/$sectionId/read', data: body);
  }

  Future<UnreadCounts> getUnreadCounts(int communityId) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$communityId/unread-counts');
    return UnreadCounts.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> mentionCandidates(int sectionId, {String q = ''}) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['q'] = q;
    final data = await _client.get<Map<String, dynamic>>(
      '/sections/$sectionId/mention-candidates',
      queryParameters: params,
    );
    return (data['items'] as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
