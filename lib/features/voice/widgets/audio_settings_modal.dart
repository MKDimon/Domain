import 'dart:async';
import 'dart:math' as math;
import 'package:domain_audio/domain_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../state/voice_settings.dart';

class AudioSettingsModal extends ConsumerStatefulWidget {
  final ColorSet c;
  const AudioSettingsModal({super.key, required this.c});

  @override
  ConsumerState<AudioSettingsModal> createState() => _AudioSettingsModalState();
}

class _AudioSettingsModalState extends ConsumerState<AudioSettingsModal> {
  bool _recordingPttKey = false;
  bool _recordingMuteKey = false;
  List<MediaDeviceInfo> _inputDevices = [];
  List<MediaDeviceInfo> _outputDevices = [];

  // Loopback (2 PCs with full SDP exchange) — always active for level meter.
  // Audio output muted via WASAPI session volume; unmuted only during mic test.
  MediaStream? _micStream;
  RTCPeerConnection? _senderPc;
  RTCPeerConnection? _receiverPc;
  Timer? _meterTimer;
  double _micLevel = 0;
  double _peakLevel = 0;
  double _peakAt = 0;
  double _prevEnergy = 0;
  double _prevDuration = 0;
  int _debugCounter = 0;

  // Auto-VAD: track noise floor in Dart (mirrors C++ logic)
  double _noiseFloor = 0.001;
  double _autoThreshold = 0.01;
  bool _selfMonitoring = false;
  double _savedOutputVol = 1.0; // saved app volume before muting for loopback

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _startLoopback();
  }

  @override
  void dispose() {
    _stopLoopback();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      if (!mounted) return;
      setState(() {
        _inputDevices = devices.where((d) => d.kind == 'audioinput').toList();
        _outputDevices = devices.where((d) => d.kind == 'audiooutput').toList();
      });
    } catch (_) {}
  }

  // ── Loopback: full SDP exchange for stats + self-monitoring ──

  Future<void> _startLoopback() async {
    try {
      // Save current output volume, then mute app audio so loopback is silent
      _savedOutputVol = ref.read(voiceSettingsProvider).outputVolume / 100.0;
      await DomainAudio.setOutputVolume(0.0);

      final settings = ref.read(voiceSettingsProvider);
      _micStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          if (settings.inputDeviceId.isNotEmpty) 'deviceId': settings.inputDeviceId,
          'echoCancellation': true,
          'noiseSuppression': settings.noiseFilter != 'off',
          'autoGainControl': false,
        },
        'video': false,
      });

      const config = {'sdpSemantics': 'unified-plan'};
      _senderPc = await createPeerConnection(config);
      _receiverPc = await createPeerConnection(config);

      _senderPc!.onIceCandidate = (c) async {
        if (c.candidate != null) {
          try { await _receiverPc?.addCandidate(c); } catch (_) {}
        }
      };
      _receiverPc!.onIceCandidate = (c) async {
        if (c.candidate != null) {
          try { await _senderPc?.addCandidate(c); } catch (_) {}
        }
      };

      for (final track in _micStream!.getAudioTracks()) {
        await _senderPc!.addTrack(track, _micStream!);
      }

      final offer = await _senderPc!.createOffer();
      await _senderPc!.setLocalDescription(offer);
      await _receiverPc!.setRemoteDescription(offer);

      final txs = await _receiverPc!.getTransceivers();
      for (final tx in txs) {
        try { await tx.setDirection(TransceiverDirection.SendRecv); } catch (_) {}
      }

      final answer = await _receiverPc!.createAnswer();
      await _receiverPc!.setLocalDescription(answer);
      await _senderPc!.setRemoteDescription(answer);

      _prevEnergy = 0;
      _prevDuration = 0;
      _debugCounter = 0;
      _meterTimer = Timer.periodic(const Duration(milliseconds: 80), (_) => _pollLevel());
    } catch (e) {
      // ignore: avoid_print
      print('[voice-modal] loopback start failed: $e');
      // Restore output volume on failure
      await DomainAudio.setOutputVolume(_savedOutputVol);
    }
  }

  void _stopLoopback() {
    _meterTimer?.cancel();
    _meterTimer = null;
    _senderPc?.close();
    _senderPc = null;
    _receiverPc?.close();
    _receiverPc = null;
    if (_micStream != null) {
      for (final t in _micStream!.getTracks()) { try { t.stop(); } catch (_) {} }
      try { _micStream!.dispose(); } catch (_) {}
      _micStream = null;
    }
    _micLevel = 0;
    _peakLevel = 0;
    // Restore output volume
    DomainAudio.setOutputVolume(_savedOutputVol);
    _selfMonitoring = false;
  }

  Future<void> _restartLoopback() async {
    _stopLoopback();
    await _startLoopback();
  }

  Future<void> _pollLevel() async {
    if (_senderPc == null || !mounted) return;
    // Debug: print VAD state every ~2 seconds (25 ticks * 80ms)
    _debugCounter++;
    if (_debugCounter % 25 == 0) {
      final vadState = await DomainAudio.getVadState();
      if (vadState != null) {
        // ignore: avoid_print
        print('[VAD] enabled=${vadState['vadEnabled']} gate=${vadState['gateOpen']} thresh=${vadState['threshold']} rms=${vadState['lastRms']} floor=${vadState['noiseFloor']} calls=${vadState['callCount']}');
      } else {
        // ignore: avoid_print
        print('[VAD] state=null (no processor?)');
      }
    }
    try {
      final stats = await _senderPc!.getStats();
      // Try media-source audioLevel
      for (final r in stats) {
        if (r.type == 'media-source' && r.values['kind'] == 'audio') {
          final level = r.values['audioLevel'];
          if (level is num && level > 0) {
            _updateLevel(level.toDouble().clamp(0.0, 1.0));
            return;
          }
        }
      }
      // Fallback: outbound-rtp energy delta
      for (final r in stats) {
        if (r.type == 'outbound-rtp' && r.values['kind'] == 'audio') {
          final energy = (r.values['totalAudioEnergy'] as num?)?.toDouble() ?? 0.0;
          final duration = (r.values['totalSamplesDuration'] as num?)?.toDouble() ?? 0.0;
          final dE = energy - _prevEnergy;
          final dD = duration - _prevDuration;
          _prevEnergy = energy;
          _prevDuration = duration;
          if (dD > 0 && dE >= 0) {
            _updateLevel(math.sqrt((dE / dD).clamp(0.0, 1.0)));
            return;
          }
        }
      }
      // Fallback: receiver inbound-rtp
      if (_receiverPc != null) {
        final rStats = await _receiverPc!.getStats();
        for (final r in rStats) {
          if (r.type == 'inbound-rtp' && r.values['kind'] == 'audio') {
            final energy = (r.values['totalAudioEnergy'] as num?)?.toDouble() ?? 0.0;
            final duration = (r.values['totalSamplesDuration'] as num?)?.toDouble() ?? 0.0;
            if (duration > 0) {
              _updateLevel(math.sqrt((energy / duration).clamp(0.0, 1.0)));
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  void _updateLevel(double rms) {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    setState(() {
      _micLevel = rms;
      if (rms >= _peakLevel) {
        _peakLevel = rms;
        _peakAt = now;
      } else if (now - _peakAt > 1000) {
        _peakLevel = math.max(0, _peakLevel * 0.97);
      }
    });

    final settings = ref.read(voiceSettingsProvider);
    if (settings.activationMode == 'vad') {
      final gainScale = math.max(0.25, settings.inputVolume / 25.0);
      final scaledLevel = rms * gainScale;

      // Auto-VAD: track noise floor during quiet, set threshold = floor × 3
      if (settings.autoVad) {
        if (scaledLevel < 0.005) {
          _noiseFloor = _noiseFloor * 0.98 + scaledLevel * 0.02;
          _autoThreshold = (_noiseFloor * 3.0).clamp(0.003, 0.15);
          // Update the settings slider to show auto threshold
          ref.read(voiceSettingsProvider.notifier).setVadSensitivity(_autoThreshold);
        }
      }

      final threshold = settings.autoVad ? _autoThreshold : settings.vadSensitivity;
      final isAboveThreshold = scaledLevel > threshold;

      // Gate loopback during self-monitoring
      if (_selfMonitoring) {
        final vol = settings.outputVolume / 100.0;
        DomainAudio.setOutputVolume(isAboveThreshold ? vol.clamp(0.1, 2.0) : 0.0);
      }
    }
  }

  // ── Self-monitoring: unmute WASAPI so loopback audio plays ──

  void _toggleMicTest() async {
    if (_selfMonitoring) {
      // Mute loopback
      await DomainAudio.setOutputVolume(0.0);
      setState(() => _selfMonitoring = false);
    } else {
      // Unmute — let user hear themselves through loopback
      final vol = ref.read(voiceSettingsProvider).outputVolume / 100.0;
      await DomainAudio.setOutputVolume(vol.clamp(0.1, 2.0));
      setState(() => _selfMonitoring = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(voiceSettingsProvider);
    final notifier = ref.read(voiceSettingsProvider.notifier);

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
              child: Row(
                children: [
                  Text(l.voiceSettingsTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
                  const Spacer(),
                  _closeBtn(c),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shrinkWrap: true,
                children: [
                  _sectionTitle(l.voiceDevices, c),
                  const SizedBox(height: 8),
                  _fieldLabel(l.voiceMicrophone, c),
                  const SizedBox(height: 4),
                  _deviceDropdown(devices: _inputDevices, selectedId: settings.inputDeviceId,
                    onChanged: (id) { notifier.setInputDeviceId(id); _restartLoopback(); }, c: c),
                  const SizedBox(height: 8),
                  _micLevelBar(c),
                  const SizedBox(height: 8),
                  _testMicButton(c, l),
                  if (_selfMonitoring)
                    Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(l.voiceTestMicHint, style: TextStyle(fontSize: 11, color: c.warning), textAlign: TextAlign.center)),
                  const SizedBox(height: 12),
                  _fieldLabel(l.voiceSpeaker, c),
                  const SizedBox(height: 4),
                  _deviceDropdown(devices: _outputDevices, selectedId: settings.outputDeviceId,
                    onChanged: (id) => notifier.setOutputDeviceId(id), c: c),
                  const SizedBox(height: 10),
                  _checkRow(l.voiceSfx, settings.sfx, c, (v) => notifier.setSfx(v)),

                  _sectionDivider(c),
                  _sectionTitle(l.voiceVolume, c),
                  const SizedBox(height: 8),
                  _volumeRow('${l.voiceInputVolume}: ${settings.inputVolume}%', settings.inputVolume, 0, 200, c,
                    (v) { notifier.setInputVolume(v); DomainAudio.setInputGain(v / 100.0); }),
                  const SizedBox(height: 10),
                  _volumeRow('${l.voiceOutputVolume}: ${settings.outputVolume}%', settings.outputVolume, 0, 200, c,
                    (v) {
                      notifier.setOutputVolume(v);
                      // Apply immediately; if self-monitoring, update loopback volume too
                      if (_selfMonitoring) {
                        DomainAudio.setOutputVolume((v / 100.0).clamp(0.0, 2.0));
                      }
                    }),

                  _sectionDivider(c),
                  _sectionTitle(l.voiceAudioProcessing, c),
                  const SizedBox(height: 8),
                  _fieldLabel(l.voiceNoiseFilter, c),
                  const SizedBox(height: 4),
                  _noiseFilterDropdown(settings, notifier, c, l),
                  const SizedBox(height: 4),
                  Text(settings.noiseFilter == 'off' ? l.voiceNfHintOff : l.voiceNfHintBuiltin,
                    style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  const SizedBox(height: 10),
                  _checkRow(l.voiceEchoCancellation, settings.echoCancellation, c, (v) {
                    notifier.setEchoCancellation(v); _restartLoopback(); }),
                  Text(l.voiceEcHint, style: TextStyle(fontSize: 11, color: c.textSecondary)),

                  _sectionDivider(c),
                  _sectionTitle(l.voiceActivationMode, c),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'vad', label: Text(l.voiceActivationVad)),
                      ButtonSegment(value: 'ptt', label: Text(l.voiceActivationPtt)),
                    ],
                    selected: {settings.activationMode},
                    onSelectionChanged: (s) => notifier.setActivationMode(s.first),
                    showSelectedIcon: false,
                  ),
                  if (settings.activationMode == 'vad') ...[
                    const SizedBox(height: 10),
                    _checkRow(l.voiceAutoVad, settings.autoVad, c, (v) {
                      notifier.setAutoVad(v);
                      DomainAudio.setVadConfig(enabled: true, threshold: settings.vadSensitivity, autoVad: v);
                    }),
                    Text(l.voiceAutoVadHint, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    const SizedBox(height: 10),
                    _fieldLabel('${l.voiceSensitivity}: ${settings.vadSensitivity.toStringAsFixed(3)}', c),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: settings.autoVad ? c.textSecondary.withValues(alpha: 0.3) : c.accent,
                        inactiveTrackColor: c.border,
                        thumbColor: settings.autoVad ? c.textSecondary : c.accent,
                        overlayColor: c.accent.withValues(alpha: 0.15),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(value: settings.vadSensitivity, min: 0.002, max: 0.3,
                        onChanged: settings.autoVad ? null : (v) {
                          notifier.setVadSensitivity(v);
                          DomainAudio.setVadConfig(enabled: true, threshold: v, autoVad: false);
                        }),
                    ),
                    _vadMeter(settings, c),
                    const SizedBox(height: 4),
                    Text(l.voiceSensitivityHint, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                  if (settings.isPtt) ...[
                    const SizedBox(height: 12),
                    _fieldLabel(l.voicePttKey, c),
                    const SizedBox(height: 4),
                    _keyRecorder(isRecording: _recordingPttKey, currentKey: settings.pttKey,
                      onTap: () => setState(() => _recordingPttKey = true),
                      onKey: (key) { notifier.setPttKey(key); setState(() => _recordingPttKey = false); },
                      onClear: () => notifier.setPttKey(''), c: c, recordingText: l.voicePttRecording),
                    const SizedBox(height: 4),
                    Text(l.voicePttHint, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],

                  _sectionDivider(c),
                  _sectionTitle(l.voiceMuteHotkey, c),
                  const SizedBox(height: 8),
                  _keyRecorder(isRecording: _recordingMuteKey, currentKey: settings.muteKey,
                    emptyText: l.voiceMuteKeyNotSet,
                    onTap: () => setState(() => _recordingMuteKey = true),
                    onKey: (key) { notifier.setMuteKey(key); setState(() => _recordingMuteKey = false); },
                    onClear: () => notifier.setMuteKey(''), c: c, recordingText: l.voiceMuteKeyRecording, allowModifierOnly: true),
                  const SizedBox(height: 4),
                  Text(l.voiceMuteKeyHint, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () { notifier.resetToDefaults(); _restartLoopback(); },
                    child: Text(l.voiceReset, style: TextStyle(fontSize: 13, color: c.textSecondary, decoration: TextDecoration.underline))),
                  FilledButton(
                    onPressed: () { _stopLoopback(); Navigator.pop(context); },
                    style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text(l.voiceDone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _closeBtn(ColorSet c) => InkWell(
    onTap: () { _stopLoopback(); Navigator.pop(context); },
    borderRadius: BorderRadius.circular(6),
    child: Container(width: 28, height: 28, alignment: Alignment.center,
      child: Text('×', style: TextStyle(fontSize: 20, color: c.textSecondary, height: 1))),
  );

  Widget _sectionTitle(String text, ColorSet c) => Text(text,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary, letterSpacing: 0.6));

  Widget _sectionDivider(ColorSet c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: c.border));

  Widget _fieldLabel(String text, ColorSet c) => Text(text,
    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text));

  Widget _checkRow(String label, bool value, ColorSet c, void Function(bool) onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.text))),
      SizedBox(height: 28, child: Switch(value: value, onChanged: onChanged, activeThumbColor: c.accent)),
    ]),
  );

  Widget _volumeRow(String label, int value, int min, int max, ColorSet c, void Function(int) onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text)),
      SliderTheme(
        data: SliderThemeData(activeTrackColor: c.accent, inactiveTrackColor: c.border,
          thumbColor: c.accent, overlayColor: c.accent.withValues(alpha: 0.15),
          trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
        child: Slider(value: value.toDouble(), min: min.toDouble(), max: max.toDouble(),
          onChanged: (v) => onChanged(v.round())),
      ),
    ],
  );

  Widget _testMicButton(ColorSet c, AppLocalizations l) => InkWell(
    onTap: _toggleMicTest, borderRadius: BorderRadius.circular(8),
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _selfMonitoring ? c.error : c.surfaceAlt,
        border: Border.all(color: _selfMonitoring ? c.error : c.border),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_selfMonitoring ? Icons.stop : Icons.mic, size: 18, color: _selfMonitoring ? Colors.white : c.text),
        const SizedBox(width: 8),
        Text(_selfMonitoring ? l.voiceStopTest : l.voiceTestMic,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _selfMonitoring ? Colors.white : c.text)),
      ]),
    ),
  );

  Widget _micLevelBar(ColorSet c) {
    final level = (_micLevel * 100).clamp(0.0, 100.0);
    final peak = (_peakLevel * 100).clamp(0.0, 100.0);
    return SizedBox(height: 14, child: LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      return Stack(children: [
        Container(decoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(4))),
        Positioned(left: 0, top: 0, bottom: 0,
          child: AnimatedContainer(duration: const Duration(milliseconds: 50), width: w * level / 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.success, level > 70 ? c.warning : c.success, level > 90 ? c.error : c.success]),
              borderRadius: BorderRadius.circular(3)))),
        if (peak > 2)
          Positioned(left: (w * peak / 100) - 1, top: 0, bottom: 0,
            child: Container(width: 2, color: Colors.white.withValues(alpha: 0.8))),
      ]);
    }));
  }

  Widget _vadMeter(VoiceSettings settings, ColorSet c) {
    final gainScale = math.max(0.25, settings.inputVolume / 25.0);
    final scaledLevel = _micLevel * gainScale;
    final scaledPeak = _peakLevel * gainScale;
    const meterMax = 0.1;
    final levelPct = (scaledLevel / meterMax * 100).clamp(0.0, 100.0);
    final peakPct = (scaledPeak / meterMax * 100).clamp(0.0, 100.0);
    final threshPct = (settings.vadSensitivity / meterMax * 100).clamp(0.0, 100.0);
    final isActive = scaledLevel > settings.vadSensitivity;
    return SizedBox(height: 14, child: LayoutBuilder(builder: (ctx, box) {
      final w = box.maxWidth;
      return Stack(clipBehavior: Clip.none, children: [
        Container(decoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(4))),
        Positioned(left: 0, top: 0, bottom: 0,
          child: AnimatedContainer(duration: const Duration(milliseconds: 50), width: w * levelPct / 100,
            decoration: BoxDecoration(color: isActive ? c.success : c.textSecondary, borderRadius: BorderRadius.circular(3)))),
        if (peakPct > 2)
          Positioned(left: (w * peakPct / 100) - 1, top: 0, bottom: 0,
            child: Container(width: 2, color: Colors.white.withValues(alpha: 0.5))),
        Positioned(left: (w * threshPct / 100) - 1, top: -2, bottom: -2,
          child: Container(width: 2, color: c.warning)),
      ]);
    }));
  }

  Widget _noiseFilterDropdown(VoiceSettings settings, VoiceSettingsNotifier notifier, ColorSet c, AppLocalizations l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: settings.noiseFilter, isExpanded: true, dropdownColor: c.surface,
      style: TextStyle(fontSize: 13, color: c.text),
      items: [
        DropdownMenuItem(value: 'off', child: Text(l.voiceNfOff)),
        DropdownMenuItem(value: 'builtin', child: Text(l.voiceNfBuiltin)),
        DropdownMenuItem(value: 'rnnoise', child: Text(l.voiceNfRnnoise, style: TextStyle(color: c.textSecondary))),
      ],
      onChanged: (v) {
        if (v == 'rnnoise') return;
        notifier.setNoiseFilter(v ?? 'builtin');
        notifier.setNoiseSuppression(v != 'off');
        _restartLoopback();
      },
    )),
  );

  Widget _deviceDropdown({required List<MediaDeviceInfo> devices, required String selectedId,
    required void Function(String) onChanged, required ColorSet c}) {
    final effectiveId = devices.any((d) => d.deviceId == selectedId) ? selectedId : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: c.surfaceAlt, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: effectiveId, isExpanded: true, dropdownColor: c.surface,
        style: TextStyle(fontSize: 13, color: c.text),
        items: [
          DropdownMenuItem(value: '', child: Text('По умолчанию', style: TextStyle(fontSize: 13, color: c.textSecondary))),
          ...devices.map((d) => DropdownMenuItem(value: d.deviceId,
            child: Text(d.label.isNotEmpty ? d.label : d.deviceId.substring(0, math.min(8, d.deviceId.length)),
              style: TextStyle(fontSize: 13, color: c.text), overflow: TextOverflow.ellipsis))),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      )),
    );
  }

  Widget _keyRecorder({required bool isRecording, required String currentKey, String? emptyText,
    required VoidCallback onTap, required void Function(String) onKey, required VoidCallback onClear,
    required ColorSet c, required String recordingText, bool allowModifierOnly = false}) {
    return GestureDetector(onTap: onTap, child: Focus(
      autofocus: isRecording,
      onKeyEvent: isRecording ? (node, event) {
        if (event is KeyDownEvent) {
          final label = event.logicalKey.keyLabel;
          if (label.isEmpty) return KeyEventResult.ignored;
          final mods = {'Control Left','Control Right','Shift Left','Shift Right','Alt Left','Alt Right','Meta Left','Meta Right'};
          if (allowModifierOnly && mods.contains(label)) { onKey(label); return KeyEventResult.handled; }
          if (mods.contains(label)) return KeyEventResult.ignored;
          final parts = <String>[];
          if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
          if (HardwareKeyboard.instance.isShiftPressed) parts.add('Shift');
          if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
          parts.add(event.logicalKey == LogicalKeyboardKey.space ? 'Space' : label);
          onKey(parts.join('+'));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isRecording ? c.accent.withValues(alpha: 0.1) : c.surfaceAlt,
          border: Border.all(color: isRecording ? c.accent : c.border), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.keyboard, size: 16, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            isRecording ? recordingText : currentKey.isEmpty ? (emptyText ?? '') : currentKey,
            style: TextStyle(fontSize: 13, fontFamily: 'monospace',
              color: isRecording ? c.accent : (currentKey.isEmpty ? c.textSecondary : c.text)))),
          if (currentKey.isNotEmpty && !isRecording)
            InkWell(onTap: onClear, child: Icon(Icons.close, size: 14, color: c.textSecondary)),
        ]),
      ),
    ));
  }
}
