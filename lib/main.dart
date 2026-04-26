import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/desktop/desktop_service.dart';
import 'core/storage/preferences.dart';
import 'core/theme/theme_provider.dart';
import 'core/tray/tray_service.dart';
import 'features/voice/utils/voice_sfx.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setMinimumSize(const Size(800, 500));

  final prefs = PreferencesService();
  await prefs.init();
  VoiceSfx().init();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await TrayService().init();
    await DesktopService.init(prefs);
  }

  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
      ],
      child: const DomainApp(),
    ),
  );
}
