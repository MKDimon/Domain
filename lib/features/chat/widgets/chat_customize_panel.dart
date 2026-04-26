import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class ChatCustomizePanel extends ConsumerStatefulWidget {
  final int sectionId;
  final VoidCallback onClose;

  const ChatCustomizePanel({super.key, required this.sectionId, required this.onClose});

  @override
  ConsumerState<ChatCustomizePanel> createState() => _ChatCustomizePanelState();
}

class _ChatCustomizePanelState extends ConsumerState<ChatCustomizePanel> {
  static const _fonts = ['Arial', 'Caveat', 'Comfortaa', 'Courier Prime', 'Fira Code', 'Lobster', 'Merriweather', 'Nunito', 'Roboto Slab', 'Rubik'];
  static const _fontSizes = [10, 12, 14, 16, 18, 20, 24];
  static const _presetColors = ['#e74c3c', '#e67e22', '#f1c40f', '#2ecc71', '#1abc9c', '#3498db', '#9b59b6', '#e91e63', '#607d8b', '#795548'];

  String _font = '';
  int _fontSize = 0;
  String _textColor = '';
  String _usernameColor = '';
  String _bubbleColor = '';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final client = ref.read(apiClientProvider);
      final data = await client.get<Map<String, dynamic>>('/user-page-settings/${widget.sectionId}');
      final s = data['settings'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _font = s['chat_font'] as String? ?? '';
          _fontSize = s['chat_font_size'] as int? ?? 0;
          _textColor = s['chat_text_color'] as String? ?? '';
          _usernameColor = s['chat_username_color'] as String? ?? '';
          _bubbleColor = s['chat_bubble_color'] as String? ?? '';
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put<dynamic>('/user-page-settings/${widget.sectionId}', data: {
        'chat_font': _font.isEmpty ? null : _font,
        'chat_font_size': _fontSize == 0 ? null : _fontSize,
        'chat_text_color': _textColor.isEmpty ? null : _textColor,
        'chat_username_color': _usernameColor.isEmpty ? null : _usernameColor,
        'chat_bubble_color': _bubbleColor.isEmpty ? null : _bubbleColor,
      });
      widget.onClose();
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() { _font = ''; _fontSize = 0; _textColor = ''; _usernameColor = ''; _bubbleColor = ''; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    if (!_loaded) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Настройки чата', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              const Spacer(),
              GestureDetector(onTap: widget.onClose, child: Icon(Icons.close, size: 16, color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Шрифт', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: DropdownButtonFormField<String>(
              value: _font.isEmpty ? null : _font,
              hint: Text('По умолчанию', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                isDense: true, filled: true, fillColor: c.surfaceAlt,
              ),
              style: TextStyle(fontSize: 12, color: c.text),
              items: [
                const DropdownMenuItem(value: '', child: Text('По умолчанию', style: TextStyle(fontSize: 12))),
                ..._fonts.map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontSize: 12, fontFamily: f)))),
              ],
              onChanged: (v) => setState(() => _font = v ?? ''),
            ),
          ),
          const SizedBox(height: 10),
          Text('Размер шрифта', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: _fontSizes.map((s) {
              final selected = _fontSize == s;
              return GestureDetector(
                onTap: () => setState(() => _fontSize = selected ? 0 : s),
                child: Container(
                  width: 32, height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : c.surfaceAlt,
                    border: Border.all(color: selected ? c.accent : c.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$s', style: TextStyle(fontSize: 11, color: selected ? Colors.white : c.text, fontWeight: FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          _ColorRow(label: 'Цвет текста', value: _textColor, colors: _presetColors, c: c, onChanged: (v) => setState(() => _textColor = v)),
          _ColorRow(label: 'Цвет имени', value: _usernameColor, colors: _presetColors, c: c, onChanged: (v) => setState(() => _usernameColor = v)),
          _ColorRow(label: 'Цвет баббла', value: _bubbleColor, colors: _presetColors, c: c, onChanged: (v) => setState(() => _bubbleColor = v)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _reset, child: Text('Сбросить', style: TextStyle(fontSize: 12, color: c.textSecondary))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(_saving ? '...' : 'Сохранить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatefulWidget {
  final String label;
  final String value;
  final List<String> colors;
  final ColorSet c;
  final ValueChanged<String> onChanged;

  const _ColorRow({required this.label, required this.value, required this.colors, required this.c, required this.onChanged});

  @override
  State<_ColorRow> createState() => _ColorRowState();
}

class _ColorRowState extends State<_ColorRow> {
  void _openPicker() {
    Color current = widget.value.isNotEmpty ? _parseHex(widget.value) : Colors.blue;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (color) => current = color,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              final hex = '#${current.toHexString().substring(2)}';
              widget.onChanged(hex);
              Navigator.pop(ctx);
            },
            child: const Text('Выбрать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              ...widget.colors.map((hex) {
                final selected = widget.value == hex;
                final color = _parseHex(hex);
                return GestureDetector(
                  onTap: () => widget.onChanged(selected ? '' : hex),
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? c.text : Colors.transparent, width: 2),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: _openPicker,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                    gradient: const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                  ),
                ),
              ),
              if (widget.value.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => widget.onChanged(''),
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border), color: c.surfaceAlt),
                    child: Icon(Icons.close, size: 12, color: c.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return Colors.grey;
  }
}
