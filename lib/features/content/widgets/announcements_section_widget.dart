import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart' show fullImageUrl;
import '../../../data/api/announcements_api.dart';
import '../../../data/models/page.dart';
import '../../../providers/auth_provider.dart';

class AnnouncementsSectionWidget extends ConsumerStatefulWidget {
  final Section section;
  final bool canEdit;
  const AnnouncementsSectionWidget({super.key, required this.section, this.canEdit = false});

  @override
  ConsumerState<AnnouncementsSectionWidget> createState() => _AnnouncementsSectionWidgetState();
}

class _AnnouncementsSectionWidgetState extends ConsumerState<AnnouncementsSectionWidget> {
  late final AnnouncementsApi _api;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int _currentPage = 1;
  int _total = 0;
  String? _error;
  bool _showForm = false;
  int? _editingId;
  bool _creating = false;
  bool _savingEdit = false;
  final _expandedIds = <int>{};

  final _newTitleCtrl = TextEditingController();
  final _newBodyCtrl = TextEditingController();
  String _newPriority = 'normal';

  final _editTitleCtrl = TextEditingController();
  final _editBodyCtrl = TextEditingController();
  String _editPriority = 'normal';

  @override
  void initState() {
    super.initState();
    _api = AnnouncementsApi(ref.read(apiClientProvider));
    _load();
  }

  @override
  void dispose() {
    _newTitleCtrl.dispose();
    _newBodyCtrl.dispose();
    _editTitleCtrl.dispose();
    _editBodyCtrl.dispose();
    super.dispose();
  }

  int get _perPage => widget.section.config['max_items'] as int? ?? 20;
  int get _totalPages => (_total / _perPage).ceil().clamp(1, 9999);

  List<Map<String, dynamic>> get _sortedAnnouncements {
    final items = [..._items];
    items.sort((a, b) {
      final aPinned = a['is_pinned'] == true;
      final bPinned = b['is_pinned'] == true;
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      final aDate = a['created_at'] as String? ?? '';
      final bDate = b['created_at'] as String? ?? '';
      return bDate.compareTo(aDate);
    });
    return items;
  }

  Future<void> _load() async {
    if (_items.isEmpty) setState(() => _loading = true);
    _error = null;
    try {
      final data = await _api.list(widget.section.id, page: _currentPage, limit: _perPage);
      final raw = data['announcements'] as List<dynamic>? ?? data['items'] as List<dynamic>? ?? [];
      _items = raw.cast<Map<String, dynamic>>();
      _total = data['total'] as int? ?? _items.length;
      _error = null;
    } catch (e) {
      if (_items.isEmpty) {
        final sd = widget.section.data;
        _items = (sd['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createAnnouncement() async {
    if (_newTitleCtrl.text.trim().isEmpty) return;
    setState(() { _creating = true; _error = null; });
    try {
      await _api.create(widget.section.id, {
        'title': _newTitleCtrl.text.trim(),
        'body': _newBodyCtrl.text.trim(),
        'priority': _newPriority,
      });
      _newTitleCtrl.clear();
      _newBodyCtrl.clear();
      _newPriority = 'normal';
      _showForm = false;
      _currentPage = 1;
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _saveEdit(int id) async {
    if (_editTitleCtrl.text.trim().isEmpty || _savingEdit) return;
    setState(() { _savingEdit = true; _error = null; });
    try {
      await _api.update(widget.section.id, id, {
        'title': _editTitleCtrl.text.trim(),
        'body': _editBodyCtrl.text.trim(),
        'priority': _editPriority,
      });
      _editingId = null;
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingEdit = false);
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    try {
      await _api.delete(widget.section.id, id);
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _togglePin(Map<String, dynamic> item) async {
    try {
      await _api.pin(widget.section.id, item['id'] as int);
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;
    try {
      await _api.markRead(widget.section.id, item['id'] as int);
      setState(() => item['is_read'] = true);
    } catch (_) {}
  }

  void _startEdit(Map<String, dynamic> item) {
    _editingId = item['id'] as int;
    _editTitleCtrl.text = item['title'] as String? ?? '';
    _editBodyCtrl.text = item['body'] as String? ?? '';
    _editPriority = item['priority'] as String? ?? 'normal';
    setState(() {});
  }

  bool _isLongText(String text) {
    if (text.isEmpty) return false;
    return text.length > 300 || text.split('\n').length > 4;
  }

  String _formatDateShort(String dateStr) {
    if (dateStr.isEmpty) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _priorityLabel(String priority) => switch (priority) {
    'important' => 'Важное',
    'urgent' => 'Срочное',
    _ => 'Обычное',
  };

  bool _isImage(String type) => type.startsWith('image/');
  bool _isVideo(String type) => type.startsWith('video/');

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _fileIcon(String type) {
    if (type.contains('pdf')) return 'PDF';
    if (type.contains('word') || type.contains('document')) return 'DOC';
    if (type.contains('excel') || type.contains('sheet')) return 'XLS';
    return 'FILE';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final auth = ref.watch(authProvider);
    final title = widget.section.config['title'] as String?;
    final accentColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(title ?? 'Объявления', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),

        // Admin toolbar
        if (widget.canEdit) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showForm = !_showForm),
            icon: Icon(_showForm ? Icons.close : Icons.add, size: 14),
            label: Text(_showForm ? 'Отмена' : 'Создать'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],

        // Create form
        if (_showForm && widget.canEdit) ...[
          const SizedBox(height: 8),
          _buildCreateForm(theme, c),
        ],

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.error, fontSize: 13)),
        ],

        const SizedBox(height: 8),

        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_sortedAnnouncements.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Нет объявлений', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ))
        else
          ..._sortedAnnouncements.map((item) => _buildCard(item, theme, c, auth, accentColor)),

        if (_totalPages > 1) _buildPagination(c, accentColor),
      ],
    );
  }

  Widget _buildCreateForm(ThemeData theme, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _newTitleCtrl,
            decoration: InputDecoration(
              hintText: 'Заголовок объявления',
              isDense: true,
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newBodyCtrl,
            decoration: InputDecoration(
              hintText: 'Содержание (необязательно)',
              isDense: true,
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            maxLines: 4,
            style: TextStyle(fontSize: 13, color: c.text),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newPriority,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Обычный')),
                    DropdownMenuItem(value: 'important', child: Text('Важный')),
                    DropdownMenuItem(value: 'urgent', child: Text('Срочный')),
                  ],
                  onChanged: (v) => setState(() => _newPriority = v ?? 'normal'),
                  style: TextStyle(fontSize: 13, color: c.text),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _newTitleCtrl.text.trim().isEmpty || _creating ? null : _createAnnouncement,
                child: _creating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Опубликовать'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, ThemeData theme, ColorSet c, AuthState auth, Color accentColor) {
    final id = item['id'] as int;
    final itemTitle = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? item['content'] as String? ?? '';
    final priority = item['priority'] as String? ?? 'normal';
    final isPinned = item['is_pinned'] == true;
    final isRead = item['is_read'] == true;
    final createdAt = item['created_at'] as String? ?? '';
    final isExpanded = _expandedIds.contains(id);
    final isEditing = _editingId == id;
    final attachments = item['attachments'] as List<dynamic>? ?? [];

    final badgeColor = (priority == 'important' || priority == 'urgent')
        ? c.error.withValues(alpha: 0.15)
        : accentColor.withValues(alpha: 0.12);
    final badgeTextColor = (priority == 'important' || priority == 'urgent')
        ? c.error
        : accentColor;

    return GestureDetector(
      onTap: () => _markAsRead(item),
      child: Container(
        padding: EdgeInsets.all(isPinned ? 12 : 0).copyWith(
          top: isPinned ? 12 : 12,
          bottom: isPinned ? 12 : 0,
          left: isPinned ? 12 : 0,
          right: isPinned ? 12 : 0,
        ),
        margin: EdgeInsets.only(bottom: isPinned ? 8 : 0),
        decoration: isPinned
            ? BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              )
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border, width: 1)),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badge, pin, unread dot, date, admin actions
            Row(
              children: [
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _priorityLabel(priority).toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeTextColor, letterSpacing: 0.3),
                  ),
                ),
                // Pin indicator
                if (isPinned) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.push_pin, size: 12, color: accentColor),
                  const SizedBox(width: 4),
                  Text('Закреплено', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: accentColor)),
                ],
                // Unread dot
                if (!isRead && auth.isAuthenticated) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  ),
                ],
                const Spacer(),
                // Date
                Text(_formatDateShort(createdAt), style: TextStyle(fontSize: 11, color: c.textSecondary)),
                // Admin actions
                if (widget.canEdit) ...[
                  const SizedBox(width: 4),
                  _AdminActionButton(
                    icon: Icons.push_pin_outlined,
                    size: 14,
                    color: c.textSecondary,
                    tooltip: isPinned ? 'Открепить' : 'Закрепить',
                    onTap: () => _togglePin(item),
                  ),
                  _AdminActionButton(
                    icon: Icons.edit_outlined,
                    size: 14,
                    color: c.textSecondary,
                    tooltip: 'Редактировать',
                    onTap: () => _startEdit(item),
                  ),
                  _AdminActionButton(
                    icon: Icons.delete_outline,
                    size: 14,
                    color: c.textSecondary,
                    tooltip: 'Удалить',
                    onTap: () => _deleteAnnouncement(id),
                  ),
                ],
              ],
            ),

            // Edit form or content
            if (isEditing) ...[
              const SizedBox(height: 8),
              _buildEditForm(id, theme, c),
            ] else ...[
              // Title
              const SizedBox(height: 6),
              Text(itemTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),

              // Body with collapse
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                if (_isLongText(body) && !isExpanded)
                  Text(body, maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5))
                else
                  Text(body, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5)),
                if (_isLongText(body))
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) _expandedIds.remove(id); else _expandedIds.add(id);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isExpanded ? 'Свернуть' : 'Читать далее',
                        style: TextStyle(fontSize: 12, color: accentColor),
                      ),
                    ),
                  ),
              ],

              // Attachments
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildAttachments(attachments, c, accentColor),
              ],
            ],

            if (!isPinned) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(int id, ThemeData theme, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _editTitleCtrl,
            decoration: InputDecoration(
              hintText: 'Заголовок',
              isDense: true,
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: TextStyle(fontSize: 14, color: c.text),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editBodyCtrl,
            decoration: InputDecoration(
              hintText: 'Содержание',
              isDense: true,
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            maxLines: 4,
            style: TextStyle(fontSize: 13, color: c.text),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _editPriority,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Обычный')),
                    DropdownMenuItem(value: 'important', child: Text('Важный')),
                    DropdownMenuItem(value: 'urgent', child: Text('Срочный')),
                  ],
                  onChanged: (v) => setState(() => _editPriority = v ?? 'normal'),
                  style: TextStyle(fontSize: 13, color: c.text),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _editingId = null),
                child: const Text('Отмена'),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _editTitleCtrl.text.trim().isEmpty || _savingEdit ? null : () => _saveEdit(id),
                child: _savingEdit
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(List<dynamic> attachments, ColorSet c, Color accentColor) {
    final imageAtts = attachments.where((a) => _isImage(a['type'] as String? ?? '')).toList();
    final videoAtts = attachments.where((a) => _isVideo(a['type'] as String? ?? '')).toList();
    final fileAtts = attachments.where((a) {
      final type = a['type'] as String? ?? '';
      return !_isImage(type) && !_isVideo(type);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageAtts.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: imageAtts.map((a) {
              final url = fullImageUrl(a['url'] as String? ?? '');
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url, height: imageAtts.length > 1 ? 150 : 250, fit: BoxFit.cover),
              );
            }).toList(),
          ),
        ...videoAtts.map((a) {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.videocam_outlined, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Expanded(child: Text(a['filename'] as String? ?? 'video', style: TextStyle(fontSize: 13, color: c.text))),
              ],
            ),
          );
        }),
        ...fileAtts.map((a) {
          final filename = a['filename'] as String? ?? 'file';
          final type = a['type'] as String? ?? '';
          final size = a['size'] as int? ?? 0;
          return Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(_fileIcon(type), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accentColor)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(filename, style: TextStyle(fontSize: 13, color: accentColor), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(_formatFileSize(size), style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPagination(ColorSet c, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _currentPage > 1 ? () { setState(() => _currentPage--); _load(); } : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                side: BorderSide(color: c.border),
              ),
              child: Text('Назад', style: TextStyle(fontSize: 13, color: _currentPage > 1 ? c.text : c.textSecondary)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_currentPage / $_totalPages', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ),
            OutlinedButton(
              onPressed: _currentPage < _totalPages ? () { setState(() => _currentPage++); _load(); } : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                side: BorderSide(color: c.border),
              ),
              child: Text('Далее', style: TextStyle(fontSize: 13, color: _currentPage < _totalPages ? c.text : c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _AdminActionButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
