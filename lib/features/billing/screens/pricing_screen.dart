import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/payments_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  String _cycle = 'yearly';
  bool _paying = false;
  String _payError = '';

  int _proPrice(PricingInfo data) {
    if (_cycle == 'monthly') return data.pro.priceMonthly;
    return (data.pro.priceYearly / 12).round();
  }

  int _yearlySavings(PricingInfo data) {
    return data.pro.priceMonthly * 12 - data.pro.priceYearly;
  }

  int _yearlyDiscountPercent(PricingInfo data) {
    final monthly12 = data.pro.priceMonthly * 12;
    if (monthly12 == 0) return 0;
    return ((_yearlySavings(data) / monthly12) * 100).round();
  }

  Future<void> _upgrade() async {
    if (_paying) return;
    setState(() {
      _paying = true;
      _payError = '';
    });
    try {
      final api = ref.read(paymentsApiProvider);
      final result = await api.createSubscription(_cycle);
      if (result.confirmationUrl.isNotEmpty) {
        final uri = Uri.parse(result.confirmationUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      setState(() {
        _payError = e.toString();
      });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final l = AppLocalizations.of(context)!;
    final pricingAsync = ref.watch(pricingProvider);
    final isAuth = ref.watch(authProvider).user != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: pricingAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.pricingLoading, style: TextStyle(color: c.textSecondary))),
            ),
            error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: c.error))),
            data: (data) => _buildContent(context, c, l, data, isAuth),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorSet c, AppLocalizations l, PricingInfo data, bool isAuth) {
    final discount = _yearlyDiscountPercent(data);
    final isWide = MediaQuery.of(context).size.width > 720;

    return Column(
      children: [
        // Hero
        Text(l.pricingTitle, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 35.2, fontWeight: FontWeight.w800, letterSpacing: -0.02 * 35.2, color: c.text,
        )),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(l.pricingSubtitle, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 16, color: c.textSecondary,
          )),
        ),
        const SizedBox(height: 24),

        // Billing toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleBtn(c, l.pricingMonthly, 'monthly', null),
              const SizedBox(width: 4),
              _toggleBtn(c, l.pricingYearly, 'yearly', discount > 0 ? '−$discount%' : null),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Trial banner
        if (data.trialDays > 0)
          _buildTrialBanner(c, l, data, isAuth),

        // Plans grid
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFreePlan(c, l, data, isAuth)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildProPlan(c, l, data, isAuth)),
                  ],
                )
              : Column(
                  children: [
                    _buildFreePlan(c, l, data, isAuth),
                    const SizedBox(height: 20),
                    _buildProPlan(c, l, data, isAuth),
                  ],
                ),
        ),
        const SizedBox(height: 56),

        // FAQ
        _buildFaq(c, l, data),
      ],
    );
  }

  Widget _toggleBtn(ColorSet c, String label, String value, String? badge) {
    final active = _cycle == value;
    return GestureDetector(
      onTap: () => setState(() => _cycle = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: active ? c.text : c.textSecondary,
            )),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.success,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge, style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
                )),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrialBanner(ColorSet c, AppLocalizations l, PricingInfo data, bool isAuth) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent.withValues(alpha: 0.08), c.accent.withValues(alpha: 0.02)],
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.pricingTrialTitle(data.trialDays), style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: c.text,
                )),
                const SizedBox(height: 4),
                Text(l.pricingTrialHint, style: TextStyle(
                  fontSize: 13.6, color: c.textSecondary,
                )),
              ],
            ),
          ),
          if (!isAuth) ...[
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => context.go('/register'),
              child: Text(l.pricingStartTrial),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFreePlan(ColorSet c, AppLocalizations l, PricingInfo data, bool isAuth) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Free', style: TextStyle(fontSize: 17.6, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: Text(l.pricingFreeTagline, style: TextStyle(fontSize: 14.1, color: c.textSecondary)),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('0₽', style: TextStyle(
                fontSize: 38.4, fontWeight: FontWeight.w800, letterSpacing: -0.02 * 38.4, color: c.text,
              )),
              const SizedBox(width: 6),
              Text('/ ${l.pricingForever}', style: TextStyle(fontSize: 15.2, color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(height: 18, child: Text(l.pricingFreePriceSub, style: TextStyle(fontSize: 13.1, color: c.textSecondary))),
          const SizedBox(height: 22),
          if (!isAuth)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/register'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                child: Text(l.pricingStartFree),
              ),
            ),
          if (!isAuth) const SizedBox(height: 24),
          ..._featureItems(c, [
            l.pricingFreeCommunities(data.free.communityLimit),
            l.pricingFreeStorage,
            l.pricingFreePlugins,
            l.pricingFreeAnalytics,
            l.pricingFreeAdmins,
          ]),
        ],
      ),
    );
  }

  Widget _buildProPlan(ColorSet c, AppLocalizations l, PricingInfo data, bool isAuth) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.accent),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: c.accent.withValues(alpha: 0.12), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pro', style: TextStyle(fontSize: 17.6, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 4),
              SizedBox(
                height: 44,
                child: Text(l.pricingProTagline, style: TextStyle(fontSize: 14.1, color: c.textSecondary)),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${_proPrice(data)}₽', style: TextStyle(
                    fontSize: 38.4, fontWeight: FontWeight.w800, letterSpacing: -0.02 * 38.4, color: c.text,
                  )),
                  const SizedBox(width: 6),
                  Text('/ ${l.pricingMonth}', style: TextStyle(fontSize: 15.2, color: c.textSecondary)),
                ],
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 18,
                child: Text(
                  _cycle == 'yearly'
                      ? l.pricingYearlyBillingSub(data.pro.priceYearly, _yearlySavings(data))
                      : l.pricingMonthlyBillingSub,
                  style: TextStyle(fontSize: 13.1, color: c.textSecondary),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: !isAuth
                    ? ElevatedButton(
                        onPressed: () => context.go('/register'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(l.pricingUpgradePro),
                      )
                    : ElevatedButton(
                        onPressed: _paying ? null : _upgrade,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(_paying ? l.pricingRedirecting : l.pricingUpgradePro),
                      ),
              ),
              if (_payError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_payError, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.1, color: c.error)),
              ],
              const SizedBox(height: 24),
              ..._featureItems(c, [
                l.pricingProIncludesFree,
                l.pricingProCommunities(data.pro.communityLimit),
                l.pricingProStorage,
                l.pricingProAnalytics,
                l.pricingProModerators(data.pro.moderatorLimit),
                l.pricingProAutomod,
                l.pricingProExport,
                l.pricingProWhitelabel,
                l.pricingProNoAds,
              ]),
            ],
          ),
        ),
        Positioned(
          top: -11,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.pricingRecommended.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.06 * 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _featureItems(ColorSet c, List<String> features) {
    return features.map((f) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✓', style: TextStyle(
            fontWeight: FontWeight.w700, color: c.success, fontSize: 14.7,
          )),
          const SizedBox(width: 10),
          Expanded(child: Text(f, style: TextStyle(
            fontSize: 14.7, height: 1.5, color: c.text,
          ))),
        ],
      ),
    )).toList();
  }

  Widget _buildFaq(ColorSet c, AppLocalizations l, PricingInfo data) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        children: [
          Text(l.pricingFaqTitle, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 22.4, fontWeight: FontWeight.w700, color: c.text,
          )),
          const SizedBox(height: 20),
          _faqItem(c, l.pricingFaqRefundQ, l.pricingFaqRefundA(data.trialDays)),
          _faqItem(c, l.pricingFaqCancelQ, l.pricingFaqCancelA),
          _faqItem(c, l.pricingFaqRenewQ, l.pricingFaqRenewA),
          _faqItem(c, l.pricingFaqDowngradeQ, l.pricingFaqDowngradeA),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              text: l.pricingOfferNote,
              style: TextStyle(fontSize: 13.6, color: c.textSecondary),
              children: [
                TextSpan(
                  text: l.pricingOfferLink,
                  style: TextStyle(color: c.accent),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _faqItem(ColorSet c, String question, String answer) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: TextStyle(
            fontSize: 15.2, fontWeight: FontWeight.w600, color: c.text,
          )),
          const SizedBox(height: 6),
          Text(answer, style: TextStyle(
            fontSize: 14.1, height: 1.6, color: c.textSecondary,
          )),
        ],
      ),
    );
  }
}
