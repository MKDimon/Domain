import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteItem {
  final int pageId;
  final String pageSlug;
  final String pageTitle;
  final int communityId;
  final String addedAt;

  const FavoriteItem({
    required this.pageId,
    required this.pageSlug,
    required this.pageTitle,
    required this.communityId,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'pageId': pageId, 'pageSlug': pageSlug, 'pageTitle': pageTitle, 'addedAt': addedAt,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json, int communityId) => FavoriteItem(
    pageId: json['pageId'] as int,
    pageSlug: json['pageSlug'] as String? ?? '',
    pageTitle: json['pageTitle'] as String? ?? '',
    communityId: communityId,
    addedAt: json['addedAt'] as String? ?? '',
  );
}

class FavoritesService {
  static Future<List<FavoriteItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <FavoriteItem>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('favorites:')) continue;
      final communityId = int.tryParse(key.substring('favorites:'.length));
      if (communityId == null) continue;
      try {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final list = (jsonDecode(raw) as List<dynamic>);
        for (final item in list) {
          out.add(FavoriteItem.fromJson(item as Map<String, dynamic>, communityId));
        }
      } catch (_) {}
    }
    out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return out;
  }

  static Future<List<FavoriteItem>> loadForCommunity(int communityId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('favorites:$communityId');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>, communityId)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> toggle(int communityId, {required int pageId, required String pageSlug, required String pageTitle}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'favorites:$communityId';
    final current = await loadForCommunity(communityId);
    final exists = current.any((f) => f.pageId == pageId);
    List<Map<String, dynamic>> updated;
    if (exists) {
      updated = current.where((f) => f.pageId != pageId).map((f) => f.toJson()).toList();
    } else {
      updated = [
        ...current.map((f) => f.toJson()),
        FavoriteItem(pageId: pageId, pageSlug: pageSlug, pageTitle: pageTitle, communityId: communityId, addedAt: DateTime.now().toIso8601String()).toJson(),
      ];
    }
    await prefs.setString(key, jsonEncode(updated));
  }

  static Future<bool> isFavorite(int communityId, int pageId) async {
    final items = await loadForCommunity(communityId);
    return items.any((f) => f.pageId == pageId);
  }
}
