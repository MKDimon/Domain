import '../../core/api/api_client.dart';
import '../models/page.dart';

class SectionsApi {
  final ApiClient _client;
  SectionsApi(this._client);

  Future<Section> get(int id) async {
    final data = await _client.get<Map<String, dynamic>>('/sections/$id');
    return Section.fromJson(data);
  }

  Future<Map<String, dynamic>> create({
    required int pageId,
    required String sectionType,
    int? order,
    Map<String, dynamic>? config,
    Map<String, dynamic>? data,
  }) async {
    return await _client.post<Map<String, dynamic>>('/sections', data: {
      'page_id': pageId,
      'section_type': sectionType,
      if (order != null) 'order': order,
      if (config != null) 'config': config,
      if (data != null) 'data': data,
    });
  }

  Future<Map<String, dynamic>> update(int id, {
    Map<String, dynamic>? config,
    Map<String, dynamic>? data,
    int? order,
  }) async {
    return await _client.patch<Map<String, dynamic>>('/sections/$id', data: {
      if (config != null) 'config': config,
      if (data != null) 'data': data,
      if (order != null) 'order': order,
    });
  }

  Future<void> delete(int id) async {
    await _client.delete('/sections/$id');
  }

  Future<void> reorder(int pageId, List<int> sectionIds) async {
    await _client.post('/pages/$pageId/sections/reorder', data: {
      'section_ids': sectionIds,
    });
  }
}
