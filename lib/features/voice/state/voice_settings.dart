import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Voice settings — persisted to SharedPreferences, mirrors web's voiceSettings store.
class VoiceSettings {
  final String activationMode; // 'vad' | 'ptt'
  final String pttKey; // e.g. 'V', 'Space', 'Ctrl+V'
  final String muteKey; // global hotkey for mute toggle, e.g. 'Ctrl+Shift+M'
  final bool echoCancellation;
  final bool noiseSuppression;
  final String noiseFilter; // 'off' | 'builtin' | 'rnnoise'
  final int inputVolume; // 0-200
  final int outputVolume; // 0-200
  final bool sfx;
  final String inputDeviceId; // '' = system default
  final String outputDeviceId; // '' = system default
  final double vadSensitivity; // RMS threshold 0.002-0.3
  final bool autoVad; // Discord-style adaptive threshold
  final String shareResolution; // 'auto' | '1080' | '720' | '480'
  final int shareFramerate; // 15 | 30 | 60
  final bool shareSystemAudio;
  final String shareSurface; // 'auto' | 'monitor' | 'window' | 'browser'
  final bool sharePreview;

  const VoiceSettings({
    this.activationMode = 'vad',
    this.pttKey = 'V',
    this.muteKey = '',
    this.echoCancellation = true,
    this.noiseSuppression = false,
    this.noiseFilter = 'builtin',
    this.inputVolume = 100,
    this.outputVolume = 100,
    this.sfx = true,
    this.inputDeviceId = '',
    this.outputDeviceId = '',
    this.vadSensitivity = 0.01,
    this.autoVad = true,
    this.shareResolution = 'auto',
    this.shareFramerate = 30,
    this.shareSystemAudio = false,
    this.shareSurface = 'auto',
    this.sharePreview = false,
  });

  VoiceSettings copyWith({
    String? activationMode,
    String? pttKey,
    String? muteKey,
    bool? echoCancellation,
    bool? noiseSuppression,
    String? noiseFilter,
    int? inputVolume,
    int? outputVolume,
    bool? sfx,
    String? inputDeviceId,
    String? outputDeviceId,
    double? vadSensitivity,
    bool? autoVad,
    String? shareResolution,
    int? shareFramerate,
    bool? shareSystemAudio,
    String? shareSurface,
    bool? sharePreview,
  }) => VoiceSettings(
    activationMode: activationMode ?? this.activationMode,
    pttKey: pttKey ?? this.pttKey,
    muteKey: muteKey ?? this.muteKey,
    echoCancellation: echoCancellation ?? this.echoCancellation,
    noiseSuppression: noiseSuppression ?? this.noiseSuppression,
    noiseFilter: noiseFilter ?? this.noiseFilter,
    inputVolume: inputVolume ?? this.inputVolume,
    outputVolume: outputVolume ?? this.outputVolume,
    sfx: sfx ?? this.sfx,
    inputDeviceId: inputDeviceId ?? this.inputDeviceId,
    outputDeviceId: outputDeviceId ?? this.outputDeviceId,
    vadSensitivity: vadSensitivity ?? this.vadSensitivity,
    autoVad: autoVad ?? this.autoVad,
    shareResolution: shareResolution ?? this.shareResolution,
    shareFramerate: shareFramerate ?? this.shareFramerate,
    shareSystemAudio: shareSystemAudio ?? this.shareSystemAudio,
    shareSurface: shareSurface ?? this.shareSurface,
    sharePreview: sharePreview ?? this.sharePreview,
  );

  bool get isPtt => activationMode == 'ptt';
}

class VoiceSettingsNotifier extends StateNotifier<VoiceSettings> {
  VoiceSettingsNotifier() : super(const VoiceSettings()) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = VoiceSettings(
      activationMode: p.getString('voice.activationMode') ?? 'vad',
      pttKey: p.getString('voice.pttKey') ?? 'V',
      muteKey: p.getString('voice.muteKey') ?? '',
      echoCancellation: p.getBool('voice.echoCancellation') ?? true,
      noiseSuppression: p.getBool('voice.noiseSuppression') ?? true,
      noiseFilter: p.getString('voice.noiseFilter') ?? 'builtin',
      inputVolume: p.getInt('voice.inputVolume') ?? 100,
      outputVolume: p.getInt('voice.outputVolume') ?? 100,
      sfx: p.getBool('voice.sfx') ?? true,
      inputDeviceId: p.getString('voice.inputDeviceId') ?? '',
      outputDeviceId: p.getString('voice.outputDeviceId') ?? '',
      vadSensitivity: p.getDouble('voice.vadSensitivity') ?? 0.01,
      autoVad: p.getBool('voice.autoVad') ?? true,
      shareResolution: p.getString('voice.shareResolution') ?? '720',
      shareFramerate: p.getInt('voice.shareFramerate') ?? 30,
      shareSystemAudio: p.getBool('voice.shareSystemAudio') ?? false,
      shareSurface: p.getString('voice.shareSurface') ?? 'auto',
      sharePreview: p.getBool('voice.sharePreview') ?? false,
    );
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    p.setString('voice.activationMode', state.activationMode);
    p.setString('voice.pttKey', state.pttKey);
    p.setString('voice.muteKey', state.muteKey);
    p.setBool('voice.echoCancellation', state.echoCancellation);
    p.setBool('voice.noiseSuppression', state.noiseSuppression);
    p.setString('voice.noiseFilter', state.noiseFilter);
    p.setInt('voice.inputVolume', state.inputVolume);
    p.setInt('voice.outputVolume', state.outputVolume);
    p.setBool('voice.sfx', state.sfx);
    p.setString('voice.inputDeviceId', state.inputDeviceId);
    p.setString('voice.outputDeviceId', state.outputDeviceId);
    p.setDouble('voice.vadSensitivity', state.vadSensitivity);
    p.setBool('voice.autoVad', state.autoVad);
    p.setString('voice.shareResolution', state.shareResolution);
    p.setInt('voice.shareFramerate', state.shareFramerate);
    p.setBool('voice.shareSystemAudio', state.shareSystemAudio);
    p.setString('voice.shareSurface', state.shareSurface);
    p.setBool('voice.sharePreview', state.sharePreview);
  }

  void setActivationMode(String mode) {
    state = state.copyWith(activationMode: mode);
    _save();
  }

  void setPttKey(String key) {
    state = state.copyWith(pttKey: key);
    _save();
  }

  void setMuteKey(String key) {
    state = state.copyWith(muteKey: key);
    _save();
  }

  void setEchoCancellation(bool v) {
    state = state.copyWith(echoCancellation: v);
    _save();
  }

  void setNoiseSuppression(bool v) {
    state = state.copyWith(noiseSuppression: v);
    _save();
  }

  void setNoiseFilter(String v) {
    state = state.copyWith(noiseFilter: v);
    _save();
  }

  void setInputVolume(int v) {
    state = state.copyWith(inputVolume: v.clamp(0, 200));
    _save();
  }

  void setOutputVolume(int v) {
    state = state.copyWith(outputVolume: v.clamp(0, 200));
    _save();
  }

  void setSfx(bool v) {
    state = state.copyWith(sfx: v);
    _save();
  }

  void setInputDeviceId(String id) {
    state = state.copyWith(inputDeviceId: id);
    _save();
  }

  void setOutputDeviceId(String id) {
    state = state.copyWith(outputDeviceId: id);
    _save();
  }

  void setVadSensitivity(double v) {
    state = state.copyWith(vadSensitivity: v.clamp(0.002, 0.3));
    _save();
  }

  void setAutoVad(bool v) {
    state = state.copyWith(autoVad: v);
    _save();
  }

  void setShareResolution(String v) {
    state = state.copyWith(shareResolution: v);
    _save();
  }

  void setShareFramerate(int v) {
    state = state.copyWith(shareFramerate: v);
    _save();
  }

  void setShareSystemAudio(bool v) {
    state = state.copyWith(shareSystemAudio: v);
    _save();
  }

  void setShareSurface(String v) {
    state = state.copyWith(shareSurface: v);
    _save();
  }

  void setSharePreview(bool v) {
    state = state.copyWith(sharePreview: v);
    _save();
  }

  void resetToDefaults() {
    state = const VoiceSettings();
    _save();
  }
}

final voiceSettingsProvider =
    StateNotifierProvider<VoiceSettingsNotifier, VoiceSettings>((ref) {
  return VoiceSettingsNotifier();
});
