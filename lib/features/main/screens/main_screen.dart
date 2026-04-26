import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/favorites.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/api/categories_api.dart';
import '../../../data/api/notifications_api.dart';
import '../../../data/models/community.dart';
import '../../../core/utils/time_ago.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../notifications/widgets/notifications_bell.dart';
import '../../billing/widgets/upgrade_modal.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  List<Community> _popular = [];
  List<Category> _categories = [];
  List<Community> _myCommunities = [];
  List<RecentVisit> _recentVisits = [];
  List<AppNotification> _notifications = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = CommunitiesApi(ref.read(apiClientProvider));
    final catApi = CategoriesApi(ref.read(apiClientProvider));
    final isAuthed = ref.read(authProvider).isAuthenticated;
    try {
      final futures = <Future>[
        api.popular(limit: 6),
        catApi.list(),
      ];
      if (isAuthed) {
        futures.add(api.listForMe());
        futures.add(api.recentVisits(limit: 10));
        futures.add(NotificationsApi(ref.read(apiClientProvider)).list(limit: 20));
      }
      final results = await Future.wait(futures);
      final popularRaw = results[0] as List<Community>;
      final enriched = await api.enrichListWithCounts(popularRaw);
      if (mounted) {
        setState(() {
          _popular = enriched;
          _categories = results[1] as List<Category>;
          if (isAuthed && results.length > 2) {
            _myCommunities = results[2] as List<Community>;
            _recentVisits = results[3] as List<RecentVisit>;
            _notifications = results[4] as List<AppNotification>;
          }
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    if (auth.isRestoringSession || (auth.isAuthenticated && !_loaded)) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }

    final showAuthed = auth.isAuthenticated && _myCommunities.isNotEmpty;

    if (showAuthed) {
      return _AuthedHome(
        auth: auth, c: c, theme: theme,
        myCommunities: _myCommunities,
        recentVisits: _recentVisits,
        notifications: _notifications,
        popular: _popular,
        categories: _categories,
        loaded: _loaded,
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _HeroSection(theme: theme, c: c),
          if (_loaded && _popular.isNotEmpty)
            _PopularSection(communities: _popular, theme: theme, c: c),
          if (_loaded && _categories.isNotEmpty)
            _CategoriesSection(categories: _categories, theme: theme, c: c),
          _CtaSection(auth: auth, theme: theme, c: c),
          _FooterSection(theme: theme, c: c),
        ],
      ),
    );
  }
}

// ─── Authed Home ────────────────────────────────────────────────────

class _AuthedHome extends StatelessWidget {
  final AuthState auth;
  final ColorSet c;
  final ThemeData theme;
  final List<Community> myCommunities;
  final List<RecentVisit> recentVisits;
  final List<AppNotification> notifications;
  final List<Community> popular;
  final List<Category> categories;
  final bool loaded;

  const _AuthedHome({
    required this.auth, required this.c, required this.theme,
    required this.myCommunities, required this.recentVisits, required this.notifications,
    required this.popular, required this.categories,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = auth.user!;
    final ownedCount = myCommunities.where((c) => c.myRole == 'owner').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBar(user: user, ownedCount: ownedCount, isAdmin: user.isAdmin, isPro: user.isPro, c: c),
          const SizedBox(height: 28),

          LayoutBuilder(builder: (ctx, box) {
            if (box.maxWidth >= 768) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _MyCommunitiesBlock(communities: myCommunities, c: c)),
                    const SizedBox(width: 16),
                    Expanded(child: _FavoritesBlock(c: c, communities: myCommunities)),
                  ],
                ),
              );
            }
            return Column(children: [
              _MyCommunitiesBlock(communities: myCommunities, c: c),
              const SizedBox(height: 16),
              _FavoritesBlock(c: c, communities: myCommunities),
            ]);
          }),
          const SizedBox(height: 20),

          // ── Row 2: Recently visited ──
          if (recentVisits.isNotEmpty) ...[
            _RecentVisitsBlock(visits: recentVisits, c: c),
            const SizedBox(height: 20),
          ],

          // ── Row 3: Activity feed ──
          if (notifications.isNotEmpty) ...[
            _ActivityBlock(notifications: notifications, c: c, communities: myCommunities),
            const SizedBox(height: 20),
          ],

          if (loaded && categories.isNotEmpty)
            _CategoriesSection(categories: categories, theme: theme, c: c),

          if (loaded && popular.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PopularSection(communities: popular, theme: theme, c: c),
          ],
        ],
      ),
    );
  }
}

class _WelcomeBar extends StatelessWidget {
  final dynamic user;
  final int ownedCount;
  final bool isAdmin;
  final bool isPro;
  final ColorSet c;
  const _WelcomeBar({required this.user, required this.ownedCount, required this.isAdmin, required this.isPro, required this.c});

  String _weekday() {
    const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${_month(now.month)}';
  }
  String _month(int m) => const ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'][m - 1];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final displayName = user.displayName?.isNotEmpty == true ? user.displayName : user.username;
    final limit = isPro ? 10 : 3;
    final available = (limit - ownedCount).clamp(0, limit);
    final atLimit = !isAdmin && available == 0;

    String quotaText;
    if (isAdmin) {
      quotaText = '∞ админ';
    } else if (atLimit) {
      quotaText = 'лимит $limit';
    } else {
      quotaText = '$ownedCount из $limit';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(
                text: 'С возвращением, ',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.text),
                children: [
                  TextSpan(
                    text: displayName,
                    style: TextStyle(
                      foreground: Paint()..shader = LinearGradient(
                        colors: [c.accent, const Color(0xFF8B5CF6)],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 30)),
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 4),
              Text(_weekday(), style: TextStyle(fontSize: 14, color: c.textSecondary)),
            ],
          ),
        ),
        InkWell(
          onTap: atLimit
              ? () => showUpgradeModal(context, trigger: UpgradeTrigger.communityLimit, currentValue: ownedCount, limitValue: limit)
              : () => context.goNamed('create-community'),
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: atLimit ? 0.7 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: atLimit ? c.surface : const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: atLimit ? c.border : Colors.transparent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: atLimit ? c.textSecondary : Colors.white),
                  const SizedBox(width: 8),
                  Text('Создать сообщество', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: atLimit ? c.textSecondary : Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.only(left: 8),
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: atLimit ? c.border : Colors.white.withValues(alpha: 0.25)))),
                    child: Text(quotaText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: atLimit ? c.textSecondary.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyCommunitiesBlock extends StatelessWidget {
  final List<Community> communities;
  final ColorSet c;
  const _MyCommunitiesBlock({required this.communities, required this.c});

  @override
  Widget build(BuildContext context) {
    final visible = communities.take(5).toList();
    return _BlockCard(
      c: c,
      icon: Icons.people_outline,
      title: 'Мои сообщества · ${communities.length}',
      actionLabel: 'все →',
      onAction: () => context.goNamed('explore'),
      child: Column(
        children: visible.map((comm) => _CommunityRow(comm: comm, c: c)).toList(),
      ),
    );
  }
}

class _CommunityRow extends StatefulWidget {
  final Community comm;
  final ColorSet c;
  const _CommunityRow({required this.comm, required this.c});
  @override
  State<_CommunityRow> createState() => _CommunityRowState();
}

class _CommunityRowState extends State<_CommunityRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final comm = widget.comm;
    final c = widget.c;
    final color = avatarColor(comm.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.goNamed('community', pathParameters: {'slug': comm.slug}),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? c.accent.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  image: comm.avatarUrl?.isNotEmpty == true
                      ? DecorationImage(image: NetworkImage(fullImageUrl(comm.avatarUrl!)), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: comm.avatarUrl?.isNotEmpty != true
                    ? Text(comm.initial, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 10),
              // Name + role + views
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(comm.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (comm.myRole == 'owner') ...[
                      const SizedBox(width: 8),
                      _RoleBadge(label: 'Владелец', color: c.accent),
                    ] else if (comm.myRole == 'moderator') ...[
                      const SizedBox(width: 8),
                      _RoleBadge(label: 'Модер', color: c.warning),
                    ],
                    if (comm.views30d > 0) ...[
                      const SizedBox(width: 8),
                      Text('${comm.views30d} просм.', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              // Unread badge
              if (comm.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  height: 20,
                  decoration: BoxDecoration(
                    color: c.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('${comm.unreadCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.04)),
  );
}

class _FavoritesBlock extends StatefulWidget {
  final ColorSet c;
  final List<Community> communities;
  const _FavoritesBlock({required this.c, required this.communities});

  @override
  State<_FavoritesBlock> createState() => _FavoritesBlockState();
}

class _FavoritesBlockState extends State<_FavoritesBlock> {
  List<FavoriteItem> _favs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await FavoritesService.loadAll();
    final communityIds = widget.communities.map((c) => c.id).toSet();
    if (mounted) setState(() => _favs = all.where((f) => communityIds.contains(f.communityId)).take(5).toList());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final commById = {for (final cm in widget.communities) cm.id: cm};

    return _BlockCard(
      c: c,
      icon: Icons.star_outline,
      title: 'Избранное · ${_favs.length}',
      child: _favs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Нет избранных страниц', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            )
          : Column(
              children: _favs.map((fav) {
                final comm = commById[fav.communityId];
                final color = avatarColor(fav.communityId);
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      if (comm != null) {
                        context.goNamed('page-view', pathParameters: {'slug': comm.slug, 'pageId': '${fav.pageId}'});
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(14),
                              image: comm?.avatarUrl?.isNotEmpty == true
                                  ? DecorationImage(image: NetworkImage(fullImageUrl(comm!.avatarUrl!)), fit: BoxFit.cover)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: comm?.avatarUrl?.isNotEmpty != true
                                ? Text(comm?.initial ?? '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fav.pageTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(comm?.name ?? '', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                              ],
                            ),
                          ),
                          Icon(Icons.star, size: 14, color: c.warning),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ─── Recent Visits ──────────────────────────────────────────────────

class _RecentVisitsBlock extends StatelessWidget {
  final List<RecentVisit> visits;
  final ColorSet c;
  const _RecentVisitsBlock({required this.visits, required this.c});

  @override
  Widget build(BuildContext context) {
    return _BlockCard(
      c: c,
      icon: Icons.history,
      title: 'Недавно посещённое',
      child: LayoutBuilder(builder: (ctx, box) {
        final cardW = box.maxWidth < 600 ? box.maxWidth : ((box.maxWidth - 12 * 3) / 4).clamp(180.0, 260.0);
        return _HorizontalScrollable(
          child: Row(
            children: visits.asMap().entries.map((e) {
              final v = e.value;
              return Padding(
                padding: EdgeInsets.only(right: e.key < visits.length - 1 ? 12 : 0),
                child: _RecentCard(visit: v, c: c, width: cardW),
              );
            }).toList(),
          ),
        );
      }),
    );
  }
}

class _RecentCard extends StatefulWidget {
  final RecentVisit visit;
  final ColorSet c;
  final double width;
  const _RecentCard({required this.visit, required this.c, required this.width});
  @override
  State<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends State<_RecentCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final c = widget.c;
    final color = avatarColor(v.communityId);
    final title = (v.pageTitle?.isNotEmpty == true) ? v.pageTitle! : v.communityName;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (v.pageSlug != null && v.pageId != null) {
            context.goNamed('page-view', pathParameters: {'slug': v.communitySlug, 'pageId': '${v.pageId}'});
          } else {
            context.goNamed('community', pathParameters: {'slug': v.communitySlug});
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.85),
            border: Border.all(color: _hovered ? c.accent : c.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    image: v.communityAvatarUrl?.isNotEmpty == true
                        ? DecorationImage(image: NetworkImage(fullImageUrl(v.communityAvatarUrl!)), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: v.communityAvatarUrl?.isNotEmpty != true
                      ? Text(v.communityName.isNotEmpty ? v.communityName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(v.communityName.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.04),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                v.visitedAt.isNotEmpty ? timeAgo(DateTime.tryParse(v.visitedAt) ?? DateTime.now(), locale: 'ru') : '',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Activity Feed ──────────────────────────────────────────────────

class _ActivityBlock extends StatefulWidget {
  final List<AppNotification> notifications;
  final ColorSet c;
  final List<Community> communities;
  const _ActivityBlock({required this.notifications, required this.c, required this.communities});
  @override
  State<_ActivityBlock> createState() => _ActivityBlockState();
}

class _ActivityBlockState extends State<_ActivityBlock> {
  String _tab = 'all';

  List<AppNotification> get _filtered {
    final all = widget.notifications;
    switch (_tab) {
      case 'mentions': return all.where((n) => n.type == 'chat_mention' || n.type == 'chat_reply').toList();
      case 'invites': return all.where((n) => n.type == 'invite_received').toList();
      case 'updates': return all.where((n) => !{'chat_mention', 'chat_reply', 'invite_received'}.contains(n.type)).toList();
      default: return all;
    }
  }

  int _unreadFor(String tab) {
    final unread = widget.notifications.where((n) => !n.isRead);
    switch (tab) {
      case 'mentions': return unread.where((n) => n.type == 'chat_mention' || n.type == 'chat_reply').length;
      case 'invites': return unread.where((n) => n.type == 'invite_received').length;
      case 'updates': return unread.where((n) => !{'chat_mention', 'chat_reply', 'invite_received'}.contains(n.type)).length;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final items = _filtered.take(4).toList();

    return _BlockCard(
      c: c,
      icon: Icons.notifications_outlined,
      title: 'Активность',
      actionLabel: 'все уведомления →',
      onAction: () => context.goNamed('notifications'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs
          Wrap(spacing: 4, children: [
            _FeedTab(label: 'Всё', active: _tab == 'all', onTap: () => setState(() => _tab = 'all'), c: c),
            _FeedTab(label: 'Упоминания', active: _tab == 'mentions', badge: _unreadFor('mentions'), onTap: () => setState(() => _tab = 'mentions'), c: c),
            _FeedTab(label: 'Приглашения', active: _tab == 'invites', badge: _unreadFor('invites'), onTap: () => setState(() => _tab = 'invites'), c: c),
            _FeedTab(label: 'Обновления', active: _tab == 'updates', badge: _unreadFor('updates'), onTap: () => setState(() => _tab = 'updates'), c: c),
          ]),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Нет уведомлений', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            )
          else
            ...items.map((n) => _FeedItem(notification: n, c: c, communities: widget.communities)),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;
  final ColorSet c;
  const _FeedTab({required this.label, required this.active, this.badge = 0, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? c.surface : Colors.transparent,
        border: Border.all(color: active ? c.border : Colors.transparent),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? c.text : c.textSecondary)),
        if (badge > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            height: 16,
            decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center,
            child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ]),
    ),
  );
}

class _FeedItem extends StatelessWidget {
  final AppNotification notification;
  final ColorSet c;
  final List<Community> communities;
  const _FeedItem({required this.notification, required this.c, required this.communities});

  IconData get _icon {
    switch (notification.type) {
      case 'chat_mention': return Icons.alternate_email;
      case 'chat_reply': return Icons.reply;
      case 'invite_received': return Icons.person_add_outlined;
      case 'friend_request': return Icons.person_add;
      case 'friend_accepted': return Icons.people;
      case 'moderation_warning_issued': return Icons.warning_amber;
      case 'moderation_muted': return Icons.volume_off;
      case 'moderation_banned': return Icons.block;
      case 'moderation_action_revoked': return Icons.check_circle_outline;
      case 'moderation_appeal_accepted': return Icons.thumb_up_outlined;
      case 'moderation_appeal_rejected': return Icons.thumb_down_outlined;
      case 'moderation_appeal_info_requested': return Icons.info_outline;
      default: return Icons.notifications_outlined;
    }
  }

  Color get _iconBg {
    switch (notification.type) {
      case 'chat_mention': return c.accent.withValues(alpha: 0.15);
      case 'chat_reply': return c.success.withValues(alpha: 0.15);
      case 'invite_received': return const Color(0xFF8B5CF6).withValues(alpha: 0.15);
      case 'friend_request' || 'friend_accepted': return c.accent.withValues(alpha: 0.12);
      case 'moderation_action_revoked' || 'moderation_appeal_accepted': return c.success.withValues(alpha: 0.12);
      default: return c.warning.withValues(alpha: 0.15);
    }
  }

  Color get _iconFg {
    switch (notification.type) {
      case 'chat_mention': return c.accent;
      case 'chat_reply': return c.success;
      case 'invite_received': return const Color(0xFF8B5CF6);
      case 'friend_request' || 'friend_accepted': return c.accent;
      case 'moderation_action_revoked' || 'moderation_appeal_accepted': return c.success;
      case 'moderation_warning_issued' || 'moderation_muted' || 'moderation_banned' || 'moderation_appeal_rejected': return c.error;
      default: return c.warning;
    }
  }

  String get _title {
    final p = notification.payload;
    String _pick(List<String> keys) {
      for (final k in keys) {
        final v = p[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }
    final who = _pick(['sender_display_name', 'sender_username', 'inviter_display_name', 'inviter_username', 'other_display_name', 'other_username', 'actor_username']);
    final where = p['community_name'] as String? ?? '';
    switch (notification.type) {
      case 'chat_mention':
        return who.isNotEmpty ? '$who упомянул вас${where.isNotEmpty ? " в $where" : ""}' : 'Вас упомянули${where.isNotEmpty ? " в $where" : ""}';
      case 'chat_reply':
        return who.isNotEmpty ? '$who ответил на ваше сообщение${where.isNotEmpty ? " в $where" : ""}' : 'Ответ на ваше сообщение${where.isNotEmpty ? " в $where" : ""}';
      case 'invite_received':
        return who.isNotEmpty ? '$who приглашает вас в $where' : 'Приглашение в $where';
      case 'friend_request':
        return who.isNotEmpty ? '$who отправил запрос в друзья' : 'Новый запрос в друзья';
      case 'friend_accepted':
        return who.isNotEmpty ? '$who принял запрос в друзья' : 'Запрос в друзья принят';
      case 'moderation_warning_issued': return 'Вам вынесено предупреждение';
      case 'moderation_muted': return 'Вы заглушены в сообществе';
      case 'moderation_banned': return 'Вы заблокированы в сообществе';
      case 'moderation_action_revoked': return 'Ограничение снято';
      case 'moderation_appeal_accepted': return 'Апелляция одобрена';
      case 'moderation_appeal_rejected': return 'Апелляция отклонена';
      case 'moderation_appeal_info_requested': return 'Запрошена информация по апелляции';
      default: return p['title'] as String? ?? p['message'] as String? ?? 'Обновление';
    }
  }

  String? get _preview {
    final p = notification.payload;
    return p['preview'] as String? ?? p['excerpt'] as String? ?? p['text'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
            child: Icon(_icon, size: 14, color: _iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: TextStyle(fontSize: 14, color: c.text, height: 1.4)),
                if (_preview != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(_preview!, style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            notification.createdAt.isNotEmpty ? timeAgo(DateTime.tryParse(notification.createdAt) ?? DateTime.now(), locale: 'ru') : '',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HorizontalScrollable extends StatefulWidget {
  final Widget child;
  const _HorizontalScrollable({required this.child});
  @override
  State<_HorizontalScrollable> createState() => _HorizontalScrollableState();
}

class _HorizontalScrollableState extends State<_HorizontalScrollable> {
  final _controller = ScrollController();
  bool _hovered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _hovered) {
      GestureBinding.instance.pointerSignalResolver.register(event, (event) {
        final delta = (event as PointerScrollEvent).scrollDelta.dy;
        final target = (_controller.offset + delta).clamp(0.0, _controller.position.maxScrollExtent);
        _controller.jumpTo(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _hovered = true,
      onExit: (_) => _hovered = false,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
          ),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final ColorSet c;
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  const _BlockCard({required this.c, required this.icon, required this.title, this.actionLabel, this.onAction, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    decoration: BoxDecoration(
      color: c.surface.withValues(alpha: 0.85),
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: c.textSecondary),
          const SizedBox(width: 6),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.06)),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: TextStyle(fontSize: 12, color: c.accent)),
            ),
        ]),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  final AuthState auth;
  final ThemeData theme;
  final ColorSet c;
  final WidgetRef ref;
  const _Header({required this.auth, required this.theme, required this.c, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.goNamed('main'),
              child: Text(AppLocalizations.of(context)!.appName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.accent)),
            ),
            const SizedBox(width: 24),
            InkWell(
              onTap: () => context.goNamed('explore'),
              borderRadius: BorderRadius.circular(4),
              child: Text(AppLocalizations.of(context)!.navExplore, style: TextStyle(fontSize: 14.4, color: c.textSecondary)),
            ),
            const Spacer(),
            _buildHeaderAction(
              icon: ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              onTap: () => ref.read(themeProvider.notifier).toggle(),
              c: c,
            ),
            if (auth.isAuthenticated) ...[
              const SizedBox(width: 10),
              _buildHeaderAction(icon: Icons.chat_bubble_outline, onTap: () => context.goNamed('messages'), c: c),
              const SizedBox(width: 10),
              NotificationsBell(iconColor: c.textSecondary, badgeColor: c.error, onTap: () => context.goNamed('notifications')),
              const SizedBox(width: 10),
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
              const SizedBox(width: 10),
              _SmallButton(
                label: AppLocalizations.of(context)!.navLogout,
                onTap: () => ref.read(authProvider.notifier).logout(),
                c: c,
                outlined: true,
              ),
            ] else ...[
              const SizedBox(width: 10),
              _SmallButton(label: AppLocalizations.of(context)!.navLogin, onTap: () => context.goNamed('login'), c: c, outlined: true),
              const SizedBox(width: 8),
              _SmallButton(label: AppLocalizations.of(context)!.navRegister, onTap: () => context.goNamed('register'), c: c, outlined: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction({required IconData icon, required VoidCallback onTap, required ColorSet c}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: c.textSecondary),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ColorSet c;
  final bool outlined;
  const _SmallButton({required this.label, required this.onTap, required this.c, required this.outlined});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : c.accent,
          border: Border.all(color: outlined ? c.border : c.accent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w500, color: outlined ? c.text : Colors.white)),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final ThemeData theme;
  final ColorSet c;
  const _HeroSection({required this.theme, required this.c});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 560;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: isMobile ? 48 : 80),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.heroTitle,
            style: TextStyle(fontSize: isMobile ? 28 : 48, fontWeight: FontWeight.w800, color: c.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.heroSubtitle,
            style: TextStyle(fontSize: isMobile ? 15 : 18, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            width: isMobile ? double.infinity : 600,
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: c.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.heroSearch,
                      hintStyle: TextStyle(color: c.textSecondary, fontSize: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      filled: false,
                    ),
                    style: TextStyle(color: c.text, fontSize: 16),
                    onSubmitted: (q) {
                      if (q.trim().isNotEmpty) context.goNamed('explore');
                    },
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

class _PopularSection extends StatelessWidget {
  final List<Community> communities;
  final ThemeData theme;
  final ColorSet c;
  const _PopularSection({required this.communities, required this.theme, required this.c});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width < 560 ? 1 : (width < 900 ? 2 : 3);

    return _BlockCard(
      c: c,
      icon: Icons.bolt,
      title: AppLocalizations.of(context)!.popularCommunities,
      actionLabel: AppLocalizations.of(context)!.viewAll,
      onAction: () => context.goNamed('explore'),
      child: _buildGrid(context, columns),
    );
  }

  Widget _buildGrid(BuildContext context, int columns) {
    return LayoutBuilder(builder: (ctx, box) {
      final totalW = box.maxWidth;
      const spacing = 16.0;
      final cardW = columns == 1 ? totalW : (totalW - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: communities.map((comm) {
          return SizedBox(
            width: cardW,
            child: _CommunityCard(community: comm, c: c),
          );
        }).toList(),
      );
    });
  }
}

class _CommunityCard extends StatefulWidget {
  final Community community;
  final ColorSet c;
  const _CommunityCard({required this.community, required this.c});

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
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
                      const SizedBox(height: 12),
                      Text(comm.description!, style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Text('${comm.memberCount}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary)),
                        const SizedBox(width: 20),
                        Icon(Icons.article_outlined, size: 14, color: c.textSecondary),
                        const SizedBox(width: 5),
                        Text('${comm.pageCount}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary)),
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

class _CategoriesSection extends StatelessWidget {
  final List<Category> categories;
  final ThemeData theme;
  final ColorSet c;
  const _CategoriesSection({required this.categories, required this.theme, required this.c});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 560;

    return _BlockCard(
      c: c,
      icon: Icons.grid_view,
      title: AppLocalizations.of(context)!.categories,
      child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categories.map((cat) {
              return InkWell(
                onTap: () => context.goNamed('explore', queryParameters: {'category': cat.slug}),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(cat.name, style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w500, color: c.text)),
                ),
              );
            }).toList(),
          ),
    );
  }
}

class _CtaSection extends StatelessWidget {
  final AuthState auth;
  final ThemeData theme;
  final ColorSet c;
  const _CtaSection({required this.auth, required this.theme, required this.c});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 560;
    final hPadding = isMobile ? 20.0 : (width < 900 ? 40.0 : 120.0);

    return Container(
      color: c.surfaceAlt,
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 48),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: isMobile ? 32 : 48),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(AppLocalizations.of(context)!.ctaTitle, style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: c.text), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.ctaSubtitle,
              style: TextStyle(fontSize: 16, color: c.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 40,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _featureItem(Icons.article_outlined, AppLocalizations.of(context)!.ctaFeaturePages, AppLocalizations.of(context)!.ctaFeaturePagesDesc, c),
                _featureItem(Icons.chat_outlined, AppLocalizations.of(context)!.ctaFeatureChat, AppLocalizations.of(context)!.ctaFeatureChatDesc, c),
                _featureItem(Icons.extension_outlined, AppLocalizations.of(context)!.ctaFeaturePlugins, AppLocalizations.of(context)!.ctaFeaturePluginsDesc, c),
              ],
            ),
            const SizedBox(height: 28),
            InkWell(
              onTap: () => context.goNamed(auth.isAuthenticated ? 'create-community' : 'register'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(AppLocalizations.of(context)!.ctaButton, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textOnAccent)),
              ),
            ),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.ctaFree, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String desc, ColorSet c) {
    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Icon(icon, color: c.accent, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 13, color: c.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  final ThemeData theme;
  final ColorSet c;
  const _FooterSection({required this.theme, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 32),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Center(
        child: Text(AppLocalizations.of(context)!.footerCopyright('${DateTime.now().year}'), style: TextStyle(fontSize: 14, color: c.textSecondary)),
      ),
    );
  }
}
