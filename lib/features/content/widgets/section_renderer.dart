import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/editor_defaults.dart';
import '../../../data/models/community.dart';
import '../../../data/models/page.dart';
import '../../community/community_navigation.dart';
import '../../chat/widgets/chat_section_widget.dart';
import '../../chat/widgets/inbox_chat_widget.dart';
import 'block_renderer.dart';
import 'announcements_section_widget.dart';
import 'booking_section_widget.dart';
import 'calendar_section_widget.dart';
import 'poll_section_widget.dart';
import 'quiz_section_widget.dart';
import 'products_section_widget.dart';
import 'wiki_section_widget.dart';
import '../../script/script_runner.dart';
import '../../script/lua_sandbox.dart';
import '../../../providers/auth_provider.dart';

class SectionRenderer extends StatelessWidget {
  final Section section;
  final List<PageSummary>? pages;
  final String? communitySlug;
  final Color? communityColor;
  final int? communityId;
  final bool isStaff;

  const SectionRenderer({
    super.key,
    required this.section,
    this.pages,
    this.communitySlug,
    this.communityColor,
    this.communityId,
    this.isStaff = false,
  });

  @override
  Widget build(BuildContext context) {
    final inner = _buildContent(context);
    final noWrap = section.sectionType == 'chat' || section.sectionType == 'community-header';
    if (noWrap) return inner;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: inner,
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (section.sectionType) {
      'content' => _ContentSection(section: section),
      'wiki' => WikiSectionWidget(section: section, communityColor: communityColor),
      'announcements' => AnnouncementsSectionWidget(section: section, canEdit: isStaff),
      'polls' => PollSectionWidget(section: section),
      'products' => ProductsSectionWidget(section: section, communityColor: communityColor, pages: pages, communitySlug: communitySlug),
      'booking' => BookingSectionWidget(section: section, canEdit: isStaff),
      'calendar' => CalendarSectionWidget(section: section),
      'quiz' => QuizSectionWidget(section: section, communityColor: communityColor),
      'chat' => _buildChatSection(),
      'script' => _ScriptLiveSection(key: ValueKey('script_${section.id}'), section: section, communityId: communityId ?? 0, communityColor: communityColor),
      'navigation' => NavigationSectionWidget(
        section: section,
        pages: pages ?? [],
        slug: communitySlug ?? '',
        communityColor: communityColor,
      ),
      'popular-pages' => PopularPagesSectionWidget(
        section: section,
        pages: pages ?? [],
        slug: communitySlug ?? '',
        communityColor: communityColor,
        communityId: communityId,
      ),
      'recent-updates' => RecentUpdatesSectionWidget(
        section: section,
        pages: pages ?? [],
        slug: communitySlug ?? '',
        communityColor: communityColor,
      ),
      'community-header' => CommunityHeaderSectionWidget(section: section, communityColor: communityColor),
      'columns' => ColumnsSectionWidget(
        section: section,
        pages: pages,
        communitySlug: communitySlug,
        communityColor: communityColor,
        communityId: communityId,
      ),
      _ => _PlaceholderSection(type: section.sectionType),
    };
  }

  Widget _buildChatSection() {
    final chatMode = section.config['chat_mode'] as String? ?? 'public';
    if (chatMode == 'inbox') {
      return InboxChatWidget(
        sectionId: section.id,
        isStaff: isStaff,
      );
    }
    return SizedBox(
      height: 500,
      child: ChatSectionWidget(sectionId: section.id),
    );
  }
}

// ─── Content ────────────────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final Section section;
  const _ContentSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final blocks = section.blocks;
    final editorMode = section.config['editorMode'] as String? ?? section.data['mode'] as String?;
    final isMarkdown = editorMode == 'markdown' || (blocks.isNotEmpty && blocks[0]['type'] == 'markdown');
    if (isMarkdown) {
      final md = (blocks.isNotEmpty && blocks[0]['type'] == 'markdown')
          ? blocks[0]['content'] as String? ?? ''
          : section.markdownContent;
      if (md.isEmpty) return const SizedBox.shrink();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final c = isDark ? AppColors.dark : AppColors.light;
      return MarkdownBody(
        data: md.replaceAll('<', '&lt;'),
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: TextStyle(fontSize: 25.6, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
          h2: TextStyle(fontSize: 20.8, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
          h3: TextStyle(fontSize: 17.6, fontWeight: FontWeight.w600, color: c.text, height: 1.3),
          p: TextStyle(fontSize: 15, color: c.text, height: 1.8),
          listBullet: TextStyle(fontSize: 15, color: c.text),
          blockquoteDecoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.accent, width: 3)),
            color: c.hoverOverlay,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          code: TextStyle(fontSize: 13, color: c.code, backgroundColor: c.codeBg, fontFamily: 'JetBrains Mono, Consolas, monospace'),
          codeblockDecoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          codeblockPadding: const EdgeInsets.all(14),
          horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: c.border, width: 1))),
          a: TextStyle(color: c.accent),
        ),
      );
    }
    return BlockList(blocks: blocks);
  }
}

// ─── Script ─────────────────────────────────────────────────────────────────

class _ScriptLiveSection extends ConsumerStatefulWidget {
  final Section section;
  final int communityId;
  final Color? communityColor;
  const _ScriptLiveSection({super.key, required this.section, required this.communityId, this.communityColor});

  @override
  ConsumerState<_ScriptLiveSection> createState() => _ScriptLiveSectionState();
}

class _ScriptLiveSectionState extends ConsumerState<_ScriptLiveSection> {
  int _runKey = 0;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final code = section.data['code'] as String? ?? section.config['code'] as String? ?? '';
    if (code.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final auth = ref.watch(authProvider);

    final title = section.config['title'] as String? ?? 'Lua Script';
    final accentColor = widget.communityColor ?? c.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.code, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _runKey++),
                child: Tooltip(
                  message: 'Перезапустить',
                  child: Icon(Icons.refresh, size: 18, color: c.textSecondary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ScriptRunner(
            key: ValueKey('script_run_${section.id}_$_runKey'),
            code: code,
            communityColor: widget.communityColor,
            context: SandboxContext(
              sectionId: section.id,
              userId: auth.user?.id ?? 0,
              userName: auth.user?.effectiveName ?? '',
              isLoggedIn: auth.isAuthenticated,
              communityName: '',
              communityId: widget.communityId,
              pageTitle: title,
            ),
            c: c,
          ),
        ],
      );
  }
}

// ─── Navigation ─────────────────────────────────────────────────────────────

class NavigationSectionWidget extends StatefulWidget {
  final Section section;
  final List<PageSummary> pages;
  final String slug;
  final Color? communityColor;

  const NavigationSectionWidget({
    super.key,
    required this.section,
    required this.pages,
    required this.slug,
    this.communityColor,
  });

  @override
  State<NavigationSectionWidget> createState() => _NavigationSectionWidgetState();
}

class _NavigationSectionWidgetState extends State<NavigationSectionWidget> {
  late bool _horizontal;

  @override
  void initState() {
    super.initState();
    _horizontal = (widget.section.config['layout'] as String? ?? 'vertical') == 'horizontal';
  }

  List<PageSummary> get _visiblePages =>
      widget.pages.where((p) => p.pageType != 'main' && p.pageType != 'chat').toList();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final accentColor = widget.communityColor ?? c.accent;
    final colorDim = accentColor.withValues(alpha: 0.12);
    final colorText = accentColor.withValues(alpha: 0.9);
    final pages = _visiblePages;
    final title = widget.section.config['title'] as String?;

    Widget listContent;
    if (pages.isEmpty) {
      listContent = Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Нет страниц', style: TextStyle(fontSize: 14, color: c.textSecondary))),
      );
    } else if (_horizontal) {
      listContent = Wrap(
        spacing: 10, runSpacing: 10,
        children: pages.map((p) => _NavPageCard(page: p, c: c, slug: widget.slug, colorDim: colorDim, colorText: colorText, accentColor: accentColor)).toList(),
      );
    } else {
      listContent = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: pages.length,
          itemBuilder: (ctx, i) => _NavPageItem(page: pages[i], c: c, slug: widget.slug, colorDim: colorDim, colorText: colorText),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view, size: 16, color: colorText),
            const SizedBox(width: 8),
            Flexible(child: Text(title ?? 'Навигация', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            _GearButton(
              icon: _horizontal ? Icons.view_list_outlined : Icons.grid_view_outlined,
              c: c,
              accentColor: accentColor,
              onTap: () => setState(() => _horizontal = !_horizontal),
            ),
          ],
        ),
        const SizedBox(height: 12),
        listContent,
      ],
    );
  }
}

class _GearButton extends StatefulWidget {
  final IconData icon;
  final ColorSet c;
  final Color accentColor;
  final VoidCallback onTap;
  const _GearButton({required this.icon, required this.c, required this.accentColor, required this.onTap});
  @override State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: _hovered ? widget.accentColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 14, color: _hovered ? widget.accentColor : widget.c.textSecondary),
        ),
      ),
    );
  }
}

class _NavPageCard extends StatefulWidget {
  final PageSummary page;
  final ColorSet c;
  final String slug;
  final Color colorDim;
  final Color colorText;
  final Color accentColor;
  const _NavPageCard({required this.page, required this.c, required this.slug, required this.colorDim, required this.colorText, required this.accentColor});
  @override State<_NavPageCard> createState() => _NavPageCardState();
}

class _NavPageCardState extends State<_NavPageCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          final nav = CommunityNavigation.of(context);
          if (nav != null) { nav.onPageSelect(p.id); }
          else if (widget.slug.isNotEmpty) { context.goNamed('page-view', pathParameters: {'slug': widget.slug, 'pageId': '${p.id}'}); }
        },
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: _hovered ? widget.accentColor : widget.c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageIconBox(page: p, size: 36, iconSize: 20, colorDim: widget.colorDim, colorText: widget.colorText),
              const SizedBox(height: 6),
              Text(p.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: widget.c.text), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPageItem extends StatefulWidget {
  final PageSummary page;
  final ColorSet c;
  final String slug;
  final Color colorDim;
  final Color colorText;
  const _NavPageItem({required this.page, required this.c, required this.slug, required this.colorDim, required this.colorText});
  @override State<_NavPageItem> createState() => _NavPageItemState();
}

class _NavPageItemState extends State<_NavPageItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          final nav = CommunityNavigation.of(context);
          if (nav != null) { nav.onPageSelect(p.id); }
          else if (widget.slug.isNotEmpty) { context.goNamed('page-view', pathParameters: {'slug': widget.slug, 'pageId': '${p.id}'}); }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: _hovered ? widget.c.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              _PageIconBox(page: p, size: 28, iconSize: 16, colorDim: widget.colorDim, colorText: widget.colorText),
              const SizedBox(width: 10),
              Expanded(child: Text(p.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: widget.c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (p.viewCount > 0)
                Text('${p.viewCount}', style: TextStyle(fontSize: 11, color: widget.c.textSecondary, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIconBox extends StatelessWidget {
  final PageSummary page;
  final double size;
  final double iconSize;
  final Color colorDim;
  final Color colorText;
  const _PageIconBox({required this.page, required this.size, required this.iconSize, required this.colorDim, required this.colorText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: colorDim, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: _resolveIcon(),
    );
  }

  Widget _resolveIcon() {
    if (page.imageUrl != null && page.imageUrl!.isNotEmpty) {
      return Image.network(fullImageUrl(page.imageUrl!), width: size, height: size, fit: BoxFit.contain);
    }
    if (page.iconEmoji != null && page.iconEmoji!.isNotEmpty && page.iconType != 'svg') {
      return Text(page.iconEmoji!, style: TextStyle(fontSize: iconSize));
    }
    return Icon(_defaultIcon(page.pageType), size: iconSize, color: colorText);
  }

  static IconData _defaultIcon(String type) => switch (type) {
    'chat' => Icons.chat_outlined,
    'wiki' => Icons.article_outlined,
    'voice' => Icons.mic_outlined,
    'faq' => Icons.help_outline,
    'calendar' => Icons.calendar_month_outlined,
    'booking' => Icons.event_available_outlined,
    'announcements' => Icons.campaign_outlined,
    'polls' => Icons.poll_outlined,
    'quiz' => Icons.quiz_outlined,
    'products' => Icons.storefront_outlined,
    'content' => Icons.view_agenda_outlined,
    'script' => Icons.code_outlined,
    _ => Icons.description_outlined,
  };
}

// ─── Popular Pages ──────────────────────────────────────────────────────────

class PopularPagesSectionWidget extends ConsumerStatefulWidget {
  final Section section;
  final List<PageSummary> pages;
  final String slug;
  final Color? communityColor;
  final int? communityId;

  const PopularPagesSectionWidget({
    super.key,
    required this.section,
    required this.pages,
    required this.slug,
    this.communityColor,
    this.communityId,
  });

  @override
  ConsumerState<PopularPagesSectionWidget> createState() => _PopularPagesSectionState();
}

class _PopularPagesSectionState extends ConsumerState<PopularPagesSectionWidget> {
  List<PageSummary>? _popular;

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  Future<void> _loadPopular() async {
    final commId = widget.communityId;
    if (commId == null) return;
    try {
      final limit = widget.section.config['limit'] as int? ?? 5;
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final resp = await api.getPopularPages(commId, limit: limit);
      if (mounted) setState(() => _popular = resp);
    } catch (_) {
      if (mounted) setState(() => _popular = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final limit = widget.section.config['limit'] as int? ?? 5;
    final showViews = widget.section.config['show_views'] as bool? ?? true;
    final title = widget.section.config['title'] as String?;
    final accentColor = widget.communityColor ?? c.accent;

    final top = _popular ?? widget.pages
        .where((p) => p.pageType != 'main' && p.pageType != 'chat')
        .take(limit).toList();

    if (top.isEmpty) {
      return Row(
        children: [
          Icon(Icons.trending_up, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Flexible(child: Text(title ?? 'Популярные страницы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('Нет данных', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Flexible(child: Text(title ?? 'Популярные страницы', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
        ...top.map((p) => _PopularPageRow(page: p, c: c, slug: widget.slug, accentColor: accentColor, showViews: showViews)),
      ],
    );
  }
}

class _PopularPageRow extends StatefulWidget {
  final PageSummary page;
  final ColorSet c;
  final String slug;
  final Color accentColor;
  final bool showViews;
  const _PopularPageRow({required this.page, required this.c, required this.slug, required this.accentColor, this.showViews = true});
  @override State<_PopularPageRow> createState() => _PopularPageRowState();
}

class _PopularPageRowState extends State<_PopularPageRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          final nav = CommunityNavigation.of(context);
          if (nav != null) { nav.onPageSelect(p.id); }
          else if (widget.slug.isNotEmpty) { context.goNamed('page-view', pathParameters: {'slug': widget.slug, 'pageId': '${p.id}'}); }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(p.title, style: TextStyle(fontSize: 13, color: _hovered ? widget.accentColor : widget.c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (widget.showViews)
                Text('${p.viewCount} просмотров', style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recent Updates ─────────────────────────────────────────────────────────

class RecentUpdatesSectionWidget extends StatelessWidget {
  final Section section;
  final List<PageSummary> pages;
  final String slug;
  final Color? communityColor;

  const RecentUpdatesSectionWidget({
    super.key,
    required this.section,
    required this.pages,
    required this.slug,
    this.communityColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final limit = section.config['limit'] as int? ?? 5;
    final title = section.config['title'] as String?;
    final accentColor = communityColor ?? c.accent;

    final recent = pages
        .where((p) => p.updatedAt != null && p.pageType != 'main' && p.pageType != 'chat')
        .toList()
      ..sort((a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''));
    final top = recent.take(limit).toList();

    if (top.isEmpty) {
      return Row(
        children: [
          Icon(Icons.history, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Flexible(child: Text(title ?? 'Последние обновления', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text('Нет данных', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Flexible(child: Text(title ?? 'Последние обновления', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
        ...top.map((p) => _RecentChangeRow(page: p, c: c, slug: slug, accentColor: accentColor)),
      ],
    );
  }
}

class _RecentChangeRow extends StatefulWidget {
  final PageSummary page;
  final ColorSet c;
  final String slug;
  final Color accentColor;
  const _RecentChangeRow({required this.page, required this.c, required this.slug, required this.accentColor});
  @override State<_RecentChangeRow> createState() => _RecentChangeRowState();
}

class _RecentChangeRowState extends State<_RecentChangeRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.page;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          final nav = CommunityNavigation.of(context);
          if (nav != null) { nav.onPageSelect(p.id); }
          else if (widget.slug.isNotEmpty) { context.goNamed('page-view', pathParameters: {'slug': widget.slug, 'pageId': '${p.id}'}); }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(p.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _hovered ? widget.accentColor : widget.c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (p.updatedAt != null)
                Text(_timeAgo(p.updatedAt!), style: TextStyle(fontSize: 12, color: widget.c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeAgo(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'только что';
      if (diff.inHours < 1) return '${diff.inMinutes}м назад';
      if (diff.inDays < 1) return '${diff.inHours}ч назад';
      if (diff.inDays < 7) return '${diff.inDays}д назад';
      return '${dt.day}.${dt.month}.${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Community Header ───────────────────────────────────────────────────────

class CommunityHeaderSectionWidget extends StatelessWidget {
  final Section section;
  final Color? communityColor;
  const CommunityHeaderSectionWidget({super.key, required this.section, this.communityColor});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final bannerUrl = section.data['banner_url'] as String?;
    final avatarUrl = section.data['avatar_url'] as String?;
    final description = section.data['description'] as String?;
    final bannerHeight = (section.data['banner_height'] as int? ?? 200).toDouble().clamp(100.0, 300.0);
    final bannerOffsetX = (section.data['banner_offset_x'] as int? ?? 50) / 100.0;
    final bannerOffsetY = (section.data['banner_offset_y'] as int? ?? 50) / 100.0;
    final bannerZoom = (section.data['banner_zoom'] as int? ?? 100) / 100.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: bannerHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bannerUrl != null && bannerUrl.isNotEmpty)
                  ClipRect(
                    child: Transform.scale(
                      scale: bannerZoom > 1.0 ? bannerZoom : 1.0,
                      child: Image.network(
                        fullImageUrl(bannerUrl),
                        fit: BoxFit.cover,
                        alignment: Alignment(bannerOffsetX * 2 - 1, bannerOffsetY * 2 - 1),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [communityColor ?? c.accent, c.surfaceAlt],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: bannerHeight * 0.6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5), c.surface],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: communityColor ?? c.accent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.surface, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? Image.network(fullImageUrl(avatarUrl), width: 72, height: 72, fit: BoxFit.cover)
                        : const Icon(Icons.group, color: Colors.white, size: 32),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Сообщество', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(description, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.6), maxLines: 4, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Columns ────────────────────────────────────────────────────────────────

class ColumnsSectionWidget extends StatelessWidget {
  final Section section;
  final List<PageSummary>? pages;
  final String? communitySlug;
  final Color? communityColor;
  final int? communityId;

  const ColumnsSectionWidget({
    super.key,
    required this.section,
    this.pages,
    this.communitySlug,
    this.communityColor,
    this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    final cols = (section.data['columns'] as List<dynamic>?) ?? [];
    if (cols.isEmpty) return const SizedBox.shrink();

    final flexValues = <int>[];
    for (final col in cols) {
      if (col is Map<String, dynamic>) {
        final cfg = col['config'] as Map<String, dynamic>? ?? {};
        final width = cfg['width'] as String?;
        if (width != null && width.endsWith('%')) {
          final pct = int.tryParse(width.replaceAll('%', ''));
          if (pct != null && pct > 0) {
            flexValues.add(pct);
            continue;
          }
        }
      }
      flexValues.add(1);
    }
    final allHaveFlex = flexValues.every((f) => f > 1);

    return _ColumnRow(
      cols: cols,
      flexValues: flexValues,
      allHaveFlex: allHaveFlex,
      section: section,
      pages: pages,
      communitySlug: communitySlug,
      communityColor: communityColor,
      communityId: communityId,
    );
  }
}

class _ColumnRow extends StatefulWidget {
  final List<dynamic> cols;
  final List<int> flexValues;
  final bool allHaveFlex;
  final Section section;
  final List<PageSummary>? pages;
  final String? communitySlug;
  final Color? communityColor;
  final int? communityId;

  const _ColumnRow({
    required this.cols, required this.flexValues, required this.allHaveFlex,
    required this.section, this.pages, this.communitySlug, this.communityColor, this.communityId,
  });

  @override
  State<_ColumnRow> createState() => _ColumnRowState();
}

class _ColumnRowState extends State<_ColumnRow> {
  final Map<int, GlobalKey> _keys = {};
  double? _maxHeight;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.cols.length; i++) { _keys[i] = GlobalKey(); }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    double max = 0;
    for (final k in _keys.values) {
      final h = k.currentContext?.size?.height ?? 0;
      if (h > max) max = h;
    }
    if (max > 0 && _maxHeight != max) setState(() => _maxHeight = max);
  }

  Widget _buildCol(int idx, Map<String, dynamic> col) {
    final type = col['section_type'] as String? ?? '';
    final config = (col['config'] as Map<String, dynamic>?) ?? {};
    final data = (col['data'] as Map<String, dynamic>?) ?? {};
    final childSection = Section(id: 0, pageId: widget.section.pageId, sectionType: type, config: config, data: data);
    return Padding(
      padding: EdgeInsets.only(right: idx < widget.cols.length - 1 ? 24 : 0),
      child: type.isEmpty
          ? const SizedBox.shrink()
          : SectionRenderer(section: childSection, pages: widget.pages, communitySlug: widget.communitySlug, communityColor: widget.communityColor, communityId: widget.communityId),
    );
  }

  List<double> _distributeWidths(double available) {
    const shell = 42.0; // SectionRenderer border(2) + padding(40)
    const gap = 24.0;
    final n = widget.cols.length;
    final totalGaps = n > 1 ? (n - 1) * gap : 0.0;
    final usable = available - totalGaps;

    final mins = <double>[];
    final flexes = <int>[];
    for (var i = 0; i < n; i++) {
      final col = widget.cols[i];
      String childType = '';
      if (col is Map<String, dynamic>) {
        childType = col['section_type'] as String? ?? '';
      }
      mins.add(shell + (sectionContentMinWidth[childType] ?? 120));
      flexes.add(widget.allHaveFlex ? widget.flexValues[i] : 1);
    }

    final widths = List<double>.filled(n, 0);
    final locked = List<bool>.filled(n, false);
    var remaining = usable;
    var remainingFlex = flexes.fold<int>(0, (a, b) => a + b);

    for (var pass = 0; pass < n; pass++) {
      var changed = false;
      for (var i = 0; i < n; i++) {
        if (locked[i]) continue;
        final proportional = remainingFlex > 0 ? remaining * flexes[i] / remainingFlex : remaining / (n - locked.where((l) => l).length);
        if (proportional <= mins[i]) {
          widths[i] = mins[i];
          locked[i] = true;
          remaining -= mins[i];
          remainingFlex -= flexes[i];
          changed = true;
        }
      }
      if (!changed) break;
    }

    for (var i = 0; i < n; i++) {
      if (!locked[i]) {
        widths[i] = remainingFlex > 0 ? remaining * flexes[i] / remainingFlex : remaining / (n - locked.where((l) => l).length);
      }
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _distributeWidths(constraints.maxWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.cols.asMap().entries.map<Widget>((e) {
            final col = e.value;
            if (col is! Map<String, dynamic>) return SizedBox(width: widths[e.key]);

            Widget child = KeyedSubtree(key: _keys[e.key]!, child: _buildCol(e.key, col));
            if (_maxHeight != null) {
              child = SizedBox(height: _maxHeight, child: child);
            }
            return SizedBox(width: widths[e.key], child: child);
          }).toList(),
        );
      },
    );
  }
}

// ─── Placeholder ────────────────────────────────────────────────────────────

class _PlaceholderSection extends StatelessWidget {
  final String type;
  const _PlaceholderSection({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.extension_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Flexible(child: Text(type, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
