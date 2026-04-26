import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../tray/tray_service.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String changelog;
  final bool required;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.required,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        version: json['version'] as String,
        downloadUrl: json['download_url'] as String,
        changelog: json['changelog'] as String? ?? '',
        required: json['required'] as bool? ?? false,
      );
}

enum UpdatePhase { checking, downloading, installing, idle }

class UpdateState {
  final UpdatePhase phase;
  final double progress;
  final String? version;

  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.progress = 0,
    this.version,
  });

  UpdateState copyWith({UpdatePhase? phase, double? progress, String? version}) =>
      UpdateState(
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        version: version ?? this.version,
      );
}

class UpdateNotifier extends Notifier<UpdateState> {
  static const _backgroundInterval = Duration(hours: 6);
  Timer? _timer;

  @override
  UpdateState build() {
    ref.onDispose(() => _timer?.cancel());
    return const UpdateState();
  }

  static String get _appDir => File(Platform.resolvedExecutable).parent.path;
  static String get _stagingDir => '$_appDir${Platform.pathSeparator}update_staging';

  bool get hasPendingUpdate => Directory(_stagingDir).existsSync();

  /// Called once at startup. Returns true if update will be applied (app will restart).
  Future<bool> checkAndApply() async {
    if (hasPendingUpdate) {
      state = state.copyWith(phase: UpdatePhase.installing);
      await _applyAndRestart();
      return true;
    }

    state = state.copyWith(phase: UpdatePhase.checking);

    final info = await _fetchUpdateInfo();
    if (info == null) {
      state = state.copyWith(phase: UpdatePhase.idle);
      _startBackgroundTimer();
      return false;
    }

    state = state.copyWith(phase: UpdatePhase.downloading, version: info.version);
    final ok = await _download(info.downloadUrl);
    if (!ok) {
      state = state.copyWith(phase: UpdatePhase.idle);
      _startBackgroundTimer();
      return false;
    }

    state = state.copyWith(phase: UpdatePhase.installing);
    await _applyAndRestart();
    return true;
  }

  void _startBackgroundTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_backgroundInterval, (_) => _backgroundCheck());
  }

  Future<void> _backgroundCheck() async {
    final info = await _fetchUpdateInfo();
    if (info == null) return;
    await _download(info.downloadUrl);
  }

  Future<UpdateInfo?> _fetchUpdateInfo() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(
        '${AppConfig.apiBase}/app/update',
        queryParameters: {
          'platform': Platform.operatingSystem,
          'version': AppConfig.appVersion,
        },
      );
      final data = response.data;
      final body = data is Map<String, dynamic> ? data : <String, dynamic>{};
      final payload = body['data'] as Map<String, dynamic>?;
      if (payload != null && payload['update_available'] == true) {
        return UpdateInfo.fromJson(payload);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _download(String url) async {
    try {
      final zipPath = '${Directory.systemTemp.path}${Platform.pathSeparator}domain_app_update.zip';

      await Dio().download(url, zipPath, onReceiveProgress: (received, total) {
        if (total > 0) {
          state = state.copyWith(progress: received / total);
        }
      });

      final staging = Directory(_stagingDir);
      if (staging.existsSync()) staging.deleteSync(recursive: true);

      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Expand-Archive',
        '-Path',
        zipPath,
        '-DestinationPath',
        _stagingDir,
        '-Force',
      ]);

      File(zipPath).deleteSync();
      return staging.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyAndRestart() async {
    final currentPid = pid;
    final appDir = _appDir;
    final sep = Platform.pathSeparator;
    final batPath = '$appDir${sep}update.bat';

    final script = '''
@echo off
:wait
tasklist /FI "PID eq $currentPid" 2>NUL | find /I "$currentPid" >NUL
if not errorlevel 1 (
    timeout /t 1 /nobreak > nul
    goto wait
)
xcopy /s /y /q "$_stagingDir${sep}*" "$appDir${sep}"
rmdir /s /q "$_stagingDir"
start "" "$appDir${sep}domain_app.exe"
del "%~f0"
''';

    await File(batPath).writeAsString(script);
    await Process.start('cmd', ['/c', batPath], mode: ProcessStartMode.detached);
    await TrayService().exitApp();
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
