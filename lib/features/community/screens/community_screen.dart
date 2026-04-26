import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/api/members_api.dart';
import '../../../data/api/pages_api.dart';
import '../../../data/models/community.dart';
import '../../../data/models/page.dart' as pm;
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../community_navigation.dart';
import '../../content/widgets/section_renderer.dart';
import '../../notifications/widgets/notifications_bell.dart';
import '../../moderation/widgets/moderation_panel.dart';
import '../widgets/community_search.dart';
import '../../feedback/widgets/feedback_panel.dart';
import '../../voice/state/voice_session.dart';
import '../../voice/widgets/floating_call_widget.dart';
import '../../voice/widgets/voice_room_view.dart';
import '../widgets/settings_panel.dart';
import '../widgets/report_dialog.dart';
import '../../../core/shell/shell_state.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  final String slug;
  final int? pageId;
  const CommunityScreen({super.key, required this.slug, this.pageId});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  Community? _community;
  List<PageSummary> _pages = [];
  List<pm.Section> _mainPageSections = [];
  int? _mainPageId;
  int? _currentPageId;
  pm.Page? _subPage;
  List<pm.Section> _subPageSections = [];
  bool _loading = true;
  String? _error;
  bool _isMember = false;
  bool _isOwner = false;
  bool _isStaff = false;
  bool _canManageMembers = false;
  bool _sidebarOpen = false;
  String _activeView = 'page'; // 'page' | 'moderation' | 'feedback'

  String? get _selectedPageId {
    if (_currentPageId == null || _currentPageId == _mainPageId) return null;
    return '$_currentPageId';
  }

  @override
  void initState() {
    super.initState();
    _currentPageId = widget.pageId;
    _load();
  }

  @override
  void dispose() {
    ref.read(shellCommunityProvider.notifier).state = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(CommunityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _currentPageId = widget.pageId;
      setState(() { _loading = true; _error = null; });
      _load();
    } else if (oldWidget.pageId != widget.pageId) {
      _currentPageId = widget.pageId;
      _activeView = 'page';
      _switchPage();
    }
  }

  void _selectPage(int? pageId) {
    if (pageId == _currentPageId && _activeView == 'page') return;
    _activeView = 'page';
    if (pageId != null && pageId != _mainPageId) {
      if (pageId == _currentPageId) {
        setState(() {});
      } else {
        context.goNamed('page-view', pathParameters: {'slug': widget.slug, 'pageId': '$pageId'});
      }
    } else if (_currentPageId != null && _currentPageId != _mainPageId) {
      context.goNamed('community', pathParameters: {'slug': widget.slug});
    } else {
      setState(() {});
    }
  }

  void _selectView(String view) {
    if (_activeView == view) return;
    setState(() => _activeView = view);
  }

  Future<void> _switchPage() async {
    if (_currentPageId == null || _currentPageId == _mainPageId) {
      setState(() { _subPage = null; _subPageSections = []; });
      return;
    }
    final pagesApi = PagesApi(ref.read(apiClientProvider));
    try {
      final page = await pagesApi.get(_currentPageId!);
      final sections = await pagesApi.listSections(_currentPageId!);
      pagesApi.recordView(_currentPageId!);
      sections.sort((a, b) => a.order.compareTo(b.order));
      _syncColumnChildren(sections);
      if (mounted) setState(() { _subPage = page; _subPageSections = sections; });
    } catch (_) {
      if (mounted) setState(() { _subPage = null; _subPageSections = []; });
    }
  }

  Future<void> _load() async {
    final api = CommunitiesApi(ref.read(apiClientProvider));
    final pagesApi = PagesApi(ref.read(apiClientProvider));
    try {
      final community = await api.getBySlug(widget.slug);
      final pages = await api.getPages(community.id);
      api.recordView(community.id);
      final userId = ref.read(authProvider).user?.id;

      List<pm.Section> mainSections = [];
      int? mainPageId;
      final mainPage = pages.cast<PageSummary?>().firstWhere(
        (p) => p!.pageType == 'main', orElse: () => null,
      );
      if (mainPage != null) {
        mainPageId = mainPage.id;
        try {
          mainSections = await pagesApi.listSections(mainPage.id);
          mainSections.sort((a, b) => a.order.compareTo(b.order));
          _syncColumnChildren(mainSections);
        } catch (_) {}
      }

      pm.Page? subPage;
      List<pm.Section> subPageSections = [];
      if (widget.pageId != null && widget.pageId != mainPageId) {
        try {
          subPage = await pagesApi.get(widget.pageId!);
          subPageSections = await pagesApi.listSections(widget.pageId!);
          pagesApi.recordView(widget.pageId!);
          subPageSections.sort((a, b) => a.order.compareTo(b.order));
          _syncColumnChildren(subPageSections);
        } catch (_) {}
      }

      // If the community has no top-level avatar/banner, fall back to what
      // the community-header section stores — that is where the page editor
      // saves them, and we want all sidebar/list renderers to see a single
      // effective value.
      Community resolvedCommunity = community;
      if ((community.avatarUrl ?? '').isEmpty || (community.settings['banner_url'] as String?)?.isNotEmpty != true) {
        final header = mainSections.where((s) => s.sectionType == 'community-header').cast<pm.Section?>().firstWhere((_) => true, orElse: () => null);
        if (header != null) {
          String? newAvatar = community.avatarUrl;
          Map<String, dynamic>? newSettings;
          if ((newAvatar ?? '').isEmpty) {
            final sa = header.data['avatar_url'] as String?;
            if (sa?.isNotEmpty == true) newAvatar = sa;
          }
          final sb = header.data['banner_url'] as String?;
          if ((community.settings['banner_url'] as String?)?.isNotEmpty != true && sb?.isNotEmpty == true) {
            newSettings = {...community.settings, 'banner_url': sb};
          }
          if (newAvatar != community.avatarUrl || newSettings != null) {
            resolvedCommunity = community.copyWith(avatarUrl: newAvatar, settings: newSettings);
          }
        }
      }

      final isOwner = userId != null && resolvedCommunity.ownerId == userId;

      // Resolve current user's membership role/permissions (for staff/moderation access).
      bool isStaff = isOwner;
      bool canManageMembers = isOwner;
      bool isMember = isOwner;
      if (!isOwner && userId != null) {
        try {
          final membersApi = MembersApi(ref.read(apiClientProvider));
          final allMembers = await membersApi.list(resolvedCommunity.id, limit: 200);
          final me = allMembers.where((m) => m.userId == userId).cast<Member?>().firstWhere((_) => true, orElse: () => null);
          if (me != null) {
            isMember = true;
            if (me.role == 'moderator' || me.role == 'owner') isStaff = true;
            if (me.permissions.contains('manage_members')) canManageMembers = true;
          }
        } catch (_) {}
      }

      // Enrich with counts (like web: client-side calculation)
      final pageCount = pages.where((p) => p.pageType != 'main' && p.pageType != 'chat').length;
      int memberCount = 0;
      try {
        final membersApi = MembersApi(ref.read(apiClientProvider));
        final allMembers = await membersApi.list(resolvedCommunity.id, limit: 999);
        memberCount = allMembers.length;
      } catch (_) {}
      resolvedCommunity = resolvedCommunity.copyWith(memberCount: memberCount, pageCount: pageCount);

      // Update shell header with community info
      ref.read(shellCommunityProvider.notifier).state = ShellCommunity(
        slug: resolvedCommunity.slug,
        name: resolvedCommunity.name,
        color: _getCommunityColor(resolvedCommunity),
      );

      // Subscribe to voice pages for live roster updates in sidebar/badge.
      final voicePageIds = pages.where((p) => p.pageType == 'voice').map((p) => p.id).toList();
      if (voicePageIds.isNotEmpty) {
        ref.read(voiceSessionProvider.notifier).subscribePages(voicePageIds);
      }

      if (mounted) {
        setState(() {
          _community = resolvedCommunity;
          _pages = pages;
          _mainPageSections = mainSections;
          _mainPageId = mainPageId;
          _subPage = subPage;
          _subPageSections = subPageSections;
          _loading = false;
          _isOwner = isOwner;
          _isStaff = isStaff;
          _canManageMembers = canManageMembers;
          _isMember = isMember;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = AppLocalizations.of(context)!.communityLoadFailed; _loading = false; });
    }
  }

  static void _syncColumnChildren(List<pm.Section> sections) {
    final allById = {for (final s in sections) s.id: s};
    for (final s in sections) {
      if (s.sectionType == 'columns') {
        final cols = s.data['columns'] as List<dynamic>? ?? [];
        for (final col in cols) {
          if (col is Map<String, dynamic>) {
            final sectionId = col['section_id'] as int?;
            if (sectionId != null && allById.containsKey(sectionId)) {
              final real = allById[sectionId]!;
              final realConfig = Map<String, dynamic>.from(real.config);
              realConfig.remove('_column_child');
              col['config'] = realConfig;
              if (real.data.isNotEmpty) col['data'] = Map<String, dynamic>.from(real.data);
              col['section_type'] = real.sectionType;
            }
          }
        }
      }
    }
  }

  Future<void> _joinCommunity() async {
    final api = CommunitiesApi(ref.read(apiClientProvider));
    try {
      await api.joinPublic(_community!.id);
      setState(() => _isMember = true);
    } catch (_) {}
  }

  Future<void> _leaveCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покинуть сообщество?'),
        content: const Text('Вы сможете вступить снова, если сообщество публичное.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Покинуть'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = CommunitiesApi(ref.read(apiClientProvider));
    try {
      await api.leave(_community!.id);
      setState(() => _isMember = false);
    } catch (_) {}
  }

  void _reportCommunity() {
    if (_community == null) return;
    showReportDialog(
      context: context,
      ref: ref,
      targetType: 'community',
      targetId: _community!.id,
      targetPreview: _community!.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final auth = ref.watch(authProvider);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }

    if (_error != null || _community == null) {
      final l = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.textSecondary),
            const SizedBox(height: 16),
            Text(_error ?? l.communityNotFound, style: TextStyle(color: c.textSecondary, fontSize: 16)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.goNamed('main'),
              child: Text(l.communityBackToMain, style: TextStyle(color: c.accent)),
            ),
          ],
        ),
      );
    }

    final comm = _community!;
    final commColor = _getCommunityColor(comm);

    final Widget content = _activeView == 'moderation'
        ? ModerationPanel(communityId: comm.id, pages: _pages, c: c, canManageMembers: _canManageMembers)
        : _activeView == 'feedback'
            ? FeedbackPanel(communityId: comm.id, pages: _pages, c: c)
            : _activeView == 'settings'
                ? SettingsPanel(community: comm, c: c, onUpdated: (u) => setState(() => _community = u))
                : _CommunityContent(
                comm: comm, pages: _pages, c: c, slug: widget.slug,
                commColor: commColor, isMember: _isMember, isOwner: _isOwner,
                isStaff: _isStaff,
                onJoin: _joinCommunity, onLeave: _leaveCommunity, onReport: _reportCommunity,
                auth: auth, sections: _mainPageSections, mainPageId: _mainPageId,
                subPage: _subPage, subPageSections: _subPageSections,
              );

    return CommunityNavigation(
      onPageSelect: (id) => _selectPage(id),
      child: Consumer(builder: (ctx, ref, _) {
        final voiceFs = ref.watch(voiceSessionProvider).isFullscreen;
        return Stack(
        children: [
          if (voiceFs && _subPage?.pageType == 'voice')
            Positioned.fill(
              child: VoiceRoomView(
                key: ValueKey('voice_fs_${_subPage!.id}'),
                pageId: _subPage!.id,
                pageTitle: _subPage!.title,
                communitySlug: widget.slug,
                c: c,
                commColor: commColor,
              ),
            )
          else
          Column(
            children: [
              Expanded(
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CommunitySidebar(
                              comm: comm, pages: _pages, c: c, slug: widget.slug,
                              commColor: commColor, selectedPageId: _selectedPageId,
                              isOwner: _isOwner, canCreatePages: _isOwner, isStaff: _isStaff, canManageMembers: _canManageMembers,
                              onPageSelect: _selectPage,
                              activeView: _activeView,
                              onViewSelect: _selectView,
                              isMember: _isMember,
                              onLeave: _leaveCommunity,
                              onReport: _reportCommunity,
                            ),
                            Expanded(child: Padding(
                              padding: const EdgeInsets.only(bottom: 12, right: 12),
                              child: content,
                            )),
                          ],
                        )
                      : content,
                ),
                if (!isDesktop)
                  _MobileBottomNav(c: c, commColor: commColor, slug: widget.slug, onMenuTap: () => setState(() => _sidebarOpen = !_sidebarOpen)),
              ],
            ),
            if (!voiceFs && !isDesktop && _sidebarOpen) ...[
              GestureDetector(
                onTap: () => setState(() => _sidebarOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
              Positioned(
                top: 0, left: 0, bottom: 56,
                child: _CommunitySidebar(
                  comm: comm, pages: _pages, c: c, slug: widget.slug,
                  commColor: commColor, selectedPageId: _selectedPageId,
                  isMobile: true, auth: auth,
                  isOwner: _isOwner, canCreatePages: _isOwner,
                  onClose: () => setState(() => _sidebarOpen = false),
                  onPageSelect: (id) { setState(() => _sidebarOpen = false); _selectPage(id); },
                  isMember: _isMember,
                  onLeave: _leaveCommunity,
                  onReport: _reportCommunity,
                ),
              ),
            ],
            // Floating call widget — visible when joined AND not already on that voice page.
            if (!voiceFs) Consumer(builder: (ctx, ref, _) {
              final vs = ref.watch(voiceSessionProvider);
              if (!vs.inCall) return const SizedBox.shrink();
              if (vs.joinedPageId == _currentPageId) return const SizedBox.shrink();
              return FloatingCallWidget(
                c: c, commColor: commColor,
                onExpand: () {
                  if (vs.joinedCommunitySlug != null && vs.joinedCommunitySlug != widget.slug) {
                    context.goNamed('page-view', pathParameters: {
                      'slug': vs.joinedCommunitySlug!,
                      'pageId': '${vs.joinedPageId}',
                    });
                  } else {
                    _selectPage(vs.joinedPageId);
                  }
                },
              );
            }),
          ],
        );
        }),
    );
  }

  Color _getCommunityColor(Community comm) {
    final hex = comm.settings['community_color'] as String?;
    if (hex != null && hex.isNotEmpty) {
      try {
        final clean = hex.replaceFirst('#', '');
        if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
    }
    return avatarColor(comm.id);
  }
}

// ─── HEADER ─────────────────────────────────────────────────────────

class _CommunityHeader extends StatelessWidget {
  final Community comm;
  final ColorSet c;
  final Color commColor;
  final AuthState auth;
  final WidgetRef ref;
  final VoidCallback? onMenuTap;
  final VoidCallback? onHomeTap;

  const _CommunityHeader({
    required this.comm, required this.c, required this.commColor,
    required this.auth, required this.ref, this.onMenuTap, this.onHomeTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16),
      child: Row(
        children: [
          if (!isDesktop && onMenuTap != null) ...[
            _HeaderIcon(icon: Icons.menu, c: c, onTap: onMenuTap!),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () => context.goNamed('main'),
            child: Text(l.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: commColor)),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 0,
            child: GestureDetector(
              onTap: onHomeTap ?? () => context.goNamed('community', pathParameters: {'slug': comm.slug}),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: commColor, borderRadius: BorderRadius.circular(6)),
                child: Text(comm.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Center(
                child: CommunitySearchField(communityId: comm.id, communitySlug: comm.slug, c: c),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 10),
          if (isDesktop) ...[
            _HeaderIcon(
              icon: ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              c: c, onTap: () => ref.read(themeProvider.notifier).toggle(),
            ),
            const SizedBox(width: 4),
          ],
          if (auth.isAuthenticated) ...[
            if (isDesktop) ...[
              _HeaderIcon(icon: Icons.mail_outlined, c: c, onTap: () => context.goNamed('messages')),
              const SizedBox(width: 4),
              NotificationsBell(iconColor: c.textSecondary, badgeColor: c.error, onTap: () => context.goNamed('notifications')),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: () => context.goNamed('profile'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: avatarColor(auth.user!.id),
                backgroundImage: auth.user!.avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(auth.user!.avatarUrl)) : null,
                child: auth.user!.avatarUrl.isEmpty
                    ? Text(auth.user!.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))
                    : null,
              ),
            ),
          ] else if (isDesktop) ...[
            TextButton(
              onPressed: () => context.goNamed('login'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(l.navLogin, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatefulWidget {
  final IconData icon;
  final ColorSet c;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.c, required this.onTap});
  @override State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _hovered ? widget.c.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 20, color: _hovered ? widget.c.text : widget.c.textSecondary),
        ),
      ),
    );
  }
}

// ─── SIDEBAR ────────────────────────────────────────────────────────

class _CommunitySidebar extends StatefulWidget {
  final Community comm;
  final List<PageSummary> pages;
  final ColorSet c;
  final String slug;
  final Color commColor;
  final String? selectedPageId;
  final bool isMobile;
  final AuthState? auth;
  final VoidCallback? onClose;
  final bool isOwner;
  final bool isStaff;
  final bool canManageMembers;
  final bool canCreatePages;
  final void Function(int? pageId)? onPageSelect;
  final String activeView;
  final void Function(String view)? onViewSelect;
  final bool isMember;
  final VoidCallback? onLeave;
  final VoidCallback? onReport;

  const _CommunitySidebar({
    required this.comm, required this.pages, required this.c,
    required this.slug, required this.commColor,
    this.selectedPageId, this.isMobile = false, this.auth, this.onClose,
    this.isOwner = false, this.isStaff = false, this.canManageMembers = false,
    this.canCreatePages = false, this.onPageSelect,
    this.activeView = 'page', this.onViewSelect,
    this.isMember = false, this.onLeave, this.onReport,
  });

  @override
  State<_CommunitySidebar> createState() => _CommunitySidebarState();
}

class _CommunitySidebarState extends State<_CommunitySidebar> {
  bool _pagesExpanded = true;
  bool _chatsExpanded = true;
  bool _voiceExpanded = true;
  bool _favoritesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final comm = widget.comm;
    final color = widget.commColor;
    final l = AppLocalizations.of(context)!;

    final chatPages = widget.pages.where((p) => p.pageType == 'chat').toList();
    final voicePages = widget.pages.where((p) => p.pageType == 'voice').toList();
    final otherPages = widget.pages.where((p) => p.pageType != 'chat' && p.pageType != 'voice' && p.pageType != 'main').toList();

    final sidebarContent = Column(
      children: [
        if (widget.isMobile && widget.auth != null) _buildMobileUserSection(l),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.surface, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: comm.avatarUrl?.isNotEmpty == true
                    ? Image.network(fullImageUrl(comm.avatarUrl!), width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 112, cacheHeight: 112)
                    : Text(comm.initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 10),
              Text(comm.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 12, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text('${comm.memberCount}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                  Text(' ${l.members}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Home
              _SidebarNavItem(
                icon: Icons.home_outlined, label: l.communityHome,
                active: widget.activeView == 'page' && widget.selectedPageId == null,
                c: c, onTap: () => widget.onPageSelect?.call(null),
              ),

              // Chats
              if (chatPages.length == 1) ...[
                const SizedBox(height: 2),
                _SidebarNavItem(
                  icon: Icons.chat_outlined, label: chatPages.first.title, c: c,
                  active: widget.activeView == 'page' && widget.selectedPageId == '${chatPages.first.id}',
                  opacity: chatPages.first.visibility != null && chatPages.first.visibility != 'public' ? 0.6 : 1.0,
                  trailing: _buildChatTrailing(chatPages.first, c),
                  onTap: () => widget.onPageSelect?.call(chatPages.first.id),
                ),
              ] else if (chatPages.length > 1) ...[
                const SizedBox(height: 4),
                _SidebarGroup(label: l.navChat, icon: Icons.chat_outlined, expanded: _chatsExpanded, onToggle: () => setState(() => _chatsExpanded = !_chatsExpanded), c: c),
                if (_chatsExpanded)
                  ...chatPages.map((p) => _SidebarNavItem(
                    icon: Icons.tag, label: p.title, c: c, indent: true,
                    active: widget.activeView == 'page' && widget.selectedPageId == '${p.id}',
                    opacity: p.visibility != null && p.visibility != 'public' ? 0.6 : 1.0,
                    trailing: _buildChatTrailing(p, c),
                    onTap: () => widget.onPageSelect?.call(p.id),
                  )),
              ],

              // Voice channels
              if (voicePages.isNotEmpty) ...[
                const SizedBox(height: 4),
                _SidebarGroup(label: l.communityVoice, icon: Icons.mic_outlined, expanded: _voiceExpanded, onToggle: () => setState(() => _voiceExpanded = !_voiceExpanded), c: c),
                if (_voiceExpanded)
                  ...voicePages.map((p) => _SidebarNavItem(
                    icon: Icons.volume_up_outlined, label: p.title, c: c, indent: true,
                    active: widget.activeView == 'page' && widget.selectedPageId == '${p.id}',
                    trailing: Consumer(builder: (ctx, ref, _) {
                      final count = ref.watch(voiceSessionProvider.select((vs) => vs.membersOn(p.id).length));
                      return _VoiceCountBadge(count: count, cap: 8, c: c);
                    }),
                    onTap: () => widget.onPageSelect?.call(p.id),
                  )),
              ],

              // Pages (respects show_pages_in_sidebar setting)
              if (otherPages.isNotEmpty && widget.comm.settings['show_pages_in_sidebar'] == true) ...[
                const SizedBox(height: 4),
                _SidebarGroup(label: l.pagesTitle, icon: Icons.article_outlined, expanded: _pagesExpanded, onToggle: () => setState(() => _pagesExpanded = !_pagesExpanded), c: c),
                if (_pagesExpanded)
                  ...otherPages.map((p) => _SidebarNavItem(
                    icon: _pageIcon(p.pageType), label: p.title, c: c, indent: true,
                    active: widget.activeView == 'page' && widget.selectedPageId == '${p.id}',
                    onTap: () => widget.onPageSelect?.call(p.id),
                  )),
              ],

              // Favorites
              const SizedBox(height: 4),
              _SidebarGroup(label: l.communityFavorites, icon: Icons.star_outline, expanded: _favoritesExpanded, onToggle: () => setState(() => _favoritesExpanded = !_favoritesExpanded), c: c),
              if (_favoritesExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 52, right: 20, top: 4, bottom: 8),
                  child: Text(l.communityNoPages, style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
                ),

              // Divider before actions
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: c.border),
              ),

              // Create page
              if (widget.canCreatePages)
                _SidebarNavItem(
                  icon: Icons.add_circle_outline, label: l.createCommunityButton, c: c,
                  onTap: () {
                    widget.onClose?.call();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке'), duration: Duration(seconds: 2)));
                  },
                ),

              // Settings (owner or manage_members)
              if (widget.isOwner || widget.canManageMembers)
                _SidebarNavItem(
                  icon: Icons.settings_outlined, label: l.communitySettings, c: c,
                  active: widget.activeView == 'settings',
                  onTap: () {
                    widget.onClose?.call();
                    widget.onViewSelect?.call('settings');
                  },
                ),

              // Moderation (owner or any staff) vs Feedback (regular members)
              if (widget.isOwner || widget.isStaff)
                _SidebarNavItem(
                  icon: Icons.shield_outlined, label: 'Модерация', c: c,
                  active: widget.activeView == 'moderation',
                  onTap: () {
                    widget.onClose?.call();
                    widget.onViewSelect?.call('moderation');
                  },
                )
              else
                _SidebarNavItem(
                  icon: Icons.rate_review_outlined, label: 'Обратная связь', c: c,
                  active: widget.activeView == 'feedback',
                  onTap: () {
                    widget.onClose?.call();
                    widget.onViewSelect?.call('feedback');
                  },
                ),

              if (!widget.isOwner && (widget.onLeave != null || widget.onReport != null)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: c.border),
                ),
                if (widget.isMember && widget.onLeave != null)
                  _SidebarNavItem(
                    icon: Icons.logout, label: l.communityLeave, c: c,
                    color: c.error,
                    onTap: () {
                      widget.onClose?.call();
                      widget.onLeave!();
                    },
                  ),
                if (widget.onReport != null)
                  _SidebarNavItem(
                    icon: Icons.flag_outlined, label: l.communityReport, c: c,
                    color: c.error,
                    onTap: () {
                      widget.onClose?.call();
                      widget.onReport!();
                    },
                  ),
              ],
            ],
          ),
        ),
        if (widget.isMobile) _buildMobileFooter(l),
      ],
    );

    return _wrapSidebar(sidebarContent, c);
  }

  Widget _wrapSidebar(Widget content, ColorSet c) {
    if (widget.isMobile) {
      return Container(width: 260, color: c.surface, child: content);
    }
    return Container(
      width: 220,
      margin: const EdgeInsets.only(left: 12, top: 12, bottom: 12, right: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surfaceAlt.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      ),
    );
  }

  Widget? _buildChatTrailing(PageSummary p, ColorSet c) {
    final widgets = <Widget>[];
    if (p.visibility == 'moderators') {
      widgets.add(Icon(Icons.shield_outlined, size: 12, color: c.warning.withValues(alpha: 0.7)));
    } else if (p.visibility == 'owner') {
      widgets.add(Icon(Icons.lock_outlined, size: 12, color: c.error.withValues(alpha: 0.7)));
    }
    if (widgets.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Widget _buildMobileUserSection(AppLocalizations l) {
    final c = widget.c;
    final auth = widget.auth!;
    if (!auth.isAuthenticated) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { widget.onClose?.call(); GoRouter.of(context).goNamed('login'); },
                style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.textOnAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text(l.navLogin),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () { widget.onClose?.call(); GoRouter.of(context).goNamed('register'); },
                style: OutlinedButton.styleFrom(side: BorderSide(color: c.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text(l.navRegister, style: TextStyle(color: c.text)),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor(auth.user!.id),
            backgroundImage: auth.user!.avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(auth.user!.avatarUrl)) : null,
            child: auth.user!.avatarUrl.isEmpty
                ? Text(auth.user!.initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(auth.user!.effectiveName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          TextButton(
            onPressed: () { widget.onClose?.call(); GoRouter.of(context).goNamed('profile'); },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              side: BorderSide(color: c.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l.navProfile, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFooter(AppLocalizations l) {
    final c = widget.c;
    return Consumer(builder: (context, ref, _) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: Row(
          children: [
            _MobileFooterButton(
              icon: ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              label: ref.watch(themeProvider) == ThemeMode.dark ? l.themeLight : l.themeDark,
              c: c, onTap: () => ref.read(themeProvider.notifier).toggle(),
            ),
          ],
        ),
      );
    });
  }

  IconData _pageIcon(String type) => switch (type) {
    'wiki' => Icons.article_outlined,
    'faq' => Icons.help_outline,
    'calendar' => Icons.calendar_month_outlined,
    'booking' => Icons.event_available_outlined,
    'announcements' => Icons.campaign_outlined,
    'polls' => Icons.poll_outlined,
    'quiz' => Icons.quiz_outlined,
    _ => Icons.description_outlined,
  };
}

class _MobileFooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorSet c;
  final VoidCallback onTap;
  const _MobileFooterButton({required this.icon, required this.label, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c.textSecondary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── SIDEBAR SUB-WIDGETS ────────────────────────────────────────────

class _SidebarGroup extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final ColorSet c;
  const _SidebarGroup({required this.label, required this.icon, required this.expanded, required this.onToggle, required this.c});
  @override State<_SidebarGroup> createState() => _SidebarGroupState();
}

class _SidebarGroupState extends State<_SidebarGroup> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: _hovered ? c.hoverOverlay : Colors.transparent,
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: c.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.5))),
              AnimatedRotation(
                turns: widget.expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.chevron_right, size: 14, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool indent;
  final ColorSet c;
  final VoidCallback onTap;
  final Widget? trailing;
  final double opacity;
  final Color? color;
  const _SidebarNavItem({required this.icon, required this.label, this.active = false, this.indent = false, required this.c, required this.onTap, this.trailing, this.opacity = 1.0, this.color});
  @override State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: widget.opacity,
          child: Container(
            padding: EdgeInsets.only(left: widget.indent ? 52 : 20, right: 20, top: widget.indent ? 4 : 10, bottom: widget.indent ? 4 : 10),
            color: widget.active ? c.activeOverlay : (_hovered ? c.hoverOverlay : Colors.transparent),
            child: Row(
              children: [
                if (!widget.indent) ...[
                  Icon(widget.icon, size: 20, color: widget.color ?? (widget.active ? c.text : c.textSecondary)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.indent ? 13.5 : 14,
                      color: widget.color ?? (widget.active ? c.text : c.textSecondary),
                      fontWeight: widget.active ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceCountBadge extends StatelessWidget {
  final int count;
  final int cap;
  final ColorSet c;
  const _VoiceCountBadge({required this.count, required this.cap, required this.c});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    if (count == 0) {
      bgColor = c.hoverOverlay;
      textColor = c.textSecondary;
    } else if (count >= cap) {
      bgColor = c.warning.withValues(alpha: 0.15);
      textColor = c.warning;
    } else {
      bgColor = c.success.withValues(alpha: 0.15);
      textColor = c.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Text('$count/$cap', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}

// ─── MOBILE BOTTOM NAV ──────────────────────────────────────────────

class _MobileBottomNav extends StatelessWidget {
  final ColorSet c;
  final Color commColor;
  final String slug;
  final VoidCallback onMenuTap;
  const _MobileBottomNav({required this.c, required this.commColor, required this.slug, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          _BottomNavTab(icon: Icons.home_outlined, label: l.communityHome, active: true, c: c, commColor: commColor, onTap: () => context.goNamed('community', pathParameters: {'slug': slug})),
          _BottomNavTab(icon: Icons.search, label: l.heroSearch.replaceAll('...', ''), c: c, commColor: commColor, onTap: () {}),
          _BottomNavTab(icon: Icons.chat_outlined, label: l.navChat, c: c, commColor: commColor, onTap: () {}),
          _BottomNavTab(icon: Icons.menu, label: l.navMenu, c: c, commColor: commColor, onTap: onMenuTap),
        ],
      ),
    );
  }
}

class _BottomNavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final ColorSet c;
  final Color commColor;
  final VoidCallback onTap;
  const _BottomNavTab({required this.icon, required this.label, this.active = false, required this.c, required this.commColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: active ? commColor : c.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: active ? commColor : c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── SECTION DISPATCHER ─────────────────────────────────────────────

class _SectionDispatchContext {
  final Community comm;
  final List<PageSummary> pages;
  final ColorSet c;
  final String slug;
  final Color commColor;
  final bool isMember;
  final bool isOwner;
  final bool isStaff;
  final AuthState auth;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onReport;

  const _SectionDispatchContext({
    required this.comm, required this.pages, required this.c, required this.slug,
    required this.commColor, required this.isMember, required this.isOwner,
    this.isStaff = false,
    required this.auth, required this.onJoin, required this.onLeave, required this.onReport,
  });

  Widget dispatch(String sectionType, Map<String, dynamic> config, Map<String, dynamic> data, bool isMobile, {int? sectionId}) {
    if (sectionType == 'community-header') {
      return _CommunityInfoBanner(
        comm: comm, c: c, commColor: commColor, isMobile: isMobile,
        isMember: isMember, isOwner: isOwner, auth: auth,
        onJoin: onJoin, onLeave: onLeave, onReport: onReport, sectionData: data,
      );
    }
    return SectionRenderer(
      section: pm.Section(
        id: sectionId ?? 0,
        pageId: 0,
        sectionType: sectionType,
        config: config,
        data: data,
      ),
      pages: pages,
      communitySlug: slug,
      communityColor: commColor,
      communityId: comm.id,
      isStaff: isStaff,
    );
  }
}

// ─── MAIN CONTENT ───────────────────────────────────────────────────

class _CommunityContent extends StatelessWidget {
  final Community comm;
  final List<PageSummary> pages;
  final List<pm.Section> sections;
  final int? mainPageId;
  final ColorSet c;
  final String slug;
  final Color commColor;
  final bool isMember;
  final bool isOwner;
  final bool isStaff;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onReport;
  final AuthState auth;
  final pm.Page? subPage;
  final List<pm.Section> subPageSections;

  const _CommunityContent({
    required this.comm, required this.pages, required this.c, required this.slug,
    required this.commColor, required this.isMember, required this.isOwner,
    this.isStaff = false,
    required this.onJoin, required this.onLeave, required this.onReport, required this.auth,
    required this.sections, this.mainPageId,
    this.subPage, this.subPageSections = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (subPage != null) return _buildSubPage(context);
    return _buildMainPage(context);
  }

  Widget _buildMainPage(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final l = AppLocalizations.of(context)!;

    final visibleSections = sections
        .where((s) => s.config['_column_child'] != true)
        .toList();

    final ctx = _SectionDispatchContext(
      comm: comm, pages: pages, c: c, slug: slug, commColor: commColor,
      isMember: isMember, isOwner: isOwner, isStaff: isStaff, auth: auth,
      onJoin: onJoin, onLeave: onLeave, onReport: onReport,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 0,
        16,
        isMobile ? 16 : 32,
        isMobile ? 76 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visibleSections.isNotEmpty)
            ...visibleSections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ctx.dispatch(section.sectionType, section.config, section.data, isMobile, sectionId: section.id),
            ))
          else ...[
            _CommunityInfoBanner(
              comm: comm, c: c, commColor: commColor, isMobile: isMobile,
              isMember: isMember, isOwner: isOwner, auth: auth,
              onJoin: onJoin, onLeave: onLeave, onReport: onReport,
            ),
            const SizedBox(height: 24),
            SectionRenderer(
              section: pm.Section(id: 0, pageId: 0, sectionType: 'navigation', config: const {}, data: const {}),
              pages: pages,
              communitySlug: slug,
              communityColor: commColor,
            ),
          ],
          if (isOwner && mainPageId != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: _EditHomeButton(c: c, commColor: commColor, slug: slug, l: l, pageId: mainPageId!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubPage(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final page = subPage!;

    if (page.pageType == 'voice') {
      final hPad = isMobile ? 16.0 : 32.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _SubPageTitle(page: page, c: c, commColor: commColor, slug: slug, isOwner: isOwner),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: VoiceRoomView(
                key: ValueKey('voice_room_${page.id}'),
                pageId: page.id,
                pageTitle: page.title,
                communitySlug: slug,
                c: c,
                commColor: commColor,
              ),
            ),
          ),
        ],
      );
    }

    final visibleSections = subPageSections
        .where((s) => s.config['_column_child'] != true && s.sectionType != 'script')
        .toList();
    final scriptSections = subPageSections
        .where((s) => s.sectionType == 'script')
        .toList();

    final isChatPage = page.pageType == 'chat';

    if (isChatPage && visibleSections.isNotEmpty) {
      final hPad = isMobile ? 16.0 : 32.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _SubPageTitle(page: page, c: c, commColor: commColor, slug: slug, isOwner: isOwner),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: SectionRenderer(
                section: visibleSections.first,
                pages: pages,
                communitySlug: slug,
                communityColor: commColor,
                communityId: comm.id,
                isStaff: isStaff,
              ),
            ),
          ),
        ],
      );
    }

    final contentWidth = page.layoutConfig?['content_width'] as int?;
    final contentMaxWidth = (contentWidth != null && contentWidth >= 40 && contentWidth < 100)
        ? MediaQuery.of(context).size.width * contentWidth / 100
        : double.infinity;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 0, 0,
        isMobile ? 16 : 32,
        isMobile ? 76 : 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SubPageTitle(page: page, c: c, commColor: commColor, slug: slug, isOwner: isOwner),
              const SizedBox(height: 20),
              if (visibleSections.isEmpty)
                Text('Нет секций', style: TextStyle(fontSize: 14, color: c.textSecondary))
              else
                ...visibleSections.map((section) {
                  final sectionWidth = section.config['width'] as String?;
                  Widget child = SectionRenderer(
                    section: section,
                    pages: pages,
                    communitySlug: slug,
                    communityColor: commColor,
                    communityId: comm.id,
                    isStaff: isStaff,
                  );
                  if (sectionWidth != null && sectionWidth.isNotEmpty) {
                    double maxW;
                    if (sectionWidth.endsWith('%')) {
                      final pct = double.tryParse(sectionWidth.replaceAll('%', ''));
                      maxW = (pct != null && pct > 0 && pct <= 100)
                          ? contentMaxWidth * pct / 100
                          : double.infinity;
                    } else {
                      maxW = double.tryParse(sectionWidth.replaceAll('px', '')) ?? double.infinity;
                    }
                    child = Center(child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: child,
                    ));
                  }
                  return Padding(padding: const EdgeInsets.only(bottom: 16), child: child);
                }),
              if (scriptSections.isNotEmpty) ...[
                Divider(color: c.border),
                const SizedBox(height: 12),
                ...scriptSections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SectionRenderer(
                    section: section,
                    pages: pages,
                    communitySlug: slug,
                    communityColor: commColor,
                    communityId: comm.id,
                  ),
                )),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubPageTitle extends StatelessWidget {
  final pm.Page page;
  final ColorSet c;
  final Color commColor;
  final String slug;
  final bool isOwner;
  const _SubPageTitle({required this.page, required this.c, required this.commColor, required this.slug, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(page.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text)),
              ),
              if (isOwner)
                GestureDetector(
                  onTap: () => context.goNamed('page-edit', pathParameters: {'slug': slug, 'pageId': '${page.id}'}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: c.textSecondary),
                        const SizedBox(width: 6),
                        Text('Редактировать', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditHomeButton extends StatefulWidget {
  final ColorSet c;
  final Color commColor;
  final String slug;
  final AppLocalizations l;
  final int pageId;
  const _EditHomeButton({required this.c, required this.commColor, required this.slug, required this.l, required this.pageId});
  @override State<_EditHomeButton> createState() => _EditHomeButtonState();
}

class _EditHomeButtonState extends State<_EditHomeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.goNamed('page-edit', pathParameters: {'slug': widget.slug, 'pageId': '${widget.pageId}'}),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? widget.commColor.withValues(alpha: 0.12) : widget.c.surface,
            border: Border.all(color: _hovered ? widget.commColor : widget.c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 14, color: _hovered ? widget.commColor : widget.c.textSecondary),
              const SizedBox(width: 6),
              Text(widget.l.communityEditHomePage, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _hovered ? widget.commColor : widget.c.text)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── INFO BANNER ────────────────────────────────────────────────────

class _CommunityInfoBanner extends StatelessWidget {
  final Community comm;
  final ColorSet c;
  final Color commColor;
  final bool isMobile;
  final bool isMember;
  final bool isOwner;
  final AuthState auth;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onReport;
  final Map<String, dynamic>? sectionData;

  const _CommunityInfoBanner({
    required this.comm, required this.c, required this.commColor,
    required this.isMobile, required this.isMember, required this.isOwner,
    required this.auth, required this.onJoin, required this.onLeave, required this.onReport,
    this.sectionData,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sd = sectionData ?? {};
    final avatarSize = isMobile ? 56.0 : 72.0;
    final cfgBannerHeight = sd['banner_height'] as int? ?? comm.settings['banner_height'] as int? ?? (isMobile ? 160 : 220);
    final bannerHeight = cfgBannerHeight.toDouble();
    final avatarRadius = isMobile ? 12.0 : 14.0;
    final bannerUrl = sd['banner_url'] as String? ?? comm.settings['banner_url'] as String?;
    final hasBanner = bannerUrl != null && bannerUrl.isNotEmpty;
    final bannerOffsetX = (sd['banner_offset_x'] as int? ?? comm.settings['banner_offset_x'] as int? ?? 50) / 100.0;
    final bannerOffsetY = (sd['banner_offset_y'] as int? ?? comm.settings['banner_offset_y'] as int? ?? 50) / 100.0;
    final bannerZoom = (sd['banner_zoom'] as int? ?? comm.settings['banner_zoom'] as int? ?? 100) / 100.0;
    final avatarUrl = sd['avatar_url'] as String? ?? comm.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final description = sd['description'] as String? ?? comm.description;

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
          // Banner
          SizedBox(
            height: bannerHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBanner)
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
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [commColor, c.surfaceAlt],
                      ),
                    ),
                  ),
                // Scrim
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: const Alignment(0.6, 0.6),
                      colors: [commColor.withValues(alpha: 0.12), Colors.transparent],
                    ),
                  ),
                ),
                // Bottom gradient
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
          // Info section
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 0, isMobile ? 16 : 24, isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: Offset(0, -avatarSize * 0.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Avatar
                      Container(
                        width: avatarSize, height: avatarSize,
                        decoration: BoxDecoration(
                          color: commColor,
                          borderRadius: BorderRadius.circular(avatarRadius),
                          border: Border.all(color: c.surface, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        child: hasAvatar
                            ? Image.network(fullImageUrl(avatarUrl), width: avatarSize, height: avatarSize, fit: BoxFit.cover)
                            : Text(comm.initial, style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const Spacer(),
                      if (auth.isAuthenticated) _buildActionButton(l),
                      if (auth.isAuthenticated && !isOwner) ...[
                        const SizedBox(width: 8),
                        _buildKebabMenu(l),
                      ],
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -avatarSize * 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comm.name,
                        style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w700, color: c.text),
                      ),
                      const SizedBox(height: 6),
                      // Meta row
                      Wrap(
                        spacing: 14, runSpacing: 6,
                        children: [
                          _MetaItem(icon: Icons.people_outline, value: '${comm.memberCount}', label: l.members, c: c),
                          _MetaItem(icon: Icons.article_outlined, value: '${comm.pageCount}', label: l.pages, c: c),
                          if (comm.categorySlug != null)
                            _CategoryTag(label: comm.categorySlug!, commColor: commColor),
                          ..._buildTags(),
                        ],
                      ),
                      if (description?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Text(description!, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.6)),
                        ),
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

  List<Widget> _buildTags() {
    final tags = comm.settings['tags'] as List<dynamic>? ?? [];
    return tags.map<Widget>((t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text('$t', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text)),
    )).toList();
  }

  Widget _buildActionButton(AppLocalizations l) {
    if (isOwner) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: c.success),
          const SizedBox(width: 4),
          Text(l.communityOwner, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.success)),
        ],
      );
    }
    if (isMember) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: c.success),
                const SizedBox(width: 4),
                Text(l.communityMember, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.success)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLeave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l.communityLeave, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: commColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(l.communityJoin, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildKebabMenu(AppLocalizations l) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 20, color: c.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(const Size(28, 28)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: c.surface,
      onSelected: (v) {
        if (v == 'report') onReport();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: c.error),
              const SizedBox(width: 10),
              Text(l.communityReport, style: TextStyle(fontSize: 14, color: c.error)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final Color commColor;
  const _CategoryTag({required this.label, required this.commColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: commColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: commColor.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: commColor.withValues(alpha: 0.9))),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorSet c;
  const _MetaItem({required this.icon, required this.value, required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 14, color: c.textSecondary)),
      ],
    );
  }
}
