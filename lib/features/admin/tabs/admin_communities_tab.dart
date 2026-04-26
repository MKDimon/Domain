import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';
import '../widgets/admin_confirm_dialog.dart';

class AdminCommunitiesTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminCommunitiesTab({super.key, required this.c, required this.ref});

  @override
  State<AdminCommunitiesTab> createState() => _AdminCommunitiesTabState();
}

class _AdminCommunitiesTabState extends State<AdminCommunitiesTab> {
  List<AdminCommunity> _communities = [];
  bool _loading = true;
  String _statusFilter = 'all';
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
      _communities = await _api.listCommunities();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<AdminCommunity> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _communities.where((c) {
      if (_statusFilter == 'active' && c.isClosed) return false;
      if (_statusFilter == 'closed' && !c.isClosed) return false;
      if (q.isNotEmpty) {
        return c.name.toLowerCase().contains(q) || c.slug.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  int get _closedCount => _communities.where((c) => c.isClosed).length;

  Future<void> _delete(AdminCommunity comm) async {
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: 'Удалить сообщество?',
      message: '${comm.name} будет удалено.',
      confirmText: 'Удалить',
      isDanger: true,
    );
    if (!confirmed) return;
    try {
      await _api.deleteCommunity(comm.id);
      _load();
    } catch (_) {}
  }

  Future<void> _restore(AdminCommunity comm) async {
    try {
      await _api.restoreCommunity(comm.id);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сообщества', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
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
                  _buildTabs(c),
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
                  ? Center(child: Text('Нет сообществ', style: TextStyle(color: c.textSecondary)))
                  : _buildTable(filtered, c),
        ),
      ],
    );
  }

  Widget _buildTabs(ColorSet c) {
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('all', 'Все', _communities.length, c),
          _tab('active', 'Активные', _communities.length - _closedCount, c),
          _tab('closed', 'Закрытые', _closedCount, c),
        ],
      ),
    );
  }

  Widget _tab(String key, String label, int count, ColorSet c) {
    final active = _statusFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: active ? c.text : c.textSecondary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? c.accent : c.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<AdminCommunity> items, ColorSet c) {
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
            DataColumn(label: Text('НАЗВАНИЕ')),
            DataColumn(label: Text('SLUG')),
            DataColumn(label: Text('ВЛАДЕЛЕЦ')),
            DataColumn(label: Text('СТАТУС')),
            DataColumn(label: Text('')),
          ],
          rows: items.map((comm) => DataRow(
            cells: [
              DataCell(Text('${comm.id}', style: TextStyle(color: c.text.withValues(alpha: comm.isClosed ? 0.55 : 1.0)))),
              DataCell(
                GestureDetector(
                  onTap: comm.isClosed ? null : () => context.push('/community/${comm.slug}'),
                  child: Text(
                    comm.name,
                    style: TextStyle(
                      color: comm.isClosed ? c.text.withValues(alpha: 0.55) : c.accent,
                      decoration: comm.isClosed ? TextDecoration.lineThrough : TextDecoration.underline,
                      decorationColor: c.accent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              DataCell(Text(
                '/${comm.slug}',
                style: TextStyle(
                  color: c.textSecondary.withValues(alpha: comm.isClosed ? 0.55 : 1.0),
                  decoration: comm.isClosed ? TextDecoration.lineThrough : null,
                ),
              )),
              DataCell(Text('${comm.ownerId ?? "—"}', style: TextStyle(color: c.text.withValues(alpha: comm.isClosed ? 0.55 : 1.0)))),
              DataCell(_statusBadge(comm, c)),
              DataCell(comm.isClosed
                  ? _actionBtn('Восстановить', c.success, Colors.white, () => _restore(comm))
                  : _actionBtn('Удалить', c.error, Colors.white, () => _delete(comm))),
            ],
          )).toList(),
        ),
      ),
    );
  }

  Widget _statusBadge(AdminCommunity comm, ColorSet c) {
    final isClosed = comm.isClosed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isClosed ? c.error : c.success).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isClosed ? 'CLOSED' : 'ACTIVE',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isClosed ? c.error : c.success, letterSpacing: 0.4),
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
