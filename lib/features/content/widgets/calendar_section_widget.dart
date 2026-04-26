import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/calendar_api.dart';
import '../../../data/models/page.dart';
import '../../../providers/auth_provider.dart';

class CalendarSectionWidget extends ConsumerStatefulWidget {
  final Section section;
  const CalendarSectionWidget({super.key, required this.section});

  @override
  ConsumerState<CalendarSectionWidget> createState() => _CalendarSectionWidgetState();
}

class _CalendarSectionWidgetState extends ConsumerState<CalendarSectionWidget> {
  late final CalendarApi _api;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  int? _selectedDay;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _showForm = false;
  int? _editingId;
  String? _error;
  bool _saving = false;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  DateTime _formDate = DateTime.now();
  TimeOfDay? _formTime;
  DateTime? _formEndDate;
  TimeOfDay? _formEndTime;
  Color _formColor = const Color(0xFF5b7ff5);
  String _formRecurrence = 'none';
  DateTime? _formRecurrenceUntil;

  static const _colorOptions = [
    Color(0xFF5b7ff5), Color(0xFF27ae60), Color(0xFFf0ad4e), Color(0xFFe74c3c),
    Color(0xFF9b59b6), Color(0xFF3498db), Color(0xFF1abc9c), Color(0xFFe67e22),
  ];

  @override
  void initState() {
    super.initState();
    _api = CalendarApi(ref.read(apiClientProvider));
    _loadEvents();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Future<void> _loadEvents() async {
    if (_events.isEmpty) setState(() => _loading = true);
    try {
      final from = '$_year-${_pad(_month)}-01T00:00:00';
      final lastDay = DateTime(_year, _month + 1, 0).day;
      final to = '$_year-${_pad(_month)}-${_pad(lastDay)}T23:59:59';
      final data = await _api.getEvents(widget.section.id, from, to);
      _events = (data['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      _events = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; } else { _month--; }
      _selectedDay = null;
      _showForm = false;
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) { _month = 1; _year++; } else { _month++; }
      _selectedDay = null;
      _showForm = false;
    });
    _loadEvents();
  }

  bool _dayHasEvent(int day) {
    final dateStr = '$_year-${_pad(_month)}-${_pad(day)}';
    return _events.any((e) {
      final start = (e['start_time'] as String? ?? '').substring(0, 10);
      final end = e['end_time'] != null ? (e['end_time'] as String).substring(0, 10) : start;
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    });
  }

  List<Map<String, dynamic>> get _selectedDayEvents {
    if (_selectedDay == null) return [];
    final dateStr = '$_year-${_pad(_month)}-${_pad(_selectedDay!)}';
    return _events.where((e) {
      final start = (e['start_time'] as String? ?? '').substring(0, 10);
      final end = e['end_time'] != null ? (e['end_time'] as String).substring(0, 10) : start;
      return dateStr.compareTo(start) >= 0 && dateStr.compareTo(end) <= 0;
    }).toList();
  }

  String _formatEventTime(Map<String, dynamic> ev) {
    final startStr = ev['start_time'] as String? ?? '';
    if (startStr.length < 16) return '';
    final dt = DateTime.tryParse(startStr);
    if (dt == null || (dt.hour == 0 && dt.minute == 0)) return '';
    return '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  void _openCreateForm() {
    final selDate = _selectedDay != null ? DateTime(_year, _month, _selectedDay!) : DateTime.now();
    _editingId = null;
    _titleCtrl.clear();
    _descCtrl.clear();
    _locationCtrl.clear();
    _formDate = selDate;
    _formTime = null;
    _formEndDate = selDate;
    _formEndTime = null;
    _formColor = _colorOptions[0];
    _formRecurrence = 'none';
    _formRecurrenceUntil = null;
    _error = null;
    setState(() => _showForm = true);
  }

  void _openEditForm(Map<String, dynamic> ev) {
    _editingId = ev['id'] as int;
    _titleCtrl.text = ev['title'] as String? ?? '';
    _descCtrl.text = ev['description'] as String? ?? '';
    _locationCtrl.text = ev['location'] as String? ?? '';
    final startDt = DateTime.tryParse(ev['start_time'] as String? ?? '');
    _formDate = startDt ?? DateTime.now();
    _formTime = startDt != null && !(startDt.hour == 0 && startDt.minute == 0)
        ? TimeOfDay(hour: startDt.hour, minute: startDt.minute) : null;
    if (ev['end_time'] != null) {
      final endDt = DateTime.tryParse(ev['end_time'] as String);
      _formEndDate = endDt;
      _formEndTime = endDt != null && !(endDt.hour == 23 && endDt.minute == 59)
          ? TimeOfDay(hour: endDt.hour, minute: endDt.minute) : null;
    } else {
      _formEndDate = _formDate;
      _formEndTime = null;
    }
    final colorHex = ev['color'] as String? ?? '#5b7ff5';
    _formColor = _parseColor(colorHex);
    if (ev['is_recurring'] == true && ev['recurrence_rule'] != null) {
      try {
        final rule = jsonDecode(ev['recurrence_rule'] as String) as Map<String, dynamic>;
        _formRecurrence = rule['freq'] as String? ?? 'none';
        _formRecurrenceUntil = rule['until'] != null ? DateTime.tryParse(rule['until'] as String) : null;
      } catch (_) { _formRecurrence = 'none'; }
    } else {
      _formRecurrence = 'none';
    }
    _error = null;
    setState(() => _showForm = true);
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  Future<void> _saveEvent() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      final timeStr = _formTime != null ? '${_pad(_formTime!.hour)}:${_pad(_formTime!.minute)}' : '00:00';
      final startTime = '${_formDate.toIso8601String().split('T')[0]}T$timeStr:00';

      String? endTime;
      if (_formEndTime != null) {
        final endDate = _formEndDate ?? _formDate;
        endTime = '${endDate.toIso8601String().split('T')[0]}T${_pad(_formEndTime!.hour)}:${_pad(_formEndTime!.minute)}:00';
      } else if (_formEndDate != null && !_formEndDate!.isAtSameMomentAs(_formDate)) {
        endTime = '${_formEndDate!.toIso8601String().split('T')[0]}T23:59:00';
      }

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'start_time': startTime,
        if (endTime != null) 'end_time': endTime,
        if (_locationCtrl.text.trim().isNotEmpty) 'location': _locationCtrl.text.trim(),
        'color': _colorToHex(_formColor),
        'is_recurring': _formRecurrence != 'none',
        'recurrence_rule': _formRecurrence != 'none'
            ? jsonEncode(<String, dynamic>{'freq': _formRecurrence, if (_formRecurrenceUntil case final until?) 'until': until.toIso8601String().split('T')[0]})
            : '',
      };

      if (_editingId != null) {
        await _api.updateEvent(widget.section.id, _editingId!, payload);
      } else {
        await _api.createEvent(widget.section.id, payload);
      }
      _showForm = false;
      _editingId = null;
      await _loadEvents();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    try {
      await _api.deleteEvent(widget.section.id, eventId);
      await _loadEvents();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final auth = ref.watch(authProvider);
    final title = widget.section.config['title'] as String?;
    final now = DateTime.now();
    final isCurrentMonth = now.year == _year && now.month == _month;
    final monthLabel = DateFormat.yMMMM().format(DateTime(_year, _month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Text(title ?? 'Календарь', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        _buildNavRow(monthLabel, c),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
        else ...[
          _buildGrid(theme, c, isCurrentMonth ? now.day : -1),
          if (_selectedDay != null) _buildDaySection(theme, c, auth),
        ],
      ],
    );
  }

  Widget _buildNavRow(String monthLabel, ColorSet c) {
    return Row(
      children: [
        Text(monthLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
        const Spacer(),
        _navBtn(Icons.chevron_left, _prevMonth, c),
        const SizedBox(width: 4),
        _navBtn(Icons.chevron_right, _nextMonth, c),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap, ColorSet c) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: c.textSecondary),
      ),
    );
  }

  Widget _buildGrid(ThemeData theme, ColorSet c, int todayDay) {
    final firstDay = DateTime(_year, _month, 1);
    final lastDay = DateTime(_year, _month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final accent = theme.colorScheme.primary;
    final weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Column(
      children: [
        Row(
          children: weekDays.map((d) => Expanded(
            child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary))),
          )).toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate(((startOffset + lastDay.day + 6) ~/ 7), (week) {
          return Row(
            children: List.generate(7, (col) {
              final idx = week * 7 + col;
              final day = idx - startOffset + 1;
              if (day < 1 || day > lastDay.day) {
                return const Expanded(child: SizedBox(height: 36));
              }
              final isToday = day == todayDay;
              final isSelected = day == _selectedDay;
              final hasEvent = _dayHasEvent(day);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedDay = _selectedDay == day ? null : day;
                    _showForm = false;
                  }),
                  child: Container(
                    height: 36,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected ? Colors.white : (isToday ? c.text : c.textSecondary),
                          ),
                        ),
                        if (hasEvent)
                          Container(
                            width: 5, height: 5,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : accent),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildDaySection(ThemeData theme, ColorSet c, AuthState auth) {
    final dateStr = '$_year-${_pad(_month)}-${_pad(_selectedDay!)}';
    final dayEvents = _selectedDayEvents;
    final canEdit = auth.isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Divider(color: c.border),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(dateStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const Spacer(),
            if (canEdit && !_showForm)
              TextButton.icon(
                onPressed: _openCreateForm,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Добавить'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), textStyle: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: TextStyle(color: c.error, fontSize: 13)),
          ),
        if (_showForm) _buildEventForm(theme, c),
        if (dayEvents.isNotEmpty)
          ...dayEvents.map((ev) => _buildEventItem(ev, theme, c, canEdit))
        else if (!_showForm)
          Center(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Нет событий', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          )),
      ],
    );
  }

  Widget _buildEventItem(Map<String, dynamic> ev, ThemeData theme, ColorSet c, bool canEdit) {
    final color = _parseColor(ev['color'] as String? ?? '#5b7ff5');
    final time = _formatEventTime(ev);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          if (time.isNotEmpty) ...[
            Text(time, style: TextStyle(fontSize: 12, color: c.textSecondary, fontFamily: 'monospace')),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(ev['title'] as String? ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text))),
          if (canEdit) ...[
            IconButton(icon: const Icon(Icons.edit_outlined, size: 14), onPressed: () => _openEditForm(ev), constraints: const BoxConstraints(minWidth: 28, minHeight: 28), padding: EdgeInsets.zero, iconSize: 14),
            IconButton(icon: Icon(Icons.delete_outline, size: 14, color: c.error), onPressed: () => _deleteEvent(ev['id'] as int), constraints: const BoxConstraints(minWidth: 28, minHeight: 28), padding: EdgeInsets.zero, iconSize: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildEventForm(ThemeData theme, ColorSet c) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Название', isDense: true),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateField('Дата', _formDate, (d) => setState(() => _formDate = d))),
              const SizedBox(width: 10),
              Expanded(child: _timeField('Время', _formTime, (t) => setState(() => _formTime = t))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateField('Дата окончания', _formEndDate, (d) => setState(() => _formEndDate = d))),
              const SizedBox(width: 10),
              Expanded(child: _timeField('Время окончания', _formEndTime, (t) => setState(() => _formEndTime = t))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Описание', isDense: true),
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(labelText: 'Место', isDense: true),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text('Цвет', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _colorOptions.map((clr) => GestureDetector(
              onTap: () => setState(() => _formColor = clr),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: clr,
                  border: Border.all(color: _formColor == clr ? c.text : Colors.transparent, width: 2),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _formRecurrence,
            decoration: const InputDecoration(labelText: 'Повтор', isDense: true),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Нет')),
              DropdownMenuItem(value: 'daily', child: Text('Ежедневно')),
              DropdownMenuItem(value: 'weekly', child: Text('Еженедельно')),
              DropdownMenuItem(value: 'monthly', child: Text('Ежемесячно')),
            ],
            onChanged: (v) => setState(() => _formRecurrence = v ?? 'none'),
            style: TextStyle(fontSize: 14, color: c.text),
          ),
          if (_formRecurrence != 'none') ...[
            const SizedBox(height: 10),
            _dateField('Повторять до', _formRecurrenceUntil, (d) => setState(() => _formRecurrenceUntil = d)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _saving || _titleCtrl.text.trim().isEmpty ? null : _saveEvent,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_editingId != null ? 'Сохранить' : 'Создать'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() { _showForm = false; _editingId = null; _error = null; }),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(
          value != null ? DateFormat('yyyy-MM-dd').format(value) : '—',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, ValueChanged<TimeOfDay> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: value ?? const TimeOfDay(hour: 12, minute: 0));
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(
          value != null ? '${_pad(value.hour)}:${_pad(value.minute)}' : '—',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
