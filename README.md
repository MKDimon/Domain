# Domain — Desktop App (Flutter)

Десктопный клиент платформы Domain. Windows / macOS / Linux.

## Сборка

```bash
cd app
flutter pub get
flutter build windows          # Release
flutter run -d windows         # Debug
```

Версия передаётся через `--dart-define`:

```bash
flutter build windows --dart-define=APP_VERSION=1.2.0
```

## Десктопные фичи

### Single Instance

Одновременно может работать только одна копия приложения. Реализовано через Named Mutex на уровне Windows runner (`windows/runner/main.cpp`). Если копия уже запущена — вторая активирует окно первой и тихо завершается.

### Системный трей

При нажатии "X" окно сворачивается в трей (не закрывается). Контекстное меню трея:
- **Открыть Domain** — показать окно
- **Выйти** — полностью закрыть приложение

Иконка трея: `windows/runner/resources/app_icon.ico` (копируется рядом с exe при сборке через CMake).

### Автообновления (модель Discord)

При запуске приложение проверяет наличие обновлений через `GET /api/v1/app/update`. Если обновление есть — автоматически скачивает, устанавливает и перезапускается. Пользователь видит только короткий splash-экран.

Фоновая проверка каждые 6 часов — если обновление найдено, оно скачивается тихо и применяется при следующем запуске.

### Автозапуск

Приложение добавляется в автозагрузку системы при первом запуске. Управляется через `DesktopService.setAutoStart(bool, prefs)`.

### Глобальная горячая клавиша

**Ctrl+Shift+D** — показать/скрыть окно из любого места в системе.

## Публикация обновления

### 1. Собрать новую версию

```bash
cd app
flutter build windows --dart-define=APP_VERSION=1.2.0
```

Готовые файлы: `build/windows/x64/runner/Release/`

### 2. Упаковать в zip

Заархивировать всё содержимое папки `Release/` в zip. Структура внутри архива — плоская (exe и dll в корне, без вложенной папки):

```
domain_app.exe
flutter_windows.dll
app_icon.ico
data/
  ...
```

### 3. Загрузить zip на сервер

Разместить архив по стабильному URL, например:

```
https://do-main.ru/releases/domain_app_1.2.0.zip
```

### 4. Обновить конфиг бэкенда

В `config.json` сервера (или через env-переменные):

**config.json:**
```json
{
  "app_update": {
    "latest_version": "1.2.0",
    "download_url": "https://do-main.ru/releases/domain_app_1.2.0.zip",
    "changelog": "Новые фичи, исправления багов",
    "required": false
  }
}
```

**Или env-переменные (docker-compose):**
```yaml
environment:
  DOMAIN_APP_UPDATE_VERSION: "1.2.0"
  DOMAIN_APP_UPDATE_URL: "https://do-main.ru/releases/domain_app_1.2.0.zip"
  DOMAIN_APP_UPDATE_CHANGELOG: "Новые фичи, исправления багов"
  DOMAIN_APP_UPDATE_REQUIRED: "false"
```

### 5. Перезапустить бэкенд

```bash
docker-compose up -d --no-build server
```

После этого все клиенты автоматически обнаружат обновление при следующей проверке (при запуске или в фоне каждые 6 часов).

### Параметр `required`

- `false` — обычное обновление, применяется автоматически
- `true` — критическое обновление, блокирует работу до установки

## Архитектура

```
lib/
  core/
    config/       — AppConfig (apiBase, wsBase, appVersion)
    desktop/      — DesktopService (автозапуск, горячие клавиши)
    tray/         — TrayService (иконка, меню, close-to-tray)
    update/       — UpdateGate (splash), UpdateProvider (auto-update)
    shell/        — AppShell (хедер, навигация, window controls)
  features/       — 14 фич (auth, chat, community, voice, ...)

windows/
  runner/
    main.cpp      — Single instance (Named Mutex)
    resources/
      app_icon.ico — Иконка приложения и трея
  CMakeLists.txt  — Копирование иконки в build output
```
