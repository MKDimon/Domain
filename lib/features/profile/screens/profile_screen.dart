import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/user.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import 'account_tab.dart';
import 'security_tab.dart';
import 'friends_tab.dart';
import 'notifications_tab.dart';
import 'communities_tab.dart';
import 'calls_tab.dart';
import 'violations_tab.dart';
import '../../billing/widgets/tier_badge.dart';
import '../../billing/screens/billing_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedTab = 0;

  static const _tabs = [
    _TabItem(icon: Icons.person_outline, label: 'Аккаунт'),
    _TabItem(icon: Icons.grid_view_outlined, label: 'Сообщества'),
    _TabItem(icon: Icons.people_outline, label: 'Друзья'),
    _TabItem(icon: Icons.payment_outlined, label: 'Оплата'),
    _TabItem(icon: Icons.notifications_outlined, label: 'Уведомления'),
    _TabItem(icon: Icons.phone_outlined, label: 'Звонки'),
    _TabItem(icon: Icons.shield_outlined, label: 'Безопасность'),
    _TabItem(icon: Icons.warning_amber_outlined, label: 'Нарушения'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Вы не авторизованы'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.goNamed('login'),
                child: const Text('Войти'),
              ),
            ],
          ),
        ),
      );
    }

    final content = _buildTabContent();

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Профиль'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 240,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildUserCard(user, theme),
                            const SizedBox(height: 12),
                            _buildNav(theme),
                            const SizedBox(height: 24),
                            if (user.isAdmin) _buildAdminButton(theme),
                            _buildLogoutButton(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Профиль'),
        actions: [
          if (user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Админ-панель',
              onPressed: () => context.goNamed('admin'),
            ),
          IconButton(
            icon: Icon(Icons.logout, color: theme.colorScheme.error),
            tooltip: 'Выйти',
            onPressed: () => _confirmLogout(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMobileHeader(user, theme),
          _buildMobileTabBar(theme),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: avatarColor(user.id),
            backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(user.avatarUrl)) : null,
            child: user.avatarUrl.isEmpty
                ? Text(user.initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))
                : null,
          ),
          const SizedBox(height: 8),
          Text(user.username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text(user.email, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              TierBadge(tier: user.subscription?.tier ?? 'free'),
              if (user.isAdmin) _badge(user.isSuperAdmin ? 'Super Admin' : 'Admin', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Widget _buildNav(ThemeData theme) {
    return Column(
      children: List.generate(_tabs.length, (i) {
        final tab = _tabs[i];
        final selected = _selectedTab == i;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Material(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _selectedTab = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Icon(tab.icon, size: 16, color: selected ? Colors.white : theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 10),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected ? Colors.white : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMobileHeader(User user, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: avatarColor(user.id),
            backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(user.avatarUrl)) : null,
            child: user.avatarUrl.isEmpty
                ? Text(user.initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(user.email, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabBar(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          final tab = _tabs[i];
          final selected = _selectedTab == i;
          return FilterChip(
            selected: selected,
            label: Text(tab.label),
            avatar: Icon(tab.icon, size: 16),
            onSelected: (_) => setState(() => _selectedTab = i),
          );
        },
      ),
    );
  }

  Widget _buildTabContent() {
    return switch (_selectedTab) {
      0 => const AccountTab(),
      1 => const CommunitiesTab(),
      2 => const FriendsTab(),
      3 => const BillingScreen(),
      4 => const NotificationsTab(),
      5 => const CallsTab(),
      6 => const SecurityTab(),
      7 => const ViolationsTab(),
      _ => const SizedBox(),
    };
  }

  Future<void> _confirmLogout() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Выход из аккаунта', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text('Вы уверены, что хотите выйти?', style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color, height: 1.5)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Отмена', style: TextStyle(color: theme.colorScheme.onSurface)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Выйти'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.goNamed('main');
    }
  }

  Widget _buildAdminButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.goNamed('admin'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 16, color: Colors.amber),
                const SizedBox(width: 10),
                Text('Админ-панель', style: TextStyle(fontSize: 14, color: Colors.amber)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _confirmLogout(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(Icons.logout, size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Text('Выйти', style: TextStyle(fontSize: 14, color: theme.colorScheme.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}
