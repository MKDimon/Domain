import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/models/community.dart' show PageSummary;
import '../../../data/models/page.dart';
import '../../community/community_navigation.dart' show CommunityNavigation;

class ProductItem {
  final String id;
  final String name;
  final String price;
  final String oldPrice;
  final String description;
  final String image;
  final List<String> tags;
  final String badge;

  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    this.oldPrice = '',
    this.description = '',
    this.image = '',
    this.tags = const [],
    this.badge = '',
  });
}

class ProductsSectionWidget extends StatefulWidget {
  final Section section;
  final Color? communityColor;
  final List<PageSummary>? pages;
  final String? communitySlug;
  const ProductsSectionWidget({super.key, required this.section, this.communityColor, this.pages, this.communitySlug});

  @override
  State<ProductsSectionWidget> createState() => _ProductsSectionWidgetState();
}

class _ProductsSectionWidgetState extends State<ProductsSectionWidget> {
  String _searchQuery = '';
  String _activeTag = '';
  Color get _pac => widget.communityColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light).accent;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _layout => widget.section.config['layout'] as String? ?? 'grid';

  List<ProductItem> get _allItems {
    final items = widget.section.data['items'] as List<dynamic>? ?? [];
    return items.map((raw) {
      final m = raw as Map<String, dynamic>;
      return ProductItem(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        price: m['price'] as String? ?? '',
        oldPrice: m['old_price'] as String? ?? '',
        description: m['description'] as String? ?? '',
        image: m['image'] as String? ?? m['image_url'] as String? ?? '',
        tags: (m['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        badge: m['badge'] as String? ?? '',
      );
    }).toList();
  }

  List<String> get _allTags {
    final tags = <String>{};
    for (final item in _allItems) {
      for (final tag in item.tags) {
        tags.add(tag);
      }
    }
    return tags.toList();
  }

  List<ProductItem> get _filteredItems {
    var result = _allItems;
    if (_activeTag.isNotEmpty) {
      result = result.where((item) => item.tags.contains(_activeTag)).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((item) =>
        item.name.toLowerCase().contains(q) ||
        item.description.toLowerCase().contains(q)
      ).toList();
    }
    return result;
  }

  void _openProductModal(ProductItem product) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final chatSectionId = widget.section.config['chat_section_id'] as int?;
    PageSummary? chatPage;
    if (chatSectionId != null && widget.pages != null) {
      for (final p in widget.pages!) { if (p.pageType == 'chat') { chatPage = p; break; } }
    }
    VoidCallback? chatTap;
    if (chatPage != null) {
      final nav = CommunityNavigation.of(context);
      final slug = widget.communitySlug;
      final pageId = chatPage.id;
      chatTap = () {
        if (nav != null) {
          nav.onPageSelect(pageId);
        } else if (slug != null) {
          context.goNamed('page-view', pathParameters: {'slug': slug, 'pageId': '$pageId'});
        }
      };
    }
    showDialog(
      context: context,
      builder: (ctx) => _ProductModal(
        product: product, c: c, communityColor: widget.communityColor,
        onChatTap: chatTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final items = _allItems;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Нет товаров', style: TextStyle(fontSize: 14, color: c.textSecondary)),
        ),
      );
    }

    final filtered = _filteredItems;
    final tags = _allTags;

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
                    hintText: 'Поиск товаров...',
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

        // Tags filter
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FilterChip(
                label: 'Все товары',
                isActive: _activeTag.isEmpty,
                c: c,
                communityColor: widget.communityColor,
                onTap: () => setState(() => _activeTag = ''),
              ),
              ...tags.map((tag) => _FilterChip(
                label: tag,
                isActive: _activeTag == tag,
                c: c,
                communityColor: widget.communityColor,
                onTap: () => setState(() {
                  _activeTag = _activeTag == tag ? '' : tag;
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
        else if (_layout == 'list')
          _buildListView(filtered, c)
        else
          _buildGridView(filtered, c),
      ],
    );
  }

  Widget _buildGridView(List<ProductItem> items, ColorSet c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / 214).floor().clamp(1, 5);
        final cardWidth = (width - (columns - 1) * 14) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items.map((item) => SizedBox(
            width: cardWidth,
            child: _ProductCard(
              item: item,
              c: c,
              communityColor: widget.communityColor,
              onTap: () => _openProductModal(item),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildListView(List<ProductItem> items, ColorSet c) {
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ProductRow(
          item: item,
          c: c,
          communityColor: widget.communityColor,
          onTap: () => _openProductModal(item),
        ),
      )).toList(),
    );
  }
}

// ─── Filter chip ───────────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final ColorSet c;
  final Color _pac;
  final VoidCallback onTap;
  _FilterChip({required this.label, required this.isActive, required this.c, Color? communityColor, required this.onTap}) : _pac = communityColor ?? c.accent;
  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
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
            color: widget.isActive ? widget._pac : widget.c.surface,
            border: Border.all(
              color: widget.isActive
                  ? widget._pac
                  : _hovered ? widget._pac : widget.c.border,
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

// ─── Product card (grid) ───────────────────────────────────────────────────

class _ProductCard extends StatefulWidget {
  final ProductItem item;
  final ColorSet c;
  final Color _pac;
  final VoidCallback onTap;
  _ProductCard({required this.item, required this.c, Color? communityColor, required this.onTap}) : _pac = communityColor ?? c.accent;
  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  Color _badgeColor(String badge) => switch (badge) {
    'new' => widget.c.success,
    'sale' => widget.c.error,
    'hit' => widget.c.warning,
    _ => Colors.grey,
  };

  String _badgeLabel(String badge) => switch (badge) {
    'new' => 'NEW',
    'sale' => 'SALE',
    'hit' => 'HIT',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.c.surface,
            border: Border.all(
              color: _hovered ? widget.c.textSecondary : widget.c.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with badge
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: widget.c.surfaceAlt,
                      child: item.image.isNotEmpty
                          ? Image.network(fullImageUrl(item.image), fit: BoxFit.cover)
                          : Center(child: Icon(Icons.photo_camera, size: 28, color: widget.c.textSecondary.withValues(alpha: 0.3))),
                    ),
                    if (item.badge.isNotEmpty)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _badgeColor(item.badge),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _badgeLabel(item.badge),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: item.badge == 'hit' ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.c.text),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.description,
                        style: TextStyle(fontSize: 12, color: widget.c.textSecondary, height: 1.5),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: item.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget._pac.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget._pac)),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Price row
                    Row(
                      children: [
                        Text('${item.price} \u20BD',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: widget._pac),
                        ),
                        if (item.oldPrice.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('${item.oldPrice} \u20BD',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.c.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ─── Product row (list) ────────────────────────────────────────────────────

class _ProductRow extends StatefulWidget {
  final ProductItem item;
  final ColorSet c;
  final Color _pac;
  final VoidCallback onTap;
  _ProductRow({required this.item, required this.c, Color? communityColor, required this.onTap}) : _pac = communityColor ?? c.accent;
  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hovered = false;

  Color _badgeColor(String badge) => switch (badge) {
    'new' => widget.c.success,
    'sale' => widget.c.error,
    'hit' => widget.c.warning,
    _ => Colors.grey,
  };

  String _badgeLabel(String badge) => switch (badge) {
    'new' => 'NEW',
    'sale' => 'SALE',
    'hit' => 'HIT',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.c.surface,
            border: Border.all(
              color: _hovered ? widget.c.textSecondary : widget.c.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 72, height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: widget.c.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.image.isNotEmpty
                    ? Image.network(fullImageUrl(item.image), fit: BoxFit.cover)
                    : Center(child: Icon(Icons.photo_camera, size: 24, color: widget.c.textSecondary.withValues(alpha: 0.3))),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: widget.c.text),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.description,
                        style: TextStyle(fontSize: 13, color: widget.c.textSecondary, height: 1.5),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: item.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget._pac.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: widget._pac)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Price + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.price} \u20BD',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: widget._pac),
                  ),
                  if (item.oldPrice.isNotEmpty)
                    Text('${item.oldPrice} \u20BD',
                      style: TextStyle(fontSize: 13, color: widget.c.textSecondary, decoration: TextDecoration.lineThrough),
                    ),
                  if (item.badge.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _badgeColor(item.badge),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _badgeLabel(item.badge),
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: item.badge == 'hit' ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Product modal ─────────────────────────────────────────────────────────

class _ProductModal extends StatelessWidget {
  final ProductItem product;
  final ColorSet c;
  final Color _pac;
  final VoidCallback? onChatTap;
  _ProductModal({required this.product, required this.c, Color? communityColor, this.onChatTap}) : _pac = communityColor ?? c.accent;

  Color _badgeColor(String badge) => switch (badge) {
    'new' => c.success,
    'sale' => c.error,
    'hit' => c.warning,
    _ => Colors.grey,
  };

  String _badgeLabel(String badge) => switch (badge) {
    'new' => 'NEW',
    'sale' => 'SALE',
    'hit' => 'HIT',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image
              if (product.image.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(fullImageUrl(product.image), fit: BoxFit.cover, width: double.infinity),
                      ),
                    ),
                    if (product.badge.isNotEmpty)
                      Positioned(
                        top: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _badgeColor(product.badge),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _badgeLabel(product.badge),
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: product.badge == 'hit' ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12, right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: c.textSecondary),
                  ),
                ),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(product.name,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
                    ),
                    const SizedBox(height: 8),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${product.price} \u20BD',
                          style: TextStyle(fontSize: 20.8, fontWeight: FontWeight.w700, color: _pac),
                        ),
                        if (product.oldPrice.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('${product.oldPrice} \u20BD',
                            style: TextStyle(fontSize: 15.2, color: c.textSecondary, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tags
                    if (product.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: product.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _pac.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _pac)),
                        )).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Description
                    if (product.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(product.description,
                          style: TextStyle(fontSize: 14, color: c.text, height: 1.7),
                        ),
                      ),

                    // Chat button
                    if (onChatTap != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onChatTap!();
                          },
                          icon: Icon(Icons.chat_outlined, size: 16, color: _pac),
                          label: Text('Написать продавцу', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _pac)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: _pac.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
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
