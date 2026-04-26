import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/admin_api.dart';

class AdminAppealsTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminAppealsTab({super.key, required this.c, required this.ref});

  @override
  State<AdminAppealsTab> createState() => _AdminAppealsTabState();
}

class _AdminAppealsTabState extends State<AdminAppealsTab> {
  List<ModerationAppeal> _items = [];
  int _totalPending = 0;
  bool _loading = true;
  int? _selectedId;
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  ModerationAppeal? get _selected =>
      _selectedId != null ? _items.where((i) => i.id == _selectedId).firstOrNull : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _api.listAppeals();
      _items = result.items;
      _totalPending = result.totalPending;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _review(String status) async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await _api.reviewAppeal(
        _selected!.id,
        status: status,
        note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      );
      final currentIndex = _items.indexWhere((i) => i.id == _selectedId);
      _items.removeWhere((i) => i.id == _selectedId);
      _noteCtrl.clear();
      if (_items.isNotEmpty) {
        final nextIndex = currentIndex.clamp(0, _items.length - 1);
        _selectedId = _items[nextIndex].id;
      } else {
        _selectedId = null;
      }
      _totalPending = _items.length;
    } catch (_) {}
    if (mounted) setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (_loading) return Center(child: CircularProgressIndicator(color: c.accent));

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel, size: 48, color: c.textSecondary),
            const SizedBox(height: 12),
            Text('Нет апелляций', style: TextStyle(fontSize: 16, color: c.textSecondary)),
          ],
        ),
      );
    }

    if (isDesktop) {
      return Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(width: 320, child: _buildList(c)),
            VerticalDivider(width: 1, thickness: 1, color: c.border),
            Expanded(
              child: _selected != null
                  ? _buildDetail(c)
                  : Center(child: Text('Выберите апелляцию', style: TextStyle(color: c.textSecondary))),
            ),
          ],
        ),
      );
    }

    return _selected != null ? _buildDetail(c) : _buildList(c);
  }

  Widget _buildList(ColorSet c) {
    return Container(
      color: c.surfaceAlt,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final isActive = _selectedId == item.id;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedId = item.id;
              _noteCtrl.clear();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? c.hoverOverlay : Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: c.border),
                  left: isActive ? BorderSide(color: c.accent, width: 3) : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: avatarColor(item.actionUserId ?? 0),
                    backgroundImage: item.userAvatarUrl?.isNotEmpty == true
                        ? NetworkImage(fullImageUrl(item.userAvatarUrl!))
                        : null,
                    child: item.userAvatarUrl?.isNotEmpty != true
                        ? Text(
                            (item.userUsername ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                item.effectiveName,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(_timeAgo(item.createdAt), style: TextStyle(fontSize: 11, color: c.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.actionReason ?? '',
                                style: TextStyle(fontSize: 12, color: c.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _typeBadge(item.actionActionType ?? '', c),
                          ],
                        ),
                      ],
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

  Widget _typeBadge(String type, ColorSet c) {
    final (Color bg, Color fg) = switch (type) {
      'warning' => (c.warning.withValues(alpha: 0.18), c.warning),
      'mute' => (const Color(0xFFA855F7).withValues(alpha: 0.18), const Color(0xFFC084FC)),
      'ban' => (c.error.withValues(alpha: 0.18), c.error),
      _ => (c.surfaceAlt, c.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildDetail(ColorSet c) {
    final a = _selected!;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktop)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedId = null),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, size: 18, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text('Назад', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                  ],
                ),
              ),
            ),

          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor(a.actionUserId ?? 0),
                backgroundImage: a.userAvatarUrl?.isNotEmpty == true
                    ? NetworkImage(fullImageUrl(a.userAvatarUrl!))
                    : null,
                child: a.userAvatarUrl?.isNotEmpty != true
                    ? Text((a.userUsername ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.effectiveName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                  Text('@${a.userUsername ?? "?"}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: c.border),
          const SizedBox(height: 14),

          // Action context
          _ctxLabel('Контекст наказания', c),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ctxRow('Тип', a.actionActionType ?? '—', c),
                _ctxRow('Выдал', a.issuerUsername ?? '—', c),
                _ctxRow('Создано', _timeAgo(a.actionCreatedAt ?? ''), c),
                if (a.actionExpiresAt != null) _ctxRow('Истекает', a.actionExpiresAt!, c),
                if (a.actionSeverity != null) _ctxRow('Серьёзность', '${a.actionSeverity}/3', c),
                _ctxRow('Причина', a.actionReason ?? '—', c),
              ],
            ),
          ),

          // User message
          const SizedBox(height: 16),
          _ctxLabel('Сообщение пользователя', c),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.07),
              border: Border(left: BorderSide(color: c.accent, width: 3)),
              borderRadius: const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
            ),
            child: Text(a.userMessage, style: TextStyle(fontSize: 14, color: c.text, height: 1.5)),
          ),

          // Review form
          const SizedBox(height: 20),
          Text('Ответ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary)),
          const SizedBox(height: 5),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style: TextStyle(fontSize: 14, color: c.text),
            decoration: InputDecoration(
              hintText: 'Необязательно...',
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.accent)),
              filled: true, fillColor: c.bg, isDense: true,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _review('accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Принять'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _review('rejected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Отклонить'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _submitting ? null : () => _review('info_requested'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                child: Text('Запросить инфо', style: TextStyle(color: c.text)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ctxLabel(String text, ColorSet c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.4)),
      );

  Widget _ctxRow(String label, String value, ColorSet c) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ),
            Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: c.text))),
          ],
        ),
      );
}
