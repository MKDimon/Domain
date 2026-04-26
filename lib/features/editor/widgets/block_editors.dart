import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/editor_provider.dart';
import 'markdown_toolbar.dart';

class BlockEditor extends ConsumerWidget {
  final int sectionIndex;
  final int blockIndex;
  final Map<String, dynamic> block;

  const BlockEditor({super.key, required this.sectionIndex, required this.blockIndex, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = block['type'] as String? ?? 'paragraph';
    return switch (type) {
      'heading' => _HeadingEditor(s: sectionIndex, b: blockIndex, block: block),
      'paragraph' => _ParagraphEditor(s: sectionIndex, b: blockIndex, block: block),
      'image' => _ImageEditor(s: sectionIndex, b: blockIndex, block: block),
      'divider' => const _DividerEditor(),
      'callout' => _CalloutEditor(s: sectionIndex, b: blockIndex, block: block),
      'code' => _CodeEditor(s: sectionIndex, b: blockIndex, block: block),
      'list' => _ListEditor(s: sectionIndex, b: blockIndex, block: block),
      'quote' => _QuoteEditor(s: sectionIndex, b: blockIndex, block: block),
      'button' => _ButtonEditor(s: sectionIndex, b: blockIndex, block: block),
      'markdown' => _MarkdownBlockEditor(s: sectionIndex, b: blockIndex, block: block),
      'embed' => _EmbedEditor(s: sectionIndex, b: blockIndex, block: block),
      'accordion' => _AccordionEditor(s: sectionIndex, b: blockIndex, block: block),
      'table' => _TableEditor(s: sectionIndex, b: blockIndex, block: block),
      'gallery' => _GalleryEditor(s: sectionIndex, b: blockIndex, block: block),
      'tabs' => _TabsEditor(s: sectionIndex, b: blockIndex, block: block),
      'product-card' => _ProductCardEditor(s: sectionIndex, b: blockIndex, block: block),
      _ => Text('Неизвестный блок: $type', style: const TextStyle(fontSize: 12, color: Colors.grey)),
    };
  }
}

// ── Helpers ──

void _update(WidgetRef ref, int s, int b, Map<String, dynamic> patch) {
  ref.read(editorProvider.notifier).updateBlock(s, b, patch);
}

InputDecoration _inputDec(String hint, ColorSet c) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.5)),
  border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
);

// ── Persistent TextField ──

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

// ── Heading ──

class _HeadingEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _HeadingEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final level = block['level'] as int? ?? 2;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: DropdownButtonFormField<int>(
            initialValue: level,
            decoration: _inputDec('', c),
            items: [1, 2, 3, 4].map((l) => DropdownMenuItem(value: l, child: Text('H$l', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => _update(ref, s, b, {'level': v}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PersistentTextField(
            text: block['text'] as String? ?? '',
            decoration: _inputDec('Заголовок...', c),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
            onChanged: (v) => _update(ref, s, b, {'text': v}),
          ),
        ),
      ],
    );
  }
}

// ── Paragraph ──

class _ParagraphEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _ParagraphEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return _PersistentTextField(
      text: block['text'] as String? ?? '',
      decoration: _inputDec('Текст...', c),
      style: TextStyle(fontSize: 13, color: c.text),
      maxLines: null,
      minLines: 2,
      onChanged: (v) => _update(ref, s, b, {'text': v}),
    );
  }
}

// ── Markdown block ──

class _MarkdownBlockEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _MarkdownBlockEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return MarkdownEditorWithToolbar(
      text: block['content'] as String? ?? '',
      colors: c,
      minLines: 4,
      onChanged: (v) => _update(ref, s, b, {'content': v}),
    );
  }
}

// ── Image ──

class _ImageEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _ImageEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return Column(
      children: [
        _PersistentTextField(
          text: block['url'] as String? ?? '',
          decoration: _inputDec('URL изображения', c),
          style: TextStyle(fontSize: 13, color: c.text),
          onChanged: (v) => _update(ref, s, b, {'url': v}),
        ),
        const SizedBox(height: 6),
        _PersistentTextField(
          text: block['caption'] as String? ?? '',
          decoration: _inputDec('Подпись (необязательно)', c),
          style: TextStyle(fontSize: 12, color: c.textSecondary),
          onChanged: (v) => _update(ref, s, b, {'caption': v}),
        ),
      ],
    );
  }
}

// ── Divider ──

class _DividerEditor extends StatelessWidget {
  const _DividerEditor();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return Divider(color: c.border, height: 24);
  }
}

// ── Callout ──

class _CalloutEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _CalloutEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final style = block['style'] as String? ?? 'info';
    return Column(
      children: [
        Row(
          children: [
            for (final s2 in ['info', 'success', 'warning', 'error'])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(s2, style: const TextStyle(fontSize: 11)),
                  selected: style == s2,
                  onSelected: (_) => _update(ref, s, b, {'style': s2}),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _PersistentTextField(
          text: block['text'] as String? ?? '',
          decoration: _inputDec('Текст выноски...', c),
          style: TextStyle(fontSize: 13, color: c.text),
          maxLines: null,
          minLines: 2,
          onChanged: (v) => _update(ref, s, b, {'text': v}),
        ),
      ],
    );
  }
}

// ── Code ──

class _CodeEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _CodeEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _PersistentTextField(
            text: block['language'] as String? ?? '',
            decoration: _inputDec('Язык (js, python, ...)', c),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
            onChanged: (v) => _update(ref, s, b, {'language': v}),
          ),
        ),
        const SizedBox(height: 6),
        _PersistentTextField(
          text: block['content'] as String? ?? '',
          decoration: _inputDec('Код...', c),
          style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: c.text),
          maxLines: null,
          minLines: 4,
          onChanged: (v) => _update(ref, s, b, {'content': v}),
        ),
      ],
    );
  }
}

// ── List ──

class _ListEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _ListEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final style = block['style'] as String? ?? 'unordered';
    final items = (block['items'] as List<dynamic>?)?.cast<String>() ?? [''];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(label: const Text('•', style: TextStyle(fontSize: 14)), selected: style == 'unordered',
              onSelected: (_) => _update(ref, s, b, {'style': 'unordered'}), visualDensity: VisualDensity.compact),
            const SizedBox(width: 4),
            ChoiceChip(label: const Text('1.', style: TextStyle(fontSize: 12)), selected: style == 'ordered',
              onSelected: (_) => _update(ref, s, b, {'style': 'ordered'}), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 6),
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(style == 'ordered' ? '${idx + 1}.' : '•', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(width: 6),
                Expanded(
                  child: _PersistentTextField(
                    text: e.value,
                    decoration: _inputDec('Пункт ${idx + 1}', c),
                    style: TextStyle(fontSize: 13, color: c.text),
                    onChanged: (v) {
                      final updated = List<String>.from(items);
                      updated[idx] = v;
                      _update(ref, s, b, {'items': updated});
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    if (items.length <= 1) return;
                    final updated = List<String>.from(items)..removeAt(idx);
                    _update(ref, s, b, {'items': updated});
                  },
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6))),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _update(ref, s, b, {'items': [...items, '']}),
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить пункт', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ],
    );
  }
}

// ── Quote ──

class _QuoteEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _QuoteEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return Column(
      children: [
        _PersistentTextField(
          text: block['text'] as String? ?? '',
          decoration: _inputDec('Цитата...', c),
          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: c.text),
          maxLines: null, minLines: 2,
          onChanged: (v) => _update(ref, s, b, {'text': v}),
        ),
        const SizedBox(height: 6),
        _PersistentTextField(
          text: block['author'] as String? ?? '',
          decoration: _inputDec('Автор (необязательно)', c),
          style: TextStyle(fontSize: 12, color: c.textSecondary),
          onChanged: (v) => _update(ref, s, b, {'author': v}),
        ),
      ],
    );
  }
}

// ── Button ──

class _ButtonEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _ButtonEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return Column(
      children: [
        _PersistentTextField(
          text: block['text'] as String? ?? '',
          decoration: _inputDec('Текст кнопки', c),
          style: TextStyle(fontSize: 13, color: c.text),
          onChanged: (v) => _update(ref, s, b, {'text': v}),
        ),
        const SizedBox(height: 6),
        _PersistentTextField(
          text: block['url'] as String? ?? '',
          decoration: _inputDec('URL ссылки', c),
          style: TextStyle(fontSize: 13, color: c.text),
          onChanged: (v) => _update(ref, s, b, {'url': v}),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final st in ['primary', 'secondary', 'outline'])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(st, style: const TextStyle(fontSize: 11)),
                  selected: (block['style'] as String? ?? 'primary') == st,
                  onSelected: (_) => _update(ref, s, b, {'style': st}),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final a in ['left', 'center', 'right'])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Icon(
                    a == 'left' ? Icons.format_align_left : a == 'center' ? Icons.format_align_center : Icons.format_align_right,
                    size: 14,
                  ),
                  selected: (block['align'] as String? ?? 'center') == a,
                  onSelected: (_) => _update(ref, s, b, {'align': a}),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Embed ──

class _EmbedEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _EmbedEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    return _PersistentTextField(
      text: block['url'] as String? ?? '',
      decoration: _inputDec('URL для встраивания (YouTube, Vimeo, ...)', c),
      style: TextStyle(fontSize: 13, color: c.text),
      onChanged: (v) => _update(ref, s, b, {'url': v}),
    );
  }
}

// ── Accordion ──

class _AccordionEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _AccordionEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final items = (block['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [{'title': '', 'content': ''}];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: block['allowMultipleOpen'] == true,
                onChanged: (v) => _update(ref, s, b, {'allowMultipleOpen': v}),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text('Несколько открытых', style: TextStyle(fontSize: 12, color: c.text)),
          ],
        ),
        const SizedBox(height: 6),
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PersistentTextField(
                        text: item['title'] as String? ?? '',
                        decoration: _inputDec('Заголовок', c),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text),
                        onChanged: (v) {
                          final updated = items.map((i) => Map<String, dynamic>.from(i)).toList();
                          updated[idx]['title'] = v;
                          _update(ref, s, b, {'items': updated});
                        },
                      ),
                    ),
                    InkWell(
                      onTap: items.length <= 1 ? null : () {
                        final updated = items.map((i) => Map<String, dynamic>.from(i)).toList()..removeAt(idx);
                        _update(ref, s, b, {'items': updated});
                      },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _PersistentTextField(
                  text: item['content'] as String? ?? '',
                  decoration: _inputDec('Содержимое', c),
                  style: TextStyle(fontSize: 13, color: c.text),
                  maxLines: null, minLines: 2,
                  onChanged: (v) {
                    final updated = items.map((i) => Map<String, dynamic>.from(i)).toList();
                    updated[idx]['content'] = v;
                    _update(ref, s, b, {'items': updated});
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final updated = items.map((i) => Map<String, dynamic>.from(i)).toList()..add({'title': '', 'content': ''});
            _update(ref, s, b, {'items': updated});
          },
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить элемент', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ],
    );
  }
}

// ── Table ──

class _TableEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _TableEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final headers = (block['headers'] as List<dynamic>?)?.cast<String>() ?? ['', '', ''];
    final rows = (block['rows'] as List<dynamic>?)?.map((r) => (r as List<dynamic>).cast<String>()).toList() ?? [['', '', '']];
    final colCount = headers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            columns: [
              ...headers.asMap().entries.map((e) => DataColumn(
                label: SizedBox(
                  width: 80,
                  child: _PersistentTextField(
                    text: e.value,
                    decoration: _inputDec('Столбец', c),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text),
                    onChanged: (v) {
                      final updated = List<String>.from(headers);
                      updated[e.key] = v;
                      _update(ref, s, b, {'headers': updated});
                    },
                  ),
                ),
              )),
              const DataColumn(label: SizedBox(width: 24)),
            ],
            rows: rows.asMap().entries.map((re) {
              final rowIdx = re.key;
              final row = re.value;
              return DataRow(cells: [
                ...List.generate(colCount, (ci) => DataCell(
                  SizedBox(
                    width: 80,
                    child: _PersistentTextField(
                      text: ci < row.length ? row[ci] : '',
                      decoration: _inputDec('', c),
                      style: TextStyle(fontSize: 12, color: c.text),
                      onChanged: (v) {
                        final updated = rows.map((r) => List<String>.from(r)).toList();
                        while (updated[rowIdx].length <= ci) { updated[rowIdx].add(''); }
                        updated[rowIdx][ci] = v;
                        _update(ref, s, b, {'rows': updated});
                      },
                    ),
                  ),
                )),
                DataCell(InkWell(
                  onTap: rows.length <= 1 ? null : () {
                    final updated = rows.map((r) => List<String>.from(r)).toList()..removeAt(rowIdx);
                    _update(ref, s, b, {'rows': updated});
                  },
                  child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6)),
                )),
              ]);
            }).toList(),
          ),
        ),
        Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: block['striped'] == true,
                onChanged: (v) => _update(ref, s, b, {'striped': v}),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text('Полосатая', style: TextStyle(fontSize: 12, color: c.text)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                final updated = rows.map((r) => List<String>.from(r)).toList()..add(List.filled(colCount, ''));
                _update(ref, s, b, {'rows': updated});
              },
              icon: Icon(Icons.add, size: 14, color: c.accent),
              label: Text('Строка', style: TextStyle(fontSize: 12, color: c.accent)),
            ),
            TextButton.icon(
              onPressed: () {
                final newHeaders = [...headers, ''];
                final newRows = rows.map((r) => [...List<String>.from(r), '']).toList();
                _update(ref, s, b, {'headers': newHeaders, 'rows': newRows});
              },
              icon: Icon(Icons.add, size: 14, color: c.accent),
              label: Text('Столбец', style: TextStyle(fontSize: 12, color: c.accent)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Gallery ──

class _GalleryEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _GalleryEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final images = (block['images'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Колонок:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(width: 8),
            for (final n in [2, 3, 4, 5])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text('$n', style: const TextStyle(fontSize: 11)),
                  selected: (block['columns'] as int? ?? 3) == n,
                  onSelected: (_) => _update(ref, s, b, {'columns': n}),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...images.asMap().entries.map((e) {
          final idx = e.key;
          final img = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PersistentTextField(
                        text: img['url'] as String? ?? '',
                        decoration: _inputDec('URL изображения ${idx + 1}', c),
                        style: TextStyle(fontSize: 12, color: c.text),
                        onChanged: (v) {
                          final updated = images.map((i) => Map<String, dynamic>.from(i)).toList();
                          updated[idx]['url'] = v;
                          _update(ref, s, b, {'images': updated});
                        },
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        final updated = images.map((i) => Map<String, dynamic>.from(i)).toList()..removeAt(idx);
                        _update(ref, s, b, {'images': updated});
                      },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _PersistentTextField(
                  text: img['caption'] as String? ?? '',
                  decoration: _inputDec('Подпись', c),
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                  onChanged: (v) {
                    final updated = images.map((i) => Map<String, dynamic>.from(i)).toList();
                    updated[idx]['caption'] = v;
                    _update(ref, s, b, {'images': updated});
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final updated = images.map((i) => Map<String, dynamic>.from(i)).toList()..add({'url': '', 'caption': ''});
            _update(ref, s, b, {'images': updated});
          },
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить изображение', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ],
    );
  }
}

// ── Tabs ──

class _TabsEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _TabsEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final tabs = (block['tabs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [{'label': '', 'blocks': []}];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...tabs.asMap().entries.map((e) {
          final idx = e.key;
          final tab = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text('Таб ${idx + 1}:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(width: 6),
                Expanded(
                  child: _PersistentTextField(
                    text: tab['label'] as String? ?? '',
                    decoration: _inputDec('Название', c),
                    style: TextStyle(fontSize: 13, color: c.text),
                    onChanged: (v) {
                      final updated = tabs.map((t) => Map<String, dynamic>.from(t)).toList();
                      updated[idx]['label'] = v;
                      _update(ref, s, b, {'tabs': updated});
                    },
                  ),
                ),
                InkWell(
                  onTap: tabs.length <= 1 ? null : () {
                    final updated = tabs.map((t) => Map<String, dynamic>.from(t)).toList()..removeAt(idx);
                    _update(ref, s, b, {'tabs': updated});
                  },
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6))),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final updated = tabs.map((t) => Map<String, dynamic>.from(t)).toList()..add({'label': '', 'blocks': []});
            _update(ref, s, b, {'tabs': updated});
          },
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить таб', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ],
    );
  }
}

// ── Product Card ──

class _ProductCardEditor extends ConsumerWidget {
  final int s, b;
  final Map<String, dynamic> block;
  const _ProductCardEditor({required this.s, required this.b, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final items = (block['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _PersistentTextField(text: item['name'] as String? ?? '', decoration: _inputDec('Название', c), style: TextStyle(fontSize: 13, color: c.text), onChanged: (v) { final u = items.map((i) => Map<String, dynamic>.from(i)).toList(); u[idx]['name'] = v; _update(ref, s, b, {'items': u}); })),
                    const SizedBox(width: 6),
                    SizedBox(width: 80, child: _PersistentTextField(text: item['price'] as String? ?? '', decoration: _inputDec('Цена', c), style: TextStyle(fontSize: 13, color: c.text), onChanged: (v) { final u = items.map((i) => Map<String, dynamic>.from(i)).toList(); u[idx]['price'] = v; _update(ref, s, b, {'items': u}); })),
                    InkWell(
                      onTap: items.length <= 1 ? null : () { final u = items.map((i) => Map<String, dynamic>.from(i)).toList()..removeAt(idx); _update(ref, s, b, {'items': u}); },
                      child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _PersistentTextField(text: item['image'] as String? ?? '', decoration: _inputDec('URL изображения', c), style: TextStyle(fontSize: 12, color: c.text), onChanged: (v) { final u = items.map((i) => Map<String, dynamic>.from(i)).toList(); u[idx]['image'] = v; _update(ref, s, b, {'items': u}); }),
                const SizedBox(height: 4),
                _PersistentTextField(text: item['description'] as String? ?? '', decoration: _inputDec('Описание', c), style: TextStyle(fontSize: 12, color: c.text), maxLines: 2, onChanged: (v) { final u = items.map((i) => Map<String, dynamic>.from(i)).toList(); u[idx]['description'] = v; _update(ref, s, b, {'items': u}); }),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final updated = items.map((i) => Map<String, dynamic>.from(i)).toList()..add({'name': '', 'price': '', 'image': '', 'description': '', 'tags': []});
            _update(ref, s, b, {'items': updated});
          },
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить товар', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ],
    );
  }
}
