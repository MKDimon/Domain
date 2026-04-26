import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/categories_api.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/api/invites_api.dart';
import '../../../data/api/members_api.dart';
import '../../../data/api/moderation_api.dart';
import '../../../data/api/uploads_api.dart';
import '../../../data/models/community.dart';
import '../../../providers/auth_provider.dart';

class CommunitySettingsScreen extends ConsumerStatefulWidget {
  final String slug;
  const CommunitySettingsScreen({super.key, required this.slug});

  @override
  ConsumerState<CommunitySettingsScreen> createState() => _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends ConsumerState<CommunitySettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Community? _community;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final comm = await api.getBySlug(widget.slug);
      if (mounted) setState(() { _community = comm; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load community'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (_loading) {
      return Scaffold(backgroundColor: c.bg, body: Center(child: CircularProgressIndicator(color: c.accent)));
    }
    if (_error != null || _community == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(child: Text(_error ?? 'Not found', style: TextStyle(color: c.textSecondary))),
      );
    }

    final comm = _community!;
    final userId = ref.watch(authProvider).user?.id;
    final isOwner = userId != null && comm.ownerId == userId;

    if (!isOwner) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
        ),
        body: Center(child: Text('Доступ запрещён', style: TextStyle(color: c.error))),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Настройки — ${comm.name}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isDesktop,
          tabs: const [
            Tab(text: 'Основные'),
            Tab(text: 'Участники'),
            Tab(text: 'Приглашения'),
            Tab(text: 'Модерация'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralTab(community: comm, c: c, onUpdated: (c) => setState(() => _community = c), ref: ref),
          _MembersTab(community: comm, c: c, ref: ref),
          _InvitesTab(community: comm, c: c, ref: ref, slug: widget.slug),
          _ModerationTab(community: comm, c: c, ref: ref),
        ],
      ),
    );
  }
}

// ─── GENERAL TAB ───────────────────────────────────────────────────

class _GeneralTab extends StatefulWidget {
  final Community community;
  final ColorSet c;
  final void Function(Community) onUpdated;
  final WidgetRef ref;
  const _GeneralTab({required this.community, required this.c, required this.onUpdated, required this.ref});

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
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
    final s = widget.community.settings;
    _nameCtrl = TextEditingController(text: widget.community.name);
    _slugCtrl = TextEditingController(text: widget.community.slug);
    _descCtrl = TextEditingController(text: widget.community.description ?? '');
    _isPublic = widget.community.isPublic;
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
      final cats = await CategoriesApi(widget.ref.read(apiClientProvider)).list();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
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

      final api = CommunitiesApi(widget.ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'settings': settings,
      });
      widget.onUpdated(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
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
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final upload = await UploadsApi(widget.ref.read(apiClientProvider)).upload(
        bytes: bytes, filename: file.name, contentType: 'image/${file.extension ?? 'png'}',
      );
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings['avatar_url'] = upload.url;
      final api = CommunitiesApi(widget.ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'settings': settings});
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось загрузить аватар')));
      }
    }
    if (mounted) setState(() => _uploadingAvatar = false);
  }

  Future<void> _removeAvatar() async {
    try {
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings['avatar_url'] = '';
      final api = CommunitiesApi(widget.ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'settings': settings});
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось удалить аватар')));
      }
    }
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;

    setState(() => _uploadingBanner = true);
    try {
      final upload = await UploadsApi(widget.ref.read(apiClientProvider)).upload(
        bytes: bytes, filename: file.name, contentType: 'image/${file.extension ?? 'png'}',
      );
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings['banner_url'] = upload.url;
      final api = CommunitiesApi(widget.ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'settings': settings});
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось загрузить баннер')));
      }
    }
    if (mounted) setState(() => _uploadingBanner = false);
  }

  Future<void> _removeBanner() async {
    try {
      final settings = Map<String, dynamic>.from(widget.community.settings);
      settings['banner_url'] = '';
      final api = CommunitiesApi(widget.ref.read(apiClientProvider));
      final updated = await api.update(widget.community.id, {'settings': settings});
      widget.onUpdated(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось удалить баннер')));
      }
    }
  }

  String _generateSecret() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var seed = random;
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      seed = (seed * 9301 + 49297) % 233280;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  Future<void> _toggleExternalAccess(bool value) async {
    setState(() {
      _allowExternalAccess = value;
      if (value && _webappSecret.isEmpty) {
        _webappSecret = _generateSecret();
      }
    });
  }

  Future<void> _regenerateSecret() async {
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;
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
      final client = widget.ref.read(apiClientProvider);
      final data = await client.get<Map<String, dynamic>>('/communities/${widget.community.id}/export');
      if (!mounted) return;
      // Show as copiable JSON dialog (desktop has no direct file-save)
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Экспорт сообщества ${widget.community.slug}'),
          content: SizedBox(
            width: 500, height: 400,
            child: SingleChildScrollView(child: SelectableText(data.toString(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          ),
          actions: [
            TextButton(onPressed: () {
              Clipboard.setData(ClipboardData(text: data.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано в буфер'), duration: Duration(seconds: 2)));
            }, child: const Text('Копировать')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteCommunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сообщество?'),
        content: const Text('Это действие необратимо. Все данные сообщества будут удалены.'),
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
    if (confirmed != true) return;
    try {
      await CommunitiesApi(widget.ref.read(apiClientProvider)).delete(widget.community.id);
      if (mounted) context.goNamed('main');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final comm = widget.community;
    final bannerUrl = comm.settings['banner_url'] as String?;
    final commColor = avatarColor(comm.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Banner
              _SectionTitle(title: 'Оформление', c: c),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
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
                            child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                          )
                        else
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
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
                              Center(child: Icon(Icons.panorama_outlined, size: 28, color: c.textSecondary)),
                            if (_uploadingBanner)
                              Container(
                                color: Colors.black45,
                                child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                              )
                            else
                              Positioned(
                                bottom: 4, right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Баннер', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (comm.avatarUrl?.isNotEmpty == true || (bannerUrl != null && bannerUrl.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      if (comm.avatarUrl?.isNotEmpty == true)
                        TextButton.icon(
                          onPressed: _removeAvatar,
                          icon: Icon(Icons.close, size: 14, color: c.error),
                          label: Text('Удалить аватар', style: TextStyle(fontSize: 12, color: c.error)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      if (bannerUrl != null && bannerUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: _removeBanner,
                          icon: Icon(Icons.close, size: 14, color: c.error),
                          label: Text('Удалить баннер', style: TextStyle(fontSize: 12, color: c.error)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              _SectionTitle(title: 'Основные', c: c),
              const SizedBox(height: 12),
              _SettingsField(label: 'Название', c: c, child: _SettingsInput(controller: _nameCtrl, c: c)),
              const SizedBox(height: 12),
              _SettingsField(label: 'Slug (URL)', c: c, child: _SettingsInput(controller: _slugCtrl, c: c)),
              const SizedBox(height: 12),
              _SettingsField(label: 'Описание', c: c, child: _SettingsInput(controller: _descCtrl, c: c, maxLines: 3)),

              const SizedBox(height: 16),
              _SettingsField(
                label: 'Видимость',
                c: c,
                child: Row(
                  children: [
                    Switch(
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v),
                      activeColor: c.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(_isPublic ? 'Публичное' : 'Приватное', style: TextStyle(color: c.text, fontSize: 14)),
                  ],
                ),
              ),

              // Community color
              const SizedBox(height: 16),
              _SettingsField(
                label: 'Цвет сообщества',
                c: c,
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final hex in ['#5B7FF5', '#4CC38A', '#F5BD41', '#EB5757', '#8B5CF6', '#D94066', '#FF8C00', '#00CED1'])
                      GestureDetector(
                        onTap: () => setState(() => _communityColor = hex),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _parseHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _communityColor == hex ? c.text : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Categories
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SettingsField(
                  label: 'Категории',
                  c: c,
                  child: Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _categories.map((cat) {
                      final sel = _selectedCategories.contains(cat.slug);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (sel) { _selectedCategories.remove(cat.slug); }
                          else { _selectedCategories.add(cat.slug); }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? c.accent.withValues(alpha: 0.15) : c.surfaceAlt,
                            border: Border.all(color: sel ? c.accent : c.border),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(cat.name, style: TextStyle(fontSize: 13, color: sel ? c.accent : c.text)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Tags
              const SizedBox(height: 16),
              _SettingsField(
                label: 'Теги',
                c: c,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _SettingsInput(controller: _tagCtrl, c: c, hint: 'Добавить тег')),
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
                      ],
                    ),
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _tags.map((t) => Chip(
                          label: Text(t, style: TextStyle(fontSize: 12, color: c.text)),
                          deleteIcon: Icon(Icons.close, size: 14, color: c.textSecondary),
                          onDeleted: () => setState(() => _tags.remove(t)),
                          backgroundColor: c.surfaceAlt,
                          side: BorderSide(color: c.border),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Sidebar pages toggle
              const SizedBox(height: 24),
              _SectionTitle(title: 'Боковое меню', c: c),
              const SizedBox(height: 12),
              _SettingsField(
                label: '',
                c: c,
                child: Row(
                  children: [
                    Switch(value: _showPagesInSidebar, onChanged: (v) => setState(() => _showPagesInSidebar = v), activeThumbColor: c.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Показывать страницы в меню', style: TextStyle(fontSize: 14, color: c.text)),
                        Text('Страницы будут видны в боковом меню как дополнительный раздел',
                          style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    )),
                  ],
                ),
              ),

              // External access (scripts)
              const SizedBox(height: 24),
              _SectionTitle(title: 'Внешний доступ для скриптов', c: c),
              const SizedBox(height: 12),
              _SettingsField(
                label: '',
                c: c,
                child: Row(
                  children: [
                    Switch(value: _allowExternalAccess, onChanged: _toggleExternalAccess, activeThumbColor: c.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_allowExternalAccess ? 'Разрешён' : 'Запрещён',
                          style: TextStyle(fontSize: 14, color: c.text)),
                        Text('Lua-скрипты смогут обращаться к внешним HTTPS-API через webapp-секрет',
                          style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    )),
                  ],
                ),
              ),
              if (_allowExternalAccess) ...[
                const SizedBox(height: 12),
                _SettingsField(
                  label: 'Webapp секрет',
                  c: c,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _webappSecret.isEmpty ? '(будет сгенерирован при сохранении)' : _webappSecret,
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace',
                            color: _webappSecret.isEmpty ? c.textSecondary : c.text),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          OutlinedButton.icon(
                            onPressed: _webappSecret.isEmpty ? null : _copySecret,
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Копировать'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _regenerateSecret,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Перегенерировать'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsField(
                  label: '',
                  c: c,
                  child: Row(
                    children: [
                      Switch(value: _allowInsecureHttp, onChanged: (v) => setState(() => _allowInsecureHttp = v), activeThumbColor: c.accent),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Разрешить HTTP', style: TextStyle(fontSize: 14, color: c.text)),
                          Text('Без шифрования. Не рекомендуется — ключи и данные будут передаваться открыто',
                            style: TextStyle(fontSize: 12, color: c.warning)),
                        ],
                      )),
                    ],
                  ),
                ),
              ],

              // Save button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.textOnAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Сохранить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),

              // Data export
              const SizedBox(height: 32),
              _SectionTitle(title: 'Экспорт данных', c: c),
              const SizedBox(height: 8),
              Text('Получить полный JSON-дамп данных сообщества (страницы, секции, участники и т.д.)',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _exporting ? null : _exportData,
                icon: _exporting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined, size: 16),
                label: Text(_exporting ? 'Экспорт...' : 'Экспортировать'),
              ),

              // Danger zone
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: c.error.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                  color: c.error.withValues(alpha: 0.05),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Опасная зона', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.error)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _deleteCommunity,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.error,
                        side: BorderSide(color: c.error.withValues(alpha: 0.5)),
                      ),
                      child: const Text('Удалить сообщество'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}

// ─── MEMBERS TAB ───────────────────────────────────────────────────

class _MembersTab extends StatefulWidget {
  final Community community;
  final ColorSet c;
  final WidgetRef ref;
  const _MembersTab({required this.community, required this.c, required this.ref});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  List<Member> _members = [];
  bool _loading = true;
  String? _roleFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final api = MembersApi(widget.ref.read(apiClientProvider));
      final members = await api.list(
        widget.community.id,
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        role: _roleFilter,
      );
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateRole(Member member, String newRole) async {
    try {
      final api = MembersApi(widget.ref.read(apiClientProvider));
      await api.update(widget.community.id, member.userId, role: newRole);
      _loadMembers();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _kickMember(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Исключить участника?'),
        content: Text('${member.effectiveName} будет удалён из сообщества.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Исключить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MembersApi(widget.ref.read(apiClientProvider)).remove(widget.community.id, member.userId);
      _loadMembers();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Column(
      children: [
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: _SettingsInput(
                  controller: _searchCtrl, c: c, hint: 'Поиск участников...',
                  onChanged: (_) => _loadMembers(),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String?>(
                onSelected: (v) { _roleFilter = v; _loadMembers(); },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: null, child: Text('Все')),
                  const PopupMenuItem(value: 'owner', child: Text('Владелец')),
                  const PopupMenuItem(value: 'moderator', child: Text('Модераторы')),
                  const PopupMenuItem(value: 'member', child: Text('Участники')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(8),
                    color: c.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list, size: 16, color: c.textSecondary),
                      const SizedBox(width: 6),
                      Text(_roleFilter ?? 'Все', style: TextStyle(fontSize: 13, color: c.text)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Members list
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : _members.isEmpty
                  ? Center(child: Text('Нет участников', style: TextStyle(color: c.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: _members.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final isOwner = m.role == 'owner';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: avatarColor(m.userId),
                            backgroundImage: m.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(m.avatarUrl!)) : null,
                            child: m.avatarUrl?.isNotEmpty != true
                                ? Text(m.effectiveName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))
                                : null,
                          ),
                          title: Text(m.effectiveName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
                          subtitle: Text(
                            m.role == 'owner' ? 'Владелец' : m.role == 'moderator' ? 'Модератор' : 'Участник',
                            style: TextStyle(fontSize: 12, color: m.role == 'owner' ? c.warning : c.textSecondary),
                          ),
                          trailing: isOwner ? null : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                onSelected: (v) => _updateRole(m, v),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'member', child: Text('Участник')),
                                  const PopupMenuItem(value: 'moderator', child: Text('Модератор')),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: c.border),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(m.role == 'moderator' ? 'Мод' : 'Участник', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                                      Icon(Icons.arrow_drop_down, size: 16, color: c.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.person_remove_outlined, size: 18, color: c.error),
                                onPressed: () => _kickMember(m),
                                tooltip: 'Исключить',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── INVITES TAB ───────────────────────────────────────────────────

class _InvitesTab extends StatefulWidget {
  final Community community;
  final ColorSet c;
  final WidgetRef ref;
  final String slug;
  const _InvitesTab({required this.community, required this.c, required this.ref, required this.slug});

  @override
  State<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends State<_InvitesTab> {
  List<Invite> _invites = [];
  bool _loading = true;
  String? _generatedLink;
  bool _generating = false;
  final _userCtrl = TextEditingController();
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvites() async {
    try {
      final api = InvitesApi(widget.ref.read(apiClientProvider));
      final invites = await api.list(widget.community.id);
      if (mounted) setState(() { _invites = invites; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateLink() async {
    setState(() => _generating = true);
    try {
      final api = InvitesApi(widget.ref.read(apiClientProvider));
      final invite = await api.create(widget.community.id);
      setState(() => _generatedLink = '${Uri.base.origin}/invite/${invite.token}');
      _loadInvites();
    } catch (_) {}
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _inviteUser() async {
    final q = _userCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _inviting = true);
    try {
      await InvitesApi(widget.ref.read(apiClientProvider)).inviteUser(widget.community.id, q);
      _userCtrl.clear();
      _loadInvites();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Приглашение отправлено')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _inviting = false);
  }

  Future<void> _revoke(int inviteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отозвать приглашение?'),
        content: const Text('Ссылка перестанет работать.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Отозвать'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await InvitesApi(widget.ref.read(apiClientProvider)).revoke(widget.community.id, inviteId);
      _loadInvites();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Generate link
              _SectionTitle(title: 'Ссылка-приглашение', c: c),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _generating ? null : _generateLink,
                    icon: _generating
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.link, size: 16),
                    label: const Text('Создать ссылку'),
                    style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.textOnAccent),
                  ),
                ],
              ),
              if (_generatedLink != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(_generatedLink!, style: TextStyle(fontSize: 13, color: c.text), overflow: TextOverflow.ellipsis)),
                      IconButton(
                        icon: Icon(Icons.copy, size: 16, color: c.accent),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedLink!));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)));
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _SectionTitle(title: 'Пригласить пользователя', c: c),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SettingsInput(controller: _userCtrl, c: c, hint: 'Имя пользователя или email')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _inviting ? null : _inviteUser,
                    style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.textOnAccent),
                    child: _inviting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Отправить'),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _SectionTitle(title: 'Активные приглашения', c: c),
              const SizedBox(height: 12),
              if (_loading)
                Center(child: CircularProgressIndicator(color: c.accent))
              else if (_invites.isEmpty)
                Text('Нет активных приглашений', style: TextStyle(color: c.textSecondary, fontSize: 14))
              else
                ...List.generate(_invites.length, (i) {
                  final inv = _invites[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surface, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          inv.inviteeUsername != null ? Icons.person_outline : Icons.link,
                          size: 16, color: c.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.inviteeUsername ?? 'Ссылка-приглашение',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text),
                              ),
                              if (inv.inviterUsername != null)
                                Text('от ${inv.inviterUsername}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: c.error),
                          onPressed: () => _revoke(inv.id),
                          tooltip: 'Отозвать',
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MODERATION TAB ────────────────────────────────────────────────

class _ModerationTab extends StatefulWidget {
  final Community community;
  final ColorSet c;
  final WidgetRef ref;
  const _ModerationTab({required this.community, required this.c, required this.ref});

  @override
  State<_ModerationTab> createState() => _ModerationTabState();
}

class _ModerationTabState extends State<_ModerationTab> {
  List<BannedWord> _bannedWords = [];
  List<ActionLogEntry> _logEntries = [];
  bool _loadingWords = true;
  bool _loadingLog = true;
  final _wordCtrl = TextEditingController();
  bool _matchSubstring = true;
  bool _caseSensitive = false;
  int _logSection = 0; // 0 = banned words, 1 = action log

  @override
  void initState() {
    super.initState();
    _loadBannedWords();
    _loadActionLog();
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBannedWords() async {
    try {
      final api = ModerationApi(widget.ref.read(apiClientProvider));
      final words = await api.listBannedWords(widget.community.id);
      if (mounted) setState(() { _bannedWords = words; _loadingWords = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingWords = false);
    }
  }

  Future<void> _addWord() async {
    final word = _wordCtrl.text.trim();
    if (word.isEmpty) return;
    try {
      final api = ModerationApi(widget.ref.read(apiClientProvider));
      await api.addBannedWord(widget.community.id, word, matchSubstring: _matchSubstring, caseSensitive: _caseSensitive);
      _wordCtrl.clear();
      _loadBannedWords();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _removeWord(int wordId) async {
    try {
      await ModerationApi(widget.ref.read(apiClientProvider)).removeBannedWord(widget.community.id, wordId);
      _loadBannedWords();
    } catch (_) {}
  }

  Future<void> _loadActionLog() async {
    try {
      final api = ModerationApi(widget.ref.read(apiClientProvider));
      final resp = await api.listActions(widget.community.id);
      if (mounted) setState(() { _logEntries = resp.items; _loadingLog = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section toggle
              Row(
                children: [
                  _TabChip(label: 'Запрещённые слова', selected: _logSection == 0, c: c, onTap: () => setState(() => _logSection = 0)),
                  const SizedBox(width: 8),
                  _TabChip(label: 'Журнал действий', selected: _logSection == 1, c: c, onTap: () => setState(() => _logSection = 1)),
                ],
              ),
              const SizedBox(height: 20),

              if (_logSection == 0) ...[
                // Add word form
                Row(
                  children: [
                    Expanded(child: _SettingsInput(controller: _wordCtrl, c: c, hint: 'Слово или фраза')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addWord,
                      style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.textOnAccent),
                      child: const Text('Добавить'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(value: _matchSubstring, onChanged: (v) => setState(() => _matchSubstring = v!), activeColor: c.accent),
                    Text('Часть слова', style: TextStyle(fontSize: 13, color: c.text)),
                    const SizedBox(width: 16),
                    Checkbox(value: _caseSensitive, onChanged: (v) => setState(() => _caseSensitive = v!), activeColor: c.accent),
                    Text('С учётом регистра', style: TextStyle(fontSize: 13, color: c.text)),
                  ],
                ),
                const SizedBox(height: 16),

                if (_loadingWords)
                  Center(child: CircularProgressIndicator(color: c.accent))
                else if (_bannedWords.isEmpty)
                  Text('Нет запрещённых слов', style: TextStyle(color: c.textSecondary, fontSize: 14))
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _bannedWords.map((w) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.error.withValues(alpha: 0.08),
                        border: Border.all(color: c.error.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(w.word, style: TextStyle(fontSize: 13, color: c.text)),
                          if (!w.matchSubstring) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                              child: Text('|w|', style: TextStyle(fontSize: 10, color: c.textSecondary)),
                            ),
                          ],
                          if (w.caseSensitive) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                              child: Text('Aa', style: TextStyle(fontSize: 10, color: c.textSecondary)),
                            ),
                          ],
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _removeWord(w.id),
                            child: Icon(Icons.close, size: 14, color: c.error),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
              ] else ...[
                // Action log
                if (_loadingLog)
                  Center(child: CircularProgressIndicator(color: c.accent))
                else if (_logEntries.isEmpty)
                  Text('Нет записей', style: TextStyle(color: c.textSecondary, fontSize: 14))
                else
                  ...List.generate(_logEntries.length, (i) {
                    final entry = _logEntries[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.surface, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: avatarColor(entry.username.hashCode),
                            backgroundImage: entry.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(entry.avatarUrl!)) : null,
                            child: entry.avatarUrl?.isNotEmpty != true
                                ? Text(entry.username.isNotEmpty ? entry.username[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10, color: Colors.white))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(children: [
                                    TextSpan(text: entry.username, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                                    TextSpan(text: '  ${entry.action}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                                    if (entry.targetTitle != null)
                                      TextSpan(text: '  ${entry.targetTitle}', style: TextStyle(fontSize: 13, color: c.accent)),
                                  ]),
                                ),
                                if (entry.details != null)
                                  Text(entry.details!, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                              ],
                            ),
                          ),
                          Text(entry.createdAt.length >= 16 ? entry.createdAt.substring(5, 16) : entry.createdAt,
                            style: TextStyle(fontSize: 11, color: c.textSecondary)),
                        ],
                      ),
                    );
                  }),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS ────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorSet c;
  const _SectionTitle({required this.title, required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text));
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final ColorSet c;
  final Widget child;
  const _SettingsField({required this.label, required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SettingsInput extends StatelessWidget {
  final TextEditingController controller;
  final ColorSet c;
  final String? hint;
  final int maxLines;
  final void Function(String)? onChanged;
  const _SettingsInput({required this.controller, required this.c, this.hint, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: c.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
        filled: true,
        fillColor: c.surface,
        isDense: true,
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorSet c;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.12) : c.surfaceAlt,
          border: Border.all(color: selected ? c.accent : c.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? c.accent : c.text)),
      ),
    );
  }
}
