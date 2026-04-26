import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

class AdminPluginsTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminPluginsTab({super.key, required this.c, required this.ref});

  @override
  State<AdminPluginsTab> createState() => _AdminPluginsTabState();
}

class _AdminPluginsTabState extends State<AdminPluginsTab> {
  List<PluginInfo> _plugins = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _plugins = await AdminApi(widget.ref.read(apiClientProvider)).listPlugins();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Плагины', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(100),
                2: FixedColumnWidth(80),
                3: FixedColumnWidth(90),
                4: FixedColumnWidth(80),
                5: FixedColumnWidth(80),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: c.surfaceAlt),
                  children: [
                    _th('ПЛАГИН', c),
                    _th('ТИП', c),
                    _th('ВЕРСИЯ', c),
                    _th('СООБЩЕСТВ', c),
                    _th('СЕКЦИЙ', c),
                    _th('СТАТУС', c),
                  ],
                ),
                ..._plugins.map((p) => TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                              if (p.description != null && p.description!.isNotEmpty)
                                Text(p.description!, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ],
                          ),
                        ),
                        _tdMono(p.type, c),
                        _tdMono(p.version, c),
                        _tdMono('${p.communitiesUsing}', c, align: TextAlign.right),
                        _tdMono('${p.sectionsCount}', c, align: TextAlign.right),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                          child: p.loaded
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: c.success.withValues(alpha: 0.15),
                                    border: Border.all(color: c.success.withValues(alpha: 0.3)),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text('LOADED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.success, letterSpacing: 0.4)),
                                )
                              : Text('—', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                        ),
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String text, ColorSet c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5)),
      );

  Widget _tdMono(String text, ColorSet c, {TextAlign align = TextAlign.left}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Text(text, textAlign: align, style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'monospace')),
      );
}
