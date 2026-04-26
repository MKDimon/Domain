import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/users_api.dart';
import '../../../data/api/friends_api.dart';
import '../../../data/api/dm_api.dart';
import '../../../data/api/admin_api.dart';
import '../../../data/models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../admin/widgets/admin_moderation_dialog.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final int? userId;
  final String? username;
  const PublicProfileScreen({super.key, this.userId, this.username});

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  PublicProfile? _profile;
  bool _loading = true;
  String? _error;

  // Friend
  String _friendStatus = 'none';
  int? _friendshipId;
  bool _friendBusy = false;

  // Block
  bool _isBlocked = false;
  bool _blockBusy = false;

  // Admin moderation
  List<ModerationAction> _modActions = [];
  bool _modLoading = false;
  int? _revokeForId;
  final _revokeReasonCtrl = TextEditingController();

  bool get _isOwn => ref.read(authProvider).user?.id == _profile?.id;
  bool get _isAuth => ref.read(authProvider).isAuthenticated;
  bool get _isAdmin => ref.read(authProvider).isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _revokeReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = UsersApi(ref.read(apiClientProvider));
      if (widget.username != null) {
        _profile = await api.getProfileByUsername(widget.username!);
      } else if (widget.userId != null) {
        _profile = await api.getProfile(widget.userId!);
      }
      if (_profile != null && _isOwn) {
        if (mounted) context.go('/profile');
        return;
      }
      if (_isAuth && !_isOwn) {
        _loadFriendStatus();
        _loadBlockState();
      }
      if (_isAdmin && !_isOwn) {
        _loadModeration();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadFriendStatus() async {
    try {
      final res = await FriendsApi(ref.read(apiClientProvider)).statusWith(_profile!.id);
      if (mounted) setState(() { _friendStatus = res.status; _friendshipId = res.friendshipId; });
    } catch (_) {}
  }

  Future<void> _loadBlockState() async {
    try {
      final ids = await DmApi(ref.read(apiClientProvider)).listBlockedIds();
      if (mounted) setState(() => _isBlocked = ids.contains(_profile!.id));
    } catch (_) {}
  }

  Future<void> _loadModeration() async {
    if (!mounted) return;
    setState(() => _modLoading = true);
    try {
      final actions = await AdminApi(ref.read(apiClientProvider)).listUserModeration(_profile!.id);
      _modActions = actions;
    } catch (e) {
      // ignore: avoid_print
      print('[public-profile] loadModeration error: $e');
    }
    if (mounted) setState(() => _modLoading = false);
  }

  Future<void> _addFriend() async {
    if (_friendBusy) return;
    setState(() => _friendBusy = true);
    try {
      await FriendsApi(ref.read(apiClientProvider)).sendRequest(_profile!.id);
      await _loadFriendStatus();
    } catch (_) {}
    if (mounted) setState(() => _friendBusy = false);
  }

  Future<void> _acceptFriend() async {
    if (_friendshipId == null || _friendBusy) return;
    setState(() => _friendBusy = true);
    try {
      await FriendsApi(ref.read(apiClientProvider)).accept(_friendshipId!);
      await _loadFriendStatus();
    } catch (_) {}
    if (mounted) setState(() => _friendBusy = false);
  }

  Future<void> _removeFriend() async {
    if (_friendBusy) return;
    setState(() => _friendBusy = true);
    try {
      await FriendsApi(ref.read(apiClientProvider)).unfriend(_profile!.id);
      await _loadFriendStatus();
    } catch (_) {}
    if (mounted) setState(() => _friendBusy = false);
  }

  Future<void> _toggleBlock() async {
    if (_blockBusy) return;
    if (!_isBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = Theme.of(ctx).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
          return Dialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Заблокировать @${_profile!.username}?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 8),
                  Text('Пользователь не сможет отправлять вам сообщения.', style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: TextStyle(color: c.text))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: c.error, foregroundColor: Colors.white),
                        child: const Text('Заблокировать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (confirmed != true) return;
    }
    setState(() => _blockBusy = true);
    try {
      final api = DmApi(ref.read(apiClientProvider));
      if (_isBlocked) {
        await api.unblockUser(_profile!.id);
        _isBlocked = false;
      } else {
        await api.blockUser(_profile!.id);
        _isBlocked = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _blockBusy = false);
  }

  Future<void> _revokeAction(int actionId) async {
    try {
      await AdminApi(ref.read(apiClientProvider)).revokeModeration(actionId, reason: _revokeReasonCtrl.text.trim());
      _revokeForId = null;
      _revokeReasonCtrl.clear();
      await _loadModeration();
    } catch (_) {}
  }

  Future<void> _openIssueDialog() async {
    if (_profile == null) return;
    final adminApi = AdminApi(ref.read(apiClientProvider));
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final adminUser = AdminUser(id: _profile!.id, username: _profile!.username, displayName: _profile!.displayName);
    final issued = await showAdminModerationDialog(context: context, user: adminUser, api: adminApi, c: c);
    if (issued) _loadModeration();
  }

  bool _isActionActive(ModerationAction a) {
    if (a.revokedAt != null) return false;
    if (a.expiresAt == null) return true;
    final exp = DateTime.tryParse(a.expiresAt!);
    return exp != null && exp.isAfter(DateTime.now());
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d).inSeconds;
    if (diff < 60) return '${diff}с назад';
    if (diff < 3600) return '${diff ~/ 60}м назад';
    if (diff < 86400) return '${diff ~/ 3600}ч назад';
    if (diff < 604800) return '${diff ~/ 86400}д назад';
    return d.toLocal().toString().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    if (_loading) {
      return Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Пользователь не найден', style: TextStyle(color: c.error)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ]),
        ),
      );
    }

    final p = _profile!;
    final name = p.displayName?.isNotEmpty == true ? p.displayName! : p.username;

    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileCard(p, name, c),
                const SizedBox(height: 24),
                _buildCommunities(p, c),
                if (_isAdmin && !_isOwn) ...[
                  const SizedBox(height: 24),
                  _buildModPanel(c),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Profile Card ───────────────────────────────────────────────

  Widget _buildProfileCard(PublicProfile p, String name, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              SizedBox(
                width: 96, height: 96,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: avatarColor(p.id),
                      backgroundImage: p.avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(p.avatarUrl)) : null,
                      child: p.avatarUrl.isEmpty
                          ? Text(p.username[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white))
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: p.lastSeenAt != null
                          ? Text('Был(а) ${_timeAgo(p.lastSeenAt)}', style: TextStyle(fontSize: 13, color: c.textSecondary))
                          : Text('Оффлайн', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    ),
                    if (p.bio.isNotEmpty)
                      Text(p.bio, style: TextStyle(fontSize: 14, color: c.text, height: 1.5))
                    else
                      Text('Нет описания', style: TextStyle(fontSize: 14, color: c.textSecondary, fontStyle: FontStyle.italic)),
                    if (p.createdAt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(builder: (_) {
                        final dt = DateTime.tryParse(p.createdAt)?.toLocal();
                        if (dt == null) return const SizedBox.shrink();
                        return Text(
                          'Участник с ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
                          style: TextStyle(fontSize: 13, color: c.textSecondary),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_isAuth && !_isOwn) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_isBlocked)
                    _btn(Icons.chat_bubble_outline, 'Написать', c.accent, filled: true, onTap: () => context.push('/messages?open=${_profile!.id}')),
                  if (!_isBlocked) ...[
                    if (_friendStatus == 'none')
                      _btn(Icons.person_add_outlined, 'Добавить в друзья', c.text, onTap: _friendBusy ? null : _addFriend),
                    if (_friendStatus == 'pending_outgoing')
                      _btn(Icons.hourglass_top, 'Запрос отправлен', c.text, onTap: _friendBusy ? null : _removeFriend),
                    if (_friendStatus == 'pending_incoming')
                      _btn(Icons.person_add, 'Принять', c.accent, filled: true, onTap: _friendBusy ? null : _acceptFriend),
                    if (_friendStatus == 'accepted')
                      _btn(Icons.check, 'В друзьях', c.text, onTap: _friendBusy ? null : _removeFriend),
                  ],
                  _btn(Icons.block, _isBlocked ? 'Разблокировать' : 'Заблокировать',
                      _isBlocked ? c.accent : c.text, filled: _isBlocked, onTap: _blockBusy ? null : _toggleBlock),
                  _btn(Icons.flag_outlined, 'Пожаловаться', c.text, onTap: _reportUser),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reportUser() async {
    if (_profile == null) return;
    final reasonCtrl = TextEditingController();
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Пожаловаться на @${_profile!.username}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: c.text),
                decoration: InputDecoration(
                  hintText: 'Опишите причину...',
                  hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                  filled: true, fillColor: c.bg, isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена', style: TextStyle(color: c.text))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: c.error, foregroundColor: Colors.white),
                    child: const Text('Отправить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (sent == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        await ref.read(apiClientProvider).post('/complaints', data: {
          'target_type': 'user',
          'target_id': _profile!.id,
          'reason': 'other',
          'comment': reasonCtrl.text.trim(),
        });
      } catch (_) {}
    }
    reasonCtrl.dispose();
  }

  Widget _btn(IconData icon, String label, Color color, {bool filled = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: Border.all(color: filled ? color : color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: filled ? Colors.white : color)),
          ],
        ),
      ),
    );
  }

  // ─── Communities ────────────────────────────────────────────────

  Widget _buildCommunities(PublicProfile p, ColorSet c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Сообщества', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 16),
          if (p.communities.isEmpty)
            Text('Нет сообществ', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          ...p.communities.map((comm) {
            final slug = comm['slug'] as String? ?? '';
            final cName = comm['name'] as String? ?? slug;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: slug.isNotEmpty ? () => context.push('/community/$slug') : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: c.bg, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
                      Text('/$slug', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Admin Moderation Panel ─────────────────────────────────────

  Widget _buildModPanel(ColorSet c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: Color.lerp(c.warning, c.border, 0.7)!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Модерация', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
              GestureDetector(
                onTap: _openIssueDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.warning.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Выдать наказание', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.warning)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // List
          if (_modLoading)
            Text('Загрузка...', style: TextStyle(fontSize: 13, color: c.textSecondary))
          else if (_modActions.isEmpty)
            Text('Нет истории модерации', style: TextStyle(fontSize: 13, color: c.textSecondary))
          else
            ..._modActions.map((a) => _buildModRow(a, c)),
        ],
      ),
    );
  }

  Widget _buildModRow(ModerationAction a, ColorSet c) {
    final active = _isActionActive(a);
    final (Color pillBg, Color pillFg) = switch (a.actionType) {
      'warning' => (c.warning.withValues(alpha: 0.18), c.warning),
      'mute' => (const Color(0xFFA855F7).withValues(alpha: 0.18), const Color(0xFFC084FC)),
      'ban' => (c.error.withValues(alpha: 0.18), c.error),
      _ => (c.surfaceAlt, c.textSecondary),
    };

    String statusLabel;
    if (a.revokedAt != null) {
      statusLabel = 'отозвано';
    } else if (a.expiresAt != null && (DateTime.tryParse(a.expiresAt!)?.isBefore(DateTime.now()) ?? false)) {
      statusLabel = 'истекло';
    } else {
      statusLabel = 'активно';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: active ? Color.lerp(c.warning, c.border, 0.7)! : c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Opacity(
        opacity: active ? 1.0 : 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Head row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(a.actionType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pillFg)),
                ),
                Text(a.communityId != null ? 'community #${a.communityId}' : 'platform', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                if (a.actionType == 'warning') Text('· severity ${a.severity}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                Text(statusLabel, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                if (active)
                  GestureDetector(
                    onTap: () => setState(() => _revokeForId = a.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
                      child: Text('Отозвать', style: TextStyle(fontSize: 12, color: c.text)),
                    ),
                  ),
              ],
            ),
            // Meta
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 12,
                children: [
                  Text('Выдано: ${_fmtDate(a.createdAt)}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  if (a.expiresAt != null) Text('Истекает: ${_fmtDate(a.expiresAt)}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  if (a.issuedBy != null) Text('by user #${a.issuedBy}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
              ),
            ),
            // Reason
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(a.reason, style: TextStyle(fontSize: 14, color: c.text, height: 1.4)),
            ),
            // Internal note
            if (a.internalNote != null && a.internalNote!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                child: Text('Внутренняя заметка: ${a.internalNote}', style: TextStyle(fontSize: 13, color: c.text)),
              ),
            // Revoke reason
            if (a.revokeReason != null && a.revokeReason!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Причина отзыва: «${a.revokeReason}»', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: c.textSecondary)),
              ),
            // Revoke form
            if (_revokeForId == a.id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _revokeReasonCtrl,
                        style: TextStyle(fontSize: 13, color: c.text),
                        decoration: InputDecoration(
                          hintText: 'Причина отзыва...',
                          hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                          filled: true, fillColor: c.bg, isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _revokeAction(a.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Отозвать', style: TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() { _revokeForId = null; _revokeReasonCtrl.clear(); }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
                        child: Text('Отмена', style: TextStyle(fontSize: 12, color: c.text)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
