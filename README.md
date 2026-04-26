# Domain

Open-source client for the **Domain** community platform.  
Build and manage communities with a page constructor, real-time chat, voice calls, and more.

**[Website](https://do-main.ru)** · **[Report Issue](https://github.com/MKDimon/Domain/issues)**

## About

Domain is a cross-platform application for creating and managing online communities. Each community gets a customizable space with pages, sections, chat rooms, and voice channels — all in one place.

### Key Features

- **Page Builder** — drag-and-drop constructor with plugin-based sections: wiki, content blocks, products catalog, polls, quizzes, booking, calendar, announcements, and Lua scripting
- **Real-time Chat** — WebSocket-powered messaging with conversations, threads, typing indicators, read status, and message search
- **Voice & Video Calls** — WebRTC peer-to-peer calls in voice rooms and 1:1 DMs, with noise suppression
- **Direct Messages** — private conversations with friend requests and online presence
- **Community Management** — roles (owner, moderator, member), invites, member lists, action logs
- **Moderation** — warnings, mutes, bans, appeals, complaint system
- **Subscriptions** — tiered plans with payment integration
- **Desktop Integration** — system tray, global hotkey (Ctrl+Shift+D), auto-start, auto-updates

### Supported Platforms

| Platform | Status |
|----------|--------|
| Windows  | Stable |
| macOS    | Stable |
| Linux    | Stable |
| Android  | Beta   |
| iOS      | Beta   |

## Screenshots

*Coming soon*

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Routing**: GoRouter with shell architecture
- **Networking**: Dio (HTTP), WebSocket, WebRTC (flutter_webrtc)
- **Desktop**: window_manager, tray_manager, launch_at_startup, hotkey_manager
- **Storage**: flutter_secure_storage, shared_preferences
- **Scripting**: lua_dardo (Lua sandbox for user scripts)

## Architecture

```
lib/
├── core/                   — Foundation layer
│   ├── api/                  API client (Dio), error handling
│   ├── auth/                 OAuth (VK, Yandex, Google)
│   ├── config/               App configuration
│   ├── desktop/              Tray, hotkeys, auto-start
│   ├── router/               GoRouter setup
│   ├── theme/                Dark/light theme, colors
│   ├── update/               Auto-update (Discord-style)
│   └── websocket/            WebSocket manager
├── data/
│   ├── api/                  23 API modules
│   └── models/               Data models
├── features/               — Feature modules
│   ├── auth/                 Login, register, OAuth, email verification
│   ├── main/                 Home feed, explore communities
│   ├── community/            Community pages, settings, navigation
│   ├── editor/               Page editor, section editors, block editors
│   ├── content/              Section renderers (wiki, chat, products, etc.)
│   ├── chat/                 Real-time messaging, composer, bubbles
│   ├── messages/             Direct messages
│   ├── voice/                Voice rooms, 1:1 calls, audio settings
│   ├── profile/              User profile, friends, security, violations
│   ├── notifications/        Bell widget, notification list
│   ├── moderation/           Moderation panel
│   ├── admin/                Platform admin dashboard
│   ├── billing/              Pricing, billing, upgrade modals
│   ├── feedback/             User feedback and reports
│   ├── legal/                Terms, privacy policy
│   └── script/               Lua sandbox, webapp consent
├── providers/              — Global Riverpod providers
└── l10n/                   — Localization (Russian, English)
```

## Building

### Prerequisites

- Flutter SDK 3.11+
- Platform-specific toolchain (Visual Studio for Windows, Xcode for macOS/iOS)

### Development

```bash
flutter pub get
flutter run -d windows    # or macos, linux, chrome
```

### Release Build

```bash
flutter build windows --release
flutter build apk --release
flutter build macos --release
```

Build output: `build/windows/x64/runner/Release/`

### Note on Private Dependencies

The open-source release excludes the proprietary `domain_audio` plugin (audio processing with PCM gain control, noise gate, and voice activity detection). The app builds and runs without it — voice calls work via standard WebRTC, but without the custom audio pipeline.

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## Code Signing

This project uses [SignPath Foundation](https://signpath.org) for code signing.

## License

Licensed under the [Apache License 2.0](LICENSE).

```
Copyright 2025 Domain

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```
