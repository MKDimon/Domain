import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/admin_api.dart';
import '../widgets/admin_confirm_dialog.dart';
import '../widgets/admin_moderation_dialog.dart';

class AdminUsersTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminUsersTab({super.key, required this.c, required this.ref});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  List<AdminUser> _users = [];
  Pagination? _pagination;
  bool _loading = true;
  int _page = 1;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _api.listUsers(
        page: _page,
        limit: 20,
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      );
      if (mounted) {
        setState(() {
          _users = result.items;
          _pagination = result.pagination;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _page = 1;
      _load();
    });
  }

  void _goToPage(int page) {
    _page = page;
    _load();
  }

  Future<void> _toggleBan(AdminUser user) async {
    final action = user.isBanned ? 'Разблокировать' : 'Заблокировать';
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: '$action пользователя?',
      message: '${user.effectiveName} будет ${user.isBanned ? "разблокирован" : "заблокирован"}.',
      confirmText: action,
      isDanger: !user.isBanned,
    );
    if (!confirmed) return;
    try {
      await _api.updateUser(user.id, {'is_banned': !user.isBanned});
      _load();
    } catch (_) {}
  }

  Future<void> _editUser(AdminUser user) async {
    final roleCtrl = TextEditingController(text: user.role);
    final limitCtrl = TextEditingController(text: '${user.communityLimit}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = widget.c;
        return Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Редактировать пользователя', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 16),
                Text('Роль', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: roleCtrl.text,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    filled: true, fillColor: c.bg, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  dropdownColor: c.surface,
                  style: TextStyle(fontSize: 14, color: c.text),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(value: 'super_admin', child: Text('super_admin')),
                  ],
                  onChanged: (v) => roleCtrl.text = v ?? 'user',
                ),
                const SizedBox(height: 12),
                Text('Лимит сообществ', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14, color: c.text),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    filled: true, fillColor: c.bg, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Отмена', style: TextStyle(color: c.text)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: Colors.white),
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved != true) return;
    final updates = <String, dynamic>{};
    if (roleCtrl.text != user.role) updates['role'] = roleCtrl.text;
    final newLimit = int.tryParse(limitCtrl.text) ?? user.communityLimit;
    if (newLimit != user.communityLimit) updates['community_limit'] = newLimit;
    if (updates.isNotEmpty) {
      try {
        await _api.updateUser(user.id, updates);
        _load();
      } catch (_) {}
    }
    roleCtrl.dispose();
    limitCtrl.dispose();
  }

  Future<void> _grantSubscription(AdminUser user) async {
    final daysCtrl = TextEditingController(text: '30');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = widget.c;
        return Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Подписка: ${user.effectiveName}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 16),
                Text('Дней Pro', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14, color: c.text),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    filled: true, fillColor: c.bg, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, 'revoke'),
                        style: OutlinedButton.styleFrom(foregroundColor: c.error, side: BorderSide(color: c.error.withValues(alpha: 0.3))),
                        child: const Text('Отозвать'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, 'grant'),
                        style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: Colors.white),
                        child: const Text('Выдать Pro'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) { daysCtrl.dispose(); return; }
    try {
      if (result == 'grant') {
        await _api.grantSubscription(user.id, int.tryParse(daysCtrl.text) ?? 30);
      } else {
        await _api.revokeSubscription(user.id);
      }
      _load();
    } catch (_) {}
    daysCtrl.dispose();
  }

  Future<void> _openModeration(AdminUser user) async {
    final issued = await showAdminModerationDialog(context: context, user: user, api: _api, c: widget.c);
    if (issued) _load();
  }

  Future<void> _revokeModeration(AdminUser user, String type) async {
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: 'Отозвать $type?',
      message: 'Все активные $type для ${user.effectiveName} будут отозваны.',
      confirmText: 'Отозвать',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      final actions = await _api.listUserModeration(user.id);
      for (final a in actions) {
        if (a.actionType == type && a.revokedAt == null) {
          await _api.revokeModeration(a.id);
        }
      }
      _load();
    } catch (_) {}
  }

  String _expiryLabel(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return '';
    if (diff.inDays > 0) return '${diff.inDays}д ${diff.inHours % 24}ч';
    if (diff.inHours > 0) return '${diff.inHours}ч ${diff.inMinutes % 60}м';
    return '${diff.inMinutes}м';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Row(
            children: [
              Text('Пользователи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
              const Spacer(),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  style: TextStyle(fontSize: 14, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Поиск...', hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, size: 18, color: c.textSecondary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    filled: true, fillColor: c.bg, isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : _users.isEmpty
                  ? Center(child: Text('Нет пользователей', style: TextStyle(color: c.textSecondary)))
                  : _buildTable(c),
        ),
        if (_pagination != null && _pagination!.totalPages > 1)
          _buildPagination(c),
      ],
    );
  }

  Widget _buildTable(ColorSet c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.transparent),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          border: TableBorder(horizontalInside: BorderSide(color: c.border)),
          headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.5),
          dataTextStyle: TextStyle(fontSize: 13, color: c.text),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('ИМЯ')),
            DataColumn(label: Text('EMAIL')),
            DataColumn(label: Text('РОЛЬ')),
            DataColumn(label: Text('СТАТУС')),
            DataColumn(label: Text('ЛИМИТ')),
            DataColumn(label: Text('')),
          ],
          rows: _users.map((u) => DataRow(
            color: u.isBanned ? WidgetStateProperty.all(Colors.white.withValues(alpha: 0.02)) : null,
            cells: [
              DataCell(Text('${u.id}')),
              DataCell(
                GestureDetector(
                  onTap: () => context.push('/user/${u.id}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 14, backgroundColor: avatarColor(u.id),
                        backgroundImage: u.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(u.avatarUrl!)) : null,
                        child: u.avatarUrl?.isNotEmpty != true
                            ? Text(u.username.isNotEmpty ? u.username[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 10))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text('@${u.username}', style: TextStyle(color: c.accent, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              DataCell(Text(u.email ?? '')),
              DataCell(_roleBadge(u.role, c)),
              DataCell(_statusCell(u, c)),
              DataCell(Text('${u.communityLimit}')),
              DataCell(_actionsCell(u, c)),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Widget _roleBadge(String role, ColorSet c) {
    final isAdmin = role == 'admin' || role == 'super_admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? c.accent : c.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isAdmin ? Colors.white : c.text),
      ),
    );
  }

  Widget _statusCell(AdminUser u, ColorSet c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          u.isBanned ? 'Заблокирован' : 'Активен',
          style: TextStyle(fontSize: 12, color: u.isBanned ? c.error : c.success),
        ),
        if (u.activeWarningsCount > 0)
          _modPill('⚠ ${u.activeWarningsCount}', c.warning, c, () => _revokeModeration(u, 'warning')),
        if (u.mutedUntil != null && _expiryLabel(u.mutedUntil).isNotEmpty)
          _modPill('🔇 ${_expiryLabel(u.mutedUntil)}', const Color(0xFFC084FC), c, () => _revokeModeration(u, 'mute')),
        if (u.bannedUntil != null && _expiryLabel(u.bannedUntil).isNotEmpty)
          _modPill('🚫 ${_expiryLabel(u.bannedUntil)}', c.error, c, () => _revokeModeration(u, 'ban')),
      ],
    );
  }

  Widget _modPill(String label, Color color, ColorSet c, VoidCallback onRevoke) {
    return GestureDetector(
      onTap: onRevoke,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Widget _actionsCell(AdminUser u, ColorSet c) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: c.textSecondary),
      color: c.surface,
      onSelected: (v) {
        switch (v) {
          case 'edit': _editUser(u);
          case 'tier': _grantSubscription(u);
          case 'action': _openModeration(u);
          case 'ban': _toggleBan(u);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'edit', child: Text('Редактировать', style: TextStyle(fontSize: 13, color: c.text))),
        PopupMenuItem(value: 'tier', child: Text('Подписка', style: TextStyle(fontSize: 13, color: c.text))),
        PopupMenuItem(value: 'action', child: Text('Модерация', style: TextStyle(fontSize: 13, color: c.warning))),
        PopupMenuItem(value: 'ban', child: Text(
          u.isBanned ? 'Разблокировать' : 'Заблокировать',
          style: TextStyle(fontSize: 13, color: u.isBanned ? c.success : c.error),
        )),
      ],
    );
  }

  Widget _buildPagination(ColorSet c) {
    final p = _pagination!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: p.hasPrevious ? c.text : c.textSecondary),
            onPressed: p.hasPrevious ? () => _goToPage(_page - 1) : null,
          ),
          const SizedBox(width: 12),
          Text('${p.currentPage} / ${p.totalPages}', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.chevron_right, color: p.hasNext ? c.text : c.textSecondary),
            onPressed: p.hasNext ? () => _goToPage(_page + 1) : null,
          ),
        ],
      ),
    );
  }
}
