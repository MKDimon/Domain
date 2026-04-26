import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/editor_defaults.dart';
import '../../../providers/editor_provider.dart';
import '../screens/page_editor_screen.dart';
import 'block_editor_list.dart';
import 'markdown_toolbar.dart';
import 'section_config_editors.dart';

class _PersistentEditorField extends StatefulWidget {
  final String text;
  final InputDecoration? decoration;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;

  const _PersistentEditorField({
    required this.text,
    this.decoration,
    this.style,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  State<_PersistentEditorField> createState() => _PersistentEditorFieldState();
}

class _PersistentEditorFieldState extends State<_PersistentEditorField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant _PersistentEditorField old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text && _ctrl.text != widget.text) {
      _ctrl.text = widget.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: widget.decoration,
      style: widget.style,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
    );
  }
}

class SectionEditorWidget extends ConsumerStatefulWidget {
  final int sectionIndex;
  final EditorSection section;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onDelete;
  final VoidCallback onInsertBefore;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const SectionEditorWidget({
    super.key,
    required this.sectionIndex,
    required this.section,
    this.isFirst = false,
    this.isLast = false,
    required this.onDelete,
    required this.onInsertBefore,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  ConsumerState<SectionEditorWidget> createState() => _SectionEditorWidgetState();
}

class _SectionEditorWidgetState extends ConsumerState<SectionEditorWidget> {
  bool _collapsed = false;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _widthCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.section.config['title'] as String? ?? '');
    _labelCtrl = TextEditingController(text: widget.section.config['label'] as String? ?? '');
    final w = widget.section.config['width'] as String?;
    _widthCtrl = TextEditingController(text: w != null ? (int.tryParse(w.replaceAll('%', ''))?.toString() ?? '') : '');
  }

  @override
  void didUpdateWidget(covariant SectionEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTitle = widget.section.config['title'] as String? ?? '';
    if (_titleCtrl.text != newTitle) {
      _titleCtrl.text = newTitle;
    }
    final newLabel = widget.section.config['label'] as String? ?? '';
    if (_labelCtrl.text != newLabel) {
      _labelCtrl.text = newLabel;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _labelCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColors = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final commColor = _parseColor(ref.watch(editorProvider).communityColorHex);
    final c = AppColors.withCommunity(baseColors, commColor);
    final s = widget.section;
    final typeLabel = sectionTypeLabels[s.sectionType] ?? s.sectionType;
    final iconCode = sectionTypeIcons[s.sectionType];

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: s.isDirty ? c.accent.withValues(alpha: 0.5) : c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(c, typeLabel, iconCode),
          if (!_collapsed)
            _buildContentEditor(c, s),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorSet c, String typeLabel, int? iconCode) {
    final sections = ref.read(editorProvider).sections;
    final labelText = _labelCtrl.text;
    final isDuplicate = labelText.isNotEmpty &&
        sections.asMap().entries.any((e) => e.key != widget.sectionIndex && e.value.config['label'] == labelText);
    final isInvalid = labelText.isNotEmpty && !_labelRegex.hasMatch(labelText);
    final hasLabelError = isDuplicate || isInvalid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.vertical(top: const Radius.circular(7), bottom: _collapsed ? const Radius.circular(7) : Radius.zero),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconData(iconCode ?? 0xe14f, fontFamily: 'MaterialIcons'), size: 12, color: c.accent),
                const SizedBox(width: 4),
                Text(typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.accent)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 5,
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Заголовок секции',
                  hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text),
                onChanged: (v) {
                  ref.read(editorProvider.notifier).updateSectionConfig(widget.sectionIndex, {'title': v});
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                hintText: 'label',
                hintStyle: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.textSecondary.withValues(alpha: 0.5)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                enabledBorder: hasLabelError
                    ? OutlineInputBorder(borderSide: BorderSide(color: c.error), borderRadius: BorderRadius.circular(4))
                    : InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: hasLabelError ? c.error : c.border),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.textSecondary),
              onChanged: (raw) {
                final sanitized = raw.toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9_]'), '')
                    .replaceFirst(RegExp(r'^[^a-z]+'), '');
                final trimmed = sanitized.length > 32 ? sanitized.substring(0, 32) : sanitized;
                if (trimmed != raw) {
                  _labelCtrl.text = trimmed;
                  _labelCtrl.selection = TextSelection.collapsed(offset: trimmed.length);
                }
                ref.read(editorProvider.notifier).updateSectionConfig(
                  widget.sectionIndex, {'label': trimmed.isEmpty ? null : trimmed},
                );
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 1,
            child: TextField(
              controller: _widthCtrl,
              decoration: InputDecoration(
                hintText: '100',
                hintStyle: TextStyle(fontSize: 11, color: c.textSecondary.withValues(alpha: 0.5)),
                filled: true,
                fillColor: c.surfaceAlt,
                border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              style: TextStyle(fontSize: 11, color: c.text),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final parsed = int.tryParse(v);
                ref.read(editorProvider.notifier).updateSectionConfig(
                  widget.sectionIndex,
                  {'width': parsed != null && parsed >= 20 && parsed < 100 ? '$parsed%' : null},
                );
              },
            ),
          ),
          Text('%', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          const SizedBox(width: 4),
          _headerButton(
            _collapsed ? Icons.expand_more : Icons.expand_less,
            c,
            () => setState(() => _collapsed = !_collapsed),
          ),
          _headerButton(Icons.add, c, widget.onInsertBefore, tooltip: 'Вставить перед'),
          if (widget.onMoveUp != null)
            _headerButton(Icons.arrow_upward, c, widget.onMoveUp!, tooltip: 'Вверх'),
          if (widget.onMoveDown != null)
            _headerButton(Icons.arrow_downward, c, widget.onMoveDown!, tooltip: 'Вниз'),
          _headerButton(Icons.delete_outline, c, _confirmDelete, color: c.error),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, ColorSet c, VoidCallback onTap, {Color? color, bool active = false, String? tooltip}) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: active ? c.accent : (color ?? c.textSecondary)),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить секцию?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildContentEditor(ColorSet c, EditorSection s) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: switch (s.sectionType) {
        'content' => _buildContentSectionEditor(c, s),
        'columns' => _ColumnsSectionEditor(sectionIndex: widget.sectionIndex, section: s),
        'polls' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'quiz' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'booking' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'calendar' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'announcements' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'chat' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'products' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'navigation' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'popular-pages' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'recent-updates' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'wiki' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'community-header' => SectionConfigEditor(sectionIndex: widget.sectionIndex, section: s),
        'script' => _buildScriptEditor(c, s),
        _ => Text('Секция "${sectionTypeLabels[s.sectionType] ?? s.sectionType}"', style: TextStyle(fontSize: 13, color: c.textSecondary)),
      },
    );
  }

  void _showBlocklyInfoDialog(BuildContext context, ColorSet c) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.extension, size: 22, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Визуальный редактор', style: TextStyle(fontSize: 17.6, fontWeight: FontWeight.w700, color: c.text)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Визуальный блочный редактор (Blockly) позволяет создавать Lua-скрипты без написания кода — перетаскиванием блоков.',
                style: TextStyle(fontSize: 14, height: 1.6, color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: c.accent, width: 3)),
                ),
                child: Text(
                  'Визуальный редактор доступен в веб-версии Domain. Откройте редактор страницы в браузере для использования блочного режима.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: c.text),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Закрыть'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      launchUrl(Uri.parse('https://do-main.ru/app/docs/scripting'), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Документация'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScriptEditor(ColorSet c, EditorSection s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar — matches web ScriptEditor toolbar
        Row(
          children: [
            // Mode label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: c.border),
              ),
              child: Text('Lua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
            ),
            const Spacer(),
            // Visual editor info button
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showBlocklyInfoDialog(context, c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.extension_outlined, size: 13, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text('Визуальный', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Docs button
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => launchUrl(Uri.parse('https://do-main.ru/app/docs/scripting'), mode: LaunchMode.externalApplication),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Документация', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Code editor
        _PersistentEditorField(
          text: s.data['code'] as String? ?? '',
          maxLines: null, minLines: 6,
          decoration: InputDecoration(
            hintText: '-- Lua-скрипт', isDense: true,
            hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.5), fontFamily: 'monospace'),
            border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
          ),
          style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: c.text),
          onChanged: (v) => ref.read(editorProvider.notifier).updateSectionData(widget.sectionIndex, {'code': v}),
        ),
      ],
    );
  }

  Widget _buildContentSectionEditor(ColorSet c, EditorSection s) {
    final blocks = s.data['blocks'] as List<dynamic>? ?? [];
    final isMarkdownBlocks = blocks.length == 1 &&
        blocks[0] is Map<String, dynamic> &&
        (blocks[0] as Map<String, dynamic>)['type'] == 'markdown';
    final mode = s.config['editorMode'] as String? ??
        s.data['mode'] as String? ??
        (isMarkdownBlocks ? 'markdown' : 'blocks');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _modeChip('blocks', 'Блоки', mode, c),
            const SizedBox(width: 6),
            _modeChip('markdown', 'Markdown', mode, c),
          ],
        ),
        const SizedBox(height: 8),
        if (mode == 'markdown')
          _buildMarkdownEditor(c, s)
        else
          BlockEditorList(sectionIndex: widget.sectionIndex),
      ],
    );
  }

  Widget _modeChip(String value, String label, String current, ColorSet c) {
    final active = current == value;
    return GestureDetector(
      onTap: () {
        final notifier = ref.read(editorProvider.notifier);
        final s = ref.read(editorProvider).sections[widget.sectionIndex];
        final blocks = s.data['blocks'] as List<dynamic>? ?? [];

        if (value == 'blocks' && current == 'markdown') {
          final mdBlock = blocks.isNotEmpty && blocks[0] is Map<String, dynamic>
              ? blocks[0] as Map<String, dynamic> : null;
          final md = mdBlock?['type'] == 'markdown' ? (mdBlock!['content'] as String? ?? '') : (s.data['content'] as String? ?? '');
          final parsed = _markdownToBlocks(md);
          notifier.updateSectionConfig(widget.sectionIndex, {'editorMode': 'blocks'});
          notifier.updateSectionData(widget.sectionIndex, {'mode': 'blocks', 'blocks': parsed});
        } else if (value == 'markdown' && current == 'blocks') {
          final md = _blocksToMarkdown(blocks);
          notifier.updateSectionConfig(widget.sectionIndex, {'editorMode': 'markdown'});
          notifier.updateSectionData(widget.sectionIndex, {'mode': 'markdown', 'content': md, 'blocks': [{'type': 'markdown', 'content': md}]});
        } else {
          notifier.updateSectionConfig(widget.sectionIndex, {'editorMode': value});
          notifier.updateSectionData(widget.sectionIndex, {'mode': value});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: active ? c.accent : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? c.accent : c.textSecondary)),
      ),
    );
  }

  static List<Map<String, dynamic>> _markdownToBlocks(String markdown) {
    if (markdown.trim().isEmpty) return [];
    final blocks = <Map<String, dynamic>>[];
    final lines = markdown.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trim().isEmpty) { i++; continue; }

      // Code block
      if (line.trimLeft().startsWith('```')) {
        final lang = line.trim().substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) { codeLines.add(lines[i]); i++; }
        if (i < lines.length) i++;
        blocks.add({'type': 'code', 'language': lang, 'content': codeLines.join('\n')});
        continue;
      }
      // Divider
      final trimmed = line.trim();
      if (RegExp(r'^-{3,}\s*$').hasMatch(trimmed) || RegExp(r'^\*{3,}\s*$').hasMatch(trimmed) || RegExp(r'^_{3,}\s*$').hasMatch(trimmed)) {
        blocks.add({'type': 'divider'}); i++; continue;
      }
      // Heading
      final hm = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (hm != null) {
        blocks.add({'type': 'heading', 'level': hm.group(1)!.length, 'text': hm.group(2)!}); i++; continue;
      }
      // Image
      final im = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)\s*$').firstMatch(line.trim());
      if (im != null) {
        blocks.add({'type': 'image', 'url': im.group(2)!, 'caption': im.group(1)!}); i++; continue;
      }
      // Blockquote
      if (line.startsWith('> ') || line == '>') {
        final qLines = <String>[];
        while (i < lines.length && (lines[i].startsWith('> ') || lines[i] == '>')) { qLines.add(lines[i].length > 2 ? lines[i].substring(2) : ''); i++; }
        blocks.add({'type': 'quote', 'text': qLines.join('\n'), 'author': ''});
        continue;
      }
      // Unordered list
      if (line.startsWith('- ') || line.startsWith('* ')) {
        final marker = line[0];
        final items = <String>[];
        while (i < lines.length && lines[i].startsWith('$marker ')) { items.add(lines[i].substring(2)); i++; }
        blocks.add({'type': 'list', 'style': 'unordered', 'items': items});
        continue;
      }
      // Ordered list
      if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final items = <String>[];
        while (i < lines.length && RegExp(r'^\d+\.\s').hasMatch(lines[i])) {
          final dotIdx = lines[i].indexOf('. ');
          items.add(lines[i].substring(dotIdx + 2)); i++;
        }
        blocks.add({'type': 'list', 'style': 'ordered', 'items': items});
        continue;
      }
      // Paragraph
      final paraLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty &&
          !lines[i].startsWith('#') && !lines[i].startsWith('```') &&
          !lines[i].startsWith('> ') && !lines[i].startsWith('- ') && !lines[i].startsWith('* ') &&
          !RegExp(r'^\d+\.\s').hasMatch(lines[i]) &&
          !RegExp(r'^!\[').hasMatch(lines[i].trim()) &&
          !RegExp(r'^-{3,}\s*$').hasMatch(lines[i].trim())) {
        paraLines.add(lines[i]); i++;
      }
      if (paraLines.isNotEmpty) {
        blocks.add({'type': 'paragraph', 'text': paraLines.join(' ')});
      } else {
        blocks.add({'type': 'paragraph', 'text': lines[i]}); i++;
      }
    }
    return blocks;
  }

  static String _blocksToMarkdown(List<dynamic> blocks) {
    final parts = <String>[];
    for (final b in blocks) {
      if (b is! Map<String, dynamic>) continue;
      final type = b['type'] as String? ?? '';
      switch (type) {
        case 'heading':
          final lvl = b['level'] as int? ?? 2;
          parts.add('${'#' * lvl} ${b['text'] ?? ''}');
        case 'paragraph':
          parts.add(b['text'] as String? ?? '');
        case 'markdown':
          parts.add(b['content'] as String? ?? '');
        case 'image':
          parts.add('![${b['caption'] ?? ''}](${b['url'] ?? ''})');
        case 'divider':
          parts.add('---');
        case 'code':
          parts.add('```${b['language'] ?? ''}\n${b['content'] ?? ''}\n```');
        case 'quote':
          final text = b['text'] as String? ?? '';
          parts.add(text.split('\n').map((l) => '> $l').join('\n'));
        case 'list':
          final items = (b['items'] as List<dynamic>?)?.cast<String>() ?? [];
          final ordered = b['style'] == 'ordered';
          for (var j = 0; j < items.length; j++) {
            parts.add(ordered ? '${j + 1}. ${items[j]}' : '- ${items[j]}');
          }
        case 'callout':
          parts.add('> **${(b['style'] as String? ?? 'info').toUpperCase()}**: ${b['text'] ?? ''}');
        default:
          final text = b['text'] as String? ?? b['content'] as String? ?? '';
          if (text.isNotEmpty) parts.add(text);
      }
    }
    return parts.join('\n\n');
  }

  String _resolveMarkdownContent(EditorSection s) {
    final direct = s.data['content'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    final blocks = s.data['blocks'] as List<dynamic>?;
    if (blocks != null && blocks.isNotEmpty) {
      final first = blocks[0] as Map<String, dynamic>;
      if (first['type'] == 'markdown') {
        return first['content'] as String? ?? '';
      }
    }
    return '';
  }

  Widget _buildMarkdownEditor(ColorSet c, EditorSection s) {
    final content = _resolveMarkdownContent(s);
    return MarkdownEditorWithToolbar(
      text: content,
      colors: c,
      hintText: 'Введите Markdown...',
      onChanged: (v) {
        ref.read(editorProvider.notifier).updateSectionData(widget.sectionIndex, {
          'content': v,
          'blocks': [{'type': 'markdown', 'content': v}],
        });
      },
    );
  }

  static final _labelRegex = RegExp(r'^[a-z][a-z0-9_]*$');
}

class _ColumnsSectionEditor extends ConsumerStatefulWidget {
  final int sectionIndex;
  final EditorSection section;
  const _ColumnsSectionEditor({required this.sectionIndex, required this.section});

  @override
  ConsumerState<_ColumnsSectionEditor> createState() => _ColumnsSectionEditorState();
}

class _ColumnsSectionEditorState extends ConsumerState<_ColumnsSectionEditor> {
  int? _colDragFrom;
  int? _colDragOver;
  String? _colDragPos;

  void _acceptTopLevelSection(int topIndex, int atColIdx) {
    final notifier = ref.read(editorProvider.notifier);
    final sections = ref.read(editorProvider).sections;
    if (topIndex >= sections.length) return;
    final section = sections[topIndex];
    final cols = List<dynamic>.from(widget.section.data['columns'] ?? []);
    if (cols.length >= 4) return;
    final newCol = <String, dynamic>{
      'section_type': section.sectionType,
      'config': Map<String, dynamic>.from(section.config),
      'data': Map<String, dynamic>.from(section.data),
    };
    cols.insert(atColIdx + 1, newCol);
    notifier.updateSectionData(widget.sectionIndex, {'columns': cols});
    notifier.removeSection(topIndex);
  }

  void _moveColumn(int from, int to) {
    if (from == to) return;
    final cols = List<dynamic>.from(widget.section.data['columns'] ?? []);
    final item = cols.removeAt(from);
    cols.insert(to, item);
    ref.read(editorProvider.notifier).updateSectionData(widget.sectionIndex, {'columns': cols});
  }

  void _addColumn() {
    final cols = List<dynamic>.from(widget.section.data['columns'] ?? []);
    cols.add({'section_type': '', 'config': <String, dynamic>{}, 'data': <String, dynamic>{}});
    ref.read(editorProvider.notifier).updateSectionData(widget.sectionIndex, {'columns': cols});
  }

  void _removeColumn(int idx) {
    final cols = List<dynamic>.from(widget.section.data['columns'] ?? []);
    if (cols.length <= 1) return;
    cols.removeAt(idx);
    ref.read(editorProvider.notifier).updateSectionData(widget.sectionIndex, {'columns': cols});
  }

  void _setColumnType(int colIdx, String type) {
    final defaults = sectionDefaults[type];
    final config = defaults != null ? json.decode(json.encode(defaults['config'])) as Map<String, dynamic> : <String, dynamic>{};
    final data = defaults != null ? json.decode(json.encode(defaults['data'])) as Map<String, dynamic> : <String, dynamic>{};
    final cols = List<dynamic>.from(widget.section.data['columns'] ?? []);
    final existing = cols[colIdx] as Map<String, dynamic>;
    cols[colIdx] = {...existing, 'section_type': type, 'config': config, 'data': data};
    ref.read(editorProvider.notifier).updateSectionData(widget.sectionIndex, {'columns': cols});
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColors = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final commColor = _parseColor(ref.watch(editorProvider).communityColorHex);
    final c = AppColors.withCommunity(baseColors, commColor);
    final cols = (widget.section.data['columns'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${cols.length} колонок', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
        const SizedBox(height: 8),
        ...cols.asMap().entries.map((e) {
          final idx = e.key;
          final col = e.value as Map<String, dynamic>;
          final type = col['section_type'] as String? ?? '';
          final colConfig = col['config'] as Map<String, dynamic>? ?? {};
          final typeLabel = sectionTypeLabels[type] ?? (type.isEmpty ? 'Пусто' : type);
          final textIcon = sectionTypeTextIcons[type];
          final width = colConfig['width'] as String?;
          final isDragging = _colDragFrom == idx;
          final dragPos = _colDragOver == idx ? _colDragPos : null;

          return DragTarget<SectionDragData>(
            key: ValueKey('col_drag_$idx'),
            onWillAcceptWithDetails: (d) {
              if (d.data.source == 'column' && d.data.parentSectionIndex == widget.sectionIndex) return d.data.index != idx;
              if (d.data.source == 'top' && cols.length < 4) return true;
              return false;
            },
            onMove: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox == null) return;
              final local = renderBox.globalToLocal(details.offset);
              final half = renderBox.size.height / 2;
              setState(() { _colDragOver = idx; _colDragPos = local.dy < half ? 'top' : 'bottom'; });
            },
            onLeave: (_) { if (_colDragOver == idx) setState(() { _colDragOver = null; _colDragPos = null; }); },
            onAcceptWithDetails: (details) {
              final data = details.data;
              if (data.source == 'column' && data.parentSectionIndex == widget.sectionIndex) {
                if (_colDragFrom != null && _colDragFrom != idx) {
                  final from = _colDragFrom!;
                  var to = idx;
                  if (_colDragPos == 'bottom') to = idx + (from < idx ? 0 : 1);
                  else to = idx + (from < idx ? -1 : 0);
                  to = to.clamp(0, cols.length - 1);
                  _moveColumn(from, to);
                }
              } else if (data.source == 'top') {
                _acceptTopLevelSection(data.index, idx);
              }
              setState(() { _colDragFrom = null; _colDragOver = null; _colDragPos = null; });
            },
            builder: (context, accepted, rejected) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: dragPos == 'top' ? BorderSide(color: c.accent, width: 3) : BorderSide.none,
                  bottom: dragPos == 'bottom' ? BorderSide(color: c.accent, width: 3) : BorderSide.none,
                ),
              ),
              child: AnimatedOpacity(
                opacity: isDragging ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: _ColumnItemRow(
                  idx: idx,
                  parentSectionIndex: widget.sectionIndex,
                  c: c,
                  typeLabel: typeLabel,
                  textIcon: textIcon,
                  width: width,
                  type: type,
                  colsLength: cols.length,
                  onRemove: () => _removeColumn(idx),
                  onDragStart: () => setState(() => _colDragFrom = idx),
                  onDragEnd: () => setState(() { _colDragFrom = null; _colDragOver = null; _colDragPos = null; }),
                  child: type.isEmpty
                      ? _buildColumnTypePicker(c, idx)
                      : _buildColumnContent(c, idx, col),
                ),
              ),
            ),
          );
        }),
        Row(
          children: [
            TextButton.icon(
              onPressed: _addColumn,
              icon: Icon(Icons.add, size: 14, color: c.accent),
              label: Text('Добавить колонку', style: TextStyle(fontSize: 12, color: c.accent)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColumnTypePicker(ColorSet c, int colIdx) {
    final types = sectionDefaults.keys.where((t) => t != 'columns').toList();
    return Wrap(
      spacing: 4, runSpacing: 4,
      children: types.map((type) {
        final label = sectionTypeLabels[type] ?? type;
        return InkWell(
          onTap: () => _setColumnType(colIdx, type),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: TextStyle(fontSize: 10, color: c.text)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColumnContent(ColorSet c, int colIdx, Map<String, dynamic> col) {
    final type = col['section_type'] as String? ?? '';
    final config = col['config'] as Map<String, dynamic>? ?? {};
    final data = col['data'] as Map<String, dynamic>? ?? {};

    final virtualSection = EditorSection(
      sectionType: type,
      config: Map<String, dynamic>.from(config),
      data: Map<String, dynamic>.from(data),
    );
    final encodedIndex = encodeNestedIndex(widget.sectionIndex, colIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Заголовок:', style: TextStyle(fontSize: 11, color: c.textSecondary)),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 28,
                child: _PersistentEditorField(
                  text: config['title'] as String? ?? '',
                  decoration: InputDecoration(
                    hintText: sectionTypeLabels[type] ?? type,
                    hintStyle: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.4)),
                    border: InputBorder.none, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  style: TextStyle(fontSize: 12, color: c.text),
                  onChanged: (v) {
                    ref.read(editorProvider.notifier).updateColumnConfig(widget.sectionIndex, colIdx, {'title': v});
                  },
                ),
              ),
            ),
            InkWell(
              onTap: () => _setColumnType(colIdx, ''),
              borderRadius: BorderRadius.circular(3),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.swap_horiz, size: 14, color: c.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: c.border),
        const SizedBox(height: 6),
        // Full settings editor for the nested section type
        SectionConfigEditor(
          sectionIndex: encodedIndex,
          section: virtualSection,
        ),
      ],
    );
  }
}

class _ColumnItemRow extends StatefulWidget {
  final int idx;
  final int parentSectionIndex;
  final ColorSet c;
  final String typeLabel;
  final String? textIcon;
  final String? width;
  final String type;
  final int colsLength;
  final VoidCallback onRemove;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final Widget child;

  const _ColumnItemRow({
    required this.idx,
    required this.parentSectionIndex,
    required this.c,
    required this.typeLabel,
    this.textIcon,
    this.width,
    required this.type,
    required this.colsLength,
    required this.onRemove,
    required this.onDragStart,
    required this.onDragEnd,
    required this.child,
  });

  @override
  State<_ColumnItemRow> createState() => _ColumnItemRowState();
}

class _ColumnItemRowState extends State<_ColumnItemRow> {
  bool _handleHovered = false;
  bool _itemHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _itemHovered = true),
      onExit: (_) => setState(() => _itemHovered = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Draggable<SectionDragData>(
            data: SectionDragData(source: 'column', index: widget.idx, parentSectionIndex: widget.parentSectionIndex),
            onDragStarted: widget.onDragStart,
            onDragEnd: (_) => widget.onDragEnd(),
            feedback: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: c.accent)),
                child: Text(widget.typeLabel, style: TextStyle(fontSize: 11, color: c.text)),
              ),
            ),
            childWhenDragging: const SizedBox.shrink(),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              onEnter: (_) => setState(() => _handleHovered = true),
              onExit: (_) => setState(() => _handleHovered = false),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 0),
                child: AnimatedOpacity(
                  opacity: _handleHovered ? 1.0 : (_itemHovered ? 0.6 : 0.0),
                  duration: const Duration(milliseconds: 150),
                  child: CustomPaint(
                    size: const Size(12, 12),
                    painter: _ColDragDotsPainter(color: c.textSecondary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: c.border),
                        alignment: Alignment.center,
                        child: Text('${widget.idx + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
                      ),
                      if (widget.width != null) ...[
                        const SizedBox(width: 6),
                        Text('(${widget.width})', style: TextStyle(fontSize: 10, color: c.textSecondary)),
                      ],
                      const Spacer(),
                      if (widget.type.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.textIcon != null) Text(widget.textIcon!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.accent, fontFamily: 'monospace')),
                              if (widget.textIcon != null) const SizedBox(width: 3),
                              Text(widget.typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.accent)),
                            ],
                          ),
                        ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: widget.colsLength <= 1 ? null : widget.onRemove,
                        child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  widget.child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColDragDotsPainter extends CustomPainter {
  final Color color;
  _ColDragDotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final cy in [5.0, 12.0, 19.0]) {
      canvas.drawCircle(Offset(size.width * 0.375, cy * size.height / 24), 1, paint);
      canvas.drawCircle(Offset(size.width * 0.625, cy * size.height / 24), 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ColDragDotsPainter old) => old.color != color;
}
