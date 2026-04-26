import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/image_url.dart';
import 'inline_markup.dart';

class BlockRenderer extends StatelessWidget {
  final Map<String, dynamic> block;
  final int depth;

  const BlockRenderer({super.key, required this.block, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final type = block['type'] as String? ?? '';
    return switch (type) {
      'paragraph' => _ParagraphBlock(block: block),
      'heading' => _HeadingBlock(block: block),
      'image' => _ImageBlock(block: block),
      'divider' => const Divider(height: 32),
      'callout' => _CalloutBlock(block: block),
      'code' => _CodeBlock(block: block),
      'list' => _ListBlock(block: block),
      'quote' => _QuoteBlock(block: block),
      'columns' => _ColumnsBlock(block: block, depth: depth),
      'markdown' => _MarkdownBlock(block: block),
      'accordion' => _AccordionBlock(block: block),
      'table' => _TableBlock(block: block),
      'tabs' => _TabsBlock(block: block, depth: depth),
      'embed' => _EmbedBlock(block: block),
      'gallery' => _GalleryBlock(block: block),
      'button' => _ButtonBlock(block: block),
      'product-card' => _ProductCardBlock(block: block),
      _ => _FallbackBlock(type: type),
    };
  }
}

class BlockList extends StatelessWidget {
  final List<dynamic> blocks;
  final int depth;

  const BlockList({super.key, required this.blocks, this.depth = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((b) {
        final block = b as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BlockRenderer(block: block, depth: depth),
        );
      }).toList(),
    );
  }
}

// --- Block implementations ---

class _ParagraphBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _ParagraphBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return InlineMarkupText(text: block['text'] as String? ?? '', style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _HeadingBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _HeadingBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final level = block['level'] as int? ?? 2;
    final text = block['text'] as String? ?? '';
    final style = switch (level) {
      1 => Theme.of(context).textTheme.headlineLarge,
      2 => Theme.of(context).textTheme.headlineMedium,
      3 => Theme.of(context).textTheme.headlineSmall,
      4 => Theme.of(context).textTheme.titleLarge,
      5 => Theme.of(context).textTheme.titleMedium,
      _ => Theme.of(context).textTheme.titleSmall,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: style),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _ImageBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block['url'] as String? ?? '';
    final caption = block['caption'] as String?;
    if (url.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(fullImageUrl(url), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 48)),
        ),
        if (caption?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(caption!, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _CalloutBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _CalloutBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final style = block['style'] as String? ?? 'info';
    final text = block['text'] as String? ?? '';
    final (color, icon) = switch (style) {
      'success' => (Colors.green, Icons.check_circle_outline),
      'warning' => (Colors.orange, Icons.warning_amber),
      'error' || 'danger' => (Colors.red, Icons.error_outline),
      _ => (Theme.of(context).colorScheme.primary, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: InlineMarkupText(text: text)),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _CodeBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final content = block['content'] as String? ?? '';
    final language = block['language'] as String? ?? '';
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(content, style: const TextStyle(fontFamily: 'JetBrains Mono, Consolas, monospace', fontSize: 13)),
          ),
          Positioned(
            top: 0, right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (language.isNotEmpty) Text(language, style: theme.textTheme.labelSmall),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () => Clipboard.setData(ClipboardData(text: content)),
                  tooltip: 'Copy',
                  iconSize: 16,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _ListBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final items = (block['items'] as List<dynamic>?)?.cast<String>() ?? [];
    final ordered = block['style'] == 'ordered';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((e) {
        final prefix = ordered ? '${e.key + 1}.' : '\u2022';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: Text(prefix, style: Theme.of(context).textTheme.bodyMedium)),
              Expanded(child: InlineMarkupText(text: e.value)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _QuoteBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final text = block['text'] as String? ?? '';
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 3)),
      ),
      child: InlineMarkupText(text: text, style: TextStyle(fontStyle: FontStyle.italic, color: theme.textTheme.bodySmall?.color)),
    );
  }
}

class _ColumnsBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final int depth;
  const _ColumnsBlock({required this.block, required this.depth});

  @override
  Widget build(BuildContext context) {
    if (depth >= 3) return const SizedBox();
    final columns = (block['columns'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (columns.isEmpty) return const SizedBox();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columns.map((col) {
        final blocks = col['blocks'] as List<dynamic>? ?? [];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: BlockList(blocks: blocks, depth: depth + 1),
          ),
        );
      }).toList(),
    );
  }
}

class _MarkdownBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _MarkdownBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final content = block['content'] as String? ?? '';
    return MarkdownBody(
      data: content.replaceAll('<', '&lt;'),
      selectable: true,
      onTapLink: (_, href, _) {
        if (href != null) launchUrl(Uri.parse(href));
      },
    );
  }
}

class _AccordionBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _AccordionBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items;
    if (block['items'] is List) {
      items = (block['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    } else {
      items = [{'title': block['title'] as String? ?? 'Accordion', 'content': block['content'] as String? ?? ''}];
    }
    return Column(
      children: items.map((item) => ExpansionTile(
        title: Text(item['title'] as String? ?? ''),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: InlineMarkupText(text: item['content'] as String? ?? ''),
          ),
        ],
      )).toList(),
    );
  }
}

class _TableBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _TableBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final headers = (block['headers'] as List<dynamic>?)?.cast<String>() ?? [];
    final rows = (block['rows'] as List<dynamic>?)?.map((r) => (r as List<dynamic>).cast<String>()).toList() ?? [];
    final theme = Theme.of(context);
    final striped = block['striped'] == true;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(theme.colorScheme.surface),
        columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
        rows: rows.asMap().entries.map((e) => DataRow(
          color: striped && e.key.isOdd
              ? WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest)
              : null,
          cells: e.value.map((cell) => DataCell(Text(cell))).toList(),
        )).toList(),
      ),
    );
  }
}

class _TabsBlock extends StatefulWidget {
  final Map<String, dynamic> block;
  final int depth;
  const _TabsBlock({required this.block, required this.depth});

  @override
  State<_TabsBlock> createState() => _TabsBlockState();
}

class _TabsBlockState extends State<_TabsBlock> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = (widget.block['tabs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (tabs.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabs.asMap().entries.map((e) {
              final selected = _activeTab == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilterChip(
                  selected: selected,
                  label: Text(e.value['label'] as String? ?? 'Tab ${e.key + 1}'),
                  onSelected: (_) => setState(() => _activeTab = e.key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (_activeTab < tabs.length)
          BlockList(blocks: tabs[_activeTab]['blocks'] as List<dynamic>? ?? [], depth: widget.depth + 1),
      ],
    );
  }
}

class _EmbedBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _EmbedBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block['url'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _GalleryBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _GalleryBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final images = (block['images'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    if (images.isEmpty) return const SizedBox();
    final columns = block['columns'] as int? ?? 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, i) {
        final url = images[i]['url'] as String? ?? '';
        final caption = images[i]['caption'] as String? ?? '';
        return Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(fullImageUrl(url), fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image)),
              ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(caption, style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ],
        );
      },
    );
  }
}

class _ButtonBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _ButtonBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final text = block['text'] as String? ?? 'Button';
    final url = block['url'] as String? ?? '';
    final align = block['align'] as String? ?? 'center';
    final style = block['style'] as String? ?? 'primary';

    final alignment = switch (align) {
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };

    final onPressed = url.isNotEmpty ? () => launchUrl(Uri.parse(url)) : null;
    final Widget button = switch (style) {
      'secondary' => OutlinedButton(onPressed: onPressed, child: Text(text)),
      'outline' => TextButton(onPressed: onPressed, child: Text(text)),
      _ => ElevatedButton(onPressed: onPressed, child: Text(text)),
    };

    return Align(alignment: alignment, child: button);
  }
}

class _ProductCardBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  const _ProductCardBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final items = (block['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final layout = block['layout'] as String? ?? 'grid';
    final theme = Theme.of(context);

    if (items.isEmpty) {
      final name = block['name'] as String? ?? '';
      if (name.isEmpty) return const SizedBox();
      return _card(block, theme);
    }

    if (layout == 'list') {
      return Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _card(item, theme),
        )).toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => SizedBox(width: 160, child: _card(item, theme))).toList(),
    );
  }

  Widget _card(Map<String, dynamic> item, ThemeData theme) {
    final name = item['name'] as String? ?? '';
    final price = item['price'] as String? ?? '';
    final imageUrl = (item['image_url'] ?? item['image']) as String? ?? '';
    final description = item['description'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(fullImageUrl(imageUrl), height: 100, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(height: 100, child: Center(child: Icon(Icons.broken_image)))),
              ),
            if (imageUrl.isNotEmpty) const SizedBox(height: 8),
            Text(name, style: theme.textTheme.titleSmall),
            if (description.isNotEmpty)
              Text(description, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (price.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(price, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackBlock extends StatelessWidget {
  final String type;
  const _FallbackBlock({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text('Unknown block: $type', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
