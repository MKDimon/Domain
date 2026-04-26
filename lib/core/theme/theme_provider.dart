import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme';

  @override
  ThemeMode build() {
    final prefs = ref.watch(preferencesProvider);
    final saved = prefs.getString(_key);
    return switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.dark,
    };
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    ref.read(preferencesProvider).setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(preferencesProvider).setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

final preferencesProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('Must be overridden with ProviderScope');
});
