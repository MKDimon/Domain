import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/feedback_api.dart';
import '../../../data/models/community.dart';

/// Regular-member feedback panel: submit new tickets + view own tickets with responses.
class FeedbackPanel extends ConsumerStatefulWidget {
  final int communityId;
  final List<PageSummary> pages;
  final ColorSet c;

  const FeedbackPanel({
    super.key,
    required this.communityId,
    required this.pages,
    required this.c,
  });

  @override
  ConsumerState<FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends ConsumerState<FeedbackPanel> {
  final _bodyCtrl = TextEditingController();
  final _replyCtrl = <int, TextEditingController>{};

  String _feedbackType = 'suggestion';
  int? _selectedPageId;
  List<FeedbackAttachment> _attachments = [];
  bool _submitting = false;
  String? _submitError;

  bool _loading = true;
  String? _loadError;
  List<FeedbackItem> _items = [];
  int _activeCount = 0;
  int _maxActive = 3;

  late final FeedbackApi _api;

  @override
  void initState() {
    super.initState();
    _api = FeedbackApi(ref.read(apiClientProvider));
    _load();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    for (final c in _replyCtrl.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final resp = await _api.listMy(widget.communityId);
      if (!mounted) return;
      setState(() {
        _items = resp.items;
        _activeCount = resp.activeCount;
        _maxActive = resp.maxActive;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = 'Не удалось загрузить'; _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_bodyCtrl.text.trim().isEmpty) return;
    setState(() { _submitting = true; _submitError = null; });
    try {
      await _api.create(widget.communityId,
        feedbackType: _feedbackType,
        body: _bodyCtrl.text.trim(),
        pageId: _selectedPageId,
        attachments: _attachments,
      );
      if (!mounted) return;
      _bodyCtrl.clear();
      setState(() {
        _feedbackType = 'suggestion';
        _selectedPageId = null;
        _attachments = [];
        _submitting = false;
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _submitError = 'Не удалось отправить'; _submitting = false; });
    }
  }

  Future<void> _submitResponse(int feedbackId) async {
    final ctrl = _replyCtrl[feedbackId];
    if (ctrl == null || ctrl.text.trim().isEmpty) return;
    try {
      await _api.respond(widget.communityId, feedbackId, ctrl.text.trim());
      ctrl.clear();
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось отправить ответ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final canSubmit = _activeCount < _maxActive;

    if (_loading) return Center(child: CircularProgressIndicator(color: c.accent));
    if (_loadError != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_loadError!, style: TextStyle(color: c.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Повторить')),
        ],
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Обратная связь', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 4),
        Text('Задайте вопрос, предложите улучшение или пожалуйтесь на проблему',
          style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const SizedBox(height: 16),
        _buildLimitBar(c),
        const SizedBox(height: 16),
        if (canSubmit) _buildSubmitForm(c) else _buildLimitReached(c),
        const SizedBox(height: 24),
        _buildMyTickets(c),
      ],
    );
  }

  Widget _buildLimitBar(ColorSet c) {
    final danger = _activeCount >= _maxActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('Активных тикетов: ', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          Text('$_activeCount из $_maxActive',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: danger ? c.error : c.text)),
          const SizedBox(width: 12),
          ...List.generate(_maxActive, (i) {
            final used = i < _activeCount;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: used ? (danger ? c.error : c.accent) : c.border,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLimitReached(ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.08),
        border: Border.all(color: c.warning.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: c.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Достигнут лимит тикетов',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 4),
              Text('Вы можете иметь не более $_maxActive активных тикетов. Дождитесь их решения или закрытия.',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildSubmitForm(ColorSet c) {
    final nonMainPages = widget.pages.where((p) => p.pageType != 'main').toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Новый тикет', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _typeButton('complaint', Icons.warning_amber_outlined, 'Жалоба', c)),
              const SizedBox(width: 8),
              Expanded(child: _typeButton('suggestion', Icons.lightbulb_outline, 'Предложение', c)),
              const SizedBox(width: 8),
              Expanded(child: _typeButton('question', Icons.help_outline, 'Вопрос', c)),
            ],
          ),
          const SizedBox(height: 12),

          Text('Описание', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 4),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: 'Опишите вашу проблему или предложение...',
              border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
              counterStyle: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
            style: TextStyle(fontSize: 13, color: c.text),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Text('Связать со страницей ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 4),
          DropdownButtonFormField<int?>(
            initialValue: _selectedPageId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Без страницы')),
              ...nonMainPages.map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.title))),
            ],
            onChanged: (v) => setState(() => _selectedPageId = v),
            style: TextStyle(fontSize: 13, color: c.text),
          ),
          const SizedBox(height: 16),

          if (_submitError != null) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_submitError!, style: TextStyle(fontSize: 12, color: c.error)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _submitting || _bodyCtrl.text.trim().isEmpty ? null : _submit,
              child: Text(_submitting ? 'Отправка...' : 'Отправить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String type, IconData icon, String label, ColorSet c) {
    final active = _feedbackType == type;
    return GestureDetector(
      onTap: () => setState(() => _feedbackType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.1) : c.surfaceAlt,
          border: Border.all(color: active ? c.accent : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: active ? c.accent : c.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: active ? c.accent : c.text,
              ), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTickets(ColorSet c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Мои тикеты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Text('${_items.length}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Пока нет тикетов', style: TextStyle(color: c.textSecondary)),
          )
        else
          ..._items.map((item) => _buildTicketCard(item, c)),
      ],
    );
  }

  Widget _buildTicketCard(FeedbackItem item, ColorSet c) {
    final canReply = item.status == 'new' || item.status == 'in_progress';
    _replyCtrl.putIfAbsent(item.id, () => TextEditingController());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _typeBadge(item.feedbackType, c),
              const SizedBox(width: 8),
              _statusBadge(item.status, c),
              const Spacer(),
              Text(_formatDate(item.createdAt),
                style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.body, style: TextStyle(fontSize: 13, color: c.text, height: 1.5)),

          if (item.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: item.attachments.map((a) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.attachment, size: 12, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text(a.filename, style: TextStyle(fontSize: 11, color: c.text)),
                ]),
              ),
            ).toList()),
          ],

          if (item.pageTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.description_outlined, size: 12, color: c.accent),
              const SizedBox(width: 4),
              Text(item.pageTitle!, style: TextStyle(fontSize: 12, color: c.accent)),
            ]),
          ],

          if (item.responses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: c.border),
            const SizedBox(height: 8),
            Text('ОТВЕТЫ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...item.responses.map((r) => _buildResponse(r, c)),
          ] else if (item.status == 'new') ...[
            const SizedBox(height: 8),
            Text('Ждём ответа от модератора...',
              style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
          ],

          if (canReply) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _replyCtrl[item.id],
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Написать ответ...',
                border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
                isDense: true,
                contentPadding: const EdgeInsets.all(10),
              ),
              style: TextStyle(fontSize: 12, color: c.text),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _submitResponse(item.id),
                child: Text('Ответить', style: TextStyle(color: c.accent)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponse(FeedbackResponse r, ColorSet c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(13),
              image: r.avatarUrl?.isNotEmpty == true
                  ? DecorationImage(image: NetworkImage(fullImageUrl(r.avatarUrl!)), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: r.avatarUrl?.isNotEmpty != true
                ? Text(r.username.isNotEmpty ? r.username[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.accent))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(r.username, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                  const SizedBox(width: 6),
                  Text(_formatDate(r.createdAt), style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ]),
                const SizedBox(height: 2),
                Text(r.body, style: TextStyle(fontSize: 12, color: c.text, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type, ColorSet c) {
    final (color, label) = switch (type) {
      'complaint' => (c.error, 'Жалоба'),
      'suggestion' => (c.success, 'Предложение'),
      'question' => (c.accent, 'Вопрос'),
      _ => (c.textSecondary, type),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusBadge(String status, ColorSet c) {
    final (color, label) = switch (status) {
      'new' => (c.accent, 'Новый'),
      'in_progress' => (c.warning, 'В работе'),
      'resolved' => (c.success, 'Решён'),
      'declined' => (c.textSecondary, 'Отклонён'),
      _ => (c.textSecondary, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'только что';
      if (diff.inHours < 1) return '${diff.inMinutes}м назад';
      if (diff.inDays < 1) return '${diff.inHours}ч назад';
      if (diff.inDays < 7) return '${diff.inDays}д назад';
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
