import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/payments_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/tier_badge.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  List<Invoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      final api = ref.read(paymentsApiProvider);
      final items = await api.listInvoices();
      if (mounted) setState(() { _invoices = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _invoices = []; _loading = false; });
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd.MM.yyyy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _formatDateLong(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMMM yyyy', 'ru').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _statusLabel(String status, AppLocalizations l) {
    switch (status) {
      case 'succeeded': return l.billingStatusSucceeded;
      case 'canceled': return l.billingStatusCanceled;
      case 'waiting_for_capture': return l.billingStatusWaiting;
      default: return l.billingStatusPending;
    }
  }

  Color _statusColor(String status, ColorSet c) {
    switch (status) {
      case 'succeeded': return c.success;
      case 'canceled': return c.error;
      default: return c.accent;
    }
  }

  String _formatMethod(String method, AppLocalizations l) {
    switch (method) {
      case 'bank_card': return l.billingMethodBankCard;
      case 'sbp': return 'СБП';
      case 'yoo_money': return 'ЮMoney';
      case 'tinkoff_bank': return 'T-Pay';
      case 'sberbank': return 'SberPay';
      case 'mock': return 'test';
      default: return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final l = AppLocalizations.of(context)!;
    final user = ref.watch(authProvider).user;
    final tier = user?.subscription?.tier ?? 'free';
    final expiresAt = user?.subscription?.currentPeriodEnd;
    final lastSuccessful = _invoices.where((i) => i.status == 'succeeded').firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(l.billingPageTitle, style: TextStyle(
            fontSize: 25.6, fontWeight: FontWeight.w700, color: c.text,
          )),
          const SizedBox(height: 4),
          Text(l.billingPageSubtitle, style: TextStyle(
            fontSize: 14.4, color: c.textSecondary,
          )),
          const SizedBox(height: 24),

          // Current plan card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TierBadge(tier: tier),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tier == 'pro' && lastSuccessful != null)
                          Text.rich(TextSpan(children: [
                            TextSpan(text: '${lastSuccessful.amountRub.round()} ₽', style: TextStyle(
                              fontSize: 20.8, fontWeight: FontWeight.w700, color: c.text,
                            )),
                            TextSpan(text: ' / ${lastSuccessful.period == 'yearly' ? l.pricingYearly : l.pricingMonthly}', style: TextStyle(
                              fontSize: 13.6, fontWeight: FontWeight.w500, color: c.textSecondary,
                            )),
                          ]))
                        else
                          Text(tier == 'pro' ? 'Pro' : 'Free', style: TextStyle(
                            fontSize: 20.8, fontWeight: FontWeight.w700, color: c.text,
                          )),
                        const SizedBox(height: 4),
                        if (tier == 'pro' && expiresAt != null)
                          Text('${l.billingActiveUntil}: ${_formatDateLong(expiresAt)}', style: TextStyle(
                            fontSize: 13.1, color: c.textSecondary,
                          ))
                        else if (tier == 'free')
                          Text(l.billingFreeHint, style: TextStyle(
                            fontSize: 13.1, color: c.textSecondary,
                          )),
                      ],
                    ),
                  ],
                ),
                tier == 'free'
                    ? ElevatedButton(
                        onPressed: () => context.go('/pricing'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13.6),
                        ),
                        child: Text(l.pricingUpgradePro),
                      )
                    : OutlinedButton(
                        onPressed: () => context.go('/pricing'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13.6),
                        ),
                        child: Text(l.billingRenewOrChange),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Invoice history
          Text(l.billingInvoiceHistory.toUpperCase(), style: TextStyle(
            fontSize: 13.1, fontWeight: FontWeight.w600, color: c.textSecondary,
            letterSpacing: 0.05 * 13.1,
          )),
          const SizedBox(height: 12),

          if (_loading)
            Text(l.billingLoading, style: TextStyle(fontSize: 14.4, color: c.textSecondary))
          else if (_invoices.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border, style: BorderStyle.none),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(l.billingEmptyInvoices, textAlign: TextAlign.center, style: TextStyle(
                color: c.textSecondary,
              )),
            )
          else
            _buildInvoiceTable(c, l),
        ],
      ),
    );
  }

  Widget _buildInvoiceTable(ColorSet c, AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: c.surfaceAlt,
            child: Row(
              children: [
                SizedBox(width: 90, child: Text(l.billingColDate, style: _headerStyle(c))),
                Expanded(child: Text(l.billingColDesc, style: _headerStyle(c))),
                SizedBox(width: 90, child: Text(l.billingColMethod, style: _headerStyle(c))),
                SizedBox(width: 80, child: Text(l.billingColAmount, textAlign: TextAlign.right, style: _headerStyle(c))),
                SizedBox(width: 100, child: Text(l.billingColStatus, textAlign: TextAlign.center, style: _headerStyle(c))),
              ],
            ),
          ),
          // Rows
          ...List.generate(_invoices.length, (i) {
            final inv = _invoices[i];
            final isLast = i == _invoices.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: isLast ? null : BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(_formatDate(inv.capturedAt ?? inv.createdAt), style: TextStyle(fontSize: 14.1, color: c.text))),
                  Expanded(child: Text(inv.description, style: TextStyle(fontSize: 14.1, color: c.text), overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 90, child: Text(_formatMethod(inv.paymentMethodType, l), style: TextStyle(fontSize: 13.1, color: c.textSecondary))),
                  SizedBox(width: 80, child: Text('${inv.amountRub.round()} ₽', textAlign: TextAlign.right, style: TextStyle(fontSize: 14.1, fontWeight: FontWeight.w600, color: c.text))),
                  SizedBox(
                    width: 100,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(inv.status, c).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(inv.status, l),
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: _statusColor(inv.status, c),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  TextStyle _headerStyle(ColorSet c) => TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: c.textSecondary,
    letterSpacing: 0.04 * 12,
  );
}
