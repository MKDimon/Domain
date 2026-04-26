import '../../core/api/api_client.dart';

class AnnouncementsApi {
  final ApiClient _client;
  AnnouncementsApi(this._client);

  Future<Map<String, dynamic>> list(int sectionId, {int page = 1, int limit = 20}) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/announcements?page=$page&limit=$limit');

  Future<Map<String, dynamic>> create(int sectionId, Map<String, dynamic> data) =>
      _client.post('/sections/$sectionId/announcements', data: data);

  Future<Map<String, dynamic>> update(int sectionId, int id, Map<String, dynamic> data) =>
      _client.patch('/sections/$sectionId/announcements/$id', data: data);

  Future<void> delete(int sectionId, int id) =>
      _client.delete('/sections/$sectionId/announcements/$id');

  Future<void> pin(int sectionId, int id) =>
      _client.post('/sections/$sectionId/announcements/$id/pin');

  Future<void> markRead(int sectionId, int id) =>
      _client.post('/sections/$sectionId/announcements/$id/read');
}
