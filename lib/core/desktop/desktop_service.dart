import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import '../storage/preferences.dart';

class DesktopService {
  static const _autoStartKey = 'desktop_autostart';

  static Future<void> init(PreferencesService prefs) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;

    await _setupAutoStart(prefs);
    await _setupGlobalHotkey();
  }

  static Future<void> _setupAutoStart(PreferencesService prefs) async {
    launchAtStartup.setup(
      appName: 'Domain',
      appPath: Platform.resolvedExecutable,
    );

    final enabled = prefs.getBool(_autoStartKey);
    if (enabled == null) {
      await launchAtStartup.enable();
      await prefs.setBool(_autoStartKey, true);
    }
  }

  static Future<void> _setupGlobalHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyD,
      modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(hotKey, keyDownHandler: (_) async {
      if (await windowManager.isVisible()) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  static Future<bool> isAutoStartEnabled() async {
    return launchAtStartup.isEnabled();
  }

  static Future<void> setAutoStart(bool enabled, PreferencesService prefs) async {
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    await prefs.setBool(_autoStartKey, enabled);
  }
}
