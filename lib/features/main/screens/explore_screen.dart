import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/api/categories_api.dart';
import '../../../data/models/community.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  const ExploreScreen({super.key, this.initialCategory});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  List<Community> _communities = [];
  List<Category> _categories = [];
  String? _selectedCategory;
  bool _loading = true;
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = CommunitiesApi(ref.read(apiClientProvider));
    final catApi = CategoriesApi(ref.read(apiClientProvider));
    try {
      final results = await Future.wait([api.list(limit: 100), catApi.list()]);
      final enriched = await api.enrichListWithCounts(results[0] as List<Community>);
      if (mounted) {
        setState(() {
          _communities = enriched;
          _categories = results[1] as List<Category>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Community> get _filtered {
    var list = _communities;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(query) || c.slug.toLowerCase().contains(query)).toList();
    }
    if (_selectedCategory != null) {
      list = list.where((c) => c.categorySlug == _selectedCategory).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final width = MediaQuery.of(context).size.width;
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildPageContent(c, width, auth),
        ],
      ),
    );
  }

  Widget _buildPageContent(ColorSet c, double width, AuthState auth) {
    final isMobile = width < 560;

    return Expanded(
      child: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => context.goNamed('main'),
                                    child: Text(AppLocalizations.of(context)!.exploreBack, style: TextStyle(fontSize: 14, color: c.textSecondary)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(AppLocalizations.of(context)!.exploreTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.text)),
                                ],
                              ),
                            ),
                            if (auth.isAuthenticated)
                              InkWell(
                                onTap: () => context.goNamed('create-community'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
                                  child: Text(AppLocalizations.of(context)!.exploreCreate, style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w500, color: c.textOnAccent)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildToolbar(c, isMobile),
                        if (_categories.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildCategoryChips(c),
                        ],
                        const SizedBox(height: 16),
                        _buildResultsInfo(c),
                        const SizedBox(height: 16),
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Center(child: Text(AppLocalizations.of(context)!.exploreNoCommunities, style: TextStyle(fontSize: 16, color: c.textSecondary))),
                          )
                        else if (_gridView)
                          _buildGrid(c, width)
                        else
                          _buildList(c),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildToolbar(ColorSet c, bool isMobile) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Container(
          height: 44,
          constraints: BoxConstraints(minWidth: isMobile ? 0 : 250),
          width: isMobile ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: c.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: c.text),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.exploreSearch,
                    hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchController.clear(); setState(() {}); },
                  child: Icon(Icons.close, size: 18, color: c.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(ColorSet c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CategoryChip(label: AppLocalizations.of(context)!.commonAll, selected: _selectedCategory == null, c: c, onTap: () => setState(() => _selectedCategory = null)),
        ..._categories.map((cat) => _CategoryChip(
          label: cat.name,
          selected: _selectedCategory == cat.slug,
          c: c,
          onTap: () => setState(() => _selectedCategory = _selectedCategory == cat.slug ? null : cat.slug),
        )),
      ],
    );
  }

  Widget _buildResultsInfo(ColorSet c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: c.textSecondary),
            children: [
              TextSpan(text: '${_filtered.length}', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
              TextSpan(text: ' ${AppLocalizations.of(context)!.communitiesLabel}'),
            ],
          ),
        ),
        Row(
          children: [
            _ViewToggleBtn(icon: Icons.grid_view, active: _gridView, c: c, onTap: () => setState(() => _gridView = true)),
            const SizedBox(width: 4),
            _ViewToggleBtn(icon: Icons.view_list, active: !_gridView, c: c, onTap: () => setState(() => _gridView = false)),
          ],
        ),
      ],
    );
  }

  Widget _buildGrid(ColorSet c, double width) {
    final columns = width < 560 ? 1 : (width < 900 ? 2 : 3);
    final spacing = 20.0;
    final availableWidth = (width < 1200 ? width : 1200.0) - 40;
    final cardWidth = (availableWidth - spacing * (columns - 1)) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: _filtered.map((comm) => SizedBox(
        width: cardWidth,
        child: _CommunityGridCard(community: comm, c: c),
      )).toList(),
    );
  }

  Widget _buildList(ColorSet c) {
    return Column(
      children: _filtered.map((comm) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _CommunityListCard(community: comm, c: c),
      )).toList(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorSet c;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          border: Border.all(color: selected ? c.accent : c.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : c.textSecondary),
        ),
      ),
    );
  }
}

class _ViewToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final ColorSet c;
  final VoidCallback onTap;
  const _ViewToggleBtn({required this.icon, required this.active, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.08) : c.surface,
          border: Border.all(color: active ? c.accent : c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: active ? c.accent : c.textSecondary),
      ),
    );
  }
}

class _CommunityGridCard extends StatefulWidget {
  final Community community;
  final ColorSet c;
  const _CommunityGridCard({required this.community, required this.c});

  @override
  State<_CommunityGridCard> createState() => _CommunityGridCardState();
}

class _CommunityGridCardState extends State<_CommunityGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final comm = widget.community;
    final c = widget.c;
    final color = avatarColor(comm.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _hovered ? Matrix4.translationValues(0.0, -2.0, 0.0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: _hovered ? c.accent : c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.goNamed('community', pathParameters: {'slug': comm.slug}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 8, color: color),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: color,
                          backgroundImage: comm.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(comm.avatarUrl!)) : null,
                          child: comm.avatarUrl?.isNotEmpty != true
                              ? Text(comm.initial, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comm.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('/${comm.slug}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (comm.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(comm.description!, style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Text('${comm.memberCount}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                        const SizedBox(width: 16),
                        Icon(Icons.article_outlined, size: 14, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Text('${comm.pageCount}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
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

class _CommunityListCard extends StatefulWidget {
  final Community community;
  final ColorSet c;
  const _CommunityListCard({required this.community, required this.c});

  @override
  State<_CommunityListCard> createState() => _CommunityListCardState();
}

class _CommunityListCardState extends State<_CommunityListCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final comm = widget.community;
    final c = widget.c;
    final color = avatarColor(comm.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: _hovered ? c.accent : c.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: () => context.goNamed('community', pathParameters: {'slug': comm.slug}),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: comm.avatarUrl?.isNotEmpty == true
                      ? Image.network(fullImageUrl(comm.avatarUrl!), width: 48, height: 48, fit: BoxFit.cover)
                      : Text(comm.initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comm.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
                      if (comm.description?.isNotEmpty == true)
                        Text(comm.description!, style: TextStyle(fontSize: 13, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 14, color: c.textSecondary),
                    const SizedBox(width: 4),
                    Text('${comm.memberCount}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    const SizedBox(width: 16),
                    Icon(Icons.article_outlined, size: 14, color: c.textSecondary),
                    const SizedBox(width: 4),
                    Text('${comm.pageCount}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
