import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/pages_api.dart';
import '../../../data/models/page.dart' as models;
import '../../../l10n/app_localizations.dart';
import '../../content/widgets/section_renderer.dart';

class PageViewScreen extends ConsumerStatefulWidget {
  final int pageId;
  final String communitySlug;

  const PageViewScreen({super.key, required this.pageId, required this.communitySlug});

  @override
  ConsumerState<PageViewScreen> createState() => _PageViewScreenState();
}

class _PageViewScreenState extends ConsumerState<PageViewScreen> {
  models.Page? _page;
  List<models.Section> _sections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = PagesApi(ref.read(apiClientProvider));
    try {
      final page = await api.get(widget.pageId);
      final sections = await api.listSections(widget.pageId);
      api.recordView(widget.pageId);
      if (mounted) setState(() { _page = page; _sections = sections; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load page'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(c, context),
          Expanded(child: _buildBody(c)),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorSet c, BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.goNamed('main'),
            child: Text(AppLocalizations.of(context)!.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.accent)),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => context.goNamed('community', pathParameters: {'slug': widget.communitySlug}),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios, size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context)!.pageViewBackToCommunity, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: c.textSecondary),
            onPressed: () => context.goNamed('page-edit', pathParameters: {'slug': widget.communitySlug, 'pageId': '${widget.pageId}'}),
            tooltip: 'Редактировать',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorSet c) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? AppLocalizations.of(context)!.pageViewLoadFailed, style: TextStyle(color: c.error)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.goNamed('community', pathParameters: {'slug': widget.communitySlug}),
              child: Text('← Back', style: TextStyle(color: c.accent)),
            ),
          ],
        ),
      );
    }

    final isChatPage = _page!.pageType == 'chat';

    if (isChatPage && _sections.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              children: [
                Expanded(child: Text(_page!.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.text), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SectionRenderer(section: _sections.first),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(_page!.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.text))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text('${_page!.viewCount} ${AppLocalizations.of(context)!.views}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  const SizedBox(width: 12),
                  Text(_page!.pageType, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
              const SizedBox(height: 24),
              if (_sections.isEmpty)
                Text(AppLocalizations.of(context)!.pageViewNoSections, style: TextStyle(fontSize: 14, color: c.textSecondary))
              else
                ..._sections.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SectionRenderer(section: s),
                )),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
