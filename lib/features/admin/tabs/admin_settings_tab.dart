import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/admin_api.dart';

class AdminSettingsTab extends StatefulWidget {
  final ColorSet c;
  final WidgetRef ref;
  const AdminSettingsTab({super.key, required this.c, required this.ref});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  Map<String, SettingEntry> _settings = {};
  final Map<String, dynamic> _edited = {};
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  AdminApi get _api => AdminApi(widget.ref.read(apiClientProvider));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _settings = await _api.getSettings();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onEdit(String key, dynamic value) {
    final entry = _settings[key];
    if (entry == null) return;
    if (value == entry.defaultValue && entry.isDefault) {
      _edited.remove(key);
    } else if (value == entry.value && !_edited.containsKey(key)) {
      return;
    } else {
      _edited[key] = value;
    }
    setState(() {});
  }

  dynamic _currentValue(String key) {
    if (_edited.containsKey(key)) return _edited[key];
    return _settings[key]?.value;
  }

  Future<void> _save() async {
    if (_edited.isEmpty) return;
    setState(() { _saving = true; _saved = false; });
    try {
      await _api.updateSettings(_edited);
      _edited.clear();
      await _load();
      _saved = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  void _discard() {
    setState(() => _edited.clear());
  }

  Map<String, List<SettingEntry>> get _groups {
    final byGroup = <String, List<SettingEntry>>{};
    for (final entry in _settings.values) {
      final g = entry.group.isNotEmpty ? entry.group : 'other';
      byGroup.putIfAbsent(g, () => []).add(entry);
    }
    return byGroup;
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

    final groups = _groups;
    final hasChanges = _edited.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Настройки платформы', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 4),
          Text('Глобальные параметры. Применяются сразу после сохранения.', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 24),
          ...groups.entries.map((e) => _buildGroup(e.key, e.value, c)),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: hasChanges && !_saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Сохранить'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: hasChanges ? _discard : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text('Отменить', style: TextStyle(color: c.text)),
              ),
              if (_saved) ...[
                const SizedBox(width: 12),
                Text('Сохранено', style: TextStyle(color: c.success, fontSize: 14)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String groupName, List<SettingEntry> entries, ColorSet c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
            child: Text(
              _groupLabels[groupName] ?? groupName.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: entries.asMap().entries.map((e) {
                final isLast = e.key == entries.length - 1;
                return _buildRow(e.value, c, isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static const _keys = {
    'platform_name': ('Название платформы', 'Отображается в шапке и футере'),
    'registration_open': ('Открытая регистрация', 'Если выключено — новые аккаунты создать нельзя'),
    'default_community_limit_free': ('Лимит сообществ для Free', 'По умолчанию для новых пользователей'),
    'default_community_limit_pro': ('Лимит сообществ для Pro', 'Действует как потолок сразу для всех Pro-пользователей'),
    'moderator_limit_pro': ('Лимит модераторов на сообщество (Pro)', 'Сколько модераторов помимо владельца может пригласить Pro-сообщество'),
    'upload_max_size_mb_free': ('Макс. размер файла для Free (МБ)', 'Потолок загрузки одного файла для пользователей без подписки'),
    'upload_max_size_mb_pro': ('Макс. размер файла для Pro (МБ)', 'Потолок загрузки одного файла для Pro-пользователей'),
    'community_soft_delete_grace_days': ('Дней для восстановления удалённого сообщества', 'После этого периода сообщество удаляется навсегда'),
    'trial_days': ('Длительность триала Pro (дни)', 'Применится когда запустим самообслуживаемую оплату через ЮKassa'),
    'pro_price_monthly': ('Цена Pro за месяц (₽)', 'Отображается на публичной странице тарифов и в модалке апгрейда'),
    'pro_price_yearly': ('Цена Pro за год (₽)', 'Годовой тариф. Обычно даётся со скидкой против 12× месячной цены'),
    'legal_name': ('Наименование / ФИО', 'Для самозанятого — ФИО как в паспорте. Для юрлица — полное название.'),
    'legal_status': ('Правовой статус', 'Например: «Самозанятый», «ИП», «ООО»'),
    'legal_inn': ('ИНН', '12 цифр для физлица / самозанятого, 10 для юрлица'),
    'legal_contact_email': ('Email для обращений', 'Публичный email для запросов и связи ЮKassa/налоговой'),
    'legal_ogrn': ('ОГРН / ОГРНИП', 'Только для ИП и юрлиц. Для самозанятого оставить пустым.'),
    'legal_address': ('Юридический адрес', 'Только для юрлиц. Для самозанятого/ИП оставить пустым.'),
  };

  static const _groupLabels = {
    'branding': 'БРЕНДИНГ',
    'access': 'ДОСТУП',
    'limits': 'ЛИМИТЫ',
    'lifecycle': 'ЖИЗНЕННЫЙ ЦИКЛ',
    'billing': 'БИЛЛИНГ',
    'legal': 'РЕКВИЗИТЫ',
    'other': 'ПРОЧЕЕ',
  };

  Widget _buildRow(SettingEntry entry, ColorSet c, bool isLast) {
    final isEdited = _edited.containsKey(entry.key);
    final current = _currentValue(entry.key);
    final meta = _keys[entry.key];
    final label = meta?.$1 ?? entry.key.replaceAll('_', ' ');
    final desc = meta?.$2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
                    ),
                    if (isEdited)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('●', style: TextStyle(fontSize: 10, color: c.warning)),
                      ),
                  ],
                ),
                if (desc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(desc, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 200,
            child: _buildInput(entry, current, c),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(SettingEntry entry, dynamic current, ColorSet c) {
    if (entry.type == 'bool') {
      return Align(
        alignment: Alignment.centerRight,
        child: Switch(
          value: current == true || current == 'true',
          onChanged: (v) => _onEdit(entry.key, v),
          activeTrackColor: c.accent,
        ),
      );
    }

    return TextField(
      controller: TextEditingController(text: '$current'),
      keyboardType: entry.type == 'int' ? TextInputType.number : TextInputType.text,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 14, color: c.text),
      onChanged: (v) {
        if (entry.type == 'int') {
          _onEdit(entry.key, int.tryParse(v) ?? 0);
        } else {
          _onEdit(entry.key, v);
        }
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.inputBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.inputBorder)),
        filled: true,
        fillColor: c.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
