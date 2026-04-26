import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;
  TrayService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final dir = File(Platform.resolvedExecutable).parent.path;
    final iconPath = [dir, 'app_icon.ico'].join(Platform.pathSeparator);

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Domain');

    final menu = Menu(items: [
      MenuItem(key: 'show', label: 'Открыть Domain'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Выйти'),
    ]);
    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);

    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'exit':
        exitApp();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> exitApp() async {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
