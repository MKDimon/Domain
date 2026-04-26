import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/payments_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';

class BillingSuccessScreen extends ConsumerStatefulWidget {
  final String? paymentId;
  const BillingSuccessScreen({super.key, this.paymentId});

  @override
  ConsumerState<BillingSuccessScreen> createState() => _BillingSuccessScreenState();
}

class _BillingSuccessScreenState extends ConsumerState<BillingSuccessScreen> {
  PaymentStatus? _status;
  String _error = '';
  Timer? _pollTimer;
  int _attempts = 0;
  static const _maxAttempts = 30;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    _attempts++;
    final id = widget.paymentId;
    if (id == null || id.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)?.billingNoPaymentId ?? 'Missing payment ID');
      _pollTimer?.cancel();
      return;
    }

    try {
      final api = ref.read(paymentsApiProvider);
      final status = await api.getStatus(id);
      if (!mounted) return;
      setState(() => _status = status);

      if (status.isSucceeded) {
        _pollTimer?.cancel();
        await ref.read(authProvider.notifier).refreshProfile();
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) context.go('/profile');
        });
        return;
      }
      if (status.isCanceled) {
        _pollTimer?.cancel();
        return;
      }
      if (_attempts >= _maxAttempts) {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final l = AppLocalizations.of(context)!;
    final isPending = _status == null || _status!.isPending;
    final isSucceeded = _status?.isSucceeded == true;
    final isCanceled = _status?.isCanceled == true;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPending && !isCanceled) ...[
                SizedBox(
                  width: 44, height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation(c.accent),
                    backgroundColor: c.border,
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.billingProcessingTitle, style: TextStyle(
                  fontSize: 22.4, fontWeight: FontWeight.w700, color: c.text,
                )),
                const SizedBox(height: 8),
                Text(l.billingProcessingDesc, textAlign: TextAlign.center, style: TextStyle(
                  color: c.textSecondary, height: 1.5,
                )),
              ] else if (isSucceeded) ...[
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: c.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('✓', style: TextStyle(fontSize: 32, color: Colors.white, height: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l.billingSuccessTitle, style: TextStyle(
                  fontSize: 22.4, fontWeight: FontWeight.w700, color: c.text,
                )),
                const SizedBox(height: 8),
                Text(
                  l.billingSuccessDesc(_status!.period == 'yearly' ? l.pricingYearly : l.pricingMonthly),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/profile'),
                  child: Text(l.billingGoToProfile),
                ),
              ] else if (isCanceled) ...[
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: c.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('✕', style: TextStyle(fontSize: 32, color: Colors.white, height: 1)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l.billingCanceledTitle, style: TextStyle(
                  fontSize: 22.4, fontWeight: FontWeight.w700, color: c.text,
                )),
                const SizedBox(height: 8),
                Text(l.billingCanceledDesc, textAlign: TextAlign.center, style: TextStyle(
                  color: c.textSecondary, height: 1.5,
                )),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/pricing'),
                  child: Text(l.billingTryAgain),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: TextStyle(fontSize: 13.6, color: c.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
