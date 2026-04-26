import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class _Requisites {
  final String name;
  final String status;
  final String inn;
  final String ogrn;
  final String address;
  final String contactEmail;
  final bool ready;

  _Requisites({
    this.name = '',
    this.status = '',
    this.inn = '',
    this.ogrn = '',
    this.address = '',
    this.contactEmail = '',
    this.ready = false,
  });

  factory _Requisites.fromJson(Map<String, dynamic> json) => _Requisites(
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        inn: json['inn'] as String? ?? '',
        ogrn: json['ogrn'] as String? ?? '',
        address: json['address'] as String? ?? '',
        contactEmail: json['contact_email'] as String? ?? '',
        ready: json['ready'] as bool? ?? false,
      );
}

class LegalRequisitesScreen extends ConsumerStatefulWidget {
  const LegalRequisitesScreen({super.key});

  @override
  ConsumerState<LegalRequisitesScreen> createState() => _LegalRequisitesScreenState();
}

class _LegalRequisitesScreenState extends ConsumerState<LegalRequisitesScreen> {
  _Requisites? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final json = await api.get<Map<String, dynamic>>('/public/legal-requisites');
      if (mounted) setState(() { _data = _Requisites.fromJson(json); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _data = null; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // h1 — 1.8rem = 28.8px
                Text('Реквизиты', style: TextStyle(
                  fontSize: 28.8, fontWeight: FontWeight.w700, color: c.text,
                )),
                const SizedBox(height: 24),

                if (_loading)
                  Text('Загрузка...', style: TextStyle(color: c.textSecondary))
                else if (_data == null || !_data!.ready)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border, style: BorderStyle.none),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Реквизиты не настроены', textAlign: TextAlign.center,
                        style: TextStyle(color: c.textSecondary)),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _row('Наименование', _data!.name, c),
                        if (_data!.status.isNotEmpty) _row('Статус', _data!.status, c),
                        _row('ИНН', _data!.inn, c),
                        if (_data!.ogrn.isNotEmpty) _row('ОГРН', _data!.ogrn, c),
                        if (_data!.address.isNotEmpty) _row('Адрес', _data!.address, c),
                        if (_data!.contactEmail.isNotEmpty)
                          _rowWidget('Email', GestureDetector(
                            onTap: () => launchUrl(Uri.parse('mailto:${_data!.contactEmail}')),
                            child: Text(_data!.contactEmail, style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500, color: c.accent,
                            )),
                          ), c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Данные предоставлены в соответствии с законодательством РФ.',
                      style: TextStyle(fontSize: 14.1, color: c.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, ColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: TextStyle(fontSize: 13.6, color: c.textSecondary)),
          ),
          const SizedBox(width: 24),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text))),
        ],
      ),
    );
  }

  Widget _rowWidget(String label, Widget value, ColorSet c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: TextStyle(fontSize: 13.6, color: c.textSecondary)),
          ),
          const SizedBox(width: 24),
          Expanded(child: value),
        ],
      ),
    );
  }
}
