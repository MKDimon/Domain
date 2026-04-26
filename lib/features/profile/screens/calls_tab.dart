import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  static const _storageKey = 'ringtone_id';
  static const _ringtones = [
    _Ringtone(id: 'none', label: 'Без звука'),
    _Ringtone(id: 'classic', label: 'Классический', file: 'sounds/ringtones/classic.mp3'),
    _Ringtone(id: 'chime', label: 'Перезвон', file: 'sounds/ringtones/chime.mp3'),
    _Ringtone(id: 'pulse', label: 'Пульс', file: 'sounds/ringtones/pulse.mp3'),
    _Ringtone(id: 'melody', label: 'Мелодия', file: 'sounds/ringtones/melody.mp3'),
  ];

  String _selectedId = 'none';
  AudioPlayer? _previewPlayer;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _loadStored();
  }

  @override
  void dispose() {
    _previewPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null && _ringtones.any((r) => r.id == stored)) {
      setState(() => _selectedId = stored);
    }
  }

  Future<void> _setRingtone(String id) async {
    setState(() => _selectedId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, id);
  }

  Future<void> _preview() async {
    final rt = _ringtones.firstWhere((r) => r.id == _selectedId);
    if (rt.file == null) return;

    _previewPlayer?.dispose();
    _previewPlayer = AudioPlayer();
    setState(() => _previewing = true);

    try {
      await _previewPlayer!.setAsset('assets/${rt.file}');
      await _previewPlayer!.play();
      await Future.delayed(const Duration(milliseconds: 3500));
      await _previewPlayer?.stop();
    } catch (_) {}

    if (mounted) setState(() => _previewing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNone = _selectedId == 'none';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Звонки', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Настройки звонков и уведомлений', style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color)),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Рингтон', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Звук входящего звонка', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('Выберите мелодию для входящих вызовов', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(6),
                        color: theme.colorScheme.surface,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedId,
                          onChanged: (v) { if (v != null) _setRingtone(v); },
                          items: _ringtones.map((r) => DropdownMenuItem(value: r.id, child: Text(r.label, style: const TextStyle(fontSize: 14)))).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: isNone || _previewing ? null : _preview,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: Text(_previewing ? '...' : 'Прослушать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ringtone {
  final String id;
  final String label;
  final String? file;
  const _Ringtone({required this.id, required this.label, this.file});
}
