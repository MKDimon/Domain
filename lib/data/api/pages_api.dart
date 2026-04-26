import '../../core/api/api_client.dart';
import '../models/page.dart';

class PagesApi {
  final ApiClient _client;
  PagesApi(this._client);

  Future<Page> get(int id) async {
    final data = await _client.get<Map<String, dynamic>>('/pages/$id');
    return Page.fromJson(data);
  }

  Future<List<Section>> listSections(int pageId) async {
    final data = await _client.get<dynamic>('/pages/$pageId/sections');
    final items = data is List ? data : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return items.map((e) => Section.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> recordView(int id) => _client.post('/pages/$id/view');

  Future<Map<String, dynamic>> create({
    required int communityId,
    required String title,
    required String slug,
    String? pageType,
    String? visibility,
    Map<String, dynamic>? metadata,
    String? imageUrl,
  }) async {
    return await _client.post<Map<String, dynamic>>('/pages', data: {
      'community_id': communityId,
      'title': title,
      'slug': slug,
      if (pageType != null) 'page_type': pageType,
      if (visibility != null) 'visibility': visibility,
      if (metadata != null) 'metadata': metadata,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async {
    return await _client.patch<Map<String, dynamic>>('/pages/$id', data: data);
  }

  Future<void> delete(int id) async {
    await _client.delete('/pages/$id');
  }

  Future<void> pin(int id, bool pinned) async {
    await _client.patch('/pages/$id/pin', data: {'pinned': pinned});
  }
}
