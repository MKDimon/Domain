import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

class AdminCategoriesTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminCategoriesTab({super.key, required this.c, required this.ref});

  @override
  State<AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<AdminCategoriesTab> {
  List<Category> _categories = [];
  bool _loading = true;
  bool _adding = false;
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _categories = await _api.listCategories();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _autoSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zа-яё0-9]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final slug = _slugCtrl.text.trim().isNotEmpty ? _slugCtrl.text.trim() : _autoSlug(name);
    setState(() => _adding = true);
    try {
      await _api.createCategory(
        name: name,
        slug: slug,
        sortOrder: _categories.length,
      );
      _nameCtrl.clear();
      _slugCtrl.clear();
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _adding = false);
  }

  Future<void> _delete(Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('«${cat.name}» будет удалена.'),
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
      await _api.deleteCategory(cat.id);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Категории', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      style: TextStyle(fontSize: 14, color: c.text),
                      decoration: _inputDecoration(c, 'Название'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _slugCtrl,
                      style: TextStyle(fontSize: 14, color: c.text),
                      decoration: _inputDecoration(c, 'Slug (авто)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _adding || _nameCtrl.text.trim().isEmpty ? null : _add,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _adding
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Добавить', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : _categories.isEmpty
                  ? Center(child: Text('Нет категорий', style: TextStyle(color: c.textSecondary)))
                  : _buildTable(c),
        ),
      ],
    );
  }

  Widget _buildTable(ColorSet c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(60),
          3: FixedColumnWidth(80),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            children: [
              _th('ID', c),
              _th('NAME', c),
              _th('SLUG', c),
              _th('', c),
            ],
          ),
          ..._categories.map((cat) => TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                children: [
                  _td('${cat.id}', c),
                  _td(cat.name, c),
                  _td(cat.slug, c),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: c.error),
                      onPressed: () => _delete(cat),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  Widget _th(String text, ColorSet c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: 0.5)),
      );

  Widget _td(String text, ColorSet c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Text(text, style: TextStyle(fontSize: 14, color: c.text)),
      );

  InputDecoration _inputDecoration(ColorSet c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
        filled: true,
        fillColor: c.bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
}
