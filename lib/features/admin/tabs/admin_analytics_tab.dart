import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

class AdminAnalyticsTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminAnalyticsTab({super.key, required this.c, required this.ref});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  AnalyticsOverview? _data;
  bool _loading = true;
  String? _error;
  String _range = '30d';

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  static const _ranges = [
    ('24h', '24ч'),
    ('7d', '7д'),
    ('30d', '30д'),
    ('90d', '90д'),
    ('365d', '365д'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _data = await _api.getAnalyticsOverview(range: _range);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmtInt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
  String _fmtRub(double n) => '${_fmtInt(n.round())} ₽';
  String _fmtPct(double? n) => n != null ? '${n.toStringAsFixed(1)}%' : '—';

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    if (_loading) return Center(child: CircularProgressIndicator(color: c.accent));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: c.error)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_data == null) return Center(child: Text('Нет данных', style: TextStyle(color: c.textSecondary)));

    final d = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + range selector
          Row(
            children: [
              Text('Аналитика', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          _buildRangeBar(c),
          const SizedBox(height: 16),

          // KPI cards
          _buildKpiRow(d.kpis, c),
          const SizedBox(height: 16),

          // Two-column layout
          LayoutBuilder(builder: (ctx, constraints) {
            if (constraints.maxWidth >= 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 13, child: Column(
                    children: [
                      _buildRevenueSection(d.revenue, c),
                      const SizedBox(height: 16),
                      _buildFunnelSection(d.funnel, c),
                    ],
                  )),
                  const SizedBox(width: 16),
                  Expanded(flex: 10, child: _buildChurnSection(d.churn, c)),
                ],
              );
            }
            return Column(
              children: [
                _buildRevenueSection(d.revenue, c),
                const SizedBox(height: 16),
                _buildFunnelSection(d.funnel, c),
                const SizedBox(height: 16),
                _buildChurnSection(d.churn, c),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Top communities
          _buildTopCommunities(d.topCommunities, c),
          const SizedBox(height: 16),

          // Plugin usage
          _buildPluginUsage(d.pluginUsage, c),
        ],
      ),
    );
  }

  Widget _buildRangeBar(ColorSet c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: _ranges.map((r) {
          final active = _range == r.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _loading ? null : () {
                _range = r.$1;
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  r.$2,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : c.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiRow(AnalyticsKpis kpis, ColorSet c) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = constraints.maxWidth > 800 ? 5 : (constraints.maxWidth > 500 ? 3 : 2);
      final gap = 12.0;
      final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          _kpiCard('MAU', _fmtInt(kpis.mau), false, c, w),
          _kpiCard('DAU', _fmtInt(kpis.dau), false, c, w),
          _kpiCard('Платящие', kpis.paying != null ? _fmtInt(kpis.paying!) : '—', kpis.paying == null, c, w),
          _kpiCard('MRR', kpis.mrr != null ? _fmtRub(kpis.mrr!) : '—', kpis.mrr == null, c, w),
          _kpiCard('ARR', kpis.arr != null ? _fmtRub(kpis.arr!) : '—', kpis.arr == null, c, w),
        ],
      );
    });
  }

  Widget _kpiCard(String label, String value, bool pending, ColorSet c, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: pending ? FontWeight.w500 : FontWeight.w700,
              color: pending ? c.textSecondary : c.text,
            ),
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Данные ожидаются', style: TextStyle(fontSize: 11, color: c.warning)),
            ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, ColorSet c, {String? subtitle, Widget? child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
          if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          if (child != null) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }

  Widget _buildRevenueSection(RevenueSeries rev, ColorSet c) {
    final maxAmount = rev.points.fold(0.0, (m, p) => p.amount > m ? p.amount : m);
    return _sectionCard('Выручка', c, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_fmtRub(rev.total30d), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(width: 12),
            Text('${rev.succeededCount30d} оплат', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          ],
        ),
        if (rev.points.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: rev.points.map((p) {
                final h = maxAmount > 0 ? (p.amount / maxAmount * 76).clamp(4.0, 76.0) : 4.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    ));
  }

  Widget _buildFunnelSection(AcquisitionFunnel funnel, ColorSet c) {
    return _sectionCard('Воронка', c,
      subtitle: 'Когорта: ${_fmtInt(funnel.cohortSize)}',
      child: Column(
        children: funnel.steps.map((step) {
          final pct = step.pct ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_funnelLabel(step.key), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text))),
                    Text(step.count != null ? _fmtInt(step.count!) : '—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text, fontFamily: 'monospace')),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: Text(_fmtPct(step.pct), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'monospace')),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(3)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (pct / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _funnelLabel(String key) => switch (key) {
    'registered' => 'Регистрации',
    'created_community' => 'Создали сообщество',
    'trial_start' => 'Начали триал',
    'paid' => 'Оплатили',
    'retained' => 'Остались',
    _ => key,
  };

  Widget _buildChurnSection(ChurnMetrics churn, ColorSet c) {
    return _sectionCard('Отток', c, child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _churnCard('Месячный отток', _fmtPct(churn.monthlyChurn), c)),
            const SizedBox(width: 12),
            Expanded(child: _churnCard('Ушли (30д)', _fmtInt(churn.lapsed30d), c)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _churnCard('Платящих', _fmtInt(churn.activePaying), c)),
            const SizedBox(width: 12),
            Expanded(child: _churnCard('NRR', _fmtPct(churn.nrr), c)),
          ],
        ),
        const SizedBox(height: 12),
        _churnCard('Триал→Платный', _fmtPct(churn.trialToPaid), c),
      ],
    ));
  }

  Widget _churnCard(String label, String value, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
        ],
      ),
    );
  }

  Widget _buildTopCommunities(List<TopCommunityRow> communities, ColorSet c) {
    if (communities.isEmpty) return const SizedBox.shrink();
    return _sectionCard('Топ сообществ', c, child: Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('#', style: _headerStyle(c))),
              Expanded(child: Text('НАЗВАНИЕ', style: _headerStyle(c))),
              SizedBox(width: 80, child: Text('DAU', textAlign: TextAlign.right, style: _headerStyle(c))),
              SizedBox(width: 80, child: Text('ПРОСМ.', textAlign: TextAlign.right, style: _headerStyle(c))),
              SizedBox(width: 80, child: Text('TIER', textAlign: TextAlign.center, style: _headerStyle(c))),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),
        ...communities.map((comm) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
          child: Row(
            children: [
              SizedBox(width: 24, child: Text('${comm.rank}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'monospace'))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comm.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                    Text(comm.ownerUsername, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              SizedBox(width: 80, child: Text(_fmtInt(comm.activeUsers), textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: c.text, fontFamily: 'monospace'))),
              SizedBox(width: 80, child: Text(_fmtInt(comm.totalViews), textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: c.text, fontFamily: 'monospace'))),
              SizedBox(width: 80, child: Center(child: _tierTag(comm.tier, c))),
            ],
          ),
        )),
      ],
    ));
  }

  Widget _tierTag(String tier, ColorSet c) {
    final (Color bg, Color fg, Color? border) = switch (tier) {
      'pro' => (c.accent, Colors.white, null),
      'trial' => (c.warning.withValues(alpha: 0.18), c.warning, c.warning.withValues(alpha: 0.3)),
      _ => (c.surfaceAlt, c.textSecondary, c.border),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: border != null ? Border.all(color: border) : null,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(tier.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.4)),
    );
  }

  Widget _buildPluginUsage(PluginUsage usage, ColorSet c) {
    if (usage.plugins.isEmpty) return const SizedBox.shrink();
    final maxUsage = usage.plugins.fold(0, (m, p) => p.usageCount > m ? p.usageCount : m);
    return _sectionCard('Использование плагинов', c, child: Column(
      children: usage.plugins.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(p.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text))),
            Expanded(
              child: Container(
                height: 14,
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: maxUsage > 0 ? (p.usageCount / maxUsage).clamp(0.0, 1.0) : 0,
                  child: Container(
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 60,
              child: Text('${p.usageCount}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'monospace')),
            ),
          ],
        ),
      )).toList(),
    ));
  }

  TextStyle _headerStyle(ColorSet c) => TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5);
}
