import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _typeCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _selectedType = 'suggestion';
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _typeCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_bodyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/feedback', data: {
        'type': _selectedType,
        'body': _bodyCtrl.text.trim(),
      });
      if (mounted) setState(() { _sent = true; _sending = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка отправки')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Обратная связь'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sent
                ? Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.check_circle, size: 64, color: c.success),
                      const SizedBox(height: 16),
                      Text('Спасибо за обратную связь!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.text)),
                      const SizedBox(height: 8),
                      Text('Мы рассмотрим ваше обращение.', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.textOnAccent),
                        child: const Text('Вернуться'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Тип обращения', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _TypeChip(label: 'Предложение', value: 'suggestion', selected: _selectedType, c: c, onTap: (v) => setState(() => _selectedType = v)),
                          _TypeChip(label: 'Жалоба', value: 'complaint', selected: _selectedType, c: c, onTap: (v) => setState(() => _selectedType = v)),
                          _TypeChip(label: 'Вопрос', value: 'question', selected: _selectedType, c: c, onTap: (v) => setState(() => _selectedType = v)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Сообщение', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bodyCtrl,
                        maxLines: 6,
                        style: TextStyle(fontSize: 14, color: c.text),
                        decoration: InputDecoration(
                          hintText: 'Опишите ваше обращение...',
                          hintStyle: TextStyle(color: c.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.accent)),
                          filled: true, fillColor: c.surface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: c.textOnAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _sending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Отправить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ColorSet c;
  final void Function(String) onTap;
  const _TypeChip({required this.label, required this.value, required this.selected, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.accent.withValues(alpha: 0.12) : c.surfaceAlt,
          border: Border.all(color: isSelected ? c.accent : c.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? c.accent : c.text)),
      ),
    );
  }
}
