import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

class AdminOverviewTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminOverviewTab({super.key, required this.c, required this.ref});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  PlatformStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = AdminApi(widget.ref.read(apiClientProvider));
      final stats = await api.stats();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (_loading) return Center(child: CircularProgressIndicator(color: c.accent));

    final stats = _stats;
    if (stats == null) {
      return Center(child: Text('Не удалось загрузить статистику', style: TextStyle(color: c.textSecondary)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Обзор платформы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 600 ? 5 : (constraints.maxWidth > 400 ? 3 : 2);
            final spacing = 16.0;
            final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCard(title: 'Пользователи', value: stats.userCount, color: c.accent, c: c, width: itemWidth),
                _StatCard(title: 'Администраторы', value: stats.adminCount, color: c.warning, c: c, width: itemWidth),
                _StatCard(title: 'Заблокированы', value: stats.bannedCount, color: c.error, c: c, width: itemWidth),
                _StatCard(title: 'Сообщества', value: stats.communityCount, color: c.success, c: c, width: itemWidth),
                _StatCard(title: 'Страницы', value: stats.pageCount, color: c.accent, c: c, width: itemWidth),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final ColorSet c;
  final double width;
  const _StatCard({required this.title, required this.value, required this.color, required this.c, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      ),
    );
  }
}
