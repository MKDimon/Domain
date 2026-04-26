import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/booking_api.dart';
import '../../../data/models/page.dart';
import '../../../providers/auth_provider.dart';

class BookingSectionWidget extends ConsumerStatefulWidget {
  final Section section;
  final bool canEdit;
  const BookingSectionWidget({super.key, required this.section, this.canEdit = false});

  @override
  ConsumerState<BookingSectionWidget> createState() => _BookingSectionWidgetState();
}

class _BookingSectionWidgetState extends ConsumerState<BookingSectionWidget> {
  late final BookingApi _api;
  bool _loading = true;
  String? _error;
  String? _success;

  // Tabs
  String _activeTab = 'booking';

  // Shared data
  List<Map<String, dynamic>> _specialists = [];
  List<Map<String, dynamic>> _services = [];
  int? _selectedSpecialist;
  int? _selectedService;

  // Week grid state
  int _weekOffset = 0;
  Map<String, List<Map<String, dynamic>>> _weekSlots = {};
  bool _weekSlotsLoading = false;
  String? _selectedWeekSlotDate;
  String? _selectedWeekSlotTime;

  // Confirm booking state
  Map<String, dynamic>? _confirmSlot;
  bool _bookingInProgress = false;
  final _notesCtrl = TextEditingController();
  Map<String, String> _customData = {};

  // My bookings
  List<Map<String, dynamic>> _allAppointments = [];
  bool _showAllPast = false;

  // Staff appointments tab
  List<Map<String, dynamic>> _appointments = [];
  bool _appointmentsLoading = false;
  int _staffYear = DateTime.now().year;
  int _staffMonth = DateTime.now().month;
  int? _staffSelectedDay = DateTime.now().day;
  String _apptStatusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _api = BookingApi(ref.read(apiClientProvider));
    _loadInitial();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  }

  List<_WeekDate> get _weekDates {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: (now.weekday - 1) % 7)).add(Duration(days: _weekOffset * 7));
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return _WeekDate(
        date: '${d.year}-${_pad(d.month)}-${_pad(d.day)}',
        dayName: dayNames[i],
        dayNum: d.day,
        monthStr: months[d.month - 1],
      );
    });
  }

  List<String> get _weekTimeRows {
    final times = <String>{};
    for (final daySlots in _weekSlots.values) {
      for (final s in daySlots) {
        times.add(s['time'] as String? ?? '');
      }
    }
    final sorted = times.toList()..sort();
    return sorted;
  }

  List<Map<String, dynamic>> get _filteredSpecialists {
    if (_selectedService == null) return _specialists;
    final svc = _services.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s!['id'] == _selectedService, orElse: () => null,
    );
    if (svc == null) return _specialists;
    final specIds = (svc['specialist_ids'] as List<dynamic>?)?.cast<int>() ?? [];
    if (specIds.isEmpty) return [];
    return _specialists.where((sp) => specIds.contains(sp['id'])).toList();
  }

  List<Map<String, dynamic>> get _bookableServices {
    if (widget.canEdit) return _services;
    return _services.where((s) {
      final ids = s['specialist_ids'] as List<dynamic>?;
      return ids != null && ids.isNotEmpty;
    }).toList();
  }

  List<Map<String, dynamic>> get _customFields =>
      (widget.section.config['custom_fields'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _loadInitial() async {
    try {
      final results = await Future.wait([
        _api.getSpecialists(widget.section.id),
        _api.getServices(widget.section.id),
        _api.getAppointments(widget.section.id),
      ]);
      _specialists = (results[0]['specialists'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      _services = (results[1]['services'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      _allAppointments = (results[2]['appointments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
    _loadWeekSlots();
  }

  Future<void> _loadWeekSlots() async {
    setState(() => _weekSlotsLoading = true);
    final results = <String, List<Map<String, dynamic>>>{};
    try {
      await Future.wait(_weekDates.map((wd) async {
        try {
          final data = await _api.getSlots(
            widget.section.id, wd.date,
            specialistId: _selectedSpecialist,
            serviceId: _selectedService,
          );
          results[wd.date] = (data['slots'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        } catch (_) {
          results[wd.date] = [];
        }
      }));
      _weekSlots = results;
    } finally {
      if (mounted) setState(() => _weekSlotsLoading = false);
    }
  }

  String _weekSlotStatus(String date, String time) {
    if (date.compareTo(_todayStr()) < 0) return 'past';
    if (_selectedWeekSlotDate == date && _selectedWeekSlotTime == time) return 'selected';
    final daySlots = _weekSlots[date];
    if (daySlots == null) return 'empty';
    final slot = daySlots.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s!['time'] == time, orElse: () => null,
    );
    if (slot == null) return 'empty';
    if (slot['status'] == 'available') return 'available';
    return 'booked';
  }

  void _selectWeekSlot(String date, String time) {
    final auth = ref.read(authProvider);
    final status = _weekSlotStatus(date, time);
    if (status == 'booked' || status == 'empty' || status == 'past') return;
    if (!auth.isAuthenticated) return;
    if (_bookableServices.isNotEmpty && _selectedService == null) {
      setState(() => _error = 'Выберите услугу');
      return;
    }
    if (_filteredSpecialists.isNotEmpty && _selectedSpecialist == null) {
      setState(() => _error = 'Выберите специалиста');
      return;
    }
    if (_selectedWeekSlotDate == date && _selectedWeekSlotTime == time) {
      setState(() {
        _selectedWeekSlotDate = null;
        _selectedWeekSlotTime = null;
        _confirmSlot = null;
      });
      return;
    }
    final daySlots = _weekSlots[date] ?? [];
    final slotObj = daySlots.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s!['time'] == time, orElse: () => {'time': time, 'status': 'available'},
    ) ?? {'time': time, 'status': 'available'};
    setState(() {
      _selectedWeekSlotDate = date;
      _selectedWeekSlotTime = time;
      _confirmSlot = {...slotObj, 'date': date};
      _customData = {};
      _notesCtrl.clear();
      _error = null;
    });
  }

  Future<void> _confirmBooking() async {
    final slot = _confirmSlot;
    if (slot == null) return;

    for (final field in _customFields) {
      if (field['required'] == true) {
        final key = field['label_en'] as String? ?? field['label_ru'] as String? ?? '';
        if (_customData[key]?.trim().isEmpty ?? true) {
          setState(() => _error = '${field['label_ru'] ?? key} — обязательное поле');
          return;
        }
      }
    }

    setState(() { _bookingInProgress = true; _error = null; _success = null; _confirmSlot = null; });
    try {
      final time = slot['time'] as String;
      final timeStr = time.length <= 5 ? '$time:00' : time;
      final date = slot['date'] as String? ?? _selectedWeekSlotDate ?? _todayStr();
      await _api.createAppointment(widget.section.id, {
        'start_time': '${date}T$timeStr',
        if (_selectedSpecialist != null) 'specialist_id': _selectedSpecialist,
        if (_selectedService != null) 'service_id': _selectedService,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        if (_customData.isNotEmpty) 'custom_data': _customData,
      });
      _success = 'Бронирование создано';
      _notesCtrl.clear();
      _customData = {};
      _selectedWeekSlotDate = null;
      _selectedWeekSlotTime = null;
      await Future.wait([_loadWeekSlots(), _loadAllAppointments()]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _bookingInProgress = false);
    }
  }

  Future<void> _loadAllAppointments() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;
    try {
      final data = await _api.getAppointments(widget.section.id);
      _allAppointments = (data['appointments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadStaffAppointments() async {
    setState(() => _appointmentsLoading = true);
    try {
      final dateStr = _staffSelectedDay != null
          ? '$_staffYear-${_pad(_staffMonth)}-${_pad(_staffSelectedDay!)}'
          : null;
      final data = await _api.getAppointments(widget.section.id, date: dateStr);
      _appointments = (data['appointments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      _appointments = [];
    }
    if (mounted) setState(() => _appointmentsLoading = false);
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appt) async {
    try {
      await _api.updateAppointment(widget.section.id, appt['id'] as int, {'status': 'cancelled'});
      await Future.wait([_loadAllAppointments(), _loadWeekSlots()]);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmAppointment(Map<String, dynamic> appt) async {
    try {
      await _api.updateAppointment(widget.section.id, appt['id'] as int, {'status': 'confirmed'});
      await _loadStaffAppointments();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _formatDateTime(String isoStr) {
    if (isoStr.isEmpty) return '';
    final d = DateTime.tryParse(isoStr);
    if (d == null) return isoStr;
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${d.day} ${months[d.month - 1]}, ${_pad(d.hour)}:${_pad(d.minute)}';
  }

  String _formatTime(String isoStr) {
    if (isoStr.isEmpty) return '';
    final d = DateTime.tryParse(isoStr);
    if (d == null) return isoStr;
    return '${_pad(d.hour)}:${_pad(d.minute)}';
  }

  String _statusLabel(String status) => switch (status) {
    'confirmed' => 'Подтверждено',
    'cancelled' => 'Отменено',
    _ => 'Ожидание',
  };

  Color _statusColor(String status, ColorSet c) => switch (status) {
    'confirmed' => c.success,
    'cancelled' => c.error,
    _ => c.warning,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final auth = ref.watch(authProvider);
    final title = widget.section.config['title'] as String?;
    final accent = theme.colorScheme.primary;

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            Text(title ?? 'Бронирование', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
          ],
        ),
        const SizedBox(height: 16),

        // Tabs
        _buildTabs(c, accent, auth),
        const SizedBox(height: 12),

        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: TextStyle(color: c.error, fontSize: 13))),
        if (_success != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_success!, style: TextStyle(color: c.success, fontSize: 13))),

        if (_activeTab == 'booking') _buildBookingTab(theme, c, auth, accent),
        if (_activeTab == 'my-bookings') _buildMyBookingsTab(theme, c, auth, accent),
        if (_activeTab == 'appointments' && widget.canEdit) _buildStaffTab(theme, c, accent),
        if (_activeTab == 'settings' && widget.canEdit) _buildSettingsTab(theme, c, accent),
      ],
    );
  }

  Widget _buildTabs(ColorSet c, Color accent, AuthState auth) {
    Widget tab(String id, String label, {bool show = true}) {
      if (!show) return const SizedBox.shrink();
      final isActive = _activeTab == id;
      return GestureDetector(
        onTap: () {
          setState(() { _activeTab = id; _error = null; _success = null; });
          if (id == 'my-bookings') _loadAllAppointments();
          if (id == 'appointments') { _loadAllAppointments(); _loadStaffAppointments(); }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? accent : Colors.transparent, width: 2)),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? accent : c.textSecondary,
          )),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        tab('booking', 'Календарь'),
        tab('my-bookings', 'Мои бронирования', show: auth.isAuthenticated),
        tab('appointments', 'Все бронирования', show: widget.canEdit),
        tab('settings', 'Настройки', show: widget.canEdit),
      ]),
    );
  }

  // ===================== BOOKING TAB =====================
  Widget _buildBookingTab(ThemeData theme, ColorSet c, AuthState auth, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Service/specialist filters
        if (_bookableServices.isNotEmpty || _filteredSpecialists.isNotEmpty)
          _buildFilters(c, accent),

        // Week navigation
        _buildWeekNav(c),
        const SizedBox(height: 8),

        // Week grid
        if (_weekSlotsLoading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_weekTimeRows.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Нет доступных слотов', style: TextStyle(fontSize: 13, color: c.textSecondary))))
        else ...[
          _buildWeekGrid(c, accent),
          const SizedBox(height: 8),
          _buildLegend(c, accent),
        ],

        if (!auth.isAuthenticated)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Войдите, чтобы записаться', style: TextStyle(fontSize: 13, color: c.textSecondary))),

        // Confirm slot dialog
        if (_confirmSlot != null) ...[
          const SizedBox(height: 12),
          _buildConfirmCard(c, accent),
        ],
      ],
    );
  }

  Widget _buildFilters(ColorSet c, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          if (_bookableServices.isNotEmpty)
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedService,
                decoration: InputDecoration(labelText: 'Услуга', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Выберите услугу...')),
                  ..._bookableServices.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String? ?? ''))),
                ],
                onChanged: (v) { setState(() => _selectedService = v); _loadWeekSlots(); },
                style: TextStyle(fontSize: 13, color: c.text),
              ),
            ),
          if (_filteredSpecialists.isNotEmpty)
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedSpecialist,
                decoration: InputDecoration(labelText: 'Специалист', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Специалист...')),
                  ..._filteredSpecialists.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String? ?? ''))),
                ],
                onChanged: (v) { setState(() => _selectedSpecialist = v); _loadWeekSlots(); },
                style: TextStyle(fontSize: 13, color: c.text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekNav(ColorSet c) {
    final dates = _weekDates;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () { setState(() { _weekOffset--; _selectedWeekSlotDate = null; _selectedWeekSlotTime = null; _confirmSlot = null; }); _loadWeekSlots(); },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.chevron_left, size: 16, color: c.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('${dates.first.dayNum} ${dates.first.monthStr} — ${dates.last.dayNum} ${dates.last.monthStr}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
        ),
        InkWell(
          onTap: () { setState(() { _weekOffset++; _selectedWeekSlotDate = null; _selectedWeekSlotTime = null; _confirmSlot = null; }); _loadWeekSlots(); },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.chevron_right, size: 16, color: c.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekGrid(ColorSet c, Color accent) {
    final dates = _weekDates;
    final times = _weekTimeRows;
    final today = _todayStr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 50),
            ...dates.map((wd) {
              final isPast = wd.date.compareTo(today) < 0;
              return Expanded(
                child: Center(child: Text('${wd.dayName} ${wd.dayNum}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPast ? c.textSecondary.withValues(alpha: 0.5) : c.textSecondary))),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
        ...times.map((time) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              SizedBox(width: 50, child: Text(time, style: TextStyle(fontSize: 11, color: c.textSecondary, fontFamily: 'monospace'))),
              ...dates.map((wd) {
                final status = _weekSlotStatus(wd.date, time);
                Color bgColor;
                Color textColor;
                String label;
                switch (status) {
                  case 'available':
                    bgColor = accent.withValues(alpha: 0.08);
                    textColor = accent;
                    label = '✓';
                  case 'selected':
                    bgColor = accent;
                    textColor = Colors.white;
                    label = '✓';
                  case 'booked':
                    bgColor = c.error.withValues(alpha: 0.08);
                    textColor = c.textSecondary.withValues(alpha: 0.5);
                    label = '--';
                  case 'past':
                    bgColor = c.surfaceAlt.withValues(alpha: 0.5);
                    textColor = c.textSecondary.withValues(alpha: 0.3);
                    label = '';
                  default:
                    bgColor = Colors.transparent;
                    textColor = Colors.transparent;
                    label = '';
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectWeekSlot(wd.date, time),
                    child: Container(
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                        border: status == 'selected' ? null : Border.all(color: c.border.withValues(alpha: 0.3)),
                      ),
                      child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor))),
                    ),
                  ),
                );
              }),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildLegend(ColorSet c, Color accent) {
    Widget dot(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
      ],
    );
    return Wrap(
      spacing: 16,
      children: [
        dot(accent.withValues(alpha: 0.15), 'Свободно'),
        dot(c.error.withValues(alpha: 0.15), 'Занято'),
        dot(accent, 'Выбрано'),
      ],
    );
  }

  Widget _buildConfirmCard(ColorSet c, Color accent) {
    final slot = _confirmSlot!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: accent.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Подтверждение записи', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 8),
          Text('${slot['date']}  ${slot['time']}', style: TextStyle(fontSize: 13, color: c.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              hintText: 'Комментарий (необязательно)',
              isDense: true,
              filled: true, fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: c.text),
          ),
          // Custom fields
          ..._customFields.map((field) {
            final key = field['label_en'] as String? ?? field['label_ru'] as String? ?? '';
            final label = field['label_ru'] as String? ?? key;
            final isRequired = field['required'] == true;
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: '$label${isRequired ? ' *' : ''}',
                  isDense: true,
                  filled: true, fillColor: c.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (v) => _customData[key] = v,
                style: TextStyle(fontSize: 13, color: c.text),
              ),
            );
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: _bookingInProgress ? null : _confirmBooking,
                child: _bookingInProgress
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Записаться'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() { _confirmSlot = null; _selectedWeekSlotDate = null; _selectedWeekSlotTime = null; }),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== MY BOOKINGS TAB =====================
  Widget _buildMyBookingsTab(ThemeData theme, ColorSet c, AuthState auth, Color accent) {
    if (!auth.isAuthenticated) {
      return Center(child: Text('Войдите, чтобы записаться', style: TextStyle(fontSize: 13, color: c.textSecondary)));
    }

    final today = _todayStr();
    final upcoming = _allAppointments.where((a) =>
      a['status'] != 'cancelled' && ((a['start_time'] as String? ?? '').substring(0, 10).compareTo(today) >= 0)
    ).toList();
    final past = _allAppointments.where((a) =>
      (a['start_time'] as String? ?? '').substring(0, 10).compareTo(today) < 0
    ).toList();

    if (_allAppointments.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Нет бронирований', style: TextStyle(fontSize: 13, color: c.textSecondary))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upcoming.isNotEmpty) ...[
          Text('Предстоящие', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 8),
          ...upcoming.map((appt) => _buildMyBookingCard(appt, c, accent, canCancel: true)),
        ],
        if (past.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Прошедшие', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 8),
          ...(_showAllPast ? past : past.take(3)).map((appt) => _buildMyBookingCardCompact(appt, c)),
          if (past.length > 3)
            TextButton(
              onPressed: () => setState(() => _showAllPast = !_showAllPast),
              child: Text(_showAllPast ? 'Свернуть' : 'Показать все (${past.length})', style: const TextStyle(fontSize: 12)),
            ),
        ],
      ],
    );
  }

  Widget _buildMyBookingCard(Map<String, dynamic> appt, ColorSet c, Color accent, {bool canCancel = false}) {
    final status = appt['status'] as String? ?? 'pending';
    final sColor = _statusColor(status, c);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDateTime(appt['start_time'] as String? ?? ''), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
              if (appt['service_name'] != null)
                Text(appt['service_name'] as String, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: sColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sColor)),
          ),
          if (canCancel && status != 'cancelled') ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _cancelAppointment(appt),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.error, side: BorderSide(color: c.error),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Отменить'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyBookingCardCompact(Map<String, dynamic> appt, ColorSet c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(child: Text(_formatDateTime(appt['start_time'] as String? ?? ''), style: TextStyle(fontSize: 12, color: c.textSecondary))),
          if (appt['service_name'] != null) ...[
            const SizedBox(width: 8),
            Text(appt['service_name'] as String, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(4)),
            child: Text('Завершено', style: TextStyle(fontSize: 10, color: c.textSecondary)),
          ),
        ],
      ),
    );
  }

  // ===================== STAFF APPOINTMENTS TAB =====================
  Widget _buildStaffTab(ThemeData theme, ColorSet c, Color accent) {
    // Stats bar
    final pending = _appointments.where((a) => a['status'] == 'pending').length;
    final confirmed = _appointments.where((a) => a['status'] == 'confirmed').length;
    final cancelled = _appointments.where((a) => a['status'] == 'cancelled').length;

    final filtered = _apptStatusFilter == 'all' ? _appointments
        : _apptStatusFilter == 'cancelled' ? _appointments.where((a) => a['status'] == 'cancelled').toList()
        : _appointments.where((a) => a['status'] != 'cancelled').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats
        Row(
          children: [
            _statBox('Всего', '${_appointments.length}', accent, c),
            _statBox('Ожидание', '$pending', c.warning, c),
            _statBox('Подтв.', '$confirmed', c.success, c),
            _statBox('Отмена', '$cancelled', c.error, c),
          ],
        ),
        const SizedBox(height: 12),

        // Mini calendar + day detail
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 240, child: _buildMiniCalendar(theme, c, accent)),
            const SizedBox(width: 12),
            Expanded(child: _buildDayDetail(c, accent, filtered)),
          ],
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color, ColorSet c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    ));
  }

  bool _dayHasAppointment(int day) {
    final prefix = '$_staffYear-${_pad(_staffMonth)}-${_pad(day)}';
    return _allAppointments.any((a) {
      final st = a['start_time'] as String? ?? '';
      return st.startsWith(prefix) && a['status'] != 'cancelled';
    });
  }

  Widget _buildMiniCalendar(ThemeData theme, ColorSet c, Color accent) {
    const ruMonths = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    final monthLabel = '${ruMonths[_staffMonth - 1]} $_staffYear';
    final firstDay = DateTime(_staffYear, _staffMonth, 1);
    final lastDay = DateTime(_staffYear, _staffMonth + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7;
    final now = DateTime.now();
    final todayDay = (now.year == _staffYear && now.month == _staffMonth) ? now.day : -1;
    final isPastMonth = DateTime(_staffYear, _staffMonth + 1, 0).isBefore(DateTime(now.year, now.month, 1));
    const weekDays = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (_staffMonth == 1) { _staffMonth = 12; _staffYear--; } else { _staffMonth--; }
                  _staffSelectedDay = null;
                });
                _loadStaffAppointments();
              },
              child: Icon(Icons.chevron_left, size: 16, color: c.textSecondary),
            ),
            Text(monthLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
            InkWell(
              onTap: () {
                setState(() {
                  if (_staffMonth == 12) { _staffMonth = 1; _staffYear++; } else { _staffMonth++; }
                  _staffSelectedDay = null;
                });
                _loadStaffAppointments();
              },
              child: Icon(Icons.chevron_right, size: 16, color: c.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(children: weekDays.map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary))))).toList()),
        ...List.generate(((startOffset + lastDay.day + 6) ~/ 7), (week) {
          return Row(
            children: List.generate(7, (col) {
              final idx = week * 7 + col;
              final day = idx - startOffset + 1;
              if (day < 1 || day > lastDay.day) return const Expanded(child: SizedBox(height: 32));
              final isToday = day == todayDay;
              final isSelected = day == _staffSelectedDay;
              final dayDate = DateTime(_staffYear, _staffMonth, day);
              final isPast = dayDate.isBefore(DateTime(now.year, now.month, now.day));
              final hasAppt = _dayHasAppointment(day);
              return Expanded(child: GestureDetector(
                onTap: () {
                  setState(() => _staffSelectedDay = _staffSelectedDay == day ? null : day);
                  _loadStaffAppointments();
                },
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? accent : isToday ? accent.withValues(alpha: 0.15) : null,
                    borderRadius: BorderRadius.circular(isToday && !isSelected ? 14 : 4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected ? Colors.white : isPast ? c.textSecondary.withValues(alpha: 0.4) : isToday ? accent : c.text,
                        ),
                      ),
                      if (hasAppt)
                        Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : accent),
                        ),
                    ],
                  ),
                ),
              ));
            }),
          );
        }),
      ],
    );
  }

  Widget _buildDayDetail(ColorSet c, Color accent, List<Map<String, dynamic>> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_staffSelectedDay != null) ...[
          Row(
            children: [
              Text('$_staffYear-${_pad(_staffMonth)}-${_pad(_staffSelectedDay!)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _apptStatusFilter,
                  decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)), contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Активные', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'all', child: Text('Все', style: TextStyle(fontSize: 11))),
                    DropdownMenuItem(value: 'cancelled', child: Text('Отменённые', style: TextStyle(fontSize: 11))),
                  ],
                  onChanged: (v) => setState(() => _apptStatusFilter = v ?? 'active'),
                  style: TextStyle(fontSize: 11, color: c.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_appointmentsLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (filtered.isEmpty)
            Text('Нет бронирований', style: TextStyle(fontSize: 13, color: c.textSecondary))
          else
            ...filtered.map((appt) => _buildStaffApptItem(appt, c, accent)),
        ] else
          Text('Выберите дату', style: TextStyle(fontSize: 13, color: c.textSecondary)),
      ],
    );
  }

  Widget _buildStaffApptItem(Map<String, dynamic> appt, ColorSet c, Color accent) {
    final status = appt['status'] as String? ?? 'pending';
    final sColor = _statusColor(status, c);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Text(_formatTime(appt['start_time'] as String? ?? ''), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          if (appt['username'] != null) Text(appt['username'] as String, style: TextStyle(fontSize: 12, color: accent)),
          if (appt['service_name'] != null) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(appt['service_name'] as String, style: TextStyle(fontSize: 12, color: c.textSecondary), overflow: TextOverflow.ellipsis)),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: sColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
          ),
          if (status == 'pending') ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: () => _confirmAppointment(appt), child: Text('Подтвердить', style: TextStyle(fontSize: 12, color: c.success))),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => _cancelAppointment(appt), child: Text('Отменить', style: TextStyle(fontSize: 12, color: c.error))),
          ] else if (status == 'confirmed') ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: () => _cancelAppointment(appt), child: Text('Отменить', style: TextStyle(fontSize: 12, color: c.error))),
          ],
        ],
      ),
    );
  }

  // ===================== SETTINGS TAB =====================

  List<Map<String, dynamic>> _overrides = [];
  bool _overridesLoaded = false;
  String _settingsSection = 'specialists';

  Widget _buildSettingsTab(ThemeData theme, ColorSet c, Color accent) {
    if (!_overridesLoaded) {
      _overridesLoaded = true;
      _loadOverrides();
    }

    Widget settingsTab(String id, String label) {
      final active = _settingsSection == id;
      return GestureDetector(
        onTap: () => setState(() => _settingsSection = id),
        child: Container(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? accent : Colors.transparent, width: 2)),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? accent : c.textSecondary)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border, width: 2))),
          child: Row(children: [
            settingsTab('specialists', 'Специалисты'),
            settingsTab('services', 'Услуги'),
            settingsTab('overrides', 'Расписание'),
          ]),
        ),
        const SizedBox(height: 16),
        if (_settingsSection == 'specialists') _buildSpecialistsPanel(c, accent),
        if (_settingsSection == 'services') _buildServicesPanel(c, accent),
        if (_settingsSection == 'overrides') _buildOverridesPanel(c, accent),
      ],
    );
  }

  Future<void> _loadOverrides() async {
    try {
      final data = await _api.getOverrides(widget.section.id);
      if (mounted) setState(() => _overrides = (data['overrides'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
  }

  InputDecoration _bInput(String hint, ColorSet c) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(fontSize: 13, color: c.textSecondary),
    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    filled: true, fillColor: c.surfaceAlt,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.inputBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.inputBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
  );

  Widget _bCard(Widget child, ColorSet c) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
    child: child,
  );

  Widget _bForm(Widget child, ColorSet c) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: c.hoverOverlay, borderRadius: BorderRadius.circular(8)),
    child: child,
  );

  // ─── Specialists ────────────────────────────────
  final _specNameCtrl = TextEditingController();
  final _specDescCtrl = TextEditingController();

  Widget _buildSpecialistsPanel(ColorSet c, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._specialists.map((sp) => _bCard(
          Row(children: [
            Expanded(child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(sp['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
              if ((sp['description'] ?? '').toString().isNotEmpty)
                Text(sp['description'], style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ])),
            GestureDetector(
              onTap: () => _deleteSpecialist(sp['id']),
              child: Text('Удалить', style: TextStyle(fontSize: 12, color: c.error)),
            ),
          ]),
          c,
        )),
        _bForm(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _specNameCtrl, decoration: _bInput('Имя специалиста', c), style: TextStyle(fontSize: 13, color: c.text)),
            const SizedBox(height: 8),
            TextField(controller: _specDescCtrl, decoration: _bInput('Описание (необязательно)', c), style: TextStyle(fontSize: 13, color: c.text)),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton(onPressed: _createSpecialist, style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), textStyle: const TextStyle(fontSize: 13)), child: const Text('Создать')),
            ]),
          ]),
          c,
        ),
      ],
    );
  }

  Future<void> _createSpecialist() async {
    final name = _specNameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await _api.createSpecialist(widget.section.id, {'name': name, 'description': _specDescCtrl.text.trim()});
      _specNameCtrl.clear(); _specDescCtrl.clear();
      await _reloadSpecialists();
    } catch (_) { setState(() => _error = 'Ошибка создания'); }
  }

  Future<void> _deleteSpecialist(int id) async {
    try { await _api.deleteSpecialist(widget.section.id, id); await _reloadSpecialists(); } catch (_) {}
  }

  Future<void> _reloadSpecialists() async {
    final data = await _api.getSpecialists(widget.section.id);
    if (mounted) setState(() => _specialists = (data['specialists'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []);
  }

  // ─── Services ────────────────────────────────
  final _svcNameCtrl = TextEditingController();
  final _svcDescCtrl = TextEditingController();
  final _svcDurationCtrl = TextEditingController(text: '30');
  final _svcPriceCtrl = TextEditingController();

  Widget _buildServicesPanel(ColorSet c, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._services.map((svc) {
          final specIds = (svc['specialist_ids'] as List<dynamic>?)?.cast<int>() ?? [];
          final specNames = _specialists.where((sp) => specIds.contains(sp['id'])).map((sp) => sp['name']).join(', ');
          return _bCard(
            Row(children: [
              Expanded(child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(svc['name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text)),
                if (svc['duration'] != null) Text('${svc['duration']} мин', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                if (svc['price'] != null && svc['price'].toString().isNotEmpty)
                  Text(svc['price'].toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                if (specNames.isNotEmpty) Text('→ $specNames', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ])),
              GestureDetector(
                onTap: () => _deleteService(svc['id']),
                child: Text('Удалить', style: TextStyle(fontSize: 12, color: c.error)),
              ),
            ]),
            c,
          );
        }),
        _bForm(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _svcNameCtrl, decoration: _bInput('Название услуги', c), style: TextStyle(fontSize: 13, color: c.text)),
            const SizedBox(height: 8),
            TextField(controller: _svcDescCtrl, decoration: _bInput('Описание (необязательно)', c), style: TextStyle(fontSize: 13, color: c.text)),
            const SizedBox(height: 8),
            Row(children: [
              SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Длительность (мин)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(controller: _svcDurationCtrl, decoration: _bInput('30', c), keyboardType: TextInputType.number, style: TextStyle(fontSize: 13, color: c.text)),
              ])),
              const SizedBox(width: 12),
              SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Цена', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(controller: _svcPriceCtrl, decoration: _bInput('0', c), style: TextStyle(fontSize: 13, color: c.text)),
              ])),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton(onPressed: _createService, style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), textStyle: const TextStyle(fontSize: 13)), child: const Text('Создать')),
            ]),
          ]),
          c,
        ),
      ],
    );
  }

  Future<void> _createService() async {
    final name = _svcNameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      await _api.createService(widget.section.id, {'name': name, 'description': _svcDescCtrl.text.trim(), 'duration': int.tryParse(_svcDurationCtrl.text) ?? 30, 'price': _svcPriceCtrl.text.trim()});
      _svcNameCtrl.clear(); _svcDescCtrl.clear(); _svcDurationCtrl.text = '30'; _svcPriceCtrl.clear();
      await _reloadServices();
    } catch (_) { setState(() => _error = 'Ошибка создания'); }
  }

  Future<void> _deleteService(int id) async {
    try { await _api.deleteService(widget.section.id, id); await _reloadServices(); } catch (_) {}
  }

  Future<void> _reloadServices() async {
    final data = await _api.getServices(widget.section.id);
    if (mounted) setState(() => _services = (data['services'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []);
  }

  // ─── Overrides ────────────────────────────────
  String _overrideType = 'block';
  final _overrideDateCtrl = TextEditingController();
  final _overrideStartCtrl = TextEditingController(text: '09:00');
  final _overrideEndCtrl = TextEditingController(text: '18:00');
  final _overrideReasonCtrl = TextEditingController();

  Widget _buildOverridesPanel(ColorSet c, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._overrides.map((ov) {
          final type = ov['type'] ?? 'block';
          final date = ov['date'] ?? ov['day_of_week'] ?? '';
          final isBlock = type == 'block';
          return _bCard(
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isBlock ? c.error : c.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(isBlock ? 'БЛОК' : 'ДОБАВ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isBlock ? c.error : c.success)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text)),
                Text('${ov['start_time'] ?? ''} — ${ov['end_time'] ?? ''}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                if ((ov['reason'] ?? '').toString().isNotEmpty)
                  Text(ov['reason'], style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
              ])),
              GestureDetector(
                onTap: () => _deleteOverride(ov['id']),
                child: Text('Удалить', style: TextStyle(fontSize: 12, color: c.error)),
              ),
            ]),
            c,
          );
        }),
        _bForm(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Тип', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'block', label: Text('Блокировка')), ButtonSegment(value: 'add', label: Text('Добавление'))],
                  selected: {_overrideType}, onSelectionChanged: (s) => setState(() => _overrideType = s.first), showSelectedIcon: false,
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Дата', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(controller: _overrideDateCtrl, decoration: _bInput('2026-05-01', c), style: TextStyle(fontSize: 13, color: c.text)),
              ])),
              const SizedBox(width: 12),
              SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('С', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(controller: _overrideStartCtrl, decoration: _bInput('09:00', c), style: TextStyle(fontSize: 13, color: c.text)),
              ])),
              const SizedBox(width: 12),
              SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('До', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary)),
                const SizedBox(height: 4),
                TextField(controller: _overrideEndCtrl, decoration: _bInput('18:00', c), style: TextStyle(fontSize: 13, color: c.text)),
              ])),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _overrideReasonCtrl, decoration: _bInput('Причина (необязательно)', c), style: TextStyle(fontSize: 13, color: c.text)),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton(onPressed: _createOverride, style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), textStyle: const TextStyle(fontSize: 13)), child: const Text('Создать')),
            ]),
          ]),
          c,
        ),
      ],
    );
  }

  Future<void> _createOverride() async {
    final date = _overrideDateCtrl.text.trim();
    if (date.isEmpty) return;
    try {
      await _api.createOverride(widget.section.id, {'type': _overrideType, 'date': date, 'start_time': _overrideStartCtrl.text.trim(), 'end_time': _overrideEndCtrl.text.trim(), 'reason': _overrideReasonCtrl.text.trim()});
      _overrideDateCtrl.clear(); _overrideReasonCtrl.clear();
      await _loadOverrides();
    } catch (_) { setState(() => _error = 'Ошибка создания'); }
  }

  Future<void> _deleteOverride(int id) async {
    try { await _api.deleteOverride(widget.section.id, id); await _loadOverrides(); } catch (_) {}
  }
}

class _WeekDate {
  final String date;
  final String dayName;
  final int dayNum;
  final String monthStr;
  const _WeekDate({required this.date, required this.dayName, required this.dayNum, required this.monthStr});
}
