import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../data/api/notifications_api.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;
  bool _unreadOnly = false;
  int _unreadCount = 0;
  final _readTimers = <int, Timer>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _readTimers.values) { t.cancel(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = NotificationsApi(ref.read(apiClientProvider));
      final items = await api.list(limit: 50, unreadOnly: _unreadOnly);
      final count = await api.unreadCount();
      if (mounted) {
        setState(() { _notifications = items; _unreadCount = count; _loading = false; });
        _scheduleAutoRead();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleAutoRead() {
    for (final n in _notifications) {
      if (n.isRead || n.type == 'invite_received') continue;
      if (_readTimers.containsKey(n.id)) continue;
      _readTimers[n.id] = Timer(const Duration(seconds: 2), () => _markRead(n.id));
    }
  }

  Future<void> _markRead(int id) async {
    _readTimers.remove(id);
    try {
      await NotificationsApi(ref.read(apiClientProvider)).markRead(id);
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n.id == id);
          if (idx >= 0) {
            _notifications[idx] = AppNotification(
              id: _notifications[idx].id,
              type: _notifications[idx].type,
              payload: _notifications[idx].payload,
              readAt: DateTime.now().toIso8601String(),
              createdAt: _notifications[idx].createdAt,
            );
            _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationsApi(ref.read(apiClientProvider)).markAllRead();
      _load();
    } catch (_) {}
  }

  void _onTap(AppNotification n) {
    final p = n.payload;
    switch (n.type) {
      case 'chat_mention' || 'chat_reply':
        final slug = p['community_slug'] as String?;
        if (slug != null) context.goNamed('community', pathParameters: {'slug': slug});
      case 'invite_received':
        break; // handled by accept/reject buttons
      case 'friend_request' || 'friend_accepted':
        context.goNamed('profile');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Уведомления'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Прочитать все', style: TextStyle(color: c.accent, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _FilterChip(label: 'Все', selected: !_unreadOnly, c: c, onTap: () { _unreadOnly = false; _load(); }),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Непрочитанные${_unreadCount > 0 ? ' ($_unreadCount)' : ''}',
                  selected: _unreadOnly, c: c,
                  onTap: () { _unreadOnly = true; _load(); },
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.accent))
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 48, color: c.success.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text('Нет уведомлений', style: TextStyle(color: c.textSecondary, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return _NotificationItem(notification: n, c: c, onTap: () => _onTap(n));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final ColorSet c;
  final VoidCallback onTap;
  const _NotificationItem({required this.notification, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final icon = _iconForType(n.type);
    final iconColor = _colorForType(n.type, c);
    final title = _titleForNotification(n);
    final body = _bodyForNotification(n);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!n.isRead)
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 6, right: 8),
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              )
            else
              const SizedBox(width: 16),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600, color: c.text)),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(body, style: TextStyle(fontSize: 13, color: c.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      n.createdAt.isNotEmpty ? timeAgo(DateTime.parse(n.createdAt)) : '',
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
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

  IconData _iconForType(String type) => switch (type) {
    'invite_received' => Icons.mail_outline,
    'chat_mention' => Icons.alternate_email,
    'chat_reply' => Icons.reply,
    'friend_request' => Icons.person_add_outlined,
    'friend_accepted' => Icons.people_outline,
    'moderation_warning_issued' => Icons.warning_amber,
    'moderation_muted' || 'moderation_banned' => Icons.block,
    'moderation_action_revoked' => Icons.undo,
    _ => Icons.notifications_outlined,
  };

  Color _colorForType(String type, ColorSet c) => switch (type) {
    'invite_received' => c.accent,
    'chat_mention' || 'chat_reply' => c.success,
    'friend_request' || 'friend_accepted' => c.accent,
    'moderation_warning_issued' => c.warning,
    'moderation_muted' || 'moderation_banned' => c.error,
    'moderation_action_revoked' => c.success,
    _ => c.textSecondary,
  };

  String _name(Map<String, dynamic> p, String displayKey, String usernameKey) {
    final display = p[displayKey] as String?;
    if (display != null && display.isNotEmpty) return display;
    final username = p[usernameKey] as String?;
    if (username != null && username.isNotEmpty) return username;
    return 'Кто-то';
  }

  String _titleForNotification(AppNotification n) {
    final p = n.payload;
    return switch (n.type) {
      'invite_received' => '${_name(p, 'inviter_display_name', 'inviter_username')} приглашает в ${p['community_name'] ?? 'сообщество'}',
      'chat_mention' => '${_name(p, 'sender_display_name', 'sender_username')} упомянул вас',
      'chat_reply' => '${_name(p, 'sender_display_name', 'sender_username')} ответил на ваше сообщение',
      'friend_request' => '${_name(p, 'sender_display_name', 'sender_username')} хочет добавить вас в друзья',
      'friend_accepted' => '${_name(p, 'other_display_name', 'other_username')} принял вашу заявку в друзья',
      'moderation_warning_issued' => 'Вам вынесено предупреждение',
      'moderation_muted' => 'Вы заглушены',
      'moderation_banned' => 'Вы заблокированы',
      'moderation_action_revoked' => 'Санкция отменена',
      _ => 'Уведомление',
    };
  }

  String _bodyForNotification(AppNotification n) {
    final p = n.payload;
    return switch (n.type) {
      'chat_mention' || 'chat_reply' => p['preview'] as String? ?? '',
      'moderation_warning_issued' || 'moderation_muted' || 'moderation_banned' => p['reason'] as String? ?? '',
      'moderation_action_revoked' => p['revoke_reason'] as String? ?? '',
      _ => '',
    };
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorSet c;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.12) : c.surfaceAlt,
          border: Border.all(color: selected ? c.accent : c.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? c.accent : c.text)),
      ),
    );
  }
}
