import '../../core/api/api_client.dart';
import '../models/community.dart';

class CommunitiesApi {
  final ApiClient _client;
  CommunitiesApi(this._client);

  Future<List<Community>> list({int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>('/communities?page=$page&limit=$limit');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Community.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Community>> listForMe() async {
    final data = await _client.get<Map<String, dynamic>>('/users/me/communities');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Community.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RecentVisit>> recentVisits({int limit = 10}) async {
    final data = await _client.get<Map<String, dynamic>>('/users/me/recent-visits?limit=$limit');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => RecentVisit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Community> get(int id) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$id');
    return Community.fromJson(data);
  }

  Future<Community> getBySlug(String slug) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/by-slug/$slug');
    return Community.fromJson(data);
  }

  Future<Community> create({required String name, required String slug, Map<String, dynamic>? settings}) async {
    final body = <String, dynamic>{
      'name': name,
      'slug': slug,
    };
    if (settings != null) body['settings'] = settings;
    final data = await _client.post<Map<String, dynamic>>('/communities', data: body);
    return Community.fromJson(data);
  }

  Future<Community> update(int id, Map<String, dynamic> updates) async {
    final data = await _client.patch<Map<String, dynamic>>('/communities/$id', data: updates);
    return Community.fromJson(data);
  }

  Future<void> delete(int id) => _client.delete('/communities/$id');

  Future<List<PageSummary>> getPages(int id) async {
    final data = await _client.get<Map<String, dynamic>>('/communities/$id/pages');
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => PageSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Community>> popular({String metric = 'session', int limit = 12, int windowDays = 30}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/communities/popular?metric=$metric&limit=$limit&window_days=$windowDays',
    );
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => Community.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PageSummary>> getPopularPages(int id, {int limit = 5, String metric = 'session', int windowDays = 30}) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/communities/$id/pages/popular?limit=$limit&metric=$metric&window_days=$windowDays',
    );
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) => PageSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> recordView(int id) => _client.post('/communities/$id/view');
  Future<void> joinPublic(int id) => _client.post('/communities/$id/join');
  Future<void> leave(int id) => _client.post('/communities/$id/leave');

  Future<Community> enrichWithCounts(Community comm) async {
    int mc = 0, pc = 0;
    try {
      final resp = await _client.get<Map<String, dynamic>>('/communities/${comm.id}/members?limit=1');
      final pagination = resp['pagination'] as Map<String, dynamic>?;
      mc = pagination?['total_items'] as int? ?? (resp['items'] as List?)?.length ?? 0;
    } catch (_) {}
    try {
      final pages = await getPages(comm.id);
      pc = pages.where((p) => p.pageType != 'main' && p.pageType != 'chat').length;
    } catch (_) {}
    return comm.copyWith(memberCount: mc, pageCount: pc);
  }

  Future<List<Community>> enrichListWithCounts(List<Community> comms) async {
    return Future.wait(comms.map(enrichWithCounts));
  }
}
