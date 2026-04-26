import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ─── Models ───────────────────────────────────────────────────────

class PricingInfo {
  final String platformName;
  final int trialDays;
  final PricingPro pro;
  final PricingFree free;

  PricingInfo({
    required this.platformName,
    required this.trialDays,
    required this.pro,
    required this.free,
  });

  factory PricingInfo.fromJson(Map<String, dynamic> json) => PricingInfo(
        platformName: json['platform_name'] as String? ?? 'Domain',
        trialDays: json['trial_days'] as int? ?? 0,
        pro: PricingPro.fromJson(json['pro'] as Map<String, dynamic>? ?? {}),
        free:
            PricingFree.fromJson(json['free'] as Map<String, dynamic>? ?? {}),
      );
}

class PricingPro {
  final int priceMonthly;
  final int priceYearly;
  final int communityLimit;
  final int moderatorLimit;

  PricingPro({
    required this.priceMonthly,
    required this.priceYearly,
    required this.communityLimit,
    required this.moderatorLimit,
  });

  factory PricingPro.fromJson(Map<String, dynamic> json) => PricingPro(
        priceMonthly: json['price_monthly'] as int? ?? 0,
        priceYearly: json['price_yearly'] as int? ?? 0,
        communityLimit: json['community_limit'] as int? ?? 10,
        moderatorLimit: json['moderator_limit'] as int? ?? 5,
      );
}

class PricingFree {
  final int communityLimit;

  PricingFree({required this.communityLimit});

  factory PricingFree.fromJson(Map<String, dynamic> json) => PricingFree(
        communityLimit: json['community_limit'] as int? ?? 3,
      );
}

class PaymentCreated {
  final String paymentId;
  final String yookassaPaymentId;
  final String confirmationUrl;

  PaymentCreated({
    required this.paymentId,
    required this.yookassaPaymentId,
    required this.confirmationUrl,
  });

  factory PaymentCreated.fromJson(Map<String, dynamic> json) =>
      PaymentCreated(
        paymentId: json['payment_id']?.toString() ?? '',
        yookassaPaymentId: json['yookassa_payment_id']?.toString() ?? '',
        confirmationUrl: json['confirmation_url'] as String? ?? '',
      );
}

class PaymentStatus {
  final String id;
  final String status;
  final String period;
  final num amountRub;
  final String createdAt;
  final String? capturedAt;

  PaymentStatus({
    required this.id,
    required this.status,
    required this.period,
    required this.amountRub,
    required this.createdAt,
    this.capturedAt,
  });

  bool get isSucceeded => status == 'succeeded';
  bool get isCanceled => status == 'canceled';
  bool get isPending =>
      status == 'pending' || status == 'waiting_for_capture';

  factory PaymentStatus.fromJson(Map<String, dynamic> json) => PaymentStatus(
        id: json['id']?.toString() ?? '',
        status: json['status'] as String? ?? 'pending',
        period: json['period'] as String? ?? 'monthly',
        amountRub: json['amount_rub'] as num? ?? 0,
        createdAt: json['created_at'] as String? ?? '',
        capturedAt: json['captured_at'] as String?,
      );
}

class Invoice {
  final String id;
  final String yookassaPaymentId;
  final num amountRub;
  final String currency;
  final String status;
  final String period;
  final String paymentMethodType;
  final String description;
  final String createdAt;
  final String? capturedAt;

  Invoice({
    required this.id,
    required this.yookassaPaymentId,
    required this.amountRub,
    required this.currency,
    required this.status,
    required this.period,
    required this.paymentMethodType,
    required this.description,
    required this.createdAt,
    this.capturedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id']?.toString() ?? '',
        yookassaPaymentId: json['yookassa_payment_id']?.toString() ?? '',
        amountRub: json['amount_rub'] as num? ?? 0,
        currency: json['currency'] as String? ?? 'RUB',
        status: json['status'] as String? ?? 'pending',
        period: json['period'] as String? ?? 'monthly',
        paymentMethodType: json['payment_method_type'] as String? ?? '',
        description: json['description'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        capturedAt: json['captured_at'] as String?,
      );
}

// ─── API ──────────────────────────────────────────────────────────

class PaymentsApi {
  final ApiClient _client;
  PaymentsApi(this._client);

  Future<PricingInfo> getPricing() async {
    final data =
        await _client.get<Map<String, dynamic>>('/public/pricing');
    return PricingInfo.fromJson(data);
  }

  Future<PaymentCreated> createSubscription(String period) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/payments/subscription',
      data: {'period': period},
    );
    return PaymentCreated.fromJson(data);
  }

  Future<PaymentStatus> getStatus(String paymentId) async {
    final data = await _client
        .get<Map<String, dynamic>>('/payments/$paymentId/status');
    return PaymentStatus.fromJson(data);
  }

  Future<List<Invoice>> listInvoices() async {
    final data =
        await _client.get<Map<String, dynamic>>('/billing/invoices');
    final list = data['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ─── Providers ────────────────────────────────────────────────────

final paymentsApiProvider = Provider<PaymentsApi>((ref) {
  return PaymentsApi(ref.watch(apiClientProvider));
});

final pricingProvider = FutureProvider<PricingInfo>((ref) {
  return ref.watch(paymentsApiProvider).getPricing();
});
