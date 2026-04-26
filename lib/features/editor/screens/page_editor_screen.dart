import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/editor_defaults.dart';
import '../../../data/models/page.dart' as models;
import '../../../providers/editor_provider.dart';
import '../../content/widgets/section_renderer.dart';
import '../widgets/section_editor_widget.dart';

class SectionDragData {
  final String source; // 'top' or 'column'
  final int index;
  final int? parentSectionIndex;
  const SectionDragData({required this.source, required this.index, this.parentSectionIndex});
}

class PageEditorScreen extends ConsumerStatefulWidget {
  final int pageId;
  final String communitySlug;

  const PageEditorScreen({super.key, required this.pageId, required this.communitySlug});

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  double _splitFraction = 0.5;
  bool _resizing = false;
  final _contentWidthCtrl = TextEditingController();
  int? _dragFromIndex;
  int? _dragOverIndex;
  String? _dragPosition; // 'top' or 'bottom'
  int _activeTab = 0; // 0 = editor, 1 = preview

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(editorProvider.notifier).loadPage(widget.pageId, communitySlug: widget.communitySlug);
    });
  }

  @override
  void dispose() {
    _contentWidthCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final editor = ref.read(editorProvider);
    if (!editor.isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Изменения будут потеряны.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Остаться')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Покинуть')),
        ],
      ),
    );
    return result ?? false;
  }

  void _goBack() {
    ref.read(editorProvider.notifier).reset();
    context.goNamed('page-view', pathParameters: {'slug': widget.communitySlug, 'pageId': '${widget.pageId}'});
  }

  Future<void> _save() async {
    final ok = await ref.read(editorProvider.notifier).save();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено'), duration: Duration(seconds: 2)));
    }
  }

  void _addSection(String type, {int? atIndex}) {
    final defaults = sectionDefaults[type];
    if (defaults == null) return;
    final config = json.decode(json.encode(defaults['config'])) as Map<String, dynamic>;
    final data = json.decode(json.encode(defaults['data'])) as Map<String, dynamic>;
    if (atIndex != null) {
      ref.read(editorProvider.notifier).insertSection(atIndex, type, config: config, data: data);
    } else {
      ref.read(editorProvider.notifier).addSection(type, config: config, data: data);
    }
  }

  void _showAddSectionMenu({int? atIndex}) {
    final editor = ref.read(editorProvider);
    final isMainPage = editor.pageType == 'main';
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => _SectionTypeMenu(
        isMainPage: isMainPage,
        c: c,
        onSelect: (type) {
          Navigator.pop(ctx);
          _addSection(type, atIndex: atIndex);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColors = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final editor = ref.watch(editorProvider);
    final commColor = _parseCommunityColor(editor.communityColorHex);
    final c = AppColors.withCommunity(baseColors, commColor);

    final cwText = '${editor.layoutConfig['content_width'] ?? 100}';
    if (_contentWidthCtrl.text != cwText && !_contentWidthCtrl.text.contains(RegExp(r'[^0-9]'))) {
      _contentWidthCtrl.text = cwText;
    }

    return PopScope(
      canPop: !editor.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) _goBack();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildToolbar(c, editor),
            Expanded(
              child: editor.isLoading
                  ? Center(child: CircularProgressIndicator(color: c.accent))
                  : editor.error != null
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(editor.error!, style: TextStyle(color: c.error, fontSize: 14)),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: () => ref.read(editorProvider.notifier).loadPage(widget.pageId), child: const Text('Повторить')),
                          ],
                        ))
                      : _buildPanels(c, editor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ColorSet c, EditorState editor) {
    return Container(
      height: 52,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () async {
              if (editor.isDirty) {
                final ok = await _onWillPop();
                if (!ok) return;
              }
              _goBack();
            },
            icon: Icon(Icons.arrow_back, size: 16, color: c.textSecondary),
            label: Text('Назад', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ),
          const SizedBox(width: 16),
          Icon(Icons.edit_note, size: 20, color: c.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text('Редактор страницы', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis),
          ),
          if (editor.isDirty) ...[
            const SizedBox(width: 12),
            Text('Не сохранено', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: c.warning)),
          ],
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ширина:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                height: 32,
                child: TextField(
                  controller: _contentWidthCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    suffixText: '%',
                    suffixStyle: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                  style: TextStyle(fontSize: 12, color: c.text),
                  keyboardType: TextInputType.number,
                  onSubmitted: (v) {
                    final val = int.tryParse(v)?.clamp(40, 100) ?? 100;
                    ref.read(editorProvider.notifier).updateLayoutConfig({'content_width': val});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: editor.isSaving || !editor.isDirty ? null : _save,
            icon: editor.isSaving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(editor.isSaving ? 'Сохранение...' : 'Сохранить'),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  static const _editorMinWidth = 400.0;
  static const _dividerWidth = 5.0;
  double _calcPreviewMinWidth(EditorState editor) {
    const scrollPad = 40.0;
    const shell = 42.0;
    const colGap = 24.0;

    double widest = 200;
    for (final s in editor.sections) {
      double sectionMin;
      if (s.sectionType == 'columns') {
        final cols = (s.data['columns'] as List<dynamic>?) ?? [];
        if (cols.isEmpty) continue;
        double childrenSum = 0;
        for (final col in cols) {
          if (col is Map<String, dynamic>) {
            final childType = col['section_type'] as String? ?? '';
            childrenSum += shell + (sectionContentMinWidth[childType] ?? 120.0);
          }
        }
        if (cols.length > 1) childrenSum += (cols.length - 1) * colGap;
        sectionMin = shell + childrenSum;
      } else {
        sectionMin = shell + (sectionContentMinWidth[s.sectionType] ?? 120.0);
      }
      if (sectionMin > widest) widest = sectionMin;
    }
    return scrollPad + widest;
  }

  Widget _buildPanels(ColorSet c, EditorState editor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final previewMin = _calcPreviewMinWidth(editor);
        final minTotal = _editorMinWidth + previewMin + _dividerWidth;

        if (totalWidth < minTotal) {
          return _buildTabbedLayout(c, editor);
        }

        final maxLeft = totalWidth - previewMin - _dividerWidth;
        final leftWidth = (totalWidth * _splitFraction).clamp(_editorMinWidth, maxLeft);
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: _buildEditorPanel(c, editor),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _resizing = true),
                onHorizontalDragUpdate: (d) {
                  final minFrac = _editorMinWidth / totalWidth;
                  final maxFrac = maxLeft / totalWidth;
                  setState(() {
                    _splitFraction = ((_splitFraction * totalWidth + d.delta.dx) / totalWidth).clamp(minFrac, maxFrac);
                  });
                },
                onHorizontalDragEnd: (_) => setState(() => _resizing = false),
                child: Container(
                  width: 5,
                  color: _resizing ? c.accent : c.border,
                ),
              ),
            ),
            Expanded(
              child: _buildPreviewPanel(c, editor),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabbedLayout(ColorSet c, EditorState editor) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              _tabButton('Редактор', 0, c),
              _tabButton('Предпросмотр', 1, c),
            ],
          ),
        ),
        Expanded(
          child: _activeTab == 0
              ? _buildEditorPanel(c, editor)
              : _buildPreviewPanel(c, editor),
        ),
      ],
    );
  }

  Widget _tabButton(String label, int index, ColorSet c) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? c.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? c.accent : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorPanel(ColorSet c, EditorState editor) {
    if (editor.sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 48, color: c.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Нет секций', style: TextStyle(fontSize: 16, color: c.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showAddSectionMenu(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Добавить секцию'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          _InsertPoint(onTap: () => _showAddSectionMenu(atIndex: 0), c: c),
          for (var sectionIdx = 0; sectionIdx < editor.sections.length; sectionIdx++) ...[
            _SectionDragWrapper(
              index: sectionIdx,
              c: c,
              isDragging: _dragFromIndex == sectionIdx,
              dragOverPosition: _dragOverIndex == sectionIdx ? _dragPosition : null,
              onDragStart: () => setState(() => _dragFromIndex = sectionIdx),
              onDragEnd: () => setState(() { _dragFromIndex = null; _dragOverIndex = null; _dragPosition = null; }),
              onDragOver: (pos) => setState(() { _dragOverIndex = sectionIdx; _dragPosition = pos; }),
              onDragLeave: () { if (_dragOverIndex == sectionIdx) setState(() { _dragOverIndex = null; _dragPosition = null; }); },
              onDrop: (data) {
                if (data.source == 'top' && data.index != sectionIdx) {
                  final from = data.index;
                  var to = sectionIdx;
                  if (_dragPosition == 'bottom') to = sectionIdx + (from < sectionIdx ? 0 : 1);
                  else to = sectionIdx + (from < sectionIdx ? -1 : 0);
                  to = to.clamp(0, editor.sections.length - 1);
                  ref.read(editorProvider.notifier).moveSection(from, to);
                } else if (data.source == 'column' && data.parentSectionIndex != null) {
                  final notifier = ref.read(editorProvider.notifier);
                  final parentIdx = data.parentSectionIndex!;
                  final colIdx = data.index;
                  final parent = editor.sections[parentIdx];
                  final cols = List<dynamic>.from(parent.data['columns'] ?? []);
                  if (colIdx < cols.length) {
                    final col = cols[colIdx] as Map<String, dynamic>;
                    final type = col['section_type'] as String? ?? '';
                    if (type.isNotEmpty) {
                      final config = Map<String, dynamic>.from(col['config'] as Map? ?? {});
                      final colData = Map<String, dynamic>.from(col['data'] as Map? ?? {});
                      cols.removeAt(colIdx);
                      notifier.updateSectionData(parentIdx, {'columns': cols});
                      var insertAt = _dragPosition == 'bottom' ? sectionIdx + 1 : sectionIdx;
                      insertAt = insertAt.clamp(0, editor.sections.length);
                      notifier.insertSection(insertAt, type, config: config, data: colData);
                    }
                  }
                }
                setState(() { _dragFromIndex = null; _dragOverIndex = null; _dragPosition = null; });
              },
              child: SectionEditorWidget(
                key: ValueKey('section_${editor.sections[sectionIdx].id ?? sectionIdx}'),
                sectionIndex: sectionIdx,
                section: editor.sections[sectionIdx],
                isFirst: sectionIdx == 0,
                isLast: sectionIdx == editor.sections.length - 1,
                onDelete: () {
                  ref.read(editorProvider.notifier).removeSection(sectionIdx);
                },
                onMoveUp: sectionIdx > 0
                    ? () => ref.read(editorProvider.notifier).moveSection(sectionIdx, sectionIdx - 1)
                    : null,
                onMoveDown: sectionIdx < editor.sections.length - 1
                    ? () => ref.read(editorProvider.notifier).moveSection(sectionIdx, sectionIdx + 1)
                    : null,
                onInsertBefore: () => _showAddSectionMenu(atIndex: sectionIdx),
              ),
            ),
            // Insert point after each section
            _InsertPoint(onTap: () => _showAddSectionMenu(atIndex: sectionIdx + 1), c: c),
          ],
        ],
      ),
    );
  }

  Color? _parseCommunityColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {}
    return null;
  }

  Widget _buildPreviewPanel(ColorSet c, EditorState editor) {
    final commColor = _parseCommunityColor(editor.communityColorHex);

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: c.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            child: Row(
              children: [
                Text('ПРЕДПРОСМОТР', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.textSecondary)),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() {}),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(4),
                      color: c.surface,
                    ),
                    child: Icon(Icons.refresh, size: 14, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: editor.sections.isEmpty
                ? Center(child: Text('Добавьте секции для предпросмотра', style: TextStyle(fontSize: 14, color: c.textSecondary)))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final panelWidth = constraints.maxWidth;
                      final cw = editor.layoutConfig['content_width'] as int?;
                      final contentMaxWidth = (cw != null && cw >= 40 && cw < 100)
                          ? panelWidth * cw / 100
                          : double.infinity;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentMaxWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: editor.sections.map((s) {
                                final section = models.Section(
                                  id: s.id ?? 0,
                                  pageId: widget.pageId,
                                  sectionType: s.sectionType,
                                  order: s.order,
                                  config: s.config,
                                  data: s.data,
                                );
                                Widget child = Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ClipRect(
                                    child: SectionRenderer(
                                      section: section,
                                      pages: editor.communityPages,
                                      communitySlug: editor.communitySlug,
                                      communityColor: commColor,
                                    ),
                                  ),
                                );
                                final sw = s.config['width'] as String?;
                                if (sw != null && sw.isNotEmpty) {
                                  double maxW;
                                  if (sw.endsWith('%')) {
                                    final pct = double.tryParse(sw.replaceAll('%', ''));
                                    maxW = (pct != null && pct > 0 && pct <= 100) ? contentMaxWidth * pct / 100 : double.infinity;
                                  } else {
                                    maxW = double.tryParse(sw.replaceAll('px', '')) ?? double.infinity;
                                  }
                                  child = Center(child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxW),
                                    child: child,
                                  ));
                                }
                                return child;
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionDragWrapper extends StatefulWidget {
  final int index;
  final ColorSet c;
  final bool isDragging;
  final String? dragOverPosition;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final void Function(String position) onDragOver;
  final VoidCallback onDragLeave;
  final void Function(SectionDragData data) onDrop;
  final Widget child;

  const _SectionDragWrapper({
    required this.index,
    required this.c,
    required this.isDragging,
    this.dragOverPosition,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragOver,
    required this.onDragLeave,
    required this.onDrop,
    required this.child,
  });

  @override
  State<_SectionDragWrapper> createState() => _SectionDragWrapperState();
}

class _SectionDragWrapperState extends State<_SectionDragWrapper> {
  bool _handleHovered = false;
  bool _sectionHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _sectionHovered = true),
      onExit: (_) => setState(() => _sectionHovered = false),
      child: DragTarget<SectionDragData>(
        onWillAcceptWithDetails: (details) => !(details.data.source == 'top' && details.data.index == widget.index),
        onAcceptWithDetails: (details) => widget.onDrop(details.data),
        onMove: (details) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null) return;
          final local = renderBox.globalToLocal(details.offset);
          final half = renderBox.size.height / 2;
          widget.onDragOver(local.dy < half ? 'top' : 'bottom');
        },
        onLeave: (_) => widget.onDragLeave(),
        builder: (context, accepted, rejected) {
          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: widget.dragOverPosition == 'top'
                    ? BorderSide(color: widget.c.accent, width: 3)
                    : BorderSide.none,
                bottom: widget.dragOverPosition == 'bottom'
                    ? BorderSide(color: widget.c.accent, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: AnimatedOpacity(
              opacity: widget.isDragging ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Draggable<SectionDragData>(
                    data: SectionDragData(source: 'top', index: widget.index),
                    onDragStarted: widget.onDragStart,
                    onDragEnd: (_) => widget.onDragEnd(),
                    feedback: _buildDragFeedback(),
                    childWhenDragging: const SizedBox.shrink(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      onEnter: (_) => setState(() => _handleHovered = true),
                      onExit: (_) => setState(() => _handleHovered = false),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, right: 0),
                        child: AnimatedOpacity(
                          opacity: _handleHovered ? 1.0 : (_sectionHovered ? 0.7 : 0.4),
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            decoration: BoxDecoration(
                              color: _handleHovered ? widget.c.surfaceAlt : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _buildDragDots(widget.c.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragFeedback() {
    final section = widget.child;
    String label = 'Секция';
    if (section is SectionEditorWidget) {
      label = sectionTypeLabels[section.section.sectionType] ?? section.section.sectionType;
    }
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.c.accent),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: widget.c.text)),
      ),
    );
  }

  Widget _buildDragDots(Color color) {
    return CustomPaint(
      size: const Size(10, 22),
      painter: _DragDotsPainter(color: color),
    );
  }
}

class _DragDotsPainter extends CustomPainter {
  final Color color;
  _DragDotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const r = 1.5;
    for (final cy in [3.0, 8.0, 13.0, 18.0]) {
      canvas.drawCircle(Offset(3, cy), r, paint);
      canvas.drawCircle(Offset(7, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DragDotsPainter old) => old.color != color;
}

class _InsertPoint extends StatefulWidget {
  final VoidCallback onTap;
  final ColorSet c;
  const _InsertPoint({required this.onTap, required this.c});

  @override
  State<_InsertPoint> createState() => _InsertPointState();
}

class _InsertPointState extends State<_InsertPoint> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: _hovered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Container(height: 1, color: widget.c.border)),
                AnimatedScale(
                  scale: _hovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: widget.c.accent),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                ),
                Expanded(child: Container(height: 1, color: widget.c.border)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTypeMenu extends StatelessWidget {
  final bool isMainPage;
  final ColorSet c;
  final void Function(String type) onSelect;

  const _SectionTypeMenu({required this.isMainPage, required this.c, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final types = sectionDefaults.keys.where((t) {
      if (!isMainPage && mainPageOnlySections.contains(t)) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Добавить секцию', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, size: 18, color: c.textSecondary), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < types.length; i += 2)
                      Padding(
                        padding: EdgeInsets.only(bottom: i + 2 < types.length ? 4 : 0),
                        child: Row(
                          children: [
                            Expanded(child: _SectionMenuItem(type: types[i], c: c, onSelect: onSelect)),
                            const SizedBox(width: 4),
                            if (i + 1 < types.length)
                              Expanded(child: _SectionMenuItem(type: types[i + 1], c: c, onSelect: onSelect))
                            else
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionMenuItem extends StatefulWidget {
  final String type;
  final ColorSet c;
  final void Function(String type) onSelect;

  const _SectionMenuItem({required this.type, required this.c, required this.onSelect});

  @override
  State<_SectionMenuItem> createState() => _SectionMenuItemState();
}

class _SectionMenuItemState extends State<_SectionMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final label = sectionTypeLabels[widget.type] ?? widget.type;
    final textIcon = sectionTypeTextIcons[widget.type] ?? '?';
    final desc = sectionTypeDescriptions[widget.type] ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelect(widget.type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? c.accent.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: _hovered ? c.accent : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  textIcon,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(desc, style: TextStyle(fontSize: 11, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
