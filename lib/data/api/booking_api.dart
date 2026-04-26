import '../../core/api/api_client.dart';

class BookingApi {
  final ApiClient _client;
  BookingApi(this._client);

  Future<Map<String, dynamic>> getSlots(int sectionId, String date, {int? specialistId, int? serviceId}) {
    final params = <String, String>{'date': date};
    if (specialistId != null) params['specialist_id'] = '$specialistId';
    if (serviceId != null) params['service_id'] = '$serviceId';
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _client.get<Map<String, dynamic>>('/sections/$sectionId/booking/slots?$qs');
  }

  Future<Map<String, dynamic>> getAppointments(int sectionId, {String? date}) {
    final qs = date != null ? '?date=$date' : '';
    return _client.get<Map<String, dynamic>>('/sections/$sectionId/booking/appointments$qs');
  }

  Future<Map<String, dynamic>> createAppointment(int sectionId, Map<String, dynamic> data) =>
      _client.post('/sections/$sectionId/booking/appointments', data: data);

  Future<Map<String, dynamic>> updateAppointment(int sectionId, int id, Map<String, dynamic> data) =>
      _client.patch('/sections/$sectionId/booking/appointments/$id', data: data);

  Future<Map<String, dynamic>> getSpecialists(int sectionId) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/booking/specialists');

  Future<Map<String, dynamic>> createSpecialist(int sectionId, Map<String, dynamic> data) =>
      _client.post('/sections/$sectionId/booking/specialists', data: data);

  Future<Map<String, dynamic>> updateSpecialist(int sectionId, int id, Map<String, dynamic> data) =>
      _client.patch('/sections/$sectionId/booking/specialists/$id', data: data);

  Future<void> deleteSpecialist(int sectionId, int id) =>
      _client.delete('/sections/$sectionId/booking/specialists/$id');

  Future<Map<String, dynamic>> getOverrides(int sectionId) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/booking/overrides');

  Future<Map<String, dynamic>> createOverride(int sectionId, Map<String, dynamic> data) =>
      _client.post('/sections/$sectionId/booking/overrides', data: data);

  Future<void> deleteOverride(int sectionId, int id) =>
      _client.delete('/sections/$sectionId/booking/overrides/$id');

  Future<Map<String, dynamic>> getServices(int sectionId) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/booking/services');

  Future<Map<String, dynamic>> createService(int sectionId, Map<String, dynamic> data) =>
      _client.post('/sections/$sectionId/booking/services', data: data);

  Future<Map<String, dynamic>> updateService(int sectionId, int id, Map<String, dynamic> data) =>
      _client.patch('/sections/$sectionId/booking/services/$id', data: data);

  Future<void> deleteService(int sectionId, int id) =>
      _client.delete('/sections/$sectionId/booking/services/$id');

  Future<Map<String, dynamic>> setServiceSpecialists(int sectionId, int serviceId, List<int> specialistIds) =>
      _client.put('/sections/$sectionId/booking/services/$serviceId/specialists', data: {'specialist_ids': specialistIds});
}
