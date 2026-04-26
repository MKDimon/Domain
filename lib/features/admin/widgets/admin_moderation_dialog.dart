import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

Future<bool> showAdminModerationDialog({
  required BuildContext context,
  required AdminUser user,
  required AdminApi api,
  required ColorSet c,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ModerationDialog(user: user, api: api, c: c),
  );
  return result ?? false;
}

class _ModerationDialog extends StatefulWidget {
  final AdminUser user;
  final AdminApi api;
  final ColorSet c;
  const _ModerationDialog({required this.user, required this.api, required this.c});

  @override
  State<_ModerationDialog> createState() => _ModerationDialogState();
}

class _ModerationDialogState extends State<_ModerationDialog> {
  String _actionType = 'warning';
  final _reasonCtrl = TextEditingController();
  int _severity = 1;
  String _scope = 'platform';
  String _duration = 'none';
  String _visibility = 'mods';
  final _noteCtrl = TextEditingController();
  bool _notify = true;
  bool _submitting = false;
  List<ModerationTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      _templates = await widget.api.listTemplates();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onTypeChanged(String type) {
    setState(() {
      _actionType = type;
      if (type == 'warning') {
        _duration = 'none';
      } else if (type == 'mute') {
        _duration = '1d';
      } else {
        _duration = 'permanent';
      }
    });
  }

  void _applyTemplate(ModerationTemplate tpl) {
    setState(() {
      _reasonCtrl.text = tpl.body;
      if (tpl.defaultType != null) _onTypeChanged(tpl.defaultType!);
      if (tpl.defaultDays != null) {
        _duration = '${tpl.defaultDays}d';
      }
    });
  }

  String? _durationToExpiresAt() {
    if (_duration == 'none' || _duration == 'permanent') return null;
    final now = DateTime.now().toUtc();
    Duration dur;
    switch (_duration) {
      case '1h': dur = const Duration(hours: 1);
      case '24h' || '1d': dur = const Duration(hours: 24);
      case '3d': dur = const Duration(days: 3);
      case '7d': dur = const Duration(days: 7);
      case '30d': dur = const Duration(days: 30);
      default: return null;
    }
    return now.add(dur).toIso8601String();
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.api.issueModeration(widget.user.id, {
        'action_type': _actionType,
        'reason': _reasonCtrl.text.trim(),
        'severity': _severity,
        'community_id': _scope == 'platform' ? null : 0,
        'expires_at': _durationToExpiresAt(),
        'visibility': _visibility,
        'internal_note': _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
        'notify': _notify,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Модерация: ${widget.user.effectiveName}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 16),

              // Type selection
              _label('Тип', c),
              const SizedBox(height: 6),
              Row(
                children: [
                  _typeOption('warning', '⚠️ Предупреждение', c),
                  const SizedBox(width: 6),
                  _typeOption('mute', '🔇 Мут', c),
                  const SizedBox(width: 6),
                  _typeOption('ban', '🚫 Бан', c),
                ],
              ),
              const SizedBox(height: 14),

              // Severity (only for warnings)
              if (_actionType == 'warning') ...[
                _label('Серьёзность', c),
                const SizedBox(height: 6),
                _severityBar(c),
                const SizedBox(height: 14),
              ],

              // Reason
              _label('Причина', c),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: c.text),
                decoration: _inputDeco(c, 'Опишите причину...'),
              ),
              if (_templates.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _templates.map((tpl) => GestureDetector(
                    onTap: () => _applyTemplate(tpl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(tpl.label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 14),

              // Duration + Scope
              if (_actionType != 'warning') ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Длительность', c),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _duration,
                            decoration: _inputDeco(c, ''),
                            dropdownColor: c.surface,
                            style: TextStyle(fontSize: 14, color: c.text),
                            items: const [
                              DropdownMenuItem(value: '1h', child: Text('1 час')),
                              DropdownMenuItem(value: '1d', child: Text('1 день')),
                              DropdownMenuItem(value: '3d', child: Text('3 дня')),
                              DropdownMenuItem(value: '7d', child: Text('7 дней')),
                              DropdownMenuItem(value: '30d', child: Text('30 дней')),
                              DropdownMenuItem(value: 'permanent', child: Text('Навсегда')),
                            ],
                            onChanged: (v) => setState(() => _duration = v ?? 'permanent'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Область', c),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _scopeOption('platform', 'Платформа', c),
                              const SizedBox(width: 6),
                              _scopeOption('community', 'Сообщество', c),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Visibility
              _label('Видимость', c),
              const SizedBox(height: 6),
              Row(
                children: [
                  _visOption('user', 'Пользователь', c),
                  const SizedBox(width: 6),
                  _visOption('mods', 'Модераторы', c),
                  const SizedBox(width: 6),
                  _visOption('public', 'Публично', c),
                ],
              ),
              const SizedBox(height: 14),

              // Internal note
              _label('Внутренняя заметка', c),
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 14, color: c.text),
                decoration: _inputDeco(c, 'Необязательно...'),
              ),
              const SizedBox(height: 10),

              // Notify
              GestureDetector(
                onTap: () => setState(() => _notify = !_notify),
                child: Row(
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: Checkbox(
                        value: _notify,
                        onChanged: (v) => setState(() => _notify = v ?? true),
                        activeColor: c.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Уведомить пользователя', style: TextStyle(fontSize: 13, color: c.text)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Отмена', style: TextStyle(color: c.text)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitting || _reasonCtrl.text.trim().isEmpty ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _actionType == 'ban' ? c.error : (_actionType == 'mute' ? const Color(0xFFA855F7) : c.warning),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_actionType == 'warning' ? 'Предупредить' : (_actionType == 'mute' ? 'Замутить' : 'Забанить')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, ColorSet c) => Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
      );

  Widget _typeOption(String type, String label, ColorSet c) {
    final active = _actionType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTypeChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? c.accent.withValues(alpha: 0.1) : c.surfaceAlt,
            border: Border.all(color: active ? c.accent : c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: active ? c.text : c.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _severityBar(ColorSet c) {
    return Row(
      children: [
        ...List.generate(3, (i) {
          final on = i < _severity;
          return GestureDetector(
            onTap: () => setState(() => _severity = i + 1),
            child: Container(
              width: 26,
              height: 6,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: on ? c.warning : c.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
        const SizedBox(width: 10),
        Text(
          _severity == 1 ? 'Низкая' : (_severity == 2 ? 'Средняя' : 'Высокая'),
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _scopeOption(String scope, String label, ColorSet c) {
    final active = _scope == scope;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _scope = scope),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? c.accent.withValues(alpha: 0.1) : c.surfaceAlt,
            border: Border.all(color: active ? c.accent : c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: active ? c.text : c.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _visOption(String vis, String label, ColorSet c) {
    final active = _visibility == vis;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibility = vis),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? c.accent.withValues(alpha: 0.1) : c.surfaceAlt,
            border: Border.all(color: active ? c.accent : c.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: active ? c.text : c.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(ColorSet c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
        filled: true,
        fillColor: c.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );
}
