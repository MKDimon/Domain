import '../../core/api/api_client.dart';
import '../models/community.dart';

class CategoriesApi {
  final ApiClient _client;
  CategoriesApi(this._client);

  Future<List<Category>> list() async {
    final data = await _client.get<dynamic>('/categories');
    final items = data is List ? data : (data as Map<String, dynamic>)['items'] as List<dynamic>? ?? [];
    return items.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }
}
