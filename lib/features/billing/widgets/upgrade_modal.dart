import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

enum UpgradeTrigger {
  communityLimit,
  whitelabel,
  export_,
  storage,
  coadmin,
  moderation,
  webapp,
}

class _TriggerContent {
  final String title;
  final String description;
  final List<String> benefits;
  _TriggerContent(this.title, this.description, this.benefits);
}

_TriggerContent _contentFor(UpgradeTrigger trigger, AppLocalizations l) {
  switch (trigger) {
    case UpgradeTrigger.communityLimit:
      return _TriggerContent(
        l.upgradeCommunityLimitTitle,
        l.upgradeCommunityLimitDesc,
        [l.upgradeCommunityLimitB1, l.upgradeCommunityLimitB2, l.upgradeCommunityLimitB3],
      );
    case UpgradeTrigger.whitelabel:
      return _TriggerContent(
        l.upgradeWhitelabelTitle,
        l.upgradeWhitelabelDesc,
        [l.upgradeWhitelabelB1, l.upgradeWhitelabelB2, l.upgradeWhitelabelB3],
      );
    case UpgradeTrigger.export_:
      return _TriggerContent(
        l.upgradeExportTitle,
        l.upgradeExportDesc,
        [l.upgradeExportB1, l.upgradeExportB2, l.upgradeExportB3],
      );
    case UpgradeTrigger.storage:
      return _TriggerContent(
        l.upgradeStorageTitle,
        l.upgradeStorageDesc,
        [l.upgradeStorageB1, l.upgradeStorageB2, l.upgradeStorageB3],
      );
    case UpgradeTrigger.coadmin:
      return _TriggerContent(
        l.upgradeCoadminTitle,
        l.upgradeCoadminDesc,
        [l.upgradeCoadminB1, l.upgradeCoadminB2, l.upgradeCoadminB3],
      );
    case UpgradeTrigger.moderation:
      return _TriggerContent(
        l.upgradeModerationTitle,
        l.upgradeModerationDesc,
        [l.upgradeModerationB1, l.upgradeModerationB2, l.upgradeModerationB3],
      );
    case UpgradeTrigger.webapp:
      return _TriggerContent(
        l.upgradeWebappTitle,
        l.upgradeWebappDesc,
        [l.upgradeWebappB1, l.upgradeWebappB2, l.upgradeWebappB3],
      );
  }
}

Future<bool?> showUpgradeModal(
  BuildContext context, {
  required UpgradeTrigger trigger,
  dynamic currentValue,
  dynamic limitValue,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'upgrade',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, anim, secAnim, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, anim, secAnim) => _UpgradeDialog(
      trigger: trigger,
      currentValue: currentValue,
      limitValue: limitValue,
    ),
  );
}

class _UpgradeDialog extends StatelessWidget {
  final UpgradeTrigger trigger;
  final dynamic currentValue;
  final dynamic limitValue;

  const _UpgradeDialog({
    required this.trigger,
    this.currentValue,
    this.limitValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final l = AppLocalizations.of(context)!;
    final content = _contentFor(trigger, l);
    final hasLimit = currentValue != null && limitValue != null;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 60,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button row
              Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, size: 18, color: c.textSecondary),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),

              // Star icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.accent.withValues(alpha: 0.2),
                      c.accent.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(Icons.star_rounded, size: 28, color: c.accent),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                content.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                content.description,
                style: TextStyle(
                  fontSize: 14.4,
                  height: 1.55,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Limit visualization
              if (hasLimit) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l.upgradeCurrentUsage,
                            style: TextStyle(
                              fontSize: 13.6,
                              color: c.textSecondary,
                            ),
                          ),
                          Text(
                            '$currentValue / $limitValue',
                            style: TextStyle(
                              fontSize: 13.6,
                              fontWeight: FontWeight.w600,
                              color: c.error,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: 1.0,
                          minHeight: 6,
                          backgroundColor: c.bg,
                          valueColor: AlwaysStoppedAnimation(c.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Benefits
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: content.benefits.map((b) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.check, size: 14, color: c.success),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                fontSize: 13.6,
                                height: 1.5,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),

              // Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    context.go('/pricing');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    textStyle: const TextStyle(fontSize: 14.4, fontWeight: FontWeight.w600),
                  ),
                  child: Text(l.upgradeGoPro),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    textStyle: const TextStyle(fontSize: 13.6),
                  ),
                  child: Text(l.upgradeNotNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
