import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../data/api/notifications_api.dart';

class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<NotificationsTab> {
  List<NotificationPref> _prefs = [];
  bool _loading = true;
  String? _error;

  static const _activityKeys = ['community_invite', 'chat_mention', 'message_reply'];
  static const _systemKeys = ['platform_news', 'subscription_ending'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = NotificationsApi(ref.read(apiClientProvider));
      final prefs = await api.listPrefs();
      if (mounted) setState(() { _prefs = prefs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Не удалось загрузить настройки'; });
    }
  }

  Future<void> _toggle(NotificationPref pref, {bool? inApp, bool? email}) async {
    final updated = NotificationPref(
      eventKey: pref.eventKey,
      inApp: inApp ?? pref.inApp,
      email: email ?? pref.email,
    );
    setState(() {
      final idx = _prefs.indexWhere((p) => p.eventKey == pref.eventKey);
      if (idx >= 0) _prefs[idx] = updated;
    });
    try {
      await NotificationsApi(ref.read(apiClientProvider)).updatePref(updated);
    } catch (_) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Уведомления', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Настройте, как вы получаете уведомления', style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color)),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEB5757).withValues(alpha: 0.08),
                border: Border.all(color: const Color(0xFFEB5757).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 16),
          ],

          _buildCard(theme, title: 'Активность', keys: _activityKeys),
          const SizedBox(height: 16),
          _buildCard(theme, title: 'Система', keys: _systemKeys),
        ],
      ),
    );
  }

  Widget _buildCard(ThemeData theme, {required String title, required List<String> keys}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 12),
          ...keys.map((key) => _buildPrefRow(key, theme)),
        ],
      ),
    );
  }

  Widget _buildPrefRow(String eventKey, ThemeData theme) {
    final pref = _prefs.cast<NotificationPref?>().firstWhere((p) => p!.eventKey == eventKey, orElse: () => null);
    final label = _labelForKey(eventKey);
    final hint = _hintForKey(eventKey);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(hint, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleLabel(theme, 'В приложении', pref?.inApp ?? true, (v) {
                if (pref != null) _toggle(pref, inApp: v);
              }),
              const SizedBox(width: 12),
              _toggleLabel(theme, 'Email', pref?.email ?? false, (v) {
                if (pref != null) _toggle(pref, email: v);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleLabel(ThemeData theme, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
        const SizedBox(width: 4),
        SizedBox(
          height: 24,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  String _labelForKey(String key) => switch (key) {
    'community_invite' => 'Приглашения в сообщества',
    'chat_mention' => 'Упоминания в чате',
    'message_reply' => 'Ответы на сообщения',
    'platform_news' => 'Новости платформы',
    'subscription_ending' => 'Окончание подписки',
    _ => key,
  };

  String? _hintForKey(String key) => switch (key) {
    'community_invite' => 'Когда вас приглашают в сообщество',
    'chat_mention' => 'Когда вас упоминают в чате',
    'message_reply' => 'Когда кто-то отвечает на ваше сообщение',
    'platform_news' => 'Новости и обновления платформы',
    'subscription_ending' => 'Напоминание об окончании подписки',
    _ => null,
  };
}
