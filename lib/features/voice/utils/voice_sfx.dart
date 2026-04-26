import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

class VoiceSfx {
  static final VoiceSfx _instance = VoiceSfx._();
  factory VoiceSfx() => _instance;
  VoiceSfx._();

  bool _muted = false;
  double _volume = 0.6;
  bool _initialized = false;

  final _files = <String, String>{};

  set muted(bool v) => _muted = v;
  set volume(double v) => _volume = v.clamp(0.0, 1.0);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final tmpDir = Directory.systemTemp.path;
    final wavs = <String, Uint8List>{
      'selfJoin': _genTone(380, 720, 0.18, 0.55),
      'selfLeave': _genTone(720, 320, 0.22, 0.5),
      'userJoin': _genTwoTone(540, 540, 0.08, 720, 720, 0.1, 0.4),
      'userLeave': _genTwoTone(540, 540, 0.08, 380, 380, 0.1, 0.4),
      'mute': _genTone(320, 240, 0.06, 0.45, wave: 'triangle'),
      'unmute': _genTone(480, 600, 0.06, 0.45, wave: 'triangle'),
      'attention': _genTwoTone(760, 760, 0.12, 1020, 1020, 0.14, 0.6),
      'ringtone': _genRingtone(),
      'outgoing': _genOutgoingTone(),
    };
    for (final entry in wavs.entries) {
      final path = '$tmpDir/domain_sfx_${entry.key}.wav';
      File(path).writeAsBytesSync(entry.value);
      _files[entry.key] = path;
    }
    for (final entry in _files.entries) {
      final player = AudioPlayer();
      await player.setFilePath(entry.value);
      await player.setVolume(0);
      await player.play();
      await player.stop();
      await player.setVolume(_volume);
      _players[entry.key] = player;
    }
  }

  final _players = <String, AudioPlayer>{};
  AudioPlayer? _loopPlayer;

  void _play(String name) {
    if (_muted) return;
    final path = _files[name];
    if (path == null) return;
    Future(() async {
      try {
        var player = _players[name];
        if (player == null) {
          player = AudioPlayer();
          await player.setFilePath(path);
          _players[name] = player;
        }
        await player.setVolume(_volume);
        await player.seek(Duration.zero);
        player.play();
      } catch (_) {}
    });
  }

  void _playLoop(String name) {
    stopLoop();
    if (_muted) return;
    final path = _files[name];
    if (path == null) return;
    Future(() async {
      try {
        final player = AudioPlayer();
        await player.setVolume(_volume);
        await player.setFilePath(path);
        _loopPlayer = player;
        player.play();
      } catch (_) {}
    });
  }

  void stopLoop() {
    final p = _loopPlayer;
    _loopPlayer = null;
    if (p != null) {
      Future(() async {
        try { await p.stop(); await p.dispose(); } catch (_) {}
      });
    }
  }

  void playSelfJoin() => _play('selfJoin');
  void playSelfLeave() => _play('selfLeave');
  void playUserJoin() => _play('userJoin');
  void playUserLeave() => _play('userLeave');
  void playMute() => _play('mute');
  void playUnmute() => _play('unmute');
  void playAttention() => _play('attention');
  void playRingtone() => _playLoop('ringtone');
  void playOutgoing() => _playLoop('outgoing');

  void dispose() {
    stopLoop();
    for (final p in _players.values) {
      try { p.dispose(); } catch (_) {}
    }
    _players.clear();
    _files.clear();
    _initialized = false;
  }

  static const _sampleRate = 44100;

  static Uint8List _genTone(double fromHz, double toHz, double dur, double peak, {String wave = 'sine'}) {
    final samples = (dur * _sampleRate).round();
    final pcm = Float64List(samples);
    for (var i = 0; i < samples; i++) {
      final t = i / _sampleRate;
      final progress = i / samples;
      final freq = fromHz * pow(toHz / fromHz, progress);
      final phase = 2 * pi * freq * t;
      double sample;
      if (wave == 'triangle') {
        sample = (2 * (phase / (2 * pi) - (phase / (2 * pi)).floor()) - 1).abs() * 2 - 1;
      } else {
        sample = sin(phase);
      }
      final attack = (t / 0.008).clamp(0.0, 1.0);
      final decay = pow(1 - progress, 2.0);
      pcm[i] = sample * peak * attack * decay;
    }
    return _pcmToWav(pcm);
  }

  static Uint8List _genTwoTone(double f1, double t1, double d1, double f2, double t2, double d2, double peak) {
    final samples1 = (d1 * _sampleRate).round();
    final samples2 = (d2 * _sampleRate).round();
    final total = samples1 + samples2;
    final pcm = Float64List(total);
    for (var i = 0; i < samples1; i++) {
      final t = i / _sampleRate;
      final progress = i / samples1;
      final freq = f1 * pow(t1 / f1, progress);
      final attack = (t / 0.008).clamp(0.0, 1.0);
      final decay = pow(1 - progress, 2.0);
      pcm[i] = sin(2 * pi * freq * t) * peak * attack * decay;
    }
    for (var i = 0; i < samples2; i++) {
      final t = i / _sampleRate;
      final progress = i / samples2;
      final freq = f2 * pow(t2 / f2, progress);
      final attack = (t / 0.008).clamp(0.0, 1.0);
      final decay = pow(1 - progress, 2.0);
      pcm[samples1 + i] = sin(2 * pi * freq * t) * peak * attack * decay;
    }
    return _pcmToWav(pcm);
  }

  static Uint8List _genRingtone() {
    const cycleDur = 3.0;
    const repeats = 10;
    const dur = cycleDur * repeats;
    final samples = (dur * _sampleRate).round();
    final pcm = Float64List(samples);
    const notes = [
      (f: 880.0, d: 0.15), (f: 0.0, d: 0.08),
      (f: 880.0, d: 0.15), (f: 0.0, d: 0.08),
      (f: 1047.0, d: 0.2), (f: 0.0, d: 1.0),
      (f: 880.0, d: 0.15), (f: 0.0, d: 0.08),
      (f: 880.0, d: 0.15), (f: 0.0, d: 0.08),
      (f: 1047.0, d: 0.2), (f: 0.0, d: 0.68),
    ];
    for (var r = 0; r < repeats; r++) {
      var offset = r * cycleDur;
      for (final n in notes) {
        final start = (offset * _sampleRate).round();
        final end = ((offset + n.d) * _sampleRate).round().clamp(0, samples);
        if (n.f > 0) {
          for (var i = start; i < end; i++) {
            final t = (i - start) / _sampleRate;
            final progress = (i - start) / (end - start);
            final attack = (t / 0.005).clamp(0.0, 1.0);
            final decay = pow(1 - progress, 1.5);
            pcm[i] = sin(2 * pi * n.f * t) * 0.35 * attack * decay;
          }
        }
        offset += n.d;
      }
    }
    return _pcmToWav(pcm);
  }

  static Uint8List _genOutgoingTone() {
    const beepDur = 0.8;
    const pauseDur = 3.2;
    const cycleDur = beepDur + pauseDur;
    const repeats = 8;
    const dur = cycleDur * repeats;
    final samples = (dur * _sampleRate).round();
    final pcm = Float64List(samples);
    const freq = 440.0;
    for (var r = 0; r < repeats; r++) {
      final offset = r * cycleDur;
      final start = (offset * _sampleRate).round();
      final end = ((offset + beepDur) * _sampleRate).round().clamp(0, samples);
      for (var i = start; i < end; i++) {
        final t = (i - start) / _sampleRate;
        final progress = (i - start) / (end - start);
        final attack = (t / 0.02).clamp(0.0, 1.0);
        final release = progress > 0.95 ? (1.0 - progress) / 0.05 : 1.0;
        pcm[i] = sin(2 * pi * freq * t) * 0.3 * attack * release;
      }
    }
    return _pcmToWav(pcm);
  }

  static Uint8List _pcmToWav(Float64List pcm) {
    final numSamples = pcm.length;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final buffer = ByteData(fileSize);

    void writeString(int offset, String s) { for (var i = 0; i < s.length; i++) buffer.setUint8(offset + i, s.codeUnitAt(i)); }
    writeString(0, 'RIFF');
    buffer.setUint32(4, fileSize - 8, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, _sampleRate, Endian.little);
    buffer.setUint32(28, _sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < numSamples; i++) {
      final sample = (pcm[i] * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}

