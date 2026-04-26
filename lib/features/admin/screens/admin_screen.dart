import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/permissions.dart';
import '../../../providers/auth_provider.dart';
import '../tabs/admin_overview_tab.dart';
import '../tabs/admin_analytics_tab.dart';
import '../tabs/admin_users_tab.dart';
import '../tabs/admin_communities_tab.dart';
import '../tabs/admin_pages_tab.dart';
import '../tabs/admin_categories_tab.dart';
import '../tabs/admin_complaints_tab.dart';
import '../tabs/admin_appeals_tab.dart';
import '../tabs/admin_plugins_tab.dart';
import '../tabs/admin_settings_tab.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final Permission? permission;
  final int? badgeCount;
  const _NavItem({required this.icon, required this.label, this.permission, this.badgeCount});
}

class _NavGroup {
  final String title;
  final List<_NavItem> items;
  const _NavGroup({required this.title, required this.items});
}

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _selectedIndex = 0;

  static const _groups = [
    _NavGroup(title: 'Обзор', items: [
      _NavItem(icon: Icons.analytics_outlined, label: 'Аналитика', permission: Permission.viewAnalytics),
    ]),
    _NavGroup(title: 'Управление', items: [
      _NavItem(icon: Icons.people_outline, label: 'Пользователи', permission: Permission.manageUsers),
      _NavItem(icon: Icons.groups_outlined, label: 'Сообщества', permission: Permission.manageCommunities),
      _NavItem(icon: Icons.article_outlined, label: 'Страницы', permission: Permission.managePages),
      _NavItem(icon: Icons.category_outlined, label: 'Категории', permission: Permission.manageCategories),
      _NavItem(icon: Icons.report_outlined, label: 'Жалобы', permission: Permission.manageComplaints),
      _NavItem(icon: Icons.gavel_outlined, label: 'Обжалования', permission: Permission.manageComplaints),
    ]),
    _NavGroup(title: 'Система', items: [
      _NavItem(icon: Icons.extension_outlined, label: 'Плагины', permission: Permission.managePlugins),
      _NavItem(icon: Icons.settings_outlined, label: 'Настройки', permission: Permission.manageSettings),
    ]),
  ];

  List<_NavItem> get _visibleItems {
    final auth = ref.read(authProvider);
    final items = <_NavItem>[];
    for (final group in _groups) {
      for (final item in group.items) {
        if (item.permission == null || auth.hasPermission(item.permission!)) {
          items.add(item);
        }
      }
    }
    return items;
  }

  Widget _buildContent(int index, ColorSet c) {
    final items = _visibleItems;
    if (index >= items.length) {
      return Center(child: Text('—', style: TextStyle(color: c.textSecondary)));
    }
    final label = items[index].label;
    return switch (label) {
      'Аналитика' => AdminAnalyticsTab(c: c, ref: ref),
      'Пользователи' => AdminUsersTab(c: c, ref: ref),
      'Сообщества' => AdminCommunitiesTab(c: c, ref: ref),
      'Страницы' => AdminPagesTab(c: c, ref: ref),
      'Категории' => AdminCategoriesTab(c: c, ref: ref),
      'Жалобы' => AdminComplaintsTab(c: c, ref: ref),
      'Обжалования' => AdminAppealsTab(c: c, ref: ref),
      'Плагины' => AdminPluginsTab(c: c, ref: ref),
      'Настройки' => AdminSettingsTab(c: c, ref: ref),
      _ => AdminOverviewTab(c: c, ref: ref),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final auth = ref.watch(authProvider);

    if (auth.user == null || !auth.user!.isAdmin) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: Text('Доступ запрещён', style: TextStyle(color: c.error))),
      );
    }

    final items = _visibleItems;
    if (_selectedIndex >= items.length) _selectedIndex = 0;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Row(
          children: [
            _AdminSidebar(
              groups: _groups,
              selectedIndex: _selectedIndex,
              c: c,
              auth: auth,
              onSelect: (i) => setState(() => _selectedIndex = i),
            ),
            VerticalDivider(width: 1, thickness: 1, color: c.border),
            Expanded(
              child: _buildContent(_selectedIndex, c),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          _AdminMobileNav(
            items: items,
            selectedIndex: _selectedIndex,
            c: c,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),
          Expanded(child: _buildContent(_selectedIndex, c)),
        ],
      ),
    );
  }
}

// ─── Desktop Sidebar ──────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final List<_NavGroup> groups;
  final int selectedIndex;
  final ColorSet c;
  final AuthState auth;
  final ValueChanged<int> onSelect;

  const _AdminSidebar({
    required this.groups,
    required this.selectedIndex,
    required this.c,
    required this.auth,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    int flatIndex = 0;
    final children = <Widget>[];

    for (final group in groups) {
      final groupItems = group.items.where(
        (i) => i.permission == null || auth.hasPermission(i.permission!),
      ).toList();
      if (groupItems.isEmpty) continue;

      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          group.title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ));

      for (final item in groupItems) {
        final idx = flatIndex;
        children.add(_SidebarItem(
          icon: item.icon,
          label: item.label,
          selected: selectedIndex == idx,
          badgeCount: item.badgeCount,
          c: c,
          onTap: () => onSelect(idx),
        ));
        flatIndex++;
      }
    }

    return Container(
      width: 240,
      color: c.surfaceAlt,
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Text(
              'Админ-панель',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int? badgeCount;
  final ColorSet c;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.badgeCount,
    required this.c,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? c.accent
                : (_hovered ? c.hoverOverlay : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: widget.selected ? Colors.white : c.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.selected ? Colors.white : c.text,
                  ),
                ),
              ),
              if (widget.badgeCount != null && widget.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Nav ───────────────────────────────────────────────────

class _AdminMobileNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ColorSet c;
  final ValueChanged<int> onSelect;

  const _AdminMobileNav({
    required this.items,
    required this.selectedIndex,
    required this.c,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, i) {
          final item = items[i];
          final selected = selectedIndex == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: selected ? Colors.white : c.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white : c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
