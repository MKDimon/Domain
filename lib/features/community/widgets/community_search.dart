import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class _SearchResult {
  final String type;
  final int pageId;
  final String pageTitle;
  final String pageSlug;
  final int? sectionId;
  final String? sectionType;
  final String? sectionTitle;
  final String? imageUrl;

  _SearchResult({
    required this.type,
    required this.pageId,
    required this.pageTitle,
    required this.pageSlug,
    this.sectionId,
    this.sectionType,
    this.sectionTitle,
    this.imageUrl,
  });

  factory _SearchResult.fromJson(Map<String, dynamic> json) => _SearchResult(
        type: json['type'] as String? ?? 'page',
        pageId: json['page_id'] as int? ?? 0,
        pageTitle: json['page_title'] as String? ?? '',
        pageSlug: json['page_slug'] as String? ?? '',
        sectionId: json['section_id'] as int?,
        sectionType: json['section_type'] as String?,
        sectionTitle: json['section_title'] as String?,
        imageUrl: json['image_url'] as String?,
      );
}

class CommunitySearchField extends ConsumerStatefulWidget {
  final int communityId;
  final String communitySlug;
  final ColorSet c;

  const CommunitySearchField({
    super.key,
    required this.communityId,
    required this.communitySlug,
    required this.c,
  });

  @override
  ConsumerState<CommunitySearchField> createState() => _CommunitySearchFieldState();
}

class _CommunitySearchFieldState extends ConsumerState<CommunitySearchField> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  List<_SearchResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    _showOverlay();
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<Map<String, dynamic>>(
        '/communities/${widget.communityId}/search',
        queryParameters: {'q': query, 'limit': '20'},
      );
      final list = data['items'] as List<dynamic>? ?? [];
      _results = list.map((e) => _SearchResult.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _results = [];
    }
    if (mounted) {
      setState(() => _loading = false);
      _overlay?.markNeedsBuild();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlay = OverlayEntry(builder: (_) => _buildDropdown());
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _goToResult(_SearchResult item) {
    _removeOverlay();
    _ctrl.clear();
    _focusNode.unfocus();
    context.go('/community/${widget.communitySlug}/page/${item.pageId}');
  }

  Widget _buildDropdown() {
    final c = widget.c;
    return Positioned(
      width: 320,
      child: CompositedTransformFollower(
        link: _layerLink,
        offset: const Offset(0, 40),
        showWhenUnlinked: false,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 360),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Ничего не найдено', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.6, color: c.textSecondary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final item = _results[i];
                          return InkWell(
                            onTap: () => _goToResult(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    item.type == 'section' ? Icons.grid_view : Icons.description_outlined,
                                    size: 16, color: c.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.type == 'section'
                                              ? (item.sectionTitle ?? item.sectionType ?? '')
                                              : item.pageTitle,
                                          style: TextStyle(fontSize: 13.6, color: c.text),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.type == 'section')
                                          Text(item.pageTitle, style: TextStyle(fontSize: 12, color: c.textSecondary), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 220,
        height: 34,
        child: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: TextStyle(fontSize: 14, color: c.text),
          decoration: InputDecoration(
            hintText: 'Поиск...',
            hintStyle: TextStyle(fontSize: 14, color: c.textSecondary),
            prefixIcon: Icon(Icons.search, size: 16, color: c.textSecondary),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
            filled: true,
            fillColor: c.surfaceAlt,
          ),
        ),
      ),
    );
  }
}
