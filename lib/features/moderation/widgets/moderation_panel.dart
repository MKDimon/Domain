import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/feedback_api.dart';
import '../../../data/api/invites_api.dart';
import '../../../data/api/members_api.dart';
import '../../../data/api/moderation_api.dart';
import '../../../data/api/pages_api.dart';
import '../../../data/api/users_api.dart';
import '../../../data/models/community.dart';
import '../../../data/models/user.dart';

enum ModerationTab { content, members, automod, log, feedback }

class ModerationPanel extends ConsumerStatefulWidget {
  final int communityId;
  final List<PageSummary> pages;
  final ColorSet c;
  final bool canManageMembers;

  const ModerationPanel({
    super.key,
    required this.communityId,
    required this.pages,
    required this.c,
    this.canManageMembers = true,
  });

  @override
  ConsumerState<ModerationPanel> createState() => _ModerationPanelState();
}

class _ModerationPanelState extends ConsumerState<ModerationPanel> {
  ModerationTab _tab = ModerationTab.content;
  int _feedbackNewCount = 0;

  late final FeedbackApi _feedbackApi;

  @override
  void initState() {
    super.initState();
    _feedbackApi = FeedbackApi(ref.read(apiClientProvider));
    _loadNewCount();
  }

  Future<void> _loadNewCount() async {
    try {
      final resp = await _feedbackApi.list(widget.communityId, status: 'new', limit: 1);
      if (!mounted) return;
      setState(() => _feedbackNewCount = resp.newCount);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      children: [
        _buildTabBar(c),
        Expanded(child: _buildTabContent(c)),
      ],
    );
  }

  Widget _buildTabBar(ColorSet c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _tabButton(ModerationTab.content, Icons.description_outlined, 'Контент', c),
            _tabButton(ModerationTab.members, Icons.people_outline, 'Участники', c),
            _tabButton(ModerationTab.automod, Icons.shield_outlined, 'Автомодерация', c),
            _tabButton(ModerationTab.log, Icons.history, 'Действия', c),
            _tabButton(ModerationTab.feedback, Icons.chat_bubble_outline, 'Обратная связь', c, badge: _feedbackNewCount),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(ModerationTab tab, IconData icon, String label, ColorSet c, {int badge = 0}) {
    final active = _tab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: active ? c.accent : c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? c.accent : c.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? c.accent : c.text)),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(8)),
                  child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorSet c) {
    return switch (_tab) {
      ModerationTab.content => _ContentTab(communityId: widget.communityId, pages: widget.pages, c: c),
      ModerationTab.members => _MembersTab(communityId: widget.communityId, c: c, canManageMembers: widget.canManageMembers),
      ModerationTab.automod => _AutomodTab(communityId: widget.communityId, c: c),
      ModerationTab.log => _LogTab(communityId: widget.communityId, c: c),
      ModerationTab.feedback => _FeedbackModTab(communityId: widget.communityId, c: c, onStatusChange: _loadNewCount),
    };
  }
}

// ─── Content Tab ───────────────────────────────────────────────────────────

class _ContentTab extends ConsumerStatefulWidget {
  final int communityId;
  final List<PageSummary> pages;
  final ColorSet c;
  const _ContentTab({required this.communityId, required this.pages, required this.c});

  @override
  ConsumerState<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends ConsumerState<_ContentTab> {
  late List<PageSummary> _pages;

  @override
  void initState() {
    super.initState();
    _pages = widget.pages.where((p) => p.pageType != 'main').toList();
  }

  Future<void> _updateVisibility(PageSummary p, String visibility) async {
    try {
      final api = PagesApi(ref.read(apiClientProvider));
      await api.update(p.id, {'visibility': visibility});
      if (!mounted) return;
      setState(() {
        final idx = _pages.indexWhere((x) => x.id == p.id);
        if (idx >= 0) _pages[idx] = p.copyWith(visibility: visibility);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось изменить видимость')));
      }
    }
  }

  Future<void> _delete(PageSummary p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить страницу?'),
        content: Text('Страница «${p.title}» будет удалена навсегда'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PagesApi(ref.read(apiClientProvider)).delete(p.id);
      if (!mounted) return;
      setState(() => _pages.removeWhere((x) => x.id == p.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось удалить')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (_pages.isEmpty) {
      return Center(child: Text('Нет страниц', style: TextStyle(color: c.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pages.length,
      itemBuilder: (ctx, i) {
        final p = _pages[i];
        final vis = p.visibility ?? 'public';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(p.slug, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.textSecondary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(3)),
                        child: Text(p.pageType, style: TextStyle(fontSize: 10, color: c.textSecondary)),
                      ),
                    ]),
                  ],
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: vis,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Публичная')),
                    DropdownMenuItem(value: 'moderator', child: Text('Модераторы')),
                    DropdownMenuItem(value: 'owner', child: Text('Владелец')),
                  ],
                  onChanged: (v) { if (v != null) _updateVisibility(p, v); },
                  style: TextStyle(fontSize: 12, color: c.text),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: c.error),
                onPressed: () => _delete(p),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Members Tab ───────────────────────────────────────────────────────────

class _MembersTab extends ConsumerStatefulWidget {
  final int communityId;
  final ColorSet c;
  final bool canManageMembers;
  const _MembersTab({required this.communityId, required this.c, required this.canManageMembers});

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  List<Member> _members = [];
  bool _loading = true;
  String _search = '';
  String _roleFilter = '';

  // Add member form
  final _searchCtrl = TextEditingController();
  List<PublicProfile> _searchResults = [];
  PublicProfile? _selectedUser;
  String _newRole = 'member';
  final Set<String> _newPermissions = {};

  // Invites
  List<Invite> _invites = [];
  final _inviteQueryCtrl = TextEditingController();
  String? _generatedInviteLink;

  late final MembersApi _membersApi;
  late final InvitesApi _invitesApi;
  late final UsersApi _usersApi;

  @override
  void initState() {
    super.initState();
    final api = ref.read(apiClientProvider);
    _membersApi = MembersApi(api);
    _invitesApi = InvitesApi(api);
    _usersApi = UsersApi(api);
    _load();
    _loadInvites();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _inviteQueryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _membersApi.list(widget.communityId, search: _search, role: _roleFilter);
      if (!mounted) return;
      setState(() { _members = list; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadInvites() async {
    try {
      final list = await _invitesApi.list(widget.communityId);
      if (!mounted) return;
      setState(() => _invites = list);
    } catch (_) {}
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await _usersApi.search(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {}
  }

  Future<void> _addMember() async {
    if (_selectedUser == null) return;
    try {
      await _membersApi.add(widget.communityId,
        userId: _selectedUser!.id,
        role: _newRole,
        permissions: _newPermissions.toList(),
      );
      _searchCtrl.clear();
      setState(() {
        _selectedUser = null;
        _searchResults = [];
        _newPermissions.clear();
        _newRole = 'member';
      });
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось добавить')));
      }
    }
  }

  Future<void> _changeRole(Member m, String role) async {
    try {
      await _membersApi.update(widget.communityId, m.userId, role: role, permissions: m.permissions);
      _load();
    } catch (_) {}
  }

  Future<void> _updatePermissions(Member m, Set<String> perms) async {
    try {
      await _membersApi.update(widget.communityId, m.userId, role: m.role, permissions: perms.toList());
      _load();
    } catch (_) {}
  }

  Future<void> _kick(Member m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Исключить участника?'),
        content: Text('${m.username} будет удалён из сообщества'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Исключить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _membersApi.remove(widget.communityId, m.userId);
      _load();
    } catch (_) {}
  }

  Future<void> _generateLink() async {
    try {
      final invite = await _invitesApi.create(widget.communityId);
      if (!mounted) return;
      setState(() => _generatedInviteLink = '/invites/${invite.token}');
      _loadInvites();
    } catch (_) {}
  }

  Future<void> _inviteUser() async {
    if (_inviteQueryCtrl.text.trim().isEmpty) return;
    try {
      await _invitesApi.inviteUser(widget.communityId, _inviteQueryCtrl.text.trim());
      _inviteQueryCtrl.clear();
      _loadInvites();
    } catch (_) {}
  }

  Future<void> _revokeInvite(int id) async {
    try {
      await _invitesApi.revoke(widget.communityId, id);
      _loadInvites();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.canManageMembers) ...[
          _buildAddMemberCard(c),
          const SizedBox(height: 12),
          _buildInvitesCard(c),
          const SizedBox(height: 12),
        ],
        _buildMembersListCard(c),
      ],
    );
  }

  Widget _buildAddMemberCard(ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ДОБАВИТЬ УЧАСТНИКА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Найти по имени или email',
              prefixIcon: Icon(Icons.search, size: 16, color: c.textSecondary),
              border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
              isDense: true,
            ),
            style: TextStyle(fontSize: 13, color: c.text),
            onChanged: (v) { _searchUsers(v); setState(() => _selectedUser = null); },
          ),
          if (_searchResults.isNotEmpty && _selectedUser == null) Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
            child: ListView(
              shrinkWrap: true,
              children: _searchResults.map((u) => ListTile(
                dense: true,
                title: Text(u.username, style: TextStyle(fontSize: 13, color: c.text)),
                onTap: () => setState(() {
                  _selectedUser = u;
                  _searchCtrl.text = u.username;
                  _searchResults = [];
                }),
              )).toList(),
            ),
          ),
          if (_selectedUser != null) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Выбран: ${_selectedUser!.username}', style: TextStyle(fontSize: 12, color: c.accent)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newRole,
                  decoration: InputDecoration(
                    labelText: 'Роль',
                    border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Участник')),
                    DropdownMenuItem(value: 'moderator', child: Text('Модератор')),
                  ],
                  onChanged: (v) => setState(() => _newRole = v ?? 'member'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _selectedUser == null ? null : _addMember,
                child: const Text('Добавить'),
              ),
            ],
          ),
          if (_newRole == 'moderator') ...[
            const SizedBox(height: 10),
            Text('Права модератора:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ...['edit_pages', 'create_pages', 'delete_pages', 'manage_members'].map((perm) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _newPermissions.contains(perm),
              onChanged: (v) => setState(() {
                if (v == true) { _newPermissions.add(perm); } else { _newPermissions.remove(perm); }
              }),
              title: Text(perm.replaceAll('_', ' '), style: TextStyle(fontSize: 12, color: c.text)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitesCard(ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ПРИГЛАШЕНИЯ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _generateLink,
              icon: const Icon(Icons.link, size: 14),
              label: const Text('Создать ссылку'),
            ),
          ]),
          if (_generatedInviteLink != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(6)),
              child: SelectableText(_generatedInviteLink!, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: c.text)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _inviteQueryCtrl,
                decoration: InputDecoration(
                  hintText: 'Email или username',
                  border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 13, color: c.text),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _inviteUser, child: const Text('Отправить')),
          ]),
          if (_invites.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._invites.map((inv) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(
                    inv.inviteeUsername ?? 'Ссылка-приглашение',
                    style: TextStyle(fontSize: 13, color: c.text),
                  )),
                  if (inv.inviterUsername != null)
                    Text('от ${inv.inviterUsername}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  IconButton(
                    icon: Icon(Icons.close, size: 14, color: c.error),
                    onPressed: () => _revokeInvite(inv.id),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersListCard(ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('УЧАСТНИКИ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Поиск участников',
              prefixIcon: Icon(Icons.search, size: 16, color: c.textSecondary),
              border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
              isDense: true,
            ),
            style: TextStyle(fontSize: 13, color: c.text),
            onChanged: (v) { _search = v; _load(); },
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 4, children: [
            _roleChip('', 'Все', c),
            _roleChip('owner', 'Владелец', c),
            _roleChip('moderator', 'Модераторы', c),
            _roleChip('member', 'Участники', c),
          ]),
          const SizedBox(height: 10),
          if (_loading)
            Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: c.accent)))
          else if (_members.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('Нет участников', style: TextStyle(color: c.textSecondary))))
          else
            ..._members.map((m) => _memberRow(m, c)),
        ],
      ),
    );
  }

  Widget _roleChip(String value, String label, ColorSet c) {
    final active = _roleFilter == value;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) { setState(() => _roleFilter = value); _load(); },
      labelStyle: TextStyle(fontSize: 12, color: active ? c.accent : c.text),
      selectedColor: c.accent.withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _memberRow(Member m, ColorSet c) {
    final (bgColor, textColor, label) = switch (m.role) {
      'owner' => (c.warning.withValues(alpha: 0.15), c.warning, 'Владелец'),
      'moderator' => (c.accent.withValues(alpha: 0.15), c.accent, 'Модератор'),
      _ => (c.surfaceAlt, c.textSecondary, 'Участник'),
    };
    final permissions = Set<String>.from(m.permissions);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(6)),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Text(m.username, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
            ),
            if (widget.canManageMembers && m.role != 'owner') ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  initialValue: m.role,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Участник')),
                    DropdownMenuItem(value: 'moderator', child: Text('Модератор')),
                  ],
                  onChanged: (v) { if (v != null) _changeRole(m, v); },
                  style: TextStyle(fontSize: 11, color: c.text),
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout, size: 16, color: c.error),
                onPressed: () => _kick(m),
                tooltip: 'Исключить',
              ),
            ],
          ]),
          if (m.role == 'moderator') ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: ['edit_pages', 'create_pages', 'delete_pages', 'manage_members'].map((perm) {
              final has = permissions.contains(perm);
              return InkWell(
                onTap: widget.canManageMembers ? () {
                  final next = Set<String>.from(permissions);
                  if (has) { next.remove(perm); } else { next.add(perm); }
                  _updatePermissions(m, next);
                } : null,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(has ? Icons.check_box : Icons.check_box_outline_blank, size: 14, color: has ? c.accent : c.textSecondary),
                  const SizedBox(width: 2),
                  Text(perm.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ]),
              );
            }).toList()),
          ],
        ],
      ),
    );
  }
}

// ─── Automod Tab ───────────────────────────────────────────────────────────

class _AutomodTab extends ConsumerStatefulWidget {
  final int communityId;
  final ColorSet c;
  const _AutomodTab({required this.communityId, required this.c});

  @override
  ConsumerState<_AutomodTab> createState() => _AutomodTabState();
}

class _AutomodTabState extends ConsumerState<_AutomodTab> {
  List<BannedWord> _words = [];
  bool _loading = true;
  final _wordCtrl = TextEditingController();
  bool _matchSubstring = true;
  bool _caseSensitive = false;
  String? _error;

  late final ModerationApi _api;

  @override
  void initState() {
    super.initState();
    _api = ModerationApi(ref.read(apiClientProvider));
    _load();
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _api.listBannedWords(widget.communityId);
      if (!mounted) return;
      setState(() { _words = list; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addWord() async {
    final word = _wordCtrl.text.trim();
    if (word.isEmpty) return;
    if (_words.any((w) => w.word == word)) {
      setState(() => _error = 'Это слово уже в списке');
      return;
    }
    try {
      final added = await _api.addBannedWord(widget.communityId, word,
        matchSubstring: _matchSubstring, caseSensitive: _caseSensitive);
      if (!mounted) return;
      setState(() {
        _words.insert(0, added);
        _wordCtrl.clear();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка');
    }
  }

  Future<void> _removeWord(int id) async {
    try {
      await _api.removeBannedWord(widget.communityId, id);
      if (!mounted) return;
      setState(() => _words.removeWhere((w) => w.id == id));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ЗАПРЕЩЁННЫЕ СЛОВА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text('Сообщения со словами из этого списка будут автоматически блокироваться',
          style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _wordCtrl,
                    maxLength: 255,
                    decoration: InputDecoration(
                      hintText: 'Слово или фраза',
                      border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                      counterText: '',
                    ),
                    style: TextStyle(fontSize: 13, color: c.text),
                    onSubmitted: (_) => _addWord(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _addWord, child: const Text('Добавить')),
              ]),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: TextStyle(fontSize: 12, color: c.error)),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _matchSubstring,
                onChanged: (v) => setState(() => _matchSubstring = v ?? true),
                title: Text('Совпадение подстроки', style: TextStyle(fontSize: 13, color: c.text)),
                subtitle: Text('Например, «ругат» сработает на «ругательство»', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _caseSensitive,
                onChanged: (v) => setState(() => _caseSensitive = v ?? false),
                title: Text('Учитывать регистр', style: TextStyle(fontSize: 13, color: c.text)),
                subtitle: Text('Различать «Слово» и «слово»', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          Center(child: CircularProgressIndicator(color: c.accent))
        else if (_words.isEmpty)
          Center(child: Text('Пусто — список запрещённых слов чист', style: TextStyle(color: c.textSecondary)))
        else
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _words.map((w) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(w.word, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: c.text)),
                if (!w.matchSubstring) ...[
                  const SizedBox(width: 4),
                  Tooltip(message: 'Только целое слово', child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                    child: Text('|w|', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.accent)),
                  )),
                ],
                if (w.caseSensitive) ...[
                  const SizedBox(width: 4),
                  Tooltip(message: 'С учётом регистра', child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                    child: Text('Aa', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.warning)),
                  )),
                ],
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _removeWord(w.id),
                  child: Icon(Icons.close, size: 14, color: c.textSecondary),
                ),
              ]),
            )).toList(),
          ),
      ],
    );
  }
}

// ─── Log Tab ───────────────────────────────────────────────────────────────

class _LogTab extends ConsumerStatefulWidget {
  final int communityId;
  final ColorSet c;
  const _LogTab({required this.communityId, required this.c});

  @override
  ConsumerState<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<_LogTab> {
  ActionLogStats? _stats;
  List<ActionLogEntry> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  String _actionFilter = '';
  String _search = '';

  late final ModerationApi _api;

  @override
  void initState() {
    super.initState();
    _api = ModerationApi(ref.read(apiClientProvider));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.listActions(widget.communityId, page: _page, action: _actionFilter, search: _search),
        _api.statsActions(widget.communityId),
      ]);
      if (!mounted) return;
      setState(() {
        _items = (results[0] as ActionLogListResponse).items;
        _totalPages = (results[0] as ActionLogListResponse).totalPages;
        _stats = results[1] as ActionLogStats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_stats != null) _buildStatsRow(c),
        const SizedBox(height: 12),
        _buildFilters(c),
        const SizedBox(height: 12),
        if (_loading)
          Center(child: CircularProgressIndicator(color: c.accent))
        else if (_items.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Нет событий', style: TextStyle(color: c.textSecondary))))
        else
          ..._items.map((e) => _buildLogEntry(e, c)),
        if (_totalPages > 1) _buildPagination(c),
      ],
    );
  }

  Widget _buildStatsRow(ColorSet c) {
    final s = _stats!;
    return Row(children: [
      Expanded(child: _statCard('${s.total}', 'За неделю', c.accent, c)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('${s.creates}', 'Создано', c.success, c)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('${s.edits}', 'Изменено', c.warning, c)),
      const SizedBox(width: 8),
      Expanded(child: _statCard('${s.deletes}', 'Удалено', c.error, c)),
    ]);
  }

  Widget _statCard(String value, String label, Color color, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFilters(ColorSet c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 4, runSpacing: 4, children: [
          _filterChip('', 'Все', c),
          _filterChip('create', 'Создание', c),
          _filterChip('edit', 'Изменение', c),
          _filterChip('delete', 'Удаление', c),
          _filterChip('settings', 'Настройки', c),
        ]),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Поиск по пользователю',
            prefixIcon: Icon(Icons.search, size: 16, color: c.textSecondary),
            border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
            isDense: true,
          ),
          style: TextStyle(fontSize: 13, color: c.text),
          onChanged: (v) { _search = v; _page = 1; _load(); },
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, ColorSet c) {
    final active = _actionFilter == value;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) { setState(() { _actionFilter = value; _page = 1; }); _load(); },
      labelStyle: TextStyle(fontSize: 12, color: active ? c.accent : c.text),
      selectedColor: c.accent.withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLogEntry(ActionLogEntry e, ColorSet c) {
    final (actionColor, actionLabel) = _actionStyle(e.action, c);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 70,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_formatTime(e.createdAt), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: c.text)),
            Text(_formatDate(e.createdAt), style: TextStyle(fontSize: 10, color: c.textSecondary)),
          ]),
        ),
        Container(width: 1, height: 40, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 10)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  image: e.avatarUrl?.isNotEmpty == true
                      ? DecorationImage(image: NetworkImage(fullImageUrl(e.avatarUrl!)), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: e.avatarUrl?.isNotEmpty != true
                    ? Text(e.username.isNotEmpty ? e.username[0].toUpperCase() : '?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent))
                    : null,
              ),
              const SizedBox(width: 6),
              Text(e.username, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: actionColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text(actionLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: actionColor)),
              ),
            ]),
            if (e.targetTitle?.isNotEmpty == true || e.targetType?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text('${e.targetType ?? ''}: ${e.targetTitle ?? ''}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
            if (e.details?.isNotEmpty == true) Text(e.details!, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  (Color, String) _actionStyle(String action, ColorSet c) {
    if (action.contains('create')) return (c.success, 'создание');
    if (action.contains('edit') || action.contains('update')) return (c.accent, 'изменение');
    if (action.contains('delete')) return (c.error, 'удаление');
    if (action.contains('settings')) return (c.warning, 'настройки');
    if (action.contains('member') || action.contains('kick')) return (const Color(0xFF9B59B6), 'участники');
    if (action.contains('join')) return (c.accent, 'вступление');
    return (c.textSecondary, action);
  }

  Widget _buildPagination(ColorSet c) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        Text('$_page / $_totalPages', style: TextStyle(fontSize: 13, color: c.textSecondary)),
        IconButton(
          onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
          icon: const Icon(Icons.chevron_right, size: 18),
        ),
      ]),
    );
  }

  static String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Feedback (Moderator view) Tab ─────────────────────────────────────────

class _FeedbackModTab extends ConsumerStatefulWidget {
  final int communityId;
  final ColorSet c;
  final VoidCallback onStatusChange;
  const _FeedbackModTab({required this.communityId, required this.c, required this.onStatusChange});

  @override
  ConsumerState<_FeedbackModTab> createState() => _FeedbackModTabState();
}

class _FeedbackModTabState extends ConsumerState<_FeedbackModTab> {
  List<FeedbackItem> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  String _typeFilter = '';
  String _statusFilter = '';
  FeedbackItem? _selected;
  final _respondCtrl = TextEditingController();

  late final FeedbackApi _api;

  @override
  void initState() {
    super.initState();
    _api = FeedbackApi(ref.read(apiClientProvider));
    _load();
  }

  @override
  void dispose() {
    _respondCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.list(widget.communityId,
        page: _page, limit: 5,
        feedbackType: _typeFilter, status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _items = resp.items;
        _totalPages = resp.totalPages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(FeedbackItem item, String status) async {
    try {
      final updated = await _api.updateStatus(widget.communityId, item.id, status);
      if (!mounted) return;
      setState(() {
        _selected = updated;
        final idx = _items.indexWhere((x) => x.id == item.id);
        if (idx >= 0) _items[idx] = updated;
      });
      widget.onStatusChange();
    } catch (_) {}
  }

  Future<void> _respond(FeedbackItem item) async {
    if (_respondCtrl.text.trim().isEmpty) return;
    try {
      final updated = await _api.respond(widget.communityId, item.id, _respondCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _respondCtrl.clear();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 4, runSpacing: 4, children: [
          _tfChip('', 'Все типы', c),
          _tfChip('complaint', 'Жалобы', c),
          _tfChip('suggestion', 'Предложения', c),
          _tfChip('question', 'Вопросы', c),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, children: [
          _sfChip('', 'Все статусы', c),
          _sfChip('new', 'Новые', c),
          _sfChip('in_progress', 'В работе', c),
          _sfChip('resolved', 'Решены', c),
          _sfChip('declined', 'Отклонены', c),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          Center(child: CircularProgressIndicator(color: c.accent))
        else if (_items.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Нет обращений', style: TextStyle(color: c.textSecondary))))
        else
          ..._items.map((item) => _buildCard(item, c)),
        if (_totalPages > 1) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null, icon: const Icon(Icons.chevron_left)),
            Text('$_page / $_totalPages', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            IconButton(onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null, icon: const Icon(Icons.chevron_right)),
          ]),
        ),
      ],
    );
  }

  Widget _tfChip(String value, String label, ColorSet c) {
    final active = _typeFilter == value;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) { setState(() { _typeFilter = value; _page = 1; }); _load(); },
      labelStyle: TextStyle(fontSize: 12, color: active ? c.accent : c.text),
      selectedColor: c.accent.withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _sfChip(String value, String label, ColorSet c) {
    final active = _statusFilter == value;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) { setState(() { _statusFilter = value; _page = 1; }); _load(); },
      labelStyle: TextStyle(fontSize: 12, color: active ? c.accent : c.text),
      selectedColor: c.accent.withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCard(FeedbackItem item, ColorSet c) {
    final isSelected = _selected?.id == item.id;
    final isNew = item.status == 'new';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? c.accent.withValues(alpha: 0.04) : c.surface,
        border: Border(
          left: BorderSide(width: 3, color: isNew ? c.accent : Colors.transparent),
          right: BorderSide(color: c.border),
          top: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _selected = isSelected ? null : item),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _typeBadge(item.feedbackType, c),
                    const SizedBox(width: 6),
                    _statusBadge(item.status, c),
                    const SizedBox(width: 8),
                    Text(item.username, style: TextStyle(fontSize: 12, color: c.text)),
                    const Spacer(),
                    Text(_formatDate(item.createdAt), style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 8),
                  Text(item.body, maxLines: isSelected ? null : 2, overflow: isSelected ? null : TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.text, height: 1.4)),
                  if (item.pageTitle != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.description_outlined, size: 12, color: c.accent),
                      const SizedBox(width: 4),
                      Text(item.pageTitle!, style: TextStyle(fontSize: 12, color: c.accent)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          if (isSelected) _buildDetailPanel(item, c),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(FeedbackItem item, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Статус:', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: item.status,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(4)),
                ),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('Новый')),
                  DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
                  DropdownMenuItem(value: 'resolved', child: Text('Решён')),
                  DropdownMenuItem(value: 'declined', child: Text('Отклонён')),
                ],
                onChanged: (v) { if (v != null) _updateStatus(item, v); },
                style: TextStyle(fontSize: 12, color: c.text),
              ),
            ),
          ]),
          if (item.responses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('ОТВЕТЫ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            ...item.responses.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.2), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(r.username.isNotEmpty ? r.username[0].toUpperCase() : '?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r.username, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                    const SizedBox(width: 6),
                    Text(_formatDate(r.createdAt), style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 2),
                  Text(r.body, style: TextStyle(fontSize: 12, color: c.text)),
                ])),
              ]),
            )),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _respondCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Написать ответ...',
              border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
              isDense: true,
            ),
            style: TextStyle(fontSize: 12, color: c.text),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: () => _respond(item), child: const Text('Ответить')),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type, ColorSet c) {
    final (color, label) = switch (type) {
      'complaint' => (c.error, 'Жалоба'),
      'suggestion' => (c.success, 'Предложение'),
      'question' => (c.accent, 'Вопрос'),
      _ => (c.textSecondary, type),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusBadge(String status, ColorSet c) {
    final (color, label) = switch (status) {
      'new' => (c.accent, 'Новый'),
      'in_progress' => (c.warning, 'В работе'),
      'resolved' => (c.success, 'Решён'),
      'declined' => (c.textSecondary, 'Отклонён'),
      _ => (c.textSecondary, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
