import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/categories_api.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/api/uploads_api.dart';
import '../../../data/models/community.dart';

/// Community settings panel — single scrollable page matching web's
/// `CommunitySettingsPage.vue` 1:1. Embedded inside CommunityScreen so the
/// sidebar stays visible.
class SettingsPanel extends ConsumerStatefulWidget {
  final Community community;
  final ColorSet c;
  final void Function(Community updated) onUpdated;

  const SettingsPanel({
    super.key,
    required this.community,
    required this.c,
    required this.onUpdated,
  });

  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  late TextEditingController _nameCtrl;
  late TextEditingController _slugCtrl;
  late TextEditingController _descCtrl;
  late bool _isPublic;
  late String? _communityColor;
  late bool _showPagesInSidebar;
  late bool _allowExternalAccess;
  late bool _allowInsecureHttp;
  late String _webappSecret;
  List<Category> _categories = [];
  List<String> _selectedCategories = [];
  List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _uploadingBanner = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final comm = widget.community;
    final s = comm.settings;
    _nameCtrl = TextEditingController(text: comm.name);
    _slugCtrl = TextEditingController(text: comm.slug);
    _descCtrl = TextEditingController(text: comm.description ?? '');
    _isPublic = comm.isPublic;
    _communityColor = s['community_color'] as String?;
    _selectedCategories = (s['categories'] as List<dynamic>?)?.cast<String>() ?? [];
    _tags = (s['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    _showPagesInSidebar = (s['show_pages_in_sidebar'] as bool?) ?? false;
    _allowExternalAccess = (s['allow_external_access'] as bool?) ?? false;
    _allowInsecureHttp = (s['allow_insecure_http'] as bool?) ?? false;
    _webappSecret = (s['webapp_secret'] as String?) ?? '';
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await CategoriesApi(ref.read(apiClientProvider)).list();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<Uint8List?> _readFileBytes(String? path) async {
    if (path == null) return null;
    try { return await File(path).readAsBytes(); } catch (_) { return null; }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _slugCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings['description'] = _descCtrl.text.trim();
      settings['public'] = _isPublic;
      settings['categories'] = _selectedCategories;
      settings['tags'] = _tags;
      settings['show_pages_in_sidebar'] = _showPagesInSidebar;
      settings['allow_external_access'] = _allowExternalAccess;
      if (_allowExternalAccess) {
        settings['allow_insecure_http'] = _allowInsecureHttp;
        if (_webappSecret.isNotEmpty) settings['webapp_secret'] = _webappSecret;
      }
      if (_communityColor != null) settings['community_color'] = _communityColor;

      final api = CommunitiesApi(ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'settings': settings,
      });
      widget.onUpdated(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ?? await _readFileBytes(file.path);
    if (bytes == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final upload = await UploadsApi(ref.read(apiClientProvider)).upload(
        bytes: bytes, filename: file.name, contentType: 'image/${file.extension ?? 'png'}',
      );
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'avatar_url': upload.url});
      widget.onUpdated(updated);
    } catch (_) {}
    if (mounted) setState(() => _uploadingAvatar = false);
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ?? await _readFileBytes(file.path);
    if (bytes == null) return;
    setState(() => _uploadingBanner = true);
    try {
      final upload = await UploadsApi(ref.read(apiClientProvider)).upload(
        bytes: bytes, filename: file.name, contentType: 'image/${file.extension ?? 'png'}',
      );
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings['banner_url'] = upload.url;
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'settings': settings});
      widget.onUpdated(updated);
    } catch (_) {}
    if (mounted) setState(() => _uploadingBanner = false);
  }

  Future<void> _removeBanner() async {
    try {
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings.remove('banner_url');
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'settings': settings});
      widget.onUpdated(updated);
    } catch (_) {}
  }

  String _generateSecret() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var seed = DateTime.now().millisecondsSinceEpoch;
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      seed = (seed * 9301 + 49297) % 233280;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  void _toggleExternalAccess(bool value) {
    setState(() {
      _allowExternalAccess = value;
      if (value && _webappSecret.isEmpty) _webappSecret = _generateSecret();
    });
  }

  Future<void> _regenerateSecret() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Перегенерировать секрет?'),
        content: const Text('Старые скрипты перестанут работать.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сгенерировать')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _webappSecret = _generateSecret());
  }

  Future<void> _copySecret() async {
    await Clipboard.setData(ClipboardData(text: _webappSecret));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 2)));
    }
  }

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final client = ref.read(apiClientProvider);
      final data = await client.get<Map<String, dynamic>>('/communities/${widget.community.id}/export');
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Экспорт ${widget.community.slug}', style: const TextStyle(fontSize: 14)),
          content: SizedBox(
            width: 500, height: 400,
            child: SingleChildScrollView(
              child: SelectableText(data.toString(),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
          ),
          actions: [
            TextButton(onPressed: () {
              Clipboard.setData(ClipboardData(text: data.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 2)));
            }, child: const Text('Копировать')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteCommunity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщество?'),
        content: const Text('Это действие необратимо. Все страницы, секции, участники и данные будут удалены навсегда.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CommunitiesApi(ref.read(apiClientProvider)).delete(widget.community.id);
      if (mounted) context.goNamed('main');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final comm = widget.community;
    final bannerUrl = comm.settings['banner_url'] as String?;
    final commColor = avatarColor(comm.id);
    final bool requiresSave = true; // always allow save; errors shown inline

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      children: [
        _title('Настройки сообщества', c),
        const SizedBox(height: 4),
        Text('Управление внешним видом, доступом и данными сообщества',
          style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const SizedBox(height: 24),

        // ─── Appearance ──────────────────────────────────────────
        _card(c, 'Оформление', [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAvatar,
                child: Stack(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: commColor, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: comm.avatarUrl?.isNotEmpty == true
                        ? Image.network(fullImageUrl(comm.avatarUrl!), fit: BoxFit.cover, width: 72, height: 72)
                        : Center(child: Text(comm.initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
                  ),
                  if (_uploadingAvatar)
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                    )
                  else
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                        child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _uploadingBanner ? null : _pickBanner,
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                      color: c.surfaceAlt,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (bannerUrl != null && bannerUrl.isNotEmpty)
                          Image.network(fullImageUrl(bannerUrl), fit: BoxFit.cover)
                        else
                          Center(child: Icon(Icons.panorama_outlined, size: 26, color: c.textSecondary)),
                        if (_uploadingBanner)
                          Container(
                            color: Colors.black45,
                            child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                          )
                        else
                          Positioned(
                            bottom: 4, right: 4,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (bannerUrl?.isNotEmpty == true) GestureDetector(
                                onTap: _removeBanner,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(color: c.error.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Удалить', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
                                child: Text(bannerUrl?.isNotEmpty == true ? 'Сменить' : 'Баннер', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]),

        const SizedBox(height: 16),

        // ─── Основные ────────────────────────────────────────────
        _card(c, 'Основные', [
          _fieldLabel('Название', c),
          const SizedBox(height: 4),
          _input(_nameCtrl, c, hint: 'Моё сообщество'),

          const SizedBox(height: 12),
          _fieldLabel('Slug (URL)', c),
          const SizedBox(height: 4),
          _input(_slugCtrl, c, hint: 'my-community', mono: true),
          const SizedBox(height: 4),
          Text('Только строчные буквы, цифры и дефис', style: TextStyle(fontSize: 11, color: c.textSecondary)),

          const SizedBox(height: 12),
          _fieldLabel('Описание', c),
          const SizedBox(height: 4),
          _input(_descCtrl, c, hint: 'Краткое описание сообщества', maxLines: 3),

          const SizedBox(height: 12),
          _fieldLabel('Видимость', c),
          const SizedBox(height: 4),
          Row(children: [
            Switch(value: _isPublic, onChanged: (v) => setState(() => _isPublic = v), activeThumbColor: c.accent),
            const SizedBox(width: 6),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isPublic ? 'Публичное' : 'Приватное', style: TextStyle(fontSize: 13, color: c.text)),
                Text(_isPublic
                    ? 'Видимо в каталоге, любой может вступить'
                    : 'Скрыто, только по приглашениям',
                  style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            )),
          ]),

          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            _fieldLabel('Категории', c),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _categories.map((cat) {
                final sel = _selectedCategories.contains(cat.slug);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) { _selectedCategories.remove(cat.slug); } else { _selectedCategories.add(cat.slug); }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? c.accent.withValues(alpha: 0.15) : c.surfaceAlt,
                      border: Border.all(color: sel ? c.accent : c.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(cat.name, style: TextStyle(fontSize: 12, color: sel ? c.accent : c.text)),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          _fieldLabel('Теги', c),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _input(_tagCtrl, c, hint: 'Добавить тег')),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add, color: c.accent),
              onPressed: () {
                final tag = _tagCtrl.text.trim();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() { _tags.add(tag); _tagCtrl.clear(); });
                }
              },
            ),
          ]),
          if (_tags.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: _tags.map((t) => Chip(
                label: Text(t, style: TextStyle(fontSize: 12, color: c.text)),
                deleteIcon: Icon(Icons.close, size: 14, color: c.textSecondary),
                onDeleted: () => setState(() => _tags.remove(t)),
                backgroundColor: c.surfaceAlt,
                side: BorderSide(color: c.border),
              )).toList(),
            ),
          ),
        ]),

        const SizedBox(height: 16),

        // ─── Боковое меню ────────────────────────────────────────
        _card(c, 'Боковое меню', [
          Row(children: [
            Switch(value: _showPagesInSidebar, onChanged: (v) => setState(() => _showPagesInSidebar = v), activeThumbColor: c.accent),
            const SizedBox(width: 6),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Показывать страницы в меню', style: TextStyle(fontSize: 13, color: c.text)),
                Text('Раздел «Страницы» появится в сайдбаре у всех участников', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            )),
          ]),
        ]),

        const SizedBox(height: 16),

        // ─── Внешний доступ для скриптов ──────────────────────────
        _card(c, 'Внешний доступ для скриптов', [
          Row(children: [
            Switch(value: _allowExternalAccess, onChanged: _toggleExternalAccess, activeThumbColor: c.accent),
            const SizedBox(width: 6),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_allowExternalAccess ? 'Разрешён' : 'Запрещён', style: TextStyle(fontSize: 13, color: c.text)),
                Text('Lua-скрипты смогут обращаться к внешним HTTPS-API, используя webapp-секрет', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            )),
          ]),
          if (_allowExternalAccess) ...[
            const SizedBox(height: 16),
            _fieldLabel('Webapp секрет', c),
            const SizedBox(height: 4),
            Text('Используется для аутентификации исходящих запросов', style: TextStyle(fontSize: 11, color: c.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _webappSecret.isEmpty ? '(сгенерируется автоматически)' : _webappSecret,
                style: TextStyle(
                  fontSize: 12, fontFamily: 'monospace',
                  color: _webappSecret.isEmpty ? c.textSecondary : c.text,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _webappSecret.isEmpty ? null : _copySecret,
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Копировать'),
              ),
              OutlinedButton.icon(
                onPressed: _regenerateSecret,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Перегенерировать'),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Switch(value: _allowInsecureHttp, onChanged: (v) => setState(() => _allowInsecureHttp = v), activeThumbColor: c.warning),
              const SizedBox(width: 6),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Разрешить HTTP (без шифрования)', style: TextStyle(fontSize: 13, color: c.text)),
                  Text('Не рекомендуется — данные передаются в открытом виде', style: TextStyle(fontSize: 11, color: c.warning)),
                ],
              )),
            ]),
          ],
        ]),

        const SizedBox(height: 24),

        // ─── Save button ─────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving || !requiresSave ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: c.accent,
              foregroundColor: c.textOnAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 32),

        // ─── Export ──────────────────────────────────────────────
        _card(c, 'Экспорт данных', [
          Text('Получить JSON-дамп всех данных сообщества (страницы, секции, участники)',
            style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _exportData,
            icon: _exporting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined, size: 16),
            label: Text(_exporting ? 'Экспорт...' : 'Экспортировать'),
          ),
        ]),

        const SizedBox(height: 16),

        // ─── Danger zone ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.error.withValues(alpha: 0.06),
            border: Border.all(color: c.error.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ОПАСНАЯ ЗОНА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.error, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Text('Удаление сообщества необратимо — все страницы, секции и данные участников будут стёрты навсегда',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deleteCommunity,
                icon: Icon(Icons.delete_outline, size: 16, color: c.error),
                label: Text('Удалить сообщество', style: TextStyle(color: c.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.error.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Widget _title(String text, ColorSet c) => Text(
    text, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text));

  Widget _card(ColorSet c, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.6,
          )),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, ColorSet c) => Text(
    text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text));

  Widget _input(TextEditingController controller, ColorSet c, {String? hint, int maxLines = 1, bool mono = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.5)),
        border: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border), borderRadius: BorderRadius.circular(6)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: c.accent), borderRadius: BorderRadius.circular(6)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      style: TextStyle(fontSize: 13, color: c.text, fontFamily: mono ? 'monospace' : null),
    );
  }
}
