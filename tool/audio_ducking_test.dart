/// Minimal test: captures microphone via flutter_webrtc's getUserMedia
/// and holds it open. Run this, then check if other app sounds get quieter.
///
/// Usage: flutter run -t tool/audio_ducking_test.dart -d windows

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() => runApp(const DuckingTestApp());

class DuckingTestApp extends StatelessWidget {
  const DuckingTestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(),
    home: const DuckingTestPage(),
  );
}

class DuckingTestPage extends StatefulWidget {
  const DuckingTestPage({super.key});
  @override
  State<DuckingTestPage> createState() => _DuckingTestPageState();
}

class _DuckingTestPageState extends State<DuckingTestPage> {
  MediaStream? _stream;
  String _status = 'Idle';
  String _log = '';

  void _addLog(String msg) {
    setState(() => _log += '$msg\n');
    // ignore: avoid_print
    print(msg);
  }

  Future<void> _captureDefault() async {
    await _release();
    _addLog('--- Capturing with DEFAULT constraints ---');
    try {
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      _addLog('OK: tracks=${_stream!.getAudioTracks().length}');
      setState(() => _status = 'CAPTURED (default)');
    } catch (e) {
      _addLog('ERROR: $e');
    }
  }

  Future<void> _captureNoProcessing() async {
    await _release();
    _addLog('--- Capturing with ALL PROCESSING OFF ---');
    try {
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': false,
          'noiseSuppression': false,
          'autoGainControl': false,
        },
        'video': false,
      });
      _addLog('OK: tracks=${_stream!.getAudioTracks().length}');
      setState(() => _status = 'CAPTURED (no processing)');
    } catch (e) {
      _addLog('ERROR: $e');
    }
  }

  Future<void> _captureWebStyle() async {
    await _release();
    _addLog('--- Capturing WEB-STYLE (echo=true, ns=false, agc=false) ---');
    try {
      _stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': false,
          'autoGainControl': false,
        },
        'video': false,
      });
      _addLog('OK: tracks=${_stream!.getAudioTracks().length}');
      setState(() => _status = 'CAPTURED (web-style)');
    } catch (e) {
      _addLog('ERROR: $e');
    }
  }

  Future<void> _release() async {
    if (_stream != null) {
      for (final t in _stream!.getTracks()) {
        try { await t.stop(); } catch (_) {}
      }
      try { await _stream!.dispose(); } catch (_) {}
      _stream = null;
      _addLog('Released mic');
      setState(() => _status = 'Released');
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Ducking Test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Нажми кнопку, потом проверь громкость других приложений.\n'
                'Если звук в других приложениях стал тише — это ducking.\n'
                'Попробуй все 3 варианта и сравни.'),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: _captureDefault, child: const Text('1. Default')),
              ElevatedButton(onPressed: _captureNoProcessing, child: const Text('2. No processing')),
              ElevatedButton(onPressed: _captureWebStyle, child: const Text('3. Web-style')),
              OutlinedButton(onPressed: _release, child: const Text('Release')),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_log, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.green)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
