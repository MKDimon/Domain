import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../data/api/communities_api.dart';
import '../data/api/pages_api.dart';
import '../data/api/sections_api.dart';
import '../data/models/community.dart';
import '../data/models/page.dart';

class EditorSection {
  int? id;
  String sectionType;
  int order;
  Map<String, dynamic> config;
  Map<String, dynamic> data;
  bool isDirty;

  EditorSection({
    this.id,
    required this.sectionType,
    this.order = 0,
    Map<String, dynamic>? config,
    Map<String, dynamic>? data,
    this.isDirty = false,
  })  : config = config ?? {},
        data = data ?? {};

  EditorSection deepCopy() => EditorSection(
        id: id,
        sectionType: sectionType,
        order: order,
        config: _deepClone(config),
        data: _deepClone(data),
        isDirty: isDirty,
      );

  static Map<String, dynamic> _deepClone(Map<String, dynamic> map) =>
      json.decode(json.encode(map)) as Map<String, dynamic>;
}

class EditorState {
  final int? pageId;
  final String pageType;
  final List<EditorSection> sections;
  final List<int> deletedSectionIds;
  final Map<String, dynamic> layoutConfig;
  final bool layoutDirty;
  final bool isSaving;
  final bool isLoading;
  final String? error;
  final List<PageSummary> communityPages;
  final String communitySlug;
  final String? communityColorHex;

  const EditorState({
    this.pageId,
    this.pageType = 'standard',
    this.sections = const [],
    this.deletedSectionIds = const [],
    this.layoutConfig = const {},
    this.layoutDirty = false,
    this.isSaving = false,
    this.isLoading = false,
    this.error,
    this.communityPages = const [],
    this.communitySlug = '',
    this.communityColorHex,
  });

  bool get isDirty =>
      layoutDirty ||
      deletedSectionIds.isNotEmpty ||
      sections.any((s) => s.isDirty);

  EditorState copyWith({
    int? pageId,
    String? pageType,
    List<EditorSection>? sections,
    List<int>? deletedSectionIds,
    Map<String, dynamic>? layoutConfig,
    bool? layoutDirty,
    bool? isSaving,
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<PageSummary>? communityPages,
    String? communitySlug,
    String? communityColorHex,
  }) =>
      EditorState(
        pageId: pageId ?? this.pageId,
        pageType: pageType ?? this.pageType,
        sections: sections ?? this.sections,
        deletedSectionIds: deletedSectionIds ?? this.deletedSectionIds,
        layoutConfig: layoutConfig ?? this.layoutConfig,
        layoutDirty: layoutDirty ?? this.layoutDirty,
        isSaving: isSaving ?? this.isSaving,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        communityPages: communityPages ?? this.communityPages,
        communitySlug: communitySlug ?? this.communitySlug,
        communityColorHex: communityColorHex ?? this.communityColorHex,
      );
}

class EditorNotifier extends StateNotifier<EditorState> {
  final PagesApi _pagesApi;
  final SectionsApi _sectionsApi;
  final CommunitiesApi _communitiesApi;

  EditorNotifier(this._pagesApi, this._sectionsApi, this._communitiesApi) : super(const EditorState());

  Future<void> loadPage(int pageId, {Page? pageData, String? communitySlug}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = pageData ?? await _pagesApi.get(pageId);
      final apiSections = await _pagesApi.listSections(pageId);

      List<PageSummary> communityPages = [];
      String slug = communitySlug ?? '';
      String? colorHex;
      try {
        communityPages = await _communitiesApi.getPages(page.communityId);
        final community = await _communitiesApi.get(page.communityId);
        if (slug.isEmpty) slug = community.slug;
        colorHex = community.settings['community_color'] as String?;
      } catch (_) {}

      final mainSections = <EditorSection>[];
      final columnChildren = <int, Section>{};

      for (final s in apiSections) {
        if (s.config['_column_child'] == true) {
          columnChildren[s.id] = s;
        } else {
          mainSections.add(EditorSection(
            id: s.id,
            sectionType: s.sectionType,
            order: s.order,
            config: Map<String, dynamic>.from(s.config),
            data: Map<String, dynamic>.from(s.data),
          ));
        }
      }

      for (final es in mainSections) {
        if (es.sectionType == 'columns') {
          _resolveColumnChildren(es, columnChildren);
        }
      }

      mainSections.sort((a, b) => a.order.compareTo(b.order));

      state = state.copyWith(
        pageId: pageId,
        pageType: page.pageType,
        sections: mainSections,
        deletedSectionIds: [],
        layoutConfig: Map<String, dynamic>.from(page.layoutConfig ?? {}),
        layoutDirty: false,
        isLoading: false,
        communityPages: communityPages,
        communitySlug: slug,
        communityColorHex: colorHex,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _resolveColumnChildren(EditorSection columnsSection, Map<int, Section> children) {
    final cols = columnsSection.data['columns'] as List<dynamic>? ?? [];
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i] as Map<String, dynamic>;
      final childId = col['section_id'] as int?;
      if (childId != null && children.containsKey(childId)) {
        final child = children[childId]!;
        col['section_type'] = child.sectionType;
        col['config'] = Map<String, dynamic>.from(child.config)..remove('_column_child');
        col['data'] = Map<String, dynamic>.from(child.data);
        col['section_id'] = childId;
      }
    }
  }

  void addSection(String type, {Map<String, dynamic>? config, Map<String, dynamic>? data}) {
    final sections = [...state.sections];
    sections.add(EditorSection(
      sectionType: type,
      order: sections.length,
      config: config ?? {},
      data: data ?? {},
      isDirty: true,
    ));
    state = state.copyWith(sections: sections);
  }

  void insertSection(int index, String type, {Map<String, dynamic>? config, Map<String, dynamic>? data}) {
    final sections = [...state.sections];
    sections.insert(
      index,
      EditorSection(
        sectionType: type,
        order: index,
        config: config ?? {},
        data: data ?? {},
        isDirty: true,
      ),
    );
    _recalcOrder(sections);
    state = state.copyWith(sections: sections);
  }

  void removeSection(int index) {
    final sections = [...state.sections];
    final removed = sections.removeAt(index);
    final deleted = [...state.deletedSectionIds];
    if (removed.id != null) deleted.add(removed.id!);
    _recalcOrder(sections);
    state = state.copyWith(sections: sections, deletedSectionIds: deleted);
  }

  void moveSection(int from, int to) {
    if (from == to) return;
    final sections = [...state.sections];
    final item = sections.removeAt(from);
    sections.insert(to, item);
    _recalcOrder(sections);
    state = state.copyWith(sections: sections);
  }

  void updateSectionConfig(int index, Map<String, dynamic> patch) {
    final sections = [...state.sections];
    final s = sections[index];
    s.config = {...s.config, ...patch};
    s.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  void updateSectionData(int index, Map<String, dynamic> patch) {
    final sections = [...state.sections];
    final s = sections[index];
    s.data = {...s.data, ...patch};
    s.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  // Nested column support: columns section at parentIdx holds `data.columns[colIdx]` with its own config/data
  void updateColumnConfig(int parentIdx, int colIdx, Map<String, dynamic> patch) {
    final sections = [...state.sections];
    final parent = sections[parentIdx];
    final columns = List<dynamic>.from(parent.data['columns'] ?? []);
    if (colIdx >= columns.length) return;
    final col = Map<String, dynamic>.from(columns[colIdx] as Map);
    final config = Map<String, dynamic>.from(col['config'] as Map? ?? {});
    patch.forEach((k, v) {
      if (v == null) { config.remove(k); } else { config[k] = v; }
    });
    col['config'] = config;
    columns[colIdx] = col;
    parent.data = {...parent.data, 'columns': columns};
    parent.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  void updateColumnData(int parentIdx, int colIdx, Map<String, dynamic> patch) {
    final sections = [...state.sections];
    final parent = sections[parentIdx];
    final columns = List<dynamic>.from(parent.data['columns'] ?? []);
    if (colIdx >= columns.length) return;
    final col = Map<String, dynamic>.from(columns[colIdx] as Map);
    final data = Map<String, dynamic>.from(col['data'] as Map? ?? {});
    patch.forEach((k, v) {
      if (v == null) { data.remove(k); } else { data[k] = v; }
    });
    col['data'] = data;
    columns[colIdx] = col;
    parent.data = {...parent.data, 'columns': columns};
    parent.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  void updateLayoutConfig(Map<String, dynamic> patch) {
    state = state.copyWith(
      layoutConfig: {...state.layoutConfig, ...patch},
      layoutDirty: true,
    );
  }

  // ── Block management ──

  void addBlock(int sectionIndex, Map<String, dynamic> block, {int? atIndex}) {
    final sections = [...state.sections];
    final s = sections[sectionIndex];
    final blocks = List<dynamic>.from(s.data['blocks'] ?? []);
    if (atIndex != null && atIndex <= blocks.length) {
      blocks.insert(atIndex, block);
    } else {
      blocks.add(block);
    }
    s.data = {...s.data, 'blocks': blocks};
    s.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  void updateBlock(int sectionIndex, int blockIndex, Map<String, dynamic> patch) {
    final sections = [...state.sections];
    final s = sections[sectionIndex];
    final blocks = List<dynamic>.from(s.data['blocks'] ?? []);
    if (blockIndex < 0 || blockIndex >= blocks.length) return;
    blocks[blockIndex] = {...(blocks[blockIndex] as Map<String, dynamic>), ...patch};
    s.data = {...s.data, 'blocks': blocks};
    s.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  void moveBlock(int sectionIndex, int from, int to) {
    if (from == to) return;
    final sections = [...state.sections];
    final s = sections[sectionIndex];
    final blocks = List<dynamic>.from(s.data['blocks'] ?? []);
    final item = blocks.removeAt(from);
    blocks.insert(to, item);
    s.data = {...s.data, 'blocks': blocks};
    s.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  void removeBlock(int sectionIndex, int blockIndex) {
    final sections = [...state.sections];
    final s = sections[sectionIndex];
    final blocks = List<dynamic>.from(s.data['blocks'] ?? []);
    if (blockIndex < 0 || blockIndex >= blocks.length) return;
    blocks.removeAt(blockIndex);
    s.data = {...s.data, 'blocks': blocks};
    s.isDirty = true;
    state = state.copyWith(sections: sections);
  }

  // ── Save ──

  Future<bool> save() async {
    if (state.pageId == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      for (final id in state.deletedSectionIds) {
        await _sectionsApi.delete(id);
      }

      final sections = state.sections;

      for (final s in sections) {
        if (s.sectionType == 'columns') {
          await _saveColumnChildren(s);
        }
      }

      for (final s in sections) {
        if (s.id == null) {
          final result = await _sectionsApi.create(
            pageId: state.pageId!,
            sectionType: s.sectionType,
            order: s.order,
            config: s.config,
            data: s.data,
          );
          s.id = result['id'] as int?;
          s.isDirty = false;
        } else if (s.isDirty) {
          await _sectionsApi.update(
            s.id!,
            config: s.config,
            data: s.data,
            order: s.order,
          );
          s.isDirty = false;
        }
      }

      final sectionIds = sections.where((s) => s.id != null).map((s) => s.id!).toList();
      if (sectionIds.isNotEmpty) {
        await _sectionsApi.reorder(state.pageId!, sectionIds);
      }

      if (state.layoutDirty) {
        await _pagesApi.update(state.pageId!, {'layout_config': state.layoutConfig});
      }

      state = state.copyWith(
        sections: sections,
        deletedSectionIds: [],
        layoutDirty: false,
        isSaving: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<void> _saveColumnChildren(EditorSection columnsSection) async {
    final cols = columnsSection.data['columns'] as List<dynamic>? ?? [];
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i] as Map<String, dynamic>;
      final childType = col['section_type'] as String? ?? '';
      if (childType.isEmpty) continue;

      final childConfig = Map<String, dynamic>.from(col['config'] as Map<String, dynamic>? ?? {});
      childConfig['_column_child'] = true;
      final childData = col['data'] as Map<String, dynamic>? ?? {};
      final existingId = col['section_id'] as int?;

      if (existingId != null) {
        await _sectionsApi.update(existingId, config: childConfig, data: childData, order: 900 + i);
      } else {
        final result = await _sectionsApi.create(
          pageId: state.pageId!,
          sectionType: childType,
          order: 900 + i,
          config: childConfig,
          data: childData,
        );
        col['section_id'] = result['id'] as int?;
      }
    }
    columnsSection.isDirty = true;
  }

  void _recalcOrder(List<EditorSection> sections) {
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].order != i) {
        sections[i].order = i;
        sections[i].isDirty = true;
      }
    }
  }

  void reset() {
    state = const EditorState();
  }
}

final editorProvider = StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  final api = ref.read(apiClientProvider);
  return EditorNotifier(PagesApi(api), SectionsApi(api), CommunitiesApi(api));
});
