import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../data/api/user_moderation_api.dart';

class ViolationsTab extends ConsumerStatefulWidget {
  const ViolationsTab({super.key});

  @override
  ConsumerState<ViolationsTab> createState() => _ViolationsTabState();
}

class _ViolationsTabState extends ConsumerState<ViolationsTab> {
  List<ModerationAction> _actions = [];
  bool _loading = true;
  int? _appealingId;
  final _appealController = TextEditingController();
  bool _submittingAppeal = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = UserModerationApi(ref.read(apiClientProvider));
      final actions = await api.listOwn();
      if (mounted) setState(() { _actions = actions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAppeal(int actionId) async {
    final msg = _appealController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _submittingAppeal = true);
    try {
      final api = UserModerationApi(ref.read(apiClientProvider));
      await api.fileAppeal(actionId, msg);
      _appealController.clear();
      setState(() => _appealingId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Апелляция отправлена')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить апелляцию')),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingAppeal = false);
    }
  }

  int get _activeCount => _actions.where((a) => a.isActive).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Нарушения', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              _activeCount > 0
                  ? 'Активных нарушений: $_activeCount'
                  : 'У вас нет активных нарушений',
              style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 18),

            // Info box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.22)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Здесь отображаются все модерационные действия, применённые к вашему аккаунту. '
                      'Вы можете подать апелляцию на активные нарушения.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_actions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text('Нарушений нет', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: _actions.map((a) => _buildActionRow(a, theme)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(ModerationAction a, ThemeData theme) {
    final isActive = a.isActive;
    final isResolved = a.revokedAt != null || !isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.04)
            : null,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Opacity(
        opacity: isResolved && !isActive ? 0.75 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotColor(a),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _actionTypeLabel(a),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        a.communityName != null ? a.communityName! : 'Платформа',
                        style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color),
                      ),
                      _statusBadge(a, theme),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Meta
                  Wrap(
                    spacing: 14,
                    children: [
                      Text('Выдано: ${_fmtDate(a.createdAt)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                      if (a.expiresAt != null && isActive)
                        Text('Истекает: ${_fmtDate(a.expiresAt)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                      if (a.revokedAt != null)
                        Text('Снято: ${_fmtDate(a.revokedAt)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Reason
                  Text(a.reason, style: const TextStyle(fontSize: 14, height: 1.45)),

                  if (a.revokeReason != null && a.revokeReason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Причина снятия: ${a.revokeReason}',
                      style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],

                  // Appeal
                  if (isActive && a.actionType != 'warning') ...[
                    const SizedBox(height: 12),
                    if (_appealingId == a.id) ...[
                      TextField(
                        controller: _appealController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Опишите вашу позицию...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => setState(() => _appealingId = null),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: const Text('Отмена'),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _submittingAppeal ? null : () => _submitAppeal(a.id),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: _submittingAppeal
                                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Отправить'),
                          ),
                        ],
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _appealingId = a.id;
                          _appealController.clear();
                        }),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('Подать апелляцию'),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _dotColor(ModerationAction a) {
    if (a.revokedAt != null) return Colors.grey;
    return switch (a.actionType) {
      'warning' => const Color(0xFFF59E0B),
      'mute' => const Color(0xFFA855F7),
      'ban' => const Color(0xFFEB5757),
      _ => Colors.grey,
    };
  }

  String _actionTypeLabel(ModerationAction a) {
    final base = switch (a.actionType) {
      'warning' => 'Предупреждение',
      'mute' => 'Мут',
      'ban' => 'Бан',
      _ => a.actionType,
    };
    if (a.severity != null) return '$base (ур. ${a.severity})';
    return base;
  }

  Widget _statusBadge(ModerationAction a, ThemeData theme) {
    final label = a.statusLabel;
    final (bg, fg) = switch (label) {
      'активно' when a.actionType == 'ban' => (const Color(0xFFEB5757).withValues(alpha: 0.18), const Color(0xFFEB5757)),
      'активно' when a.actionType == 'mute' => (const Color(0xFFA855F7).withValues(alpha: 0.18), const Color(0xFFC084FC)),
      'предупреждение' => (const Color(0xFFF59E0B).withValues(alpha: 0.18), const Color(0xFFF59E0B)),
      _ => (theme.colorScheme.surfaceContainerHighest, theme.textTheme.bodySmall?.color ?? Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: label == 'истекло' || label == 'снято'
            ? Border.all(color: theme.dividerColor)
            : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return '—';
    }
  }
}
