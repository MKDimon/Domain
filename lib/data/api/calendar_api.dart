import '../../core/api/api_client.dart';

class CalendarApi {
  final ApiClient _client;
  CalendarApi(this._client);

  Future<Map<String, dynamic>> getEvents(int sectionId, String from, String to) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/events?from=$from&to=$to');

  Future<Map<String, dynamic>> createEvent(int sectionId, Map<String, dynamic> data) =>
      _client.post('/sections/$sectionId/events', data: data);

  Future<Map<String, dynamic>> updateEvent(int sectionId, int eventId, Map<String, dynamic> data) =>
      _client.patch('/sections/$sectionId/events/$eventId', data: data);

  Future<void> deleteEvent(int sectionId, int eventId) =>
      _client.delete('/sections/$sectionId/events/$eventId');
}
