import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/uploads_api.dart';
import '../../../providers/editor_provider.dart';
import 'markdown_toolbar.dart';

class _PersistentTextField extends StatefulWidget {
  final String text;
  final InputDecoration? decoration;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;

  const _PersistentTextField({
    required this.text,
    this.decoration,
    this.style,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
  });

  @override
  State<_PersistentTextField> createState() => _PersistentTextFieldState();
}

class _PersistentTextFieldState extends State<_PersistentTextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant _PersistentTextField old) {
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
      keyboardType: widget.keyboardType,
    );
  }
}

class SectionConfigEditor extends ConsumerWidget {
  final int sectionIndex;
  final EditorSection section;

  const SectionConfigEditor({super.key, required this.sectionIndex, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    return switch (section.sectionType) {
      'community-header' => _HeaderConfigEditor(i: sectionIndex, data: section.data, c: c),
      'chat' => _ChatConfigEditor(i: sectionIndex, config: section.config, c: c),
      'polls' => _PollsConfigEditor(i: sectionIndex, config: section.config, data: section.data, c: c),
      'calendar' => _CalendarConfigEditor(i: sectionIndex, config: section.config, c: c),
      'announcements' => _AnnouncementsConfigEditor(i: sectionIndex, config: section.config, c: c),
      'booking' => _BookingConfigEditor(i: sectionIndex, config: section.config, c: c),
      'quiz' => _QuizConfigEditor(i: sectionIndex, config: section.config, data: section.data, c: c),
      'products' => _ProductsConfigEditor(i: sectionIndex, config: section.config, data: section.data, c: c),
      'wiki' => _WikiConfigEditor(i: sectionIndex, data: section.data, c: c),
      'navigation' => _NavigationConfigEditor(i: sectionIndex, config: section.config, c: c),
      'popular-pages' => _PopularPagesConfigEditor(i: sectionIndex, config: section.config, c: c),
      'recent-updates' => _RecentUpdatesConfigEditor(i: sectionIndex, config: section.config, c: c),
      'content' => _ContentConfigEditor(i: sectionIndex, config: section.config, c: c),
      'script' => _ScriptConfigEditor(i: sectionIndex, config: section.config, c: c),
      'columns' => _ColumnsConfigEditor(i: sectionIndex, data: section.data, c: c),
      _ => _CommonConfigEditor(i: sectionIndex, config: section.config, c: c),
    };
  }
}

// ── Content ──
// Web: content section config — visible, editable, editorMode (blocks|markdown)

class _ContentConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _ContentConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorMode = config['editorMode'] as String? ?? 'blocks';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggle('Видимая', config['visible'] != false, c, (v) => _cfg(ref, i, {'visible': v})),
        _toggle('Редактируемая', config['editable'] != false, c, (v) => _cfg(ref, i, {'editable': v})),
        _sectionLabel('Режим редактора', c),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'blocks', label: Text('Блоки')),
            ButtonSegment(value: 'markdown', label: Text('Markdown')),
          ],
          selected: {editorMode},
          onSelectionChanged: (sel) => _cfg(ref, i, {'editorMode': sel.first}),
          showSelectedIcon: false,
        ),
        _hint('В режиме Markdown блоки недоступны. Переключение режима приводит к конвертации контента.', c),
      ],
    );
  }
}

// ── Script ──
// Web: ScriptEditor — text/visual mode toggle, code, visual_blocks

class _ScriptConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _ScriptConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggle('Видимая', config['visible'] != false, c, (v) => _cfg(ref, i, {'visible': v})),
        _hint('Код скрипта редактируется в основной области секции.', c),
      ],
    );
  }
}

// ── Columns ──
// Web: ColumnsSectionEditor — column_count, per-column width

class _ColumnsConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> data;
  final ColorSet c;
  const _ColumnsConfigEditor({required this.i, required this.data, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = (data['columns'] as List<dynamic>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${cols.length} колонок', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 8),
        ...cols.asMap().entries.map((e) {
          final idx = e.key;
          final col = e.value as Map<String, dynamic>;
          final cfg = col['config'] as Map<String, dynamic>? ?? {};
          final width = cfg['width'] as String?;
          final widthNum = width != null ? int.tryParse(width.replaceAll('%', '')) : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text('Колонка ${idx + 1}', style: TextStyle(fontSize: 12, color: c.textSecondary))),
                Expanded(
                  child: _PersistentTextField(
                    text: widthNum?.toString() ?? '',
                    decoration: InputDecoration(
                      hintText: 'auto',
                      hintStyle: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.4)),
                      border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      suffixText: '%',
                      suffixStyle: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    style: TextStyle(fontSize: 13, color: c.text),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      final newCols = List<dynamic>.from(cols);
                      final newCfg = Map<String, dynamic>.from(cfg);
                      if (parsed != null && parsed > 0 && parsed <= 100) {
                        newCfg['width'] = '$parsed%';
                      } else {
                        newCfg.remove('width');
                      }
                      newCols[idx] = {...col, 'config': newCfg};
                      _dat(ref, i, {'columns': newCols});
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        _hint('Ширина каждой колонки в процентах. Пусто = авторазмер.', c),
      ],
    );
  }
}

// ── Common fallback ──

class _CommonConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _CommonConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggle('Видимая', config['visible'] != false, c, (v) => _cfg(ref, i, {'visible': v})),
      ],
    );
  }
}

InputDecoration _dec(String label, ColorSet c) => InputDecoration(
  labelText: label.isEmpty ? null : label,
  labelStyle: TextStyle(fontSize: 12, color: c.textSecondary),
  border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
);

// Encoded sectionIndex: negative value means nested column.
// Format: -(parentIdx * 1000 + colIdx) - 1
int encodeNestedIndex(int parentIdx, int colIdx) => -(parentIdx * 1000 + colIdx) - 1;

void _cfg(WidgetRef ref, int i, Map<String, dynamic> patch) {
  if (i < 0) {
    final encoded = -i - 1;
    final parentIdx = encoded ~/ 1000;
    final colIdx = encoded % 1000;
    ref.read(editorProvider.notifier).updateColumnConfig(parentIdx, colIdx, patch);
  } else {
    ref.read(editorProvider.notifier).updateSectionConfig(i, patch);
  }
}

void _dat(WidgetRef ref, int i, Map<String, dynamic> patch) {
  if (i < 0) {
    final encoded = -i - 1;
    final parentIdx = encoded ~/ 1000;
    final colIdx = encoded % 1000;
    ref.read(editorProvider.notifier).updateColumnData(parentIdx, colIdx, patch);
  } else {
    ref.read(editorProvider.notifier).updateSectionData(i, patch);
  }
}

Widget _toggle(String label, bool value, ColorSet c, void Function(bool) onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.text))),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

Widget _sectionLabel(String text, ColorSet c) {
  return Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
        letterSpacing: 0.6,
      ),
    ),
  );
}

Widget _hint(String text, ColorSet c) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
  );
}

Widget _fieldLabel(String text, ColorSet c) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text),
    ),
  );
}

BoxDecoration _cardDec(ColorSet c) => BoxDecoration(
  color: c.hoverOverlay,
  border: Border.all(color: c.border),
  borderRadius: BorderRadius.circular(8),
);

Widget _smallBtn(String label, ColorSet c, VoidCallback onTap, {Color? color, IconData? icon}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
        color: c.surfaceAlt,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color ?? c.text),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: color ?? c.text)),
        ],
      ),
    ),
  );
}

Widget _numInput({
  required String hint,
  required int value,
  required void Function(int) onChanged,
  required ColorSet c,
  int? min,
  int? max,
  double width = 90,
  String? suffix,
}) {
  final field = _PersistentTextField(
    text: '$value',
    decoration: InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    style: TextStyle(fontSize: 13, color: c.text),
    keyboardType: TextInputType.number,
    onChanged: (v) {
      final parsed = int.tryParse(v);
      if (parsed == null) return;
      final clamped = max != null
          ? (min != null ? parsed.clamp(min, max) : (parsed > max ? max : parsed))
          : (min != null && parsed < min ? min : parsed);
      onChanged(clamped);
    },
  );
  final wrappedField = width.isFinite ? SizedBox(width: width, child: field) : Expanded(child: field);
  return Row(
    mainAxisSize: width.isFinite ? MainAxisSize.min : MainAxisSize.max,
    children: [
      wrappedField,
      if (suffix != null) ...[
        const SizedBox(width: 6),
        Text(suffix, style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ],
    ],
  );
}

// ── Header ──
// Web: HeaderEditor.vue — banner upload+drag, avatar upload, community_color, description

class _HeaderConfigEditor extends ConsumerStatefulWidget {
  final int i;
  final Map<String, dynamic> data;
  final ColorSet c;
  const _HeaderConfigEditor({required this.i, required this.data, required this.c});

  @override
  ConsumerState<_HeaderConfigEditor> createState() => _HeaderConfigEditorState();
}

class _HeaderConfigEditorState extends ConsumerState<_HeaderConfigEditor> {
  bool _bannerUploading = false;
  bool _avatarUploading = false;
  int _bannerProgress = 0;
  int _avatarProgress = 0;
  String? _bannerError;
  String? _avatarError;

  Future<void> _pickAndUpload({required bool isBanner}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    final maxBytes = isBanner ? 10 * 1024 * 1024 : 5 * 1024 * 1024;
    if (file.bytes!.length > maxBytes) {
      setState(() {
        if (isBanner) { _bannerError = 'Файл слишком большой'; }
        else { _avatarError = 'Файл слишком большой'; }
      });
      return;
    }

    setState(() {
      if (isBanner) { _bannerUploading = true; _bannerProgress = 0; _bannerError = null; }
      else { _avatarUploading = true; _avatarProgress = 0; _avatarError = null; }
    });

    try {
      final api = UploadsApi(ref.read(apiClientProvider));
      final uploaded = await api.upload(
        bytes: file.bytes!,
        filename: file.name,
        contentType: 'image/${file.extension ?? 'png'}',
        onProgress: (p) => setState(() {
          if (isBanner) { _bannerProgress = p; } else { _avatarProgress = p; }
        }),
      );
      _dat(ref, widget.i, {isBanner ? 'banner_url' : 'avatar_url': uploaded.url});
    } catch (e) {
      setState(() {
        if (isBanner) { _bannerError = 'Ошибка загрузки'; }
        else { _avatarError = 'Ошибка загрузки'; }
      });
    } finally {
      if (mounted) setState(() {
        if (isBanner) { _bannerUploading = false; } else { _avatarUploading = false; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final data = widget.data;
    final i = widget.i;
    final bannerUrl = data['banner_url'] as String? ?? '';
    final avatarUrl = data['avatar_url'] as String? ?? '';
    final communityColor = data['community_color'] as String? ?? '';
    final bannerHeight = (data['banner_height'] as int?) ?? 120;
    final bannerOffsetX = (data['banner_offset_x'] as int?) ?? 50;
    final bannerOffsetY = (data['banner_offset_y'] as int?) ?? 50;
    final bannerZoom = (data['banner_zoom'] as int?) ?? 100;
    final description = data['description'] as String? ?? '';
    Color? colorSwatch;
    try {
      if (communityColor.isNotEmpty && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(communityColor)) {
        colorSwatch = Color(int.parse(communityColor.replaceFirst('#', 'FF'), radix: 16));
      }
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Баннер', c),
        // Banner preview or placeholder
        Container(
          height: bannerHeight.toDouble().clamp(60.0, 200.0),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
            gradient: bannerUrl.isEmpty
                ? LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [colorSwatch ?? c.accent, c.surfaceAlt],
                  )
                : null,
            image: bannerUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(fullImageUrl(bannerUrl)), fit: BoxFit.cover, alignment: Alignment(bannerOffsetX / 50 - 1, bannerOffsetY / 50 - 1))
                : null,
          ),
          alignment: Alignment.center,
          child: bannerUrl.isEmpty
              ? Text('БАННЕР', style: TextStyle(fontSize: 11, letterSpacing: 0.6, fontWeight: FontWeight.w600, color: c.surface))
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _smallBtn(
              _bannerUploading ? 'Загрузка $_bannerProgress%' : 'Выбрать файл',
              c,
              _bannerUploading ? () {} : () => _pickAndUpload(isBanner: true),
              icon: Icons.upload_file_outlined,
              color: c.accent,
            ),
            if (bannerUrl.isNotEmpty) ...[
              const SizedBox(width: 8),
              _smallBtn('Удалить', c, () => _dat(ref, i, {'banner_url': ''}), color: c.error, icon: Icons.close),
            ],
          ],
        ),
        if (_bannerError != null) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_bannerError!, style: TextStyle(fontSize: 12, color: c.error)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Высота (px)', c),
                  _numInput(hint: '120', value: bannerHeight, min: 60, max: 300, c: c, width: double.infinity,
                    onChanged: (v) => _dat(ref, i, {'banner_height': v})),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Масштаб (%)', c),
                  _numInput(hint: '100', value: bannerZoom, min: 100, max: 300, c: c, width: double.infinity,
                    onChanged: (v) => _dat(ref, i, {'banner_zoom': v})),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Смещение X (%)', c),
                  _numInput(hint: '50', value: bannerOffsetX, min: 0, max: 100, c: c, width: double.infinity,
                    onChanged: (v) => _dat(ref, i, {'banner_offset_x': v})),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Смещение Y (%)', c),
                  _numInput(hint: '50', value: bannerOffsetY, min: 0, max: 100, c: c, width: double.infinity,
                    onChanged: (v) => _dat(ref, i, {'banner_offset_y': v})),
                ],
              ),
            ),
          ],
        ),

        _sectionLabel('Аватар', c),
        Row(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: avatarUrl.isNotEmpty ? null : (colorSwatch ?? c.accent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(fullImageUrl(avatarUrl)), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: avatarUrl.isEmpty
                  ? const Text('?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _smallBtn(
                        _avatarUploading ? 'Загрузка $_avatarProgress%' : 'Выбрать файл',
                        c,
                        _avatarUploading ? () {} : () => _pickAndUpload(isBanner: false),
                        icon: Icons.upload_file_outlined,
                        color: c.accent,
                      ),
                      if (avatarUrl.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _smallBtn('Удалить', c, () => _dat(ref, i, {'avatar_url': ''}), color: c.error, icon: Icons.close),
                      ],
                    ],
                  ),
                  if (_avatarError != null) Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_avatarError!, style: TextStyle(fontSize: 12, color: c.error)),
                  ),
                ],
              ),
            ),
          ],
        ),

        _sectionLabel('Цвет сообщества', c),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await _showColorPicker(context, colorSwatch ?? c.accent, c);
                if (picked != null) {
                  final hex = '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                  _dat(ref, i, {'community_color': hex});
                }
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: colorSwatch ?? c.accent,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PersistentTextField(
                text: communityColor,
                decoration: _dec('#hex', c),
                style: TextStyle(fontSize: 13, color: c.text, fontFamily: 'monospace'),
                onChanged: (v) => _dat(ref, i, {'community_color': v}),
              ),
            ),
            if (communityColor.isNotEmpty) ...[
              const SizedBox(width: 8),
              _smallBtn('Сброс', c, () => _dat(ref, i, {'community_color': ''}), color: c.textSecondary),
            ],
          ],
        ),

        _sectionLabel('Описание', c),
        _PersistentTextField(
          text: description,
          decoration: _dec('Описание сообщества', c),
          style: TextStyle(fontSize: 13, color: c.text),
          maxLines: 3,
          onChanged: (v) => _dat(ref, i, {'description': v}),
        ),
      ],
    );
  }

  static Future<Color?> _showColorPicker(BuildContext context, Color current, ColorSet c) async {
    const palette = [
      0xFF5B7FF5, 0xFFE74C3C, 0xFFE67E22, 0xFFF1C40F, 0xFF2ECC71,
      0xFF1ABC9C, 0xFF3498DB, 0xFF9B59B6, 0xFF34495E, 0xFFECF0F1,
      0xFF95A5A6, 0xFFFF6B9D, 0xFF6AB04C, 0xFFE58E26, 0xFF2C3E50,
    ];
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Выбрать цвет', style: TextStyle(fontSize: 16)),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: palette.map((v) {
            final color = Color(v);
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, color),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border, width: 2),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена'))],
      ),
    );
  }
}

// ── Chat ──
// Web: SectionEditor.vue inline — max_length, chat_height_pct, moderated, allow_attachments,
//   max_attachments, disabled_fonts checklist (11 fonts), allowed_colors (color tags + picker)

class _ChatConfigEditor extends ConsumerStatefulWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _ChatConfigEditor({required this.i, required this.config, required this.c});

  @override
  ConsumerState<_ChatConfigEditor> createState() => _ChatConfigEditorState();
}

class _ChatConfigEditorState extends ConsumerState<_ChatConfigEditor> {
  final _colorCtrl = TextEditingController(text: '#e74c3c');

  @override
  void dispose() {
    _colorCtrl.dispose();
    super.dispose();
  }

  static const _allFonts = [
    'Arial', 'Comic Sans MS', 'Courier New', 'Georgia', 'Impact',
    'Lucida Console', 'Palatino Linotype', 'Tahoma', 'Times New Roman',
    'Trebuchet MS', 'Verdana',
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final config = widget.config;
    final i = widget.i;
    final disabledFonts = (config['disabled_fonts'] as List<dynamic>?)?.cast<String>() ?? [];
    final allowedColors = (config['allowed_colors'] as List<dynamic>?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Основные', c),
        Row(
          children: [
            Expanded(child: Text('Макс. длина сообщения', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '500',
              value: (config['max_length'] as int?) ?? 500,
              min: 1, max: 2000,
              c: c,
              width: 90,
              onChanged: (v) => _cfg(ref, i, {'max_length': v}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('Высота чата (%)', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '30',
              value: (config['chat_height_pct'] as int?) ?? 30,
              min: 10, max: 100,
              c: c,
              width: 90,
              suffix: '%',
              onChanged: (v) => _cfg(ref, i, {'chat_height_pct': v}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _toggle('Модерация', config['moderated'] == true, c, (v) => _cfg(ref, i, {'moderated': v})),
        _toggle('Разрешить вложения', config['allow_attachments'] != false, c, (v) => _cfg(ref, i, {'allow_attachments': v})),
        if (config['allow_attachments'] != false)
          Row(
            children: [
              Expanded(child: Text('Макс. вложений', style: TextStyle(fontSize: 13, color: c.textSecondary))),
              _numInput(
                hint: '5',
                value: (config['max_attachments'] as int?) ?? 5,
                min: 1, max: 20,
                c: c,
                width: 90,
                onChanged: (v) => _cfg(ref, i, {'max_attachments': v}),
              ),
            ],
          ),

        _sectionLabel('Доступные шрифты', c),
        ..._allFonts.map((font) {
          final enabled = !disabledFonts.contains(font);
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 24, height: 24,
                  child: Checkbox(
                    value: enabled,
                    onChanged: (v) {
                      final updated = List<String>.from(disabledFonts);
                      if (v == true) { updated.remove(font); } else { updated.add(font); }
                      _cfg(ref, i, {'disabled_fonts': updated});
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Text(font, style: TextStyle(fontSize: 13, color: c.text)),
              ],
            ),
          );
        }),

        _sectionLabel('Цвета', c),
        if (allowedColors.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 6, runSpacing: 4,
            children: allowedColors.asMap().entries.map((e) {
              final ci = e.key;
              final hex = e.value;
              Color? parsed;
              try { parsed = Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16)); } catch (_) {}
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: parsed ?? Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(hex, style: TextStyle(fontSize: 12, color: c.text, fontFamily: 'monospace')),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        final updated = List<String>.from(allowedColors)..removeAt(ci);
                        _cfg(ref, i, {'allowed_colors': updated});
                      },
                      child: Icon(Icons.close, size: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _colorCtrl,
                decoration: _dec('#hex цвет', c),
                style: TextStyle(fontSize: 12, color: c.text, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final color = _colorCtrl.text.trim();
                if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) return;
                if (allowedColors.contains(color)) return;
                final updated = List<String>.from(allowedColors)..add(color);
                _cfg(ref, i, {'allowed_colors': updated});
              },
              icon: Icon(Icons.add, color: c.accent),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Polls ──
// Web: PollEditor.vue — question, options CRUD, allow_multiple, show_results, allow_vote_cancel

class _PollsConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final Map<String, dynamic> data;
  final ColorSet c;
  const _PollsConfigEditor({required this.i, required this.config, required this.data, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = (data['options'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PersistentTextField(
          text: data['question'] as String? ?? '',
          decoration: _dec('Вопрос', c),
          style: TextStyle(fontSize: 13, color: c.text),
          onChanged: (v) => _dat(ref, i, {'question': v}),
        ),
        const SizedBox(height: 12),
        _sectionLabel('Варианты', c),
        ...options.asMap().entries.map((e) {
          final idx = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${idx + 1}.', style: TextStyle(fontSize: 13, color: c.textSecondary), textAlign: TextAlign.right),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PersistentTextField(
                    text: e.value['text'] as String? ?? '',
                    decoration: _dec('', c),
                    style: TextStyle(fontSize: 13, color: c.text),
                    onChanged: (v) {
                      final updated = options.map((o) => Map<String, dynamic>.from(o)).toList();
                      updated[idx]['text'] = v;
                      _dat(ref, i, {'options': updated});
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    final updated = options.map((o) => Map<String, dynamic>.from(o)).toList()..removeAt(idx);
                    _dat(ref, i, {'options': updated});
                  },
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final updated = options.map((o) => Map<String, dynamic>.from(o)).toList()
              ..add({'text': '', 'id': '${DateTime.now().millisecondsSinceEpoch}'});
            _dat(ref, i, {'options': updated});
          },
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить вариант', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
        const SizedBox(height: 8),
        _sectionLabel('Настройки', c),
        _toggle('Множественный выбор', config['allow_multiple'] == true, c, (v) => _cfg(ref, i, {'allow_multiple': v})),
        _toggle('Показывать результаты', config['show_results'] != false, c, (v) => _cfg(ref, i, {'show_results': v})),
        _toggle('Разрешить отмену голоса', config['allow_vote_cancel'] != false, c, (v) => _cfg(ref, i, {'allow_vote_cancel': v})),
      ],
    );
  }
}

// ── Calendar ──
// Web: CalendarEditor.vue — allow_member_create, week_start, default_view, hint

class _CalendarConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _CalendarConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Настройки', c),
        _toggle('Участники могут создавать события', config['allow_member_create'] == true, c,
          (v) => _cfg(ref, i, {'allow_member_create': v}),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: config['week_start'] as String? ?? 'monday',
          decoration: _dec('Начало недели', c),
          items: const [
            DropdownMenuItem(value: 'monday', child: Text('Понедельник')),
            DropdownMenuItem(value: 'sunday', child: Text('Воскресенье')),
          ],
          onChanged: (v) => _cfg(ref, i, {'week_start': v}),
          style: TextStyle(fontSize: 13, color: c.text),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: config['default_view'] as String? ?? 'month',
          decoration: _dec('Вид по умолчанию', c),
          items: const [
            DropdownMenuItem(value: 'month', child: Text('Месяц')),
            DropdownMenuItem(value: 'week', child: Text('Неделя')),
            DropdownMenuItem(value: 'day', child: Text('День')),
          ],
          onChanged: (v) => _cfg(ref, i, {'default_view': v}),
          style: TextStyle(fontSize: 13, color: c.text),
        ),
        _hint('Добавляйте и редактируйте события на странице календаря', c),
      ],
    );
  }
}

// ── Announcements ──
// Web: AnnouncementEditor.vue — allow_priority, allow_pinning, max_items, hint

class _AnnouncementsConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _AnnouncementsConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Настройки', c),
        _toggle('Разрешить приоритеты', config['allow_priority'] != false, c, (v) => _cfg(ref, i, {'allow_priority': v})),
        _toggle('Разрешить закрепление', config['allow_pinning'] != false, c, (v) => _cfg(ref, i, {'allow_pinning': v})),
        Row(
          children: [
            Expanded(child: Text('Макс. количество', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '50',
              value: (config['max_items'] as int?) ?? 50,
              min: 5, max: 200,
              c: c,
              width: 90,
              onChanged: (v) => _cfg(ref, i, {'max_items': v}),
            ),
          ],
        ),
        _hint('Создание и редактирование объявлений доступно на странице', c),
      ],
    );
  }
}

// ── Booking ──
// Web: BookingEditor.vue — working_hours per-day, slot_interval, max_advance_days,
//   require_confirmation, custom_fields CRUD (label_ru/en, type, required, options)

class _BookingConfigEditor extends ConsumerStatefulWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _BookingConfigEditor({required this.i, required this.config, required this.c});

  @override
  ConsumerState<_BookingConfigEditor> createState() => _BookingConfigEditorState();
}

class _BookingConfigEditorState extends ConsumerState<_BookingConfigEditor> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final config = widget.config;
    final i = widget.i;
    final workingHours = config['working_hours'] as Map<String, dynamic>? ?? {};
    final customFields = (config['custom_fields'] as List<dynamic>?)
        ?.map((f) => Map<String, dynamic>.from(f as Map))
        .toList() ?? [];

    final cancelBefore = (config['allow_cancel_before_minutes'] as int?) ?? 120;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Рабочие часы', c),
        ..._buildWorkingHours(workingHours, i),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Интервал слота', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '30',
              value: (config['slot_interval'] as int?) ?? (config['slot_duration'] as int?) ?? (config['slot_duration_minutes'] as int?) ?? 30,
              min: 5, max: 480,
              c: c,
              width: 90,
              suffix: 'мин',
              onChanged: (v) => _cfg(ref, i, {'slot_interval': v}),
            ),
          ],
        ),

        _sectionLabel('Настройки', c),
        Row(
          children: [
            Expanded(child: Text('Макс. дней вперёд', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '30',
              value: (config['max_advance_days'] as int?) ?? 30,
              min: 1, max: 365,
              c: c,
              width: 90,
              onChanged: (v) => _cfg(ref, i, {'max_advance_days': v}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('Отмена за (мин)', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '120',
              value: cancelBefore,
              min: 0, max: 10080,
              c: c,
              width: 90,
              suffix: 'мин',
              onChanged: (v) => _cfg(ref, i, {'allow_cancel_before_minutes': v}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _toggle('Требуется подтверждение', config['require_confirmation'] == true, c,
          (v) => _cfg(ref, i, {'require_confirmation': v}),
        ),

        _sectionLabel('Дополнительные поля', c),
        ...customFields.asMap().entries.map((e) => _buildCustomField(e.key, e.value, customFields, i)),
        Align(
          alignment: Alignment.centerLeft,
          child: _smallBtn('+ Добавить поле', c, () {
            final updated = _cloneFields(customFields)
              ..add({'label_ru': '', 'label_en': '', 'type': 'text', 'required': false, 'options': <String>[]});
            _cfg(ref, i, {'custom_fields': updated});
          }, color: c.accent),
        ),
        _hint('Управление специалистами и услугами — со страницы бронирования', c),
      ],
    );
  }

  Widget _buildCustomField(int fi, Map<String, dynamic> field, List<Map<String, dynamic>> allFields, int i) {
    final c = widget.c;
    final fieldType = field['type'] as String? ?? 'text';
    final fieldOptions = (field['options'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDec(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${fi + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
              const Spacer(),
              InkWell(
                onTap: () {
                  final updated = _cloneFields(allFields)..removeAt(fi);
                  _cfg(ref, i, {'custom_fields': updated});
                },
                child: Text('Удалить', style: TextStyle(fontSize: 12, color: c.error)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _PersistentTextField(
                text: field['label_ru'] as String? ?? '',
                decoration: _dec('Метка (RU)', c),
                style: TextStyle(fontSize: 13, color: c.text),
                onChanged: (v) {
                  final updated = _cloneFields(allFields);
                  updated[fi]['label_ru'] = v;
                  _cfg(ref, i, {'custom_fields': updated});
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: _PersistentTextField(
                text: field['label_en'] as String? ?? '',
                decoration: _dec('Метка (EN)', c),
                style: TextStyle(fontSize: 13, color: c.text),
                onChanged: (v) {
                  final updated = _cloneFields(allFields);
                  updated[fi]['label_en'] = v;
                  _cfg(ref, i, {'custom_fields': updated});
                },
              )),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: fieldType,
                  decoration: _dec('Тип', c),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('Text')),
                    DropdownMenuItem(value: 'textarea', child: Text('Textarea')),
                    DropdownMenuItem(value: 'select', child: Text('Select')),
                  ],
                  onChanged: (v) {
                    final updated = _cloneFields(allFields);
                    updated[fi]['type'] = v;
                    _cfg(ref, i, {'custom_fields': updated});
                  },
                  style: TextStyle(fontSize: 13, color: c.text),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24, height: 24,
                    child: Checkbox(
                      value: field['required'] == true,
                      onChanged: (v) {
                        final updated = _cloneFields(allFields);
                        updated[fi]['required'] = v;
                        _cfg(ref, i, {'custom_fields': updated});
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Обязат.', style: TextStyle(fontSize: 12, color: c.text)),
                ],
              ),
            ],
          ),
          if (fieldType == 'select') ...[
            const SizedBox(height: 6),
            Text('Варианты:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 4),
            ...fieldOptions.asMap().entries.map((oe) {
              final oi = oe.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: _PersistentTextField(
                      text: oe.value,
                      decoration: _dec('', c),
                      style: TextStyle(fontSize: 12, color: c.text),
                      onChanged: (v) {
                        final updated = _cloneFields(allFields);
                        final opts = List<String>.from(updated[fi]['options'] as List? ?? []);
                        opts[oi] = v;
                        updated[fi]['options'] = opts;
                        _cfg(ref, i, {'custom_fields': updated});
                      },
                    )),
                    InkWell(
                      onTap: () {
                        final updated = _cloneFields(allFields);
                        final opts = List<String>.from(updated[fi]['options'] as List? ?? [])..removeAt(oi);
                        updated[fi]['options'] = opts;
                        _cfg(ref, i, {'custom_fields': updated});
                      },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error)),
                    ),
                  ],
                ),
              );
            }),
            TextButton(
              onPressed: () {
                final updated = _cloneFields(allFields);
                final opts = List<String>.from(updated[fi]['options'] as List? ?? [])..add('');
                updated[fi]['options'] = opts;
                _cfg(ref, i, {'custom_fields': updated});
              },
              child: Text('+ Добавить вариант', style: TextStyle(fontSize: 12, color: c.accent)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildWorkingHours(Map<String, dynamic> hours, int i) {
    const days = [
      ('mon', 'Пн'), ('tue', 'Вт'), ('wed', 'Ср'), ('thu', 'Чт'),
      ('fri', 'Пт'), ('sat', 'Сб'), ('sun', 'Вс'),
    ];
    final c = widget.c;

    return days.map((day) {
      final dayConfig = hours[day.$1] as Map<String, dynamic>? ?? {};
      final enabled = dayConfig['enabled'] as bool? ?? (day.$1 != 'sat' && day.$1 != 'sun');
      final start = dayConfig['start'] as String? ?? '09:00';
      final end = dayConfig['end'] as String? ?? '18:00';

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.hoverOverlay,
          borderRadius: BorderRadius.circular(6),
        ),
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: enabled,
                onChanged: (v) {
                  final updated = Map<String, dynamic>.from(hours);
                  updated[day.$1] = {'enabled': v, 'start': start, 'end': end};
                  _cfg(ref, i, {'working_hours': updated});
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text(day.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: enabled ? c.text : c.textSecondary)),
            ),
            const SizedBox(width: 4),
            if (enabled) ...[
              SizedBox(
                width: 70,
                child: _PersistentTextField(
                  text: start,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                  ),
                  style: TextStyle(fontSize: 13, color: c.text),
                  onChanged: (v) {
                    final updated = Map<String, dynamic>.from(hours);
                    updated[day.$1] = {'enabled': enabled, 'start': v, 'end': end};
                    _cfg(ref, i, {'working_hours': updated});
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('—', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              ),
              SizedBox(
                width: 70,
                child: _PersistentTextField(
                  text: end,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                  ),
                  style: TextStyle(fontSize: 13, color: c.text),
                  onChanged: (v) {
                    final updated = Map<String, dynamic>.from(hours);
                    updated[day.$1] = {'enabled': enabled, 'start': start, 'end': v};
                    _cfg(ref, i, {'working_hours': updated});
                  },
                ),
              ),
            ] else
              Expanded(
                child: Text('Выходной', style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _cloneFields(List<Map<String, dynamic>> fields) {
    return fields.map((f) {
      final clone = Map<String, dynamic>.from(f);
      if (clone['options'] is List) {
        clone['options'] = List<String>.from(clone['options'] as List);
      }
      return clone;
    }).toList();
  }
}

// ── Quiz ──
// Web: QuizEditor.vue — shuffleOnStart, one_time, mode settings (flashcards/test/type enable+label),
//   cards (front/back 2-col, move up/down, per-card options expand, frontImage/backImage),
//   add card + import

class _QuizConfigEditor extends ConsumerStatefulWidget {
  final int i;
  final Map<String, dynamic> config;
  final Map<String, dynamic> data;
  final ColorSet c;
  const _QuizConfigEditor({required this.i, required this.config, required this.data, required this.c});

  @override
  ConsumerState<_QuizConfigEditor> createState() => _QuizConfigEditorState();
}

class _QuizConfigEditorState extends ConsumerState<_QuizConfigEditor> {
  final _importCtrl = TextEditingController();
  bool _showImport = false;
  final Set<int> _expandedOptions = {};

  @override
  void dispose() {
    _importCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final config = widget.config;
    final data = widget.data;
    final i = widget.i;
    final settings = data['settings'] as Map<String, dynamic>? ?? {};
    final cards = (data['cards'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final modes = settings['modes'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Настройки', c),
        Row(
          children: [
            Expanded(child: _toggle('Перемешивать', settings['shuffleOnStart'] != false, c, (v) {
              _dat(ref, i, {'settings': {...settings, 'shuffleOnStart': v}});
            })),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${cards.length} карт.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ),
          ],
        ),
        _toggle('Однократный проход', config['one_time'] == true, c, (v) => _cfg(ref, i, {'one_time': v})),

        _sectionLabel('Режимы', c),
        ...['flashcards', 'test', 'type'].map((modeKey) {
          final mode = modes[modeKey] as Map<String, dynamic>? ?? {};
          final enabled = mode['enabled'] != false;
          final label = mode['label'] as String? ?? '';
          final modeLabel = switch (modeKey) { 'flashcards' => 'Карточки', 'test' => 'Тест', 'type' => 'Ввод', _ => modeKey };

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24, height: 24,
                  child: Checkbox(
                    value: enabled,
                    onChanged: (v) {
                      final updatedModes = Map<String, dynamic>.from(modes);
                      updatedModes[modeKey] = {...Map<String, dynamic>.from(mode), 'enabled': v};
                      _dat(ref, i, {'settings': {...settings, 'modes': updatedModes}});
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Text(modeLabel, style: TextStyle(fontSize: 13, color: c.text)),
                const SizedBox(width: 8),
                Expanded(
                  child: _PersistentTextField(
                    text: label,
                    decoration: _dec('Метка', c),
                    style: TextStyle(fontSize: 12, color: c.text),
                    onChanged: (v) {
                      final updatedModes = Map<String, dynamic>.from(modes);
                      updatedModes[modeKey] = {...Map<String, dynamic>.from(mode), 'label': v};
                      _dat(ref, i, {'settings': {...settings, 'modes': updatedModes}});
                    },
                  ),
                ),
              ],
            ),
          );
        }),

        _sectionLabel('Карточки', c),
        ...cards.asMap().entries.map((e) {
          final idx = e.key;
          final card = e.value;
          final cardOptions = (card['options'] as List<dynamic>?)?.cast<String>() ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: _cardDec(c),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('#${idx + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
                    const Spacer(),
                    if (idx > 0) InkWell(
                      onTap: () {
                        final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                        final tmp = updated[idx]; updated[idx] = updated[idx - 1]; updated[idx - 1] = tmp;
                        _dat(ref, i, {'cards': updated});
                      },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.arrow_upward, size: 14, color: c.textSecondary)),
                    ),
                    if (idx < cards.length - 1) InkWell(
                      onTap: () {
                        final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                        final tmp = updated[idx]; updated[idx] = updated[idx + 1]; updated[idx + 1] = tmp;
                        _dat(ref, i, {'cards': updated});
                      },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.arrow_downward, size: 14, color: c.textSecondary)),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList()..removeAt(idx);
                        _dat(ref, i, {'cards': updated});
                      },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ВОПРОС', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        _PersistentTextField(
                          text: card['front'] as String? ?? '',
                          decoration: _dec('', c),
                          style: TextStyle(fontSize: 13, color: c.text),
                          maxLines: 2,
                          onChanged: (v) {
                            final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                            updated[idx]['front'] = v;
                            _dat(ref, i, {'cards': updated});
                          },
                        ),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ОТВЕТ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        _PersistentTextField(
                          text: card['back'] as String? ?? '',
                          decoration: _dec('', c),
                          style: TextStyle(fontSize: 13, color: c.text),
                          maxLines: 2,
                          onChanged: (v) {
                            final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                            updated[idx]['back'] = v;
                            _dat(ref, i, {'cards': updated});
                          },
                        ),
                      ],
                    )),
                  ],
                ),
                const Divider(height: 12),
                InkWell(
                  onTap: () => setState(() {
                    if (_expandedOptions.contains(idx)) { _expandedOptions.remove(idx); }
                    else { _expandedOptions.add(idx); }
                  }),
                  child: Row(
                    children: [
                      Text('Варианты ответа', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      if (cardOptions.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text('${cardOptions.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent)),
                        ),
                      ],
                      Icon(_expandedOptions.contains(idx) ? Icons.expand_less : Icons.expand_more, size: 14, color: c.textSecondary),
                    ],
                  ),
                ),
                if (_expandedOptions.contains(idx)) ...[
                  const SizedBox(height: 4),
                  Text('Добавьте варианты для множественного выбора', style: TextStyle(fontSize: 11, color: c.textSecondary, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  ...cardOptions.asMap().entries.map((oe) {
                    final oi = oe.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: _PersistentTextField(
                            text: oe.value,
                            decoration: _dec('', c),
                            style: TextStyle(fontSize: 12, color: c.text),
                            onChanged: (v) {
                              final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                              final opts = List<String>.from(updated[idx]['options'] as List? ?? []);
                              opts[oi] = v;
                              updated[idx]['options'] = opts;
                              _dat(ref, i, {'cards': updated});
                            },
                          )),
                          InkWell(
                            onTap: () {
                              final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                              final opts = List<String>.from(updated[idx]['options'] as List? ?? [])..removeAt(oi);
                              updated[idx]['options'] = opts;
                              _dat(ref, i, {'cards': updated});
                            },
                            child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error)),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton(
                    onPressed: () {
                      final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList();
                      final opts = List<String>.from(updated[idx]['options'] as List? ?? [])..add('');
                      updated[idx]['options'] = opts;
                      _dat(ref, i, {'cards': updated});
                    },
                    child: Text('+ Добавить вариант', style: TextStyle(fontSize: 12, color: c.accent)),
                  ),
                ],
              ],
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList()
                    ..add({'front': '', 'back': '', 'options': <String>[]});
                  _dat(ref, i, {'cards': updated});
                },
                icon: Icon(Icons.add, size: 14, color: c.accent),
                label: Text('Добавить карточку', style: TextStyle(fontSize: 12, color: c.accent)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showImport = !_showImport),
              child: Text('Импорт', style: TextStyle(fontSize: 12, color: c.accent)),
            ),
          ],
        ),
        if (_showImport) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Формат: Вопрос;Ответ (каждый на новой строке)', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _importCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    hintText: 'Question;Answer',
                    hintStyle: TextStyle(color: c.textSecondary, fontFamily: 'monospace'),
                  ),
                  style: TextStyle(fontSize: 12, color: c.text, fontFamily: 'monospace'),
                  maxLines: 6,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final text = _importCtrl.text.trim();
                      if (text.isEmpty) return;
                      final lines = text.split('\n').where((l) => l.trim().isNotEmpty);
                      final newCards = <Map<String, dynamic>>[];
                      for (final line in lines) {
                        final sep = line.contains('\t') ? '\t' : ';';
                        final parts = line.split(sep).map((p) => p.trim()).toList();
                        if (parts.isNotEmpty && (parts[0].isNotEmpty || (parts.length > 1 && parts[1].isNotEmpty))) {
                          newCards.add({'front': parts[0], 'back': parts.length > 1 ? parts[1] : '', 'options': <String>[]});
                        }
                      }
                      if (newCards.isNotEmpty) {
                        final updated = cards.map((c2) => Map<String, dynamic>.from(c2)).toList()..addAll(newCards);
                        _dat(ref, i, {'cards': updated});
                        _importCtrl.clear();
                        setState(() => _showImport = false);
                      }
                    },
                    child: const Text('Импортировать'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Products ──
// Web: ProductsEditor.vue — layout, items_per_page, sort_order, chat_section_id,
//   items list with form overlay

class _ProductsConfigEditor extends ConsumerStatefulWidget {
  final int i;
  final Map<String, dynamic> config;
  final Map<String, dynamic> data;
  final ColorSet c;
  const _ProductsConfigEditor({required this.i, required this.config, required this.data, required this.c});

  @override
  ConsumerState<_ProductsConfigEditor> createState() => _ProductsConfigEditorState();
}

class _ProductsConfigEditorState extends ConsumerState<_ProductsConfigEditor> {
  bool _showForm = false;
  int? _editingIdx;
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _oldPriceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  String _formImage = '';
  String _formBadge = '';
  List<String> _formTags = [];

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose(); _oldPriceCtrl.dispose(); _descCtrl.dispose(); _tagCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _items =>
      (widget.data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  void _openAdd() {
    _nameCtrl.clear(); _priceCtrl.clear(); _oldPriceCtrl.clear(); _descCtrl.clear(); _tagCtrl.clear();
    _formImage = ''; _formBadge = ''; _formTags = [];
    _editingIdx = null;
    setState(() => _showForm = true);
  }

  void _openEdit(int idx) {
    final item = _items[idx];
    _nameCtrl.text = item['name'] as String? ?? '';
    _priceCtrl.text = item['price'] as String? ?? '';
    _oldPriceCtrl.text = item['old_price'] as String? ?? '';
    _descCtrl.text = item['description'] as String? ?? '';
    _formImage = item['image'] as String? ?? '';
    _formBadge = item['badge'] as String? ?? '';
    _formTags = List<String>.from((item['tags'] as List<dynamic>?)?.cast<String>() ?? []);
    _tagCtrl.clear();
    _editingIdx = idx;
    setState(() => _showForm = true);
  }

  void _saveForm() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final entry = <String, dynamic>{
      'id': _editingIdx != null ? _items[_editingIdx!]['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _nameCtrl.text.trim(), 'price': _priceCtrl.text.trim(), 'old_price': _oldPriceCtrl.text.trim(),
      'description': _descCtrl.text.trim(), 'image': _formImage, 'tags': _formTags, 'badge': _formBadge,
    };
    final list = _items.map((x) => Map<String, dynamic>.from(x)).toList();
    if (_editingIdx != null) { list[_editingIdx!] = entry; } else { list.add(entry); }
    _dat(ref, widget.i, {'items': list});
    setState(() { _showForm = false; _editingIdx = null; });
  }

  void _remove(int idx) {
    final list = _items.map((x) => Map<String, dynamic>.from(x)).toList()..removeAt(idx);
    _dat(ref, widget.i, {'items': list});
  }

  void _move(int idx, int dir) {
    final target = idx + dir;
    if (target < 0 || target >= _items.length) return;
    final list = _items.map((x) => Map<String, dynamic>.from(x)).toList();
    final tmp = list[idx]; list[idx] = list[target]; list[target] = tmp;
    _dat(ref, widget.i, {'items': list});
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_formTags.contains(tag)) setState(() => _formTags.add(tag));
    _tagCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Config row
        _sectionLabel('Параметры', c),
        Wrap(
          spacing: 10, runSpacing: 8,
          children: [
            SizedBox(width: 140, child: DropdownButtonFormField<String>(
              initialValue: widget.config['layout'] as String? ?? 'grid',
              decoration: _dec('Макет', c), items: const [DropdownMenuItem(value: 'grid', child: Text('Сетка')), DropdownMenuItem(value: 'list', child: Text('Список'))],
              onChanged: (v) => _cfg(ref, widget.i, {'layout': v}), style: TextStyle(fontSize: 13, color: c.text),
            )),
            SizedBox(width: 140, child: DropdownButtonFormField<String>(
              initialValue: widget.config['sort_order'] as String? ?? 'manual',
              decoration: _dec('Сортировка', c), items: const [DropdownMenuItem(value: 'manual', child: Text('Вручную')), DropdownMenuItem(value: 'price_asc', child: Text('Цена ↑')), DropdownMenuItem(value: 'price_desc', child: Text('Цена ↓')), DropdownMenuItem(value: 'name', child: Text('Имя'))],
              onChanged: (v) => _cfg(ref, widget.i, {'sort_order': v}), style: TextStyle(fontSize: 13, color: c.text),
            )),
          ],
        ),
        const SizedBox(height: 12),

        // Product list — compact rows
        _sectionLabel('Товары (${items.length})', c),
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          final name = item['name'] as String? ?? '';
          final price = item['price'] as String? ?? '';
          final imageUrl = item['image'] as String? ?? '';
          final badge = item['badge'] as String? ?? '';
          final tags = (item['tags'] as List<dynamic>?)?.cast<String>() ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                // Move buttons
                Column(mainAxisSize: MainAxisSize.min, children: [
                  if (idx > 0) InkWell(onTap: () => _move(idx, -1), child: Icon(Icons.arrow_drop_up, size: 18, color: c.textSecondary)),
                  if (idx < items.length - 1) InkWell(onTap: () => _move(idx, 1), child: Icon(Icons.arrow_drop_down, size: 18, color: c.textSecondary)),
                ]),
                const SizedBox(width: 8),
                // Thumbnail + badge
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(6)),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isNotEmpty
                        ? Image.network(fullImageUrl(imageUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image, size: 18, color: c.textSecondary))
                        : Center(child: Icon(Icons.image_outlined, size: 18, color: c.textSecondary.withValues(alpha: 0.4))),
                  ),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: badge == 'sale' ? c.error : badge == 'new' ? c.accent : const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: badge == 'hit' ? Colors.black : Colors.white)),
                    ),
                  ],
                ]),
                const SizedBox(width: 10),
                // Info
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isNotEmpty ? name : 'Без названия', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (price.isNotEmpty || tags.isNotEmpty)
                      Text([if (price.isNotEmpty) '$price ₽', if (tags.isNotEmpty) tags.join(', ')].join(' · '),
                        style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Actions
                InkWell(onTap: () => _openEdit(idx), borderRadius: BorderRadius.circular(4),
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.edit_outlined, size: 16, color: c.textSecondary))),
                const SizedBox(width: 2),
                InkWell(onTap: () => _remove(idx), borderRadius: BorderRadius.circular(4),
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: c.error.withValues(alpha: 0.6)))),
              ],
            ),
          );
        }),

        // Add button
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _openAdd,
            icon: Icon(Icons.add, size: 14, color: c.accent),
            label: Text('Добавить товар', style: TextStyle(fontSize: 12, color: c.accent)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: c.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          )),
        ),

        // Inline form
        if (_showForm) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_editingIdx != null ? 'Редактирование' : 'Новый товар', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                  const Spacer(),
                  InkWell(onTap: () => setState(() { _showForm = false; _editingIdx = null; }),
                    child: Icon(Icons.close, size: 16, color: c.textSecondary)),
                ]),
                const SizedBox(height: 12),
                // Image
                _ImageUploadField(imageUrl: _formImage, c: c, onChanged: (v) => setState(() => _formImage = v)),
                const SizedBox(height: 10),
                // Name
                TextField(controller: _nameCtrl, decoration: _dec('Название', c), style: TextStyle(fontSize: 13, color: c.text)),
                const SizedBox(height: 8),
                // Price row
                Row(children: [
                  Expanded(child: TextField(controller: _priceCtrl, decoration: _dec('Цена', c), style: TextStyle(fontSize: 13, color: c.text))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _oldPriceCtrl, decoration: _dec('Старая цена', c), style: TextStyle(fontSize: 13, color: c.text))),
                ]),
                const SizedBox(height: 8),
                // Description
                TextField(controller: _descCtrl, decoration: _dec('Описание', c), style: TextStyle(fontSize: 13, color: c.text), maxLines: 3),
                const SizedBox(height: 8),
                // Tags
                Wrap(spacing: 4, runSpacing: 4, children: [
                  ..._formTags.asMap().entries.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.accent)),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => setState(() => _formTags.removeAt(e.key)),
                        child: Icon(Icons.close, size: 12, color: c.accent.withValues(alpha: 0.7))),
                    ]),
                  )),
                ]),
                const SizedBox(height: 4),
                SizedBox(width: 200, child: TextField(
                  controller: _tagCtrl,
                  decoration: _dec('Добавить тег...', c),
                  style: TextStyle(fontSize: 12, color: c.text),
                  onSubmitted: (_) => _addTag(),
                )),
                const SizedBox(height: 8),
                // Badge
                SizedBox(width: 160, child: DropdownButtonFormField<String>(
                  initialValue: _formBadge,
                  decoration: _dec('Бейдж', c),
                  items: const [DropdownMenuItem(value: '', child: Text('Нет')), DropdownMenuItem(value: 'new', child: Text('NEW')), DropdownMenuItem(value: 'sale', child: Text('SALE')), DropdownMenuItem(value: 'hit', child: Text('HIT'))],
                  onChanged: (v) => setState(() => _formBadge = v ?? ''),
                  style: TextStyle(fontSize: 13, color: c.text),
                )),
                const SizedBox(height: 12),
                // Save/Cancel
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: () => setState(() { _showForm = false; _editingIdx = null; }),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: c.border), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                    child: Text('Отмена', style: TextStyle(fontSize: 13, color: c.textSecondary))),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _nameCtrl.text.trim().isEmpty ? null : _saveForm,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                    child: const Text('Сохранить', style: TextStyle(fontSize: 13))),
                ]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Wiki ──
// Web: WikiEditor.vue — list mode (article items) ↔ edit mode (title+category+markdown toolbar+textarea)

class _WikiConfigEditor extends ConsumerStatefulWidget {
  final int i;
  final Map<String, dynamic> data;
  final ColorSet c;
  const _WikiConfigEditor({required this.i, required this.data, required this.c});

  @override
  ConsumerState<_WikiConfigEditor> createState() => _WikiConfigEditorState();
}

class _WikiConfigEditorState extends ConsumerState<_WikiConfigEditor> {
  String _viewMode = 'list';
  String? _editingId;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _openNew() {
    _titleCtrl.clear();
    _contentCtrl.clear();
    _categoryCtrl.clear();
    _editingId = null;
    setState(() => _viewMode = 'edit');
  }

  void _openEdit(Map<String, dynamic> article) {
    _titleCtrl.text = article['title'] as String? ?? '';
    _contentCtrl.text = article['content'] as String? ?? '';
    _categoryCtrl.text = article['category'] as String? ?? '';
    _editingId = article['id'] as String?;
    setState(() => _viewMode = 'edit');
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    final articles = (widget.data['articles'] as List<dynamic>?)
        ?.map((a) => Map<String, dynamic>.from(a as Map)).toList() ?? [];

    if (_editingId != null) {
      final idx = articles.indexWhere((a) => a['id'] == _editingId);
      if (idx >= 0) {
        articles[idx] = {...articles[idx], 'title': _titleCtrl.text, 'content': _contentCtrl.text, 'category': _categoryCtrl.text};
      }
    } else {
      articles.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': _titleCtrl.text,
        'content': _contentCtrl.text,
        'category': _categoryCtrl.text,
      });
    }
    _dat(ref, widget.i, {'articles': articles});
    setState(() { _viewMode = 'list'; _editingId = null; });
  }

  void _removeArticle(String id) {
    final articles = (widget.data['articles'] as List<dynamic>?)
        ?.map((a) => Map<String, dynamic>.from(a as Map)).toList() ?? [];
    articles.removeWhere((a) => a['id'] == id);
    _dat(ref, widget.i, {'articles': articles});
  }


  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final articles = (widget.data['articles'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    if (_viewMode == 'edit') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() { _viewMode = 'list'; _editingId = null; }),
                child: Text('← Назад', style: TextStyle(fontSize: 13, color: c.accent)),
              ),
              const Spacer(),
              Text(_editingId != null ? 'Редактирование' : 'Новая статья',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
              const Spacer(),
              ElevatedButton(
                onPressed: _titleCtrl.text.trim().isEmpty ? null : _save,
                child: const Text('Сохранить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _titleCtrl,
                  decoration: _dec('Заголовок', c),
                  style: TextStyle(fontSize: 13, color: c.text),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _categoryCtrl,
                  decoration: _dec('Категория', c),
                  style: TextStyle(fontSize: 13, color: c.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownEditorWithToolbar(
            text: _contentCtrl.text,
            colors: c,
            minLines: 8,
            maxLines: 15,
            onChanged: (v) => _contentCtrl.text = v,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (articles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Нет статей', style: TextStyle(color: c.textSecondary))),
          ),
        ...articles.map((article) {
          final id = article['id'] as String? ?? '';
          final title = article['title'] as String? ?? 'Без названия';
          final category = article['category'] as String? ?? '';
          final contentLen = (article['content'] as String? ?? '').length;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('W', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (category.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.accent)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text('$contentLen симв.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openEdit(article),
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.edit, size: 16, color: c.textSecondary)),
                ),
                InkWell(
                  onTap: () => _removeArticle(id),
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: c.error)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _openNew,
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить статью', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ],
    );
  }

}

// ── Navigation ──
// Web: SectionEditor.vue inline — toggle buttons for layout, select for manage_access

class _NavigationConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _NavigationConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = config['layout'] as String? ?? 'vertical';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Настройки', c),
        _fieldLabel('Расположение', c),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'vertical', label: Text('Вертикально')),
            ButtonSegment(value: 'horizontal', label: Text('Горизонтально')),
          ],
          selected: {layout},
          onSelectionChanged: (sel) => _cfg(ref, i, {'layout': sel.first}),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: config['manage_access'] as String? ?? 'owner',
          decoration: _dec('Управление доступом', c),
          items: const [
            DropdownMenuItem(value: 'owner', child: Text('Только владелец')),
            DropdownMenuItem(value: 'moderator', child: Text('Модераторы')),
            DropdownMenuItem(value: 'editor', child: Text('Редакторы')),
          ],
          onChanged: (v) => _cfg(ref, i, {'manage_access': v}),
          style: TextStyle(fontSize: 13, color: c.text),
        ),
      ],
    );
  }
}

// ── Popular Pages ──
// Web: SectionEditor.vue inline — limit number, metric select, window_days SELECT (7/30/90/All),
//   show_views checkbox

class _PopularPagesConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _PopularPagesConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawWd = config['window_days'];
    final wd = rawWd is int ? rawWd : (int.tryParse('$rawWd') ?? 30);
    final windowDays = const [7, 30, 90, 0].contains(wd) ? wd : 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Настройки виджета', c),
        Row(
          children: [
            Expanded(child: Text('Количество', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '5',
              value: (config['limit'] as int?) ?? 5,
              min: 1, max: 20,
              c: c,
              width: 90,
              onChanged: (v) => _cfg(ref, i, {'limit': v}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: config['metric'] as String? ?? 'session',
          decoration: _dec('Метрика', c),
          items: const [
            DropdownMenuItem(value: 'session', child: Text('Сессии')),
            DropdownMenuItem(value: 'unique', child: Text('Уникальные')),
            DropdownMenuItem(value: 'total', child: Text('Всего')),
          ],
          onChanged: (v) => _cfg(ref, i, {'metric': v}),
          style: TextStyle(fontSize: 13, color: c.text),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: windowDays,
          decoration: _dec('Период', c),
          items: const [
            DropdownMenuItem(value: 7, child: Text('7 дней')),
            DropdownMenuItem(value: 30, child: Text('30 дней')),
            DropdownMenuItem(value: 90, child: Text('90 дней')),
            DropdownMenuItem(value: 0, child: Text('Всё время')),
          ],
          onChanged: (v) => _cfg(ref, i, {'window_days': v ?? 30}),
          style: TextStyle(fontSize: 13, color: c.text),
        ),
        const SizedBox(height: 8),
        _toggle('Показывать просмотры', config['show_views'] != false, c, (v) => _cfg(ref, i, {'show_views': v})),
      ],
    );
  }
}

// ── Recent Updates ──
// Web: SectionEditor.vue inline — limit number only

class _RecentUpdatesConfigEditor extends ConsumerWidget {
  final int i;
  final Map<String, dynamic> config;
  final ColorSet c;
  const _RecentUpdatesConfigEditor({required this.i, required this.config, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Настройки виджета', c),
        Row(
          children: [
            Expanded(child: Text('Количество', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            _numInput(
              hint: '5',
              value: (config['limit'] as int?) ?? 5,
              min: 1, max: 20,
              c: c,
              width: 90,
              onChanged: (v) => _cfg(ref, i, {'limit': v}),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageUploadField extends ConsumerStatefulWidget {
  final String imageUrl;
  final ColorSet c;
  final void Function(String) onChanged;
  const _ImageUploadField({required this.imageUrl, required this.c, required this.onChanged});

  @override
  ConsumerState<_ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends ConsumerState<_ImageUploadField> {
  bool _uploading = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final api = UploadsApi(ref.read(apiClientProvider));
      final uploaded = await api.upload(bytes: file.bytes!, filename: file.name, contentType: 'image/${file.extension ?? 'png'}');
      widget.onChanged(uploaded.url);
    } catch (_) {}
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final url = widget.imageUrl;
    if (url.isNotEmpty) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(fullImageUrl(url), width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 48, height: 48, color: c.surfaceAlt, child: Icon(Icons.broken_image, size: 18, color: c.textSecondary))),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: Icon(Icons.refresh, size: 14, color: c.accent),
            label: Text('Заменить', style: TextStyle(fontSize: 12, color: c.accent)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              side: BorderSide(color: c.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => widget.onChanged(''),
            icon: Icon(Icons.delete_outline, size: 14, color: c.error),
            label: Text('Удалить', style: TextStyle(fontSize: 12, color: c.error)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              side: BorderSide(color: c.error.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: _uploading ? null : _pick,
      icon: _uploading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
          : Icon(Icons.add_photo_alternate_outlined, size: 16, color: c.accent),
      label: Text(_uploading ? 'Загрузка...' : 'Добавить фото', style: TextStyle(fontSize: 12, color: c.accent)),
    );
  }
}
