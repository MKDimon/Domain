import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../data/api/users_api.dart';
import '../../../data/api/sessions_api.dart';
import '../../../data/api/dm_api.dart';
import '../../../data/models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';

class SecurityTab extends ConsumerStatefulWidget {
  const SecurityTab({super.key});

  @override
  ConsumerState<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends ConsumerState<SecurityTab> {
  // Password
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _changingPassword = false;
  String? _passwordError;
  bool _passwordSuccess = false;
  bool _showPasswordForm = false;

  // OAuth
  List<_OAuthAccount> _oauthAccounts = [];
  bool _oauthLoading = true;

  // Sessions
  List<UserSession>? _sessions;
  bool _loadingSessions = true;
  bool _revokingAll = false;

  // Blocked
  List<_BlockedUser> _blockedUsers = [];
  bool _blockedLoading = true;

  // Export
  bool _exporting = false;
  String? _exportError;

  // Delete
  bool _showDeleteConfirm = false;
  final _deleteConfirmController = TextEditingController();
  bool _deleting = false;
  String? _deleteError;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadOAuth();
    _loadBlocked();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    _deleteConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final api = SessionsApi(ref.read(apiClientProvider));
      final sessions = await api.list();
      if (mounted) setState(() { _sessions = sessions; _loadingSessions = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  Future<void> _loadOAuth() async {
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>('/users/me/oauth-accounts');
      final items = data['items'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _oauthAccounts = items.map((e) => _OAuthAccount.fromJson(e as Map<String, dynamic>)).toList();
          _oauthLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _oauthLoading = false);
    }
  }

  Future<void> _loadBlocked() async {
    try {
      final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>('/users/me/blocks');
      final items = data['items'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _blockedUsers = items.map((e) => _BlockedUser.fromJson(e as Map<String, dynamic>)).toList();
          _blockedLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _blockedLoading = false);
    }
  }

  Future<void> _unlinkOAuth(String provider) async {
    try {
      await ref.read(apiClientProvider).delete('/users/me/oauth/$provider');
      _loadOAuth();
    } catch (_) {}
  }

  Future<void> _unblock(int userId) async {
    try {
      await DmApi(ref.read(apiClientProvider)).unblockUser(userId);
      _loadBlocked();
    } catch (_) {}
  }

  Future<void> _changePassword() async {
    if (_changingPassword) return;
    final oldPw = _oldPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirm = _confirmController.text;

    if (oldPw.isEmpty || newPw.isEmpty) {
      setState(() => _passwordError = 'Заполните все поля');
      return;
    }
    if (newPw != confirm) {
      setState(() => _passwordError = 'Пароли не совпадают');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _passwordError = 'Минимум 6 символов');
      return;
    }

    setState(() { _changingPassword = true; _passwordError = null; _passwordSuccess = false; });

    try {
      final api = UsersApi(ref.read(apiClientProvider));
      await api.changePassword(oldPw, newPw);
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmController.clear();
      setState(() { _passwordSuccess = true; _showPasswordForm = false; });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _passwordSuccess = false);
      });
    } on ApiException catch (e) {
      setState(() => _passwordError = e.message);
    } catch (_) {
      setState(() => _passwordError = 'Не удалось сменить пароль');
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _revokeSession(String id) async {
    final confirmed = await _confirmDialog('Завершить сессию?', 'Устройство будет разлогинено.');
    if (confirmed != true) return;
    try {
      final api = SessionsApi(ref.read(apiClientProvider));
      await api.revoke(id);
      _loadSessions();
    } catch (_) {}
  }

  Future<void> _revokeAllSessions() async {
    final confirmed = await _confirmDialog('Завершить все сессии?', 'Вы будете разлогинены на всех устройствах.');
    if (confirmed != true) return;
    setState(() => _revokingAll = true);
    try {
      final api = SessionsApi(ref.read(apiClientProvider));
      await api.revokeAll();
      if (mounted) {
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.goNamed('main');
      }
    } catch (_) {
      if (mounted) setState(() => _revokingAll = false);
    }
  }

  Future<void> _exportData() async {
    setState(() { _exporting = true; _exportError = null; });
    try {
      final api = UsersApi(ref.read(apiClientProvider));
      await api.exportMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные отправлены на email')),
        );
      }
    } catch (_) {
      setState(() => _exportError = 'Не удалось экспортировать');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_deleteConfirmController.text != user.username) {
      setState(() => _deleteError = 'Введите имя пользователя для подтверждения');
      return;
    }
    setState(() { _deleting = true; _deleteError = null; });
    try {
      final api = UsersApi(ref.read(apiClientProvider));
      await api.deleteMe();
      if (mounted) {
        await ref.read(authProvider.notifier).logout();
        if (mounted) context.goNamed('main');
      }
    } catch (_) {
      setState(() => _deleteError = 'Не удалось удалить аккаунт');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<bool?> _confirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Безопасность', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Пароль, подключённые аккаунты и сессии', style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color)),
          const SizedBox(height: 24),

          // Password
          _card(theme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Смена пароля', style: _cardTitleStyle(theme)),
              const SizedBox(height: 4),
              Text('Рекомендуем использовать надёжный пароль', style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
              if (_passwordSuccess)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                      border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Пароль успешно изменён', style: TextStyle(color: Color(0xFF2ECC71), fontSize: 14)),
                  ),
                ),
              if (!_showPasswordForm) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _showPasswordForm = true),
                  child: const Text('Изменить пароль'),
                ),
              ] else ...[
                const SizedBox(height: 16),
                _inputField('Текущий пароль', _oldPasswordController, obscure: true),
                const SizedBox(height: 12),
                _inputField('Новый пароль', _newPasswordController, obscure: true),
                const SizedBox(height: 12),
                _inputField('Подтвердите пароль', _confirmController, obscure: true, onSubmitted: (_) => _changePassword()),
                if (_passwordError != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(_passwordError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => setState(() { _showPasswordForm = false; _passwordError = null; }),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _changingPassword ? null : _changePassword,
                      child: _changingPassword
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ],
          )),
          const SizedBox(height: 16),

          // OAuth
          _card(theme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Привязанные аккаунты', style: _cardTitleStyle(theme)),
              const SizedBox(height: 4),
              Text('Вход через внешние сервисы', style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
              const SizedBox(height: 16),
              if (_oauthLoading)
                const Center(child: CircularProgressIndicator())
              else
                ...['vk', 'yandex', 'google'].map((provider) {
                  final account = _oauthAccounts.cast<_OAuthAccount?>().firstWhere((a) => a!.provider == provider, orElse: () => null);
                  return _oauthRow(theme, provider, account);
                }),
            ],
          )),
          const SizedBox(height: 16),

          // Sessions
          _card(theme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Активные сессии', style: _cardTitleStyle(theme))),
                  if (_sessions != null && _sessions!.length > 1)
                    TextButton(
                      onPressed: _revokingAll ? null : _revokeAllSessions,
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      child: const Text('Завершить все', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingSessions)
                const Center(child: CircularProgressIndicator())
              else if (_sessions == null || _sessions!.isEmpty)
                Text('Нет активных сессий', style: theme.textTheme.bodySmall)
              else
                ..._sessions!.map((s) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.devices, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.userAgent.isEmpty ? 'Неизвестное устройство' : s.userAgent,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 12,
                              children: [
                                Text(s.ipAddress, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                                Text(
                                  s.lastUsedAt != null && DateTime.tryParse(s.lastUsedAt!) != null
                                      ? timeAgo(DateTime.parse(s.lastUsedAt!))
                                      : 'никогда',
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: theme.colorScheme.error),
                        onPressed: () => _revokeSession(s.id),
                        tooltip: 'Завершить',
                      ),
                    ],
                  ),
                )),
            ],
          )),
          const SizedBox(height: 16),

          // Export
          _card(theme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Экспорт данных', style: _cardTitleStyle(theme)),
              const SizedBox(height: 4),
              Text('Скачайте копию ваших данных в формате JSON', style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
              const SizedBox(height: 12),
              if (_exportError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_exportError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                ),
              OutlinedButton(
                onPressed: _exporting ? null : _exportData,
                child: _exporting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Экспортировать'),
              ),
            ],
          )),
          const SizedBox(height: 16),

          // Blocked users
          _card(theme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Заблокированные пользователи', style: _cardTitleStyle(theme)),
              const SizedBox(height: 12),
              if (_blockedLoading)
                const Center(child: CircularProgressIndicator())
              else if (_blockedUsers.isEmpty)
                Text('Нет заблокированных пользователей', style: theme.textTheme.bodySmall)
              else
                ..._blockedUsers.map((u) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: avatarColor(u.id),
                        backgroundImage: u.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(u.avatarUrl!)) : null,
                        child: u.avatarUrl?.isNotEmpty != true
                            ? Text(u.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(u.displayName ?? u.username, style: const TextStyle(fontSize: 14))),
                      OutlinedButton(
                        onPressed: () => _unblock(u.id),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Разблокировать', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )),
            ],
          )),
          const SizedBox(height: 16),

          // Delete account
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: const Color(0xFFEB5757).withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [const Color(0xFFEB5757).withValues(alpha: 0.04), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Удаление аккаунта', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.error)),
                const SizedBox(height: 4),
                Text('Это действие необратимо. Все данные будут удалены.', style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
                const SizedBox(height: 12),
                if (!_showDeleteConfirm)
                  OutlinedButton(
                    onPressed: () => setState(() => _showDeleteConfirm = true),
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    child: const Text('Удалить аккаунт'),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Введите "${user?.username}" для подтверждения:',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _deleteConfirmController,
                          decoration: const InputDecoration(isDense: true),
                        ),
                        if (_deleteError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_deleteError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => setState(() { _showDeleteConfirm = false; _deleteError = null; }),
                              child: const Text('Отмена'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _deleting ? null : _deleteAccount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: Colors.white,
                              ),
                              child: _deleting
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Удалить навсегда'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  TextStyle _cardTitleStyle(ThemeData theme) =>
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color);

  Widget _inputField(String label, TextEditingController controller, {bool obscure = false, ValueChanged<String>? onSubmitted}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: const InputDecoration(isDense: true),
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }

  Widget _oauthRow(ThemeData theme, String provider, _OAuthAccount? account) {
    final name = switch (provider) { 'vk' => 'VK ID', 'yandex' => 'Яндекс ID', 'google' => 'Google', _ => provider };
    final linked = account != null;
    final statusText = linked
        ? account.providerEmail.isNotEmpty ? account.providerEmail : 'Привязан'
        : 'Не привязан';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(
        children: [
          _oauthIcon(provider, theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 2),
                Text(statusText, style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
          if (linked)
            OutlinedButton(
              onPressed: () => _unlinkOAuth(provider),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Отвязать', style: TextStyle(fontSize: 13)),
            )
          else
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Привязка через браузер — скоро')),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Привязать', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _oauthIcon(String provider, ThemeData theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: switch (provider) {
          'vk' => const Color(0xFF0077FF),
          'yandex' => Colors.transparent,
          'google' => Colors.white,
          _ => theme.colorScheme.surface,
        },
        borderRadius: BorderRadius.circular(8),
        border: provider == 'google' ? Border.all(color: theme.dividerColor) : null,
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(painter: _OAuthIconPainter(provider)),
        ),
      ),
    );
  }
}

class _OAuthAccount {
  final String provider;
  final String providerEmail;
  final String createdAt;

  _OAuthAccount({required this.provider, required this.providerEmail, required this.createdAt});

  factory _OAuthAccount.fromJson(Map<String, dynamic> json) => _OAuthAccount(
    provider: json['provider'] as String? ?? '',
    providerEmail: json['provider_email'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
  );
}

class _BlockedUser {
  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  _BlockedUser({required this.id, required this.username, this.displayName, this.avatarUrl});

  factory _BlockedUser.fromJson(Map<String, dynamic> json) => _BlockedUser(
    id: json['id'] as int,
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}

class _OAuthIconPainter extends CustomPainter {
  final String provider;
  _OAuthIconPainter(this.provider);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s, s);

    switch (provider) {
      case 'vk':
        _paintVk(canvas);
      case 'yandex':
        _paintYandex(canvas);
      case 'google':
        _paintGoogle(canvas);
    }

    canvas.restore();
  }

  void _paintVk(Canvas canvas) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(2.6, 2.6)
      ..cubicTo(1, 4.2, 1, 6.7, 1, 11.7)
      ..lineTo(1, 12.3)
      ..cubicTo(1, 17.3, 1, 19.8, 2.6, 21.4)
      ..cubicTo(4.2, 23, 6.7, 23, 11.7, 23)
      ..lineTo(12.3, 23)
      ..cubicTo(17.3, 23, 19.8, 23, 21.4, 21.4)
      ..cubicTo(23, 19.8, 23, 17.3, 23, 12.3)
      ..lineTo(23, 11.7)
      ..cubicTo(23, 6.7, 23, 4.2, 21.4, 2.6)
      ..cubicTo(19.8, 1, 17.3, 1, 12.3, 1)
      ..lineTo(11.7, 1)
      ..cubicTo(6.7, 1, 4.2, 1, 2.6, 2.6)
      ..close()
      ..moveTo(5.2, 7.2)
      ..lineTo(7.9, 7.2)
      ..cubicTo(8, 11.6, 9.9, 13.5, 11.5, 13.9)
      ..lineTo(11.5, 7.2)
      ..lineTo(14, 7.2)
      ..lineTo(14, 11.1)
      ..cubicTo(15.5, 10.9, 17.2, 9.2, 17.7, 7.2)
      ..lineTo(20.2, 7.2)
      ..cubicTo(19.7, 9.7, 18, 11.4, 16.8, 12.1)
      ..cubicTo(18, 12.7, 19.9, 14.2, 20.7, 17)
      ..lineTo(17.9, 17)
      ..cubicTo(17.3, 15.1, 15.8, 13.6, 14, 13.3)
      ..lineTo(14, 17)
      ..lineTo(13.7, 17)
      ..cubicTo(8.7, 17, 5.8, 13.6, 5.7, 7.8)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintYandex(Canvas canvas) {
    final circlePaint = Paint()..color = const Color(0xFFFC3F1D);
    canvas.drawCircle(const Offset(12, 12), 11, circlePaint);

    final textPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(13.6, 18.5)
      ..lineTo(15.8, 18.5)
      ..lineTo(15.8, 5.5)
      ..lineTo(12.6, 5.5)
      ..cubicTo(9.4, 5.5, 7.7, 7.1, 7.7, 9.5)
      ..cubicTo(7.7, 11.4, 8.6, 12.6, 10.2, 13.7)
      ..lineTo(7.4, 18.5)
      ..lineTo(9.8, 18.5)
      ..lineTo(13, 13)
      ..lineTo(11.9, 12.2)
      ..cubicTo(10.6, 11.3, 10, 10.6, 10, 9.1)
      ..cubicTo(10, 7.8, 10.9, 6.9, 12.6, 6.9)
      ..lineTo(13.6, 6.9)
      ..close();
    canvas.drawPath(path, textPaint);
  }

  void _paintGoogle(Canvas canvas) {
    // Red
    final red = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12, 5)
      ..cubicTo(13.6, 5, 15.1, 5.6, 16.2, 6.6)
      ..lineTo(19.5, 3.4)
      ..cubicTo(17.4, 1.5, 14.9, 0.5, 12, 0.5)
      ..cubicTo(7.4, 0.5, 3.4, 3.1, 1.4, 7)
      ..lineTo(5.1, 9.9)
      ..cubicTo(6, 7.1, 8.7, 5, 12, 5)
      ..close();
    canvas.drawPath(redPath, red);

    // Blue
    final blue = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.5, 12.3)
      ..cubicTo(23.5, 11.5, 23.4, 10.8, 23.3, 10)
      ..lineTo(12, 10)
      ..lineTo(12, 14.5)
      ..lineTo(18.5, 14.5)
      ..cubicTo(18.2, 16, 17.4, 17.3, 16.1, 18.2)
      ..lineTo(19.7, 21)
      ..cubicTo(21.8, 19, 23, 16.1, 23, 12.3)
      ..close();
    // Adjust for viewBox starting at 0
    canvas.drawPath(bluePath, blue);

    // Yellow
    final yellow = Paint()..color = const Color(0xFFFBBC04);
    final yellowPath = Path()
      ..moveTo(5.1, 14.1)
      ..cubicTo(4.8, 13.3, 4.7, 12.5, 4.7, 11.5)
      ..cubicTo(4.7, 10.6, 4.9, 9.7, 5.1, 8.9)
      ..lineTo(1.4, 6)
      ..cubicTo(0.4, 8, -0.1, 10.1, -0.1, 12.5)
      ..cubicTo(-0.1, 14.9, 0.4, 17, 1.4, 19)
      ..lineTo(5.2, 16.1)
      ..close();
    canvas.drawPath(yellowPath, yellow);

    // Green
    final green = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12, 23.5)
      ..cubicTo(15.2, 23.5, 17.9, 22.4, 19.9, 20.6)
      ..lineTo(16.3, 17.8)
      ..cubicTo(15.3, 18.5, 14, 18.9, 12, 18.9)
      ..cubicTo(8.7, 18.9, 6, 16.8, 5, 13.9)
      ..lineTo(1.2, 16.8)
      ..cubicTo(3.2, 20.8, 7.2, 23.5, 12, 23.5)
      ..close();
    canvas.drawPath(greenPath, green);
  }

  @override
  bool shouldRepaint(covariant _OAuthIconPainter old) => old.provider != provider;
}
