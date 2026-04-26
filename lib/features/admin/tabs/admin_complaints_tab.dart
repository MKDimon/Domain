import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

class AdminComplaintsTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminComplaintsTab({super.key, required this.c, required this.ref});

  @override
  State<AdminComplaintsTab> createState() => _AdminComplaintsTabState();
}

class _AdminComplaintsTabState extends State<AdminComplaintsTab> {
  List<Complaint> _items = [];
  Map<String, int> _counts = {};
  int _total = 0;
  bool _loading = false;
  Complaint? _selected;
  String _statusFilter = 'all';
  String _reasonFilter = 'all';
  String _targetFilter = 'all';
  final _resolutionCtrl = TextEditingController();

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  static const _reasons = ['all', 'spam', 'fraud', 'insult', 'extremism', 'adult', 'copyright', 'threat', 'other'];
  static const _targets = ['all', 'message', 'community', 'page', 'user'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.listComplaints(
          status: _statusFilter != 'all' ? _statusFilter : null,
          reason: _reasonFilter != 'all' ? _reasonFilter : null,
          targetType: _targetFilter != 'all' ? _targetFilter : null,
        ),
        _api.listComplaints(),
      ]);
      final filtered = results[0];
      final all = results[1];
      _items = filtered.items;
      _counts = all.counts;
      _total = all.total;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _select(Complaint c) {
    setState(() {
      _selected = c;
      _resolutionCtrl.text = c.resolutionNote;
    });
  }

  Future<void> _updateStatus(String status) async {
    if (_selected == null) return;
    try {
      await _api.updateComplaintStatus(
        _selected!.id,
        status: status,
        resolutionNote: _resolutionCtrl.text.trim().isNotEmpty ? _resolutionCtrl.text.trim() : null,
      );
      _selected = null;
      _load();
    } catch (_) {}
  }

  String _timeAgo(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d).inSeconds;
    if (diff < 60) return '${diff}с назад';
    if (diff < 3600) return '${diff ~/ 60}м назад';
    if (diff < 86400) return '${diff ~/ 3600}ч назад';
    if (diff < 604800) return '${diff ~/ 86400}д назад';
    return d.toLocal().toString().substring(0, 10);
  }

  String _targetSummary(Complaint c) {
    final s = c.targetSnapshot;
    return switch (c.targetType) {
      'message' => 'Сообщение @${s['author_username'] ?? '?'} · ${s['community_slug'] ?? '?'}',
      'community' => 'Сообщество ${s['name'] ?? s['slug'] ?? '?'}',
      'page' => 'Страница ${s['community_slug'] ?? '?'}/${s['page_slug'] ?? '?'}',
      'user' => 'Пользователь @${s['username'] ?? '?'}',
      _ => c.targetType,
    };
  }

  String _targetPreview(Complaint c) {
    final s = c.targetSnapshot;
    if (c.targetType == 'message') return s['content'] as String? ?? '';
    if (c.targetType == 'page') return s['title'] as String? ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Column(
      children: [
        // Status tabs
        _buildStatusTabs(c),
        // Filter chips
        _buildFilters(c),
        // Main content
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : _items.isEmpty
                  ? Center(child: Text('Нет жалоб', style: TextStyle(color: c.textSecondary)))
                  : isDesktop
                      ? Row(
                          children: [
                            Expanded(child: _buildList(c)),
                            if (_selected != null) ...[
                              VerticalDivider(width: 1, color: c.border),
                              SizedBox(width: 400, child: _buildDetail(c)),
                            ],
                          ],
                        )
                      : _selected != null
                          ? _buildDetail(c)
                          : _buildList(c),
        ),
      ],
    );
  }

  Widget _buildStatusTabs(ColorSet c) {
    const statuses = ['all', 'new', 'in_progress', 'resolved', 'rejected'];
    const labels = {'all': 'Все', 'new': 'Новые', 'in_progress': 'В работе', 'resolved': 'Решены', 'rejected': 'Отклонены'};
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          children: statuses.map((s) {
            final active = _statusFilter == s;
            final count = s == 'all' ? _total : (_counts[s] ?? 0);
            return GestureDetector(
              onTap: () {
                setState(() => _statusFilter = s);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? c.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      labels[s] ?? s,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: active ? c.accent : c.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (s == 'new' && count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilters(ColorSet c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._reasons.map((r) => _filterChip(r, _reasonFilter, (v) {
              setState(() => _reasonFilter = v);
              _load();
            }, c)),
            Container(width: 1, height: 18, color: c.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
            ..._targets.map((t) => _filterChip(t, _targetFilter, (v) {
              setState(() => _targetFilter = v);
              _load();
            }, c)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String current, ValueChanged<String> onTap, ColorSet c) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          border: Border.all(color: active ? c.accent : c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          value == 'all' ? 'все' : value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : c.textSecondary),
        ),
      ),
    );
  }

  Widget _buildList(ColorSet c) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 8, 12, 16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = _items[i];
        final isSelected = _selected?.id == item.id;
        final isNew = item.status == 'new';
        return GestureDetector(
          onTap: () => _select(item),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? c.focusRing : c.surface,
              border: Border.all(color: isSelected ? c.accent : c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(item.reason, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.error)),
                    ),
                    const SizedBox(width: 6),
                    _complaintStatusBadge(item.status, c),
                    const Spacer(),
                    Text(_timeAgo(item.createdAt), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                // Target
                if (isNew)
                  Container(
                    width: 3,
                    color: c.error,
                  ),
                Text(_targetSummary(item), style: TextStyle(fontSize: 14, color: c.text)),
                // Preview
                if (_targetPreview(item).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _targetPreview(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
                // Footer
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: c.accent,
                        child: Text(
                          item.reporterUsername.isNotEmpty ? item.reporterUsername[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('@${item.reporterUsername}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      const Spacer(),
                      Text('#${item.id}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _complaintStatusBadge(String status, ColorSet c) {
    final (Color bg, Color fg) = switch (status) {
      'new' => (c.error.withValues(alpha: 0.15), c.error),
      'in_progress' => (c.warning.withValues(alpha: 0.15), c.warning),
      'resolved' => (c.success.withValues(alpha: 0.15), c.success),
      _ => (c.surfaceAlt, c.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg, letterSpacing: 0.3)),
    );
  }

  Widget _buildDetail(ColorSet c) {
    final s = _selected!;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDesktop)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 18, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Text('Назад', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            Text('Жалоба #${s.id}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 16),

            _detailSection('Причина', s.reason, c),
            _detailSection('Тип цели', s.targetType, c),
            _detailSection('Заявитель', '@${s.reporterUsername}', c),
            _detailSection('Создана', _timeAgo(s.createdAt), c),
            _detailSection('Статус', s.status, c),

            const SizedBox(height: 12),
            _detailLabel('Объект жалобы', c),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_targetSummary(s), style: TextStyle(fontSize: 14, color: c.text)),
                  if (_targetPreview(s).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_targetPreview(s), style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ],
                ],
              ),
            ),

            if (s.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailLabel('Комментарий заявителя', c),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c.accent, width: 3)),
                  color: c.surfaceAlt,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                ),
                child: Text(s.comment, style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: c.textSecondary)),
              ),
            ],

            const SizedBox(height: 16),
            _detailLabel('Резолюция', c),
            TextField(
              controller: _resolutionCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 14, color: c.text),
              decoration: InputDecoration(
                hintText: 'Заметка о решении...',
                hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.accent)),
                filled: true,
                fillColor: c.surfaceAlt,
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
              ),
            ),

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Column(
                children: [
                  if (s.status == 'new')
                    _fullBtn('Взять в работу', c.warning, () => _updateStatus('in_progress')),
                  if (s.status != 'resolved')
                    _fullBtn('Решено', c.success, () => _updateStatus('resolved')),
                  if (s.status != 'rejected')
                    _fullBtn('Отклонить', c.textSecondary, () => _updateStatus('rejected')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String label, String value, ColorSet c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailLabel(label, c),
          Text(value, style: TextStyle(fontSize: 14, color: c.text)),
        ],
      ),
    );
  }

  Widget _detailLabel(String text, ColorSet c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.4)),
      );

  Widget _fullBtn(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
