import '../../core/api/api_client.dart';
import '../models/chat_message.dart';
import '../models/dm_conversation.dart';

class DmMessagesResult {
  final List<ChatMessage> messages;
  final int? otherLastReadId;

  DmMessagesResult({required this.messages, this.otherLastReadId});
}

class DmApi {
  final ApiClient _client;
  DmApi(this._client);

  Future<List<DmConversation>> listConversations() async {
    final data = await _client.get<Map<String, dynamic>>('/dm/conversations');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => DmConversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DmConversation> createConversation(int targetUserId) async {
    final data = await _client.post<Map<String, dynamic>>('/dm/conversations', data: {'target_user_id': targetUserId});
    return DmConversation.fromJson(data);
  }

  Future<DmMessagesResult> listMessages(int conversationId, {int? before, int limit = 50}) async {
    final params = <String>['limit=$limit'];
    if (before != null) params.add('before=$before');
    final data = await _client.get<Map<String, dynamic>>('/dm/conversations/$conversationId/messages?${params.join('&')}');
    final items = data['messages'] as List<dynamic>? ?? data['items'] as List<dynamic>? ?? [];
    return DmMessagesResult(
      messages: items.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList(),
      otherLastReadId: data['other_last_read_id'] as int?,
    );
  }

  Future<ChatMessage> sendMessage(int conversationId, String text, {int? replyToId, List<Map<String, dynamic>>? attachments}) async {
    final body = <String, dynamic>{'text': text};
    if (replyToId != null) body['reply_to_message_id'] = replyToId;
    if (attachments != null) body['attachments'] = attachments;
    final data = await _client.post<Map<String, dynamic>>('/dm/conversations/$conversationId/messages', data: body);
    return ChatMessage.fromJson(data);
  }

  Future<void> deleteMessage(int messageId) =>
      _client.delete('/dm/messages/$messageId');

  Future<void> markAsRead(int conversationId, int lastMessageId) =>
      _client.post('/dm/conversations/$conversationId/read', data: {'last_read_message_id': lastMessageId});

  Future<int> unreadTotal() async {
    final data = await _client.get<Map<String, dynamic>>('/dm/unread-total');
    return data['unread'] as int? ?? 0;
  }

  Future<List<DmConversation>> listRequests() async {
    final data = await _client.get<Map<String, dynamic>>('/dm/requests');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => DmConversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acceptRequest(int conversationId) =>
      _client.post('/dm/requests/$conversationId/accept');

  Future<void> rejectRequest(int conversationId) =>
      _client.post('/dm/requests/$conversationId/reject');

  Future<String> getPolicy() async {
    final data = await _client.get<Map<String, dynamic>>('/dm/policy');
    return data['dm_policy'] as String? ?? 'everyone';
  }

  Future<void> setPolicy(String policy) =>
      _client.put('/dm/policy', data: {'dm_policy': policy});

  Future<List<ChatMessage>> searchMessages(String query, {int? conversationId}) async {
    final params = <String>['q=${Uri.encodeComponent(query)}'];
    if (conversationId != null) params.add('conversation_id=$conversationId');
    final data = await _client.get<Map<String, dynamic>>('/dm/search?${params.join('&')}');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> messagesAround(int conversationId, int anchorId) async {
    return await _client.get<Map<String, dynamic>>('/dm/conversations/$conversationId/messages/around?anchor_id=$anchorId');
  }

  Future<int> findMessageByDate(int conversationId, String date) async {
    final data = await _client.get<Map<String, dynamic>>('/dm/conversations/$conversationId/messages/date-jump?date=$date');
    return data['anchor_id'] as int? ?? 0;
  }

  Future<void> blockUser(int userId) =>
      _client.post('/users/$userId/block');

  Future<void> unblockUser(int userId) =>
      _client.delete('/users/$userId/block');

  Future<List<int>> listBlockedIds() async {
    final data = await _client.get<Map<String, dynamic>>('/users/me/blocks');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map<String, dynamic>)['id'] as int).toList();
  }
}
