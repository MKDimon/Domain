import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/page.dart';

class WikiArticle {
  final String id;
  final String title;
  final String content;
  final String category;

  const WikiArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
  });
}

class TocItem {
  final int level;
  final String text;
  final String id;

  const TocItem({required this.level, required this.text, required this.id});
}

class WikiSectionWidget extends StatefulWidget {
  final Section section;
  final Color? communityColor;
  const WikiSectionWidget({super.key, required this.section, this.communityColor});

  @override
  State<WikiSectionWidget> createState() => _WikiSectionWidgetState();
}

class _WikiSectionWidgetState extends State<WikiSectionWidget> {
  String _searchQuery = '';
  String _activeCategory = '';
  WikiArticle? _viewingArticle;
  final _searchCtrl = TextEditingController();
  Color get _ac => widget.communityColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light).accent;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<WikiArticle> get _articles {
    final data = widget.section.data;
    final config = widget.section.config;

    final articlesRaw = data['articles'] as List<dynamic>?;
    if (articlesRaw != null && articlesRaw.isNotEmpty) {
      return articlesRaw.map((a) {
        final m = a as Map<String, dynamic>;
        return WikiArticle(
          id: m['id'] as String? ?? '',
          title: m['title'] as String? ?? '',
          content: m['content'] as String? ?? '',
          category: m['category'] as String? ?? '',
        );
      }).toList();
    }

    final content = data['content'] as String?;
    if (content != null && content.isNotEmpty) {
      return [
        WikiArticle(
          id: 'legacy',
          title: config['title'] as String? ?? 'Wiki',
          content: content,
          category: '',
        ),
      ];
    }

    return [];
  }

  List<String> get _allCategories {
    final cats = <String>{};
    for (final a in _articles) {
      if (a.category.isNotEmpty) cats.add(a.category);
    }
    return cats.toList();
  }

  List<WikiArticle> get _filteredArticles {
    var result = _articles;
    if (_activeCategory.isNotEmpty) {
      result = result.where((a) => a.category == _activeCategory).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((a) =>
        a.title.toLowerCase().contains(q) ||
        a.content.toLowerCase().contains(q)
      ).toList();
    }
    return result;
  }

  List<TocItem> _buildToc(String content) {
    final lines = content.split('\n');
    final items = <TocItem>[];
    final usedIds = <String, int>{};

    for (final line in lines) {
      final m = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (m != null) {
        final text = m.group(2)!.replaceAll(RegExp(r'[*`~\[\]]'), '');
        var id = text.toLowerCase().trim()
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll(RegExp(r'[^\w-]'), '');
        final count = usedIds[id] ?? 0;
        usedIds[id] = count + 1;
        if (count > 0) id += '-$count';
        items.add(TocItem(level: m.group(1)!.length, text: text, id: id));
      }
    }
    return items;
  }

  void _viewArticle(WikiArticle article) {
    setState(() => _viewingArticle = article);
  }

  void _backToIndex() {
    setState(() => _viewingArticle = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    if (_viewingArticle != null) {
      return _buildArticleView(c);
    }
    return _buildArticleIndex(c);
  }

  Widget _buildArticleIndex(ColorSet c) {
    final articles = _articles;

    if (articles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Нет статей', style: TextStyle(fontSize: 14, color: c.textSecondary)),
        ),
      );
    }

    final filtered = _filteredArticles;
    final categories = _allCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            border: Border.all(color: c.inputBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: c.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(fontSize: 14, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Поиск статей...',
                    hintStyle: TextStyle(color: c.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Categories
        if (categories.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CategoryChip(
                label: 'Все статьи',
                isActive: _activeCategory.isEmpty,
                c: c,
                communityColor: widget.communityColor,
                onTap: () => setState(() => _activeCategory = ''),
              ),
              ...categories.map((cat) => _CategoryChip(
                label: cat,
                isActive: _activeCategory == cat,
                c: c,
                communityColor: widget.communityColor,
                onTap: () => setState(() {
                  _activeCategory = _activeCategory == cat ? '' : cat;
                }),
              )),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // No results
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text('Ничего не найдено', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            ),
          )
        else
          // Article cards grid
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = (width / 264).floor().clamp(1, 4);
              final cardWidth = (width - (columns - 1) * 14) / columns;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: filtered.map((article) => SizedBox(
                  width: cardWidth,
                  child: _WikiCard(
                    article: article,
                    c: c,
                    communityColor: widget.communityColor,
                    onTap: () => _viewArticle(article),
                  ),
                )).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildArticleView(ColorSet c) {
    final article = _viewingArticle!;
    final toc = _buildToc(article.content);
    final hasToc = toc.length > 1;
    final isWide = MediaQuery.of(context).size.width > 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: back + category
        Row(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _backToIndex,
                child: Text(
                  '← К списку статей',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _ac),
                ),
              ),
            ),
            if (article.category.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: _ac.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(article.category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _ac)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Layout: TOC sidebar + Article body
        if (hasToc && isWide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOC sidebar
                SizedBox(
                  width: 200,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'СОДЕРЖАНИЕ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...toc.map((item) => _TocButton(
                          item: item,
                          c: c,
                        )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Article body
                Expanded(child: _articleBody(article, c)),
              ],
            ),
          )
        else
          _articleBody(article, c),
      ],
    );
  }

  Widget _articleBody(WikiArticle article, ColorSet c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          article.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: c.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),
        MarkdownBody(
          data: article.content.replaceAll('<', '&lt;'),
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(fontSize: 25.6, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
            h2: TextStyle(fontSize: 20.8, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
            h3: TextStyle(fontSize: 17.6, fontWeight: FontWeight.w600, color: c.text, height: 1.3),
            p: TextStyle(fontSize: 15, color: c.text, height: 1.8),
            listBullet: TextStyle(fontSize: 15, color: c.text),
            blockquoteDecoration: BoxDecoration(
              border: Border(left: BorderSide(color: _ac, width: 3)),
              color: c.hoverOverlay,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            code: TextStyle(
              fontSize: 13,
              color: c.code,
              backgroundColor: c.codeBg,
              fontFamily: 'JetBrains Mono, Consolas, monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            codeblockPadding: const EdgeInsets.all(14),
            horizontalRuleDecoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border, width: 1)),
            ),
            a: TextStyle(color: _ac),
          ),
        ),
      ],
    );
  }
}

// ─── Category chip ─────────────────────────────────────────────────────────

class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final ColorSet c;
  final Color _ac;
  final VoidCallback onTap;

  _CategoryChip({
    required this.label,
    required this.isActive,
    required this.c,
    Color? communityColor,
    required this.onTap,
  }) : _ac = communityColor ?? c.accent;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isActive ? widget._ac : widget.c.surface,
            border: Border.all(
              color: widget.isActive
                  ? widget._ac
                  : _hovered ? widget._ac : widget.c.border,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.isActive
                  ? Colors.white
                  : _hovered ? widget.c.text : widget.c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Wiki card ─────────────────────────────────────────────────────────────

class _WikiCard extends StatefulWidget {
  final WikiArticle article;
  final ColorSet c;
  final Color _ac;
  final VoidCallback onTap;

  _WikiCard({
    required this.article,
    required this.c,
    Color? communityColor,
    required this.onTap,
  }) : _ac = communityColor ?? c.accent;

  @override
  State<_WikiCard> createState() => _WikiCardState();
}

class _WikiCardState extends State<_WikiCard> {
  bool _hovered = false;

  String _getExcerpt(String content, [int maxLen = 120]) {
    final plain = content
        .replaceAll(RegExp(r'[#*`~>\[\]!_\-|]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    return plain.length > maxLen ? '${plain.substring(0, maxLen)}...' : plain;
  }

  String _getCharCount(String content) {
    final len = content.length;
    if (len < 1000) return '$len симв.';
    return '${(len / 1000).toStringAsFixed(1)}K симв.';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.c.surface,
            border: Border.all(
              color: _hovered ? widget.c.textSecondary : widget.c.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          transform: _hovered ? (Matrix4.identity()..translate(0.0, -1.0)) : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget._ac.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('W', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: widget._ac)),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                a.title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: widget.c.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Excerpt
              Text(
                _getExcerpt(a.content),
                style: TextStyle(fontSize: 13, color: widget.c.textSecondary, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Footer: category + char count
              Row(
                children: [
                  if (a.category.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget._ac.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        a.category,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget._ac),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _getCharCount(a.content),
                    style: TextStyle(fontSize: 12, color: widget.c.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TOC button ────────────────────────────────────────────────────────────

class _TocButton extends StatefulWidget {
  final TocItem item;
  final ColorSet c;

  const _TocButton({required this.item, required this.c});

  @override
  State<_TocButton> createState() => _TocButtonState();
}

class _TocButtonState extends State<_TocButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final indent = (widget.item.level - 1) * 10.0;
    final fontSize = widget.item.level == 1 ? 13.0 : 12.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // TOC scroll is non-trivial in Flutter without GlobalKeys per heading.
          // For now this is a visual match; scroll-to-heading would require
          // a custom markdown renderer with anchor keys.
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(left: 10 + indent, top: 4, bottom: 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.transparent, width: 2)),
          ),
          child: Text(
            widget.item.text,
            style: TextStyle(
              fontSize: fontSize,
              color: _hovered ? widget.c.text : widget.c.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
