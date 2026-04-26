import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';
import '../../../l10n/app_localizations.dart';

const _reasons = [
  'fraud', 'spam', 'insult', 'extremism', 'adult', 'copyright', 'threat', 'other',
];

Future<void> showReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String targetType,
  required int targetId,
  String? targetPreview,
}) {
  return showDialog(
    context: context,
    builder: (_) => _ReportDialog(
      ref: ref,
      targetType: targetType,
      targetId: targetId,
      targetPreview: targetPreview,
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  final WidgetRef ref;
  final String targetType;
  final int targetId;
  final String? targetPreview;

  const _ReportDialog({
    required this.ref,
    required this.targetType,
    required this.targetId,
    this.targetPreview,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _selectedReason = 'spam';
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _reasonLabel(AppLocalizations l, String reason) {
    return switch (reason) {
      'spam' => l.reportReasonSpam,
      'fraud' => l.reportReasonFraud,
      'insult' => l.reportReasonInsult,
      'extremism' => l.reportReasonExtremism,
      'adult' => l.reportReasonAdult,
      'copyright' => l.reportReasonCopyright,
      'threat' => l.reportReasonThreat,
      _ => l.reportReasonOther,
    };
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() { _sending = true; _error = null; });
    try {
      final api = AdminApi(widget.ref.read(apiClientProvider));
      await api.createComplaint(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selectedReason,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        setState(() => _error = l.reportFailed);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final l = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(26),
        child: _sent ? _buildSuccess(c, l) : _buildForm(c, l),
      ),
    );
  }

  Widget _buildSuccess(ColorSet c, AppLocalizations l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.success.withValues(alpha: 0.15),
          ),
          child: Icon(Icons.check, size: 28, color: c.success),
        ),
        const SizedBox(height: 16),
        Text(l.reportSentTitle, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 8),
        Text(l.reportSentMessage, style: TextStyle(fontSize: 14, color: c.textSecondary, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(l.reportDone),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildForm(ColorSet c, AppLocalizations l) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.reportTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.close, size: 16, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.reportSubtitle, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5)),
          const SizedBox(height: 18),

          if (widget.targetPreview != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.reportTarget, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.04)),
                  const SizedBox(height: 4),
                  Text(widget.targetPreview!, style: TextStyle(fontSize: 13, color: c.textSecondary, fontStyle: FontStyle.italic, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          ...List.generate(_reasons.length, (i) {
            final reason = _reasons[i];
            final selected = _selectedReason == reason;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: () => setState(() => _selectedReason = reason),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: selected ? c.accent : c.border),
                    borderRadius: BorderRadius.circular(8),
                    color: selected ? c.accent.withValues(alpha: 0.08) : null,
                  ),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: reason,
                        groupValue: _selectedReason,
                        onChanged: (v) => setState(() => _selectedReason = v!),
                        activeColor: c.accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 10),
                      Text(_reasonLabel(l, reason), style: TextStyle(fontSize: 14, color: c.text)),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          Text(l.reportCommentLabel, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 5),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: l.reportCommentHint,
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
              filled: true,
              fillColor: c.surfaceAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              counterText: '',
              isDense: true,
            ),
            style: TextStyle(fontSize: 14, color: c.text),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(fontSize: 13, color: c.error)),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.reportCancel, style: TextStyle(color: c.text)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(_sending ? l.reportSending : l.reportSubmit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
