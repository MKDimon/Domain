import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';
import '../widgets/admin_confirm_dialog.dart';

class AdminPagesTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminPagesTab({super.key, required this.c, required this.ref});

  @override
  State<AdminPagesTab> createState() => _AdminPagesTabState();
}

class _AdminPagesTabState extends State<AdminPagesTab> {
  List<AdminPage> _pages = [];
  bool _loading = true;
  String _visFilter = 'all';
  final _searchCtrl = TextEditingController();

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.listPages(),
        _api.listCommunities(),
      ]);
      _pages = results[0] as List<AdminPage>;
      final comms = results[1] as List<AdminCommunity>;
      final slugMap = {for (final c in comms) c.id: c.slug};
      for (final p in _pages) {
        p.communitySlug ??= slugMap[p.communityId];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<AdminPage> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _pages.where((p) {
      if (_visFilter != 'all' && p.visibility != _visFilter) return false;
      if (q.isNotEmpty) {
        return p.title.toLowerCase().contains(q) ||
            (p.communityName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();
  }

  Map<String, int> get _counts => {
    'all': _pages.length,
    'public': _pages.where((p) => p.visibility == 'public' || p.visibility.isEmpty).length,
    'moderator': _pages.where((p) => p.visibility == 'moderator').length,
    'owner': _pages.where((p) => p.visibility == 'owner').length,
  };

  Future<void> _delete(AdminPage page) async {
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: 'Удалить страницу?',
      message: '${page.title} будет удалена.',
      confirmText: 'Удалить',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      await _api.deletePage(page.id);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final filtered = _filtered;
    final counts = _counts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Страницы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
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
                  const SizedBox(width: 12),
                  _buildTabs(counts, c),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : filtered.isEmpty
                  ? Center(child: Text('Нет страниц', style: TextStyle(color: c.textSecondary)))
                  : _buildTable(filtered, c),
        ),
      ],
    );
  }

  Widget _buildTabs(Map<String, int> counts, ColorSet c) {
    const labels = {
      'all': 'Все',
      'public': '🌐 Public',
      'moderator': '🛡 Moderator',
      'owner': '👑 Owner',
    };
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: labels.entries.map((e) {
          final active = _visFilter == e.key;
          return GestureDetector(
            onTap: () => setState(() => _visFilter = e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.value, style: TextStyle(fontSize: 13, color: active ? c.text : c.textSecondary)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: active ? c.accent : c.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${counts[e.key] ?? 0}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : c.textSecondary)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable(List<AdminPage> items, ColorSet c) {
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
            DataColumn(label: Text('ЗАГОЛОВОК')),
            DataColumn(label: Text('СООБЩЕСТВО')),
            DataColumn(label: Text('ТИП')),
            DataColumn(label: Text('ВИДИМОСТЬ')),
            DataColumn(label: Text('')),
          ],
          rows: items.map((p) {
            final isHidden = p.visibility != 'public' && p.visibility.isNotEmpty;
            return DataRow(
              color: isHidden ? WidgetStateProperty.all(c.warning.withValues(alpha: 0.05)) : null,
              cells: [
                DataCell(Text('${p.id}')),
                DataCell(
                  p.communitySlug != null
                      ? GestureDetector(
                          onTap: () => context.push('/community/${p.communitySlug}/page/${p.id}'),
                          child: Text(p.title, style: TextStyle(color: c.accent, decoration: TextDecoration.underline, decorationColor: c.accent.withValues(alpha: 0.4))),
                        )
                      : Text(p.title),
                ),
                DataCell(Text(p.communityName ?? '—', style: TextStyle(color: c.textSecondary))),
                DataCell(Text(p.pageType, style: TextStyle(color: c.textSecondary))),
                DataCell(_visBadge(p.visibility, c)),
                DataCell(p.pageType == 'main'
                    ? Text('—', style: TextStyle(color: c.textSecondary))
                    : GestureDetector(
                        onTap: () => _delete(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Удалить', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                      )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _visBadge(String vis, ColorSet c) {
    final (Color bg, Color fg) = switch (vis) {
      'moderator' => (c.warning.withValues(alpha: 0.18), c.warning),
      'owner' => (c.accent.withValues(alpha: 0.18), c.accent),
      _ => (c.success.withValues(alpha: 0.18), c.success),
    };
    final label = switch (vis) {
      'moderator' => '🛡 moderator',
      'owner' => '👑 owner',
      _ => '🌐 public',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
