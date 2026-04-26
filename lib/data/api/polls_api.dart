import '../../core/api/api_client.dart';

class PollsApi {
  final ApiClient _client;
  PollsApi(this._client);

  Future<Map<String, dynamic>> get(int sectionId) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/poll');

  Future<Map<String, dynamic>> vote(int sectionId, String optionId) =>
      _client.post('/sections/$sectionId/poll/vote', data: {'option_id': optionId});

  Future<void> unvote(int sectionId) =>
      _client.delete('/sections/$sectionId/poll/vote');
}
