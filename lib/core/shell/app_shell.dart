import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import 'shell_state.dart';
import '../../features/voice/state/call_session.dart';
import '../../features/voice/state/voice_session.dart';
import '../../features/voice/widgets/floating_call_widget.dart';
import '../../features/voice/widgets/voice_room_view.dart';
import '../../features/notifications/widgets/notifications_bell.dart';
import '../../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../utils/avatar_color.dart';
import '../utils/image_url.dart';
import '../../l10n/app_localizations.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  final String? communitySlug;
  final String? communityName;
  final Color? communityColor;

  const AppShell({
    super.key,
    required this.child,
    this.communitySlug,
    this.communityName,
    this.communityColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    if (auth.isRestoringSession) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.appName,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.accent)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kBackMouseButton) {
          final loc = NavHistory().goBack();
          if (loc != null) { isNavHistoryNav = true; GoRouter.of(context).go(loc); }
        } else if (event.buttons == kForwardMouseButton) {
          final loc = NavHistory().goForward();
          if (loc != null) { isNavHistoryNav = true; GoRouter.of(context).go(loc); }
        }
      },
      child: Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Background gradients — all adapt to community color
          _AnimatedGradientBg(
            color1: communityColor ?? c.accent,
            color2: communityColor ?? const Color(0xFF8B5CF6),
            color3: communityColor ?? const Color(0xFFD94066),
            isDark: isDark,
          ),
          Consumer(builder: (ctx, ref2, _) {
            final voiceFs = ref2.watch(voiceSessionProvider.select((vs) => vs.isFullscreen));
            return Column(
              children: [
                if (!voiceFs)
                  _AdaptiveHeader(
                    auth: auth, c: c, ref: ref,
                    communitySlug: communitySlug,
                    communityName: communityName,
                    communityColor: communityColor,
                  ),
                Expanded(child: child),
              ],
            );
          }),
          _VoiceFullscreenLayer(c: c, communityColor: communityColor),
          Consumer(builder: (ctx, ref, _) {
            final call = ref.watch(callSessionProvider);
            if (call.status == CallStatus.incoming) {
              return _IncomingCallOverlay(call: call, c: c, ref: ref);
            }
            if (call.status == CallStatus.outgoing || call.status == CallStatus.connecting) {
              return _OutgoingCallOverlay(call: call, c: c, ref: ref);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    ),
    );
  }
}

class _VoiceFullscreenLayer extends ConsumerStatefulWidget {
  final ColorSet c;
  final Color? communityColor;
  const _VoiceFullscreenLayer({required this.c, this.communityColor});

  @override
  ConsumerState<_VoiceFullscreenLayer> createState() => _VoiceFullscreenLayerState();
}

class _VoiceFullscreenLayerState extends ConsumerState<_VoiceFullscreenLayer> {
  bool _wasFs = false;

  @override
  Widget build(BuildContext context) {
    final isFs = ref.watch(voiceSessionProvider.select((vs) => vs.isFullscreen));
    final inCall = ref.watch(voiceSessionProvider.select((vs) => vs.inCall));
    final showFs = isFs && inCall;

    if (showFs && !_wasFs) {
      _wasFs = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await windowManager.setFullScreen(true);
      });
    } else if (!showFs && _wasFs) {
      _wasFs = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await windowManager.setFullScreen(false);
        await Future.delayed(const Duration(milliseconds: 200));
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      });
    }

    if (!showFs) return const SizedBox.shrink();
    final vs = ref.read(voiceSessionProvider);

    return Positioned.fill(
      child: Container(
        color: widget.c.bg,
        child: VoiceRoomView(
          key: ValueKey('shell_voice_fs_${vs.joinedPageId}'),
          pageId: vs.joinedPageId!,
          pageTitle: vs.joinedPageTitle ?? '',
          communitySlug: vs.joinedCommunitySlug ?? '',
          c: widget.c,
          commColor: widget.communityColor,
        ),
      ),
    );
  }
}

class _AdaptiveHeader extends StatefulWidget {
  final AuthState auth;
  final ColorSet c;
  final WidgetRef ref;
  final String? communitySlug;
  final String? communityName;
  final Color? communityColor;

  const _AdaptiveHeader({
    required this.auth, required this.c, required this.ref,
    this.communitySlug, this.communityName, this.communityColor,
  });

  @override
  State<_AdaptiveHeader> createState() => _AdaptiveHeaderState();
}

class _AdaptiveHeaderState extends State<_AdaptiveHeader> {
  bool _logoHovered = false;

  AuthState get auth => widget.auth;
  ColorSet get c => widget.c;
  WidgetRef get ref => widget.ref;
  String? get communitySlug => widget.communitySlug;
  String? get communityName => widget.communityName;
  Color? get communityColor => widget.communityColor;

  bool get _inCommunity => communitySlug != null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final accent = communityColor ?? c.accent;

    return GestureDetector(
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) { windowManager.unmaximize(); } else { windowManager.maximize(); }
      },
      child: DragToMoveArea(
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.only(left: isDesktop ? 20 : 16, right: isDesktop ? 0 : 16),
      child: Row(
        children: [
          // Nav arrows
          _NavArrow(icon: Icons.arrow_back_ios_new, onTap: NavHistory().canGoBack ? () {
            final loc = NavHistory().goBack();
            if (loc != null) { isNavHistoryNav = true; context.go(loc); }
          } : null, c: c),
          const SizedBox(width: 2),
          _NavArrow(icon: Icons.arrow_forward_ios, onTap: NavHistory().canGoForward ? () {
            final loc = NavHistory().goForward();
            if (loc != null) { isNavHistoryNav = true; context.go(loc); }
          } : null, c: c),
          const SizedBox(width: 12),
          // Logo
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _logoHovered = true),
            onExit: (_) => setState(() => _logoHovered = false),
            child: GestureDetector(
              onDoubleTap: () {},
              child: Listener(
                onPointerDown: (_) => context.goNamed('main'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: _logoHovered ? c.text : (_inCommunity ? accent : const Color(0xFF5B6CFF))),
                      duration: const Duration(milliseconds: 250),
                      builder: (ctx, color, _) => SvgPicture.asset('assets/logo.svg', width: 28, height: 28,
                        colorFilter: ColorFilter.mode(color ?? const Color(0xFF5B6CFF), BlendMode.srcIn)),
                    ),
                    const SizedBox(width: 3),
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: _logoHovered ? accent : c.text),
                      duration: const Duration(milliseconds: 250),
                      builder: (ctx, color, _) => Text('omain', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: color,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Community badge or nav link — crossfade
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _inCommunity
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onDoubleTap: () {},
                      child: Listener(
                        key: ValueKey('comm_$communitySlug'),
                        onPointerDown: (_) => context.goNamed('community', pathParameters: {'slug': communitySlug!}),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                          child: Text(communityName ?? communitySlug!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  )
                : MouseRegion(
                    key: const ValueKey('nav_explore'),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onDoubleTap: () {},
                      child: Listener(
                        onPointerDown: (_) => context.goNamed('explore'),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(l.navExplore, style: TextStyle(fontSize: 14.4, color: c.textSecondary)),
                        ),
                      ),
                    ),
                  ),
          ),

          // Search or spacer — animated
          if (_inCommunity && isDesktop) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Center(
                child: Container(
                  height: 36,
                  constraints: const BoxConstraints(maxWidth: 500),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    border: Border.all(color: c.inputBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, size: 16, color: c.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: TextStyle(fontSize: 14, color: c.text),
                        decoration: InputDecoration(
                          hintText: l.communitySearch,
                          hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
                          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8), isDense: true, filled: false,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ] else
            const Spacer(),

          const SizedBox(width: 10),

          // Right-side actions
          if (isDesktop) ...[
            _HeaderIcon(
              icon: ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              c: c, onTap: () => ref.read(themeProvider.notifier).toggle(),
            ),
            const SizedBox(width: 4),
          ],
          if (auth.isAuthenticated) ...[
            if (isDesktop) ...[
              _HeaderIcon(icon: Icons.chat_bubble_outline, c: c, onTap: () => context.goNamed('messages')),
              const SizedBox(width: 4),
              NotificationsBell(iconColor: c.textSecondary, hoverColor: c.text, badgeColor: c.error, highlightColor: c.accent.withValues(alpha: 0.08), onTap: () => context.goNamed('notifications')),
              const SizedBox(width: 8),
            ],
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onDoubleTap: () {},
                child: Listener(
                  onPointerDown: (_) => context.goNamed('profile'),
                  child: CircleAvatar(
                  radius: 16,
                  backgroundColor: avatarColor(auth.user!.id),
                  backgroundImage: auth.user!.avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(auth.user!.avatarUrl)) : null,
                  child: auth.user!.avatarUrl.isEmpty
                      ? Text(auth.user!.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))
                      : null,
                  ),
                ),
              ),
            ),
          ] else if (isDesktop) ...[
            const SizedBox(width: 10),
            _SmallButton(label: l.navLogin, onTap: () => context.goNamed('login'), c: c),
            const SizedBox(width: 8),
            _SmallButton(label: l.navRegister, onTap: () => context.goNamed('register'), c: c, filled: true),
          ],

          // Window controls separator + buttons
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: c.border),
          const SizedBox(width: 4),
          _WindowButton(icon: Icons.remove, onTap: () => windowManager.minimize(), c: c),
          _WindowButton(icon: Icons.crop_square, onTap: () async {
            if (await windowManager.isMaximized()) { windowManager.unmaximize(); } else { windowManager.maximize(); }
          }, c: c),
          _WindowButton(icon: Icons.close, onTap: () => windowManager.close(), c: c, isClose: true),
        ],
      ),
    ),
    ),
    );
  }
}

class _AnimatedGradientBg extends StatelessWidget {
  final Color color1;
  final Color color2;
  final Color color3;
  final bool isDark;
  const _AnimatedGradientBg({required this.color1, required this.color2, required this.color3, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color1),
            duration: const Duration(milliseconds: 400),
            builder: (ctx, c, _) => DecoratedBox(decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -1.2), radius: 1.0,
                colors: [(c ?? color1).withValues(alpha: isDark ? 0.18 : 0.22), Colors.transparent],
                stops: const [0.0, 0.6],
              ),
            )),
          )),
          Positioned.fill(child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color2),
            duration: const Duration(milliseconds: 400),
            builder: (ctx, c, _) => DecoratedBox(decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, -1.0), radius: 0.9,
                colors: [(c ?? color2).withValues(alpha: isDark ? 0.15 : 0.22), Colors.transparent],
                stops: const [0.0, 0.55],
              ),
            )),
          )),
          Positioned.fill(child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color3),
            duration: const Duration(milliseconds: 400),
            builder: (ctx, c, _) => DecoratedBox(decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 0.3), radius: 1.2,
                colors: [(c ?? color3).withValues(alpha: isDark ? 0.06 : 0.08), Colors.transparent],
                stops: const [0.0, 0.7],
              ),
            )),
          )),
        ],
      ),
    );
  }
}

class _NavArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ColorSet c;
  const _NavArrow({required this.icon, this.onTap, required this.c});
  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 28,
        decoration: BoxDecoration(
          color: _hovered && widget.onTap != null ? widget.c.accent.withValues(alpha: 0.08) : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(widget.icon, size: 14, color: widget.onTap != null ? widget.c.textSecondary : widget.c.textSecondary.withValues(alpha: 0.3)),
      ),
    ),
  );
}


class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorSet c;
  final bool isClose;
  const _WindowButton({required this.icon, required this.onTap, required this.c, this.isClose = false});
  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 46,
        decoration: BoxDecoration(
          color: _hovered ? (widget.isClose ? const Color(0xFFE81123) : widget.c.accent.withValues(alpha: 0.1)) : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(widget.icon, size: 16, color: _hovered && widget.isClose ? Colors.white : widget.c.textSecondary),
      ),
    ),
  );
}

class _HeaderIcon extends StatefulWidget {
  final IconData icon;
  final ColorSet c;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.c, required this.onTap});
  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onDoubleTap: () {},
      child: Listener(
        onPointerDown: (_) => widget.onTap(),
        child: Container(
          width: 32,
          decoration: BoxDecoration(
            color: _hovered ? widget.c.accent.withValues(alpha: 0.08) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 20, color: _hovered ? widget.c.text : widget.c.textSecondary),
        ),
      ),
    ),
  );
}

class _IncomingCallOverlay extends StatelessWidget {
  final CallState call;
  final ColorSet c;
  final WidgetRef ref;
  const _IncomingCallOverlay({required this.call, required this.c, required this.ref});

  @override
  Widget build(BuildContext context) {
    final peer = call.peer;
    return Positioned(
      top: 80, right: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: c.surface,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(call.withVideo ? Icons.videocam : Icons.call, size: 32, color: c.success),
            const SizedBox(height: 12),
            Text('Входящий ${call.withVideo ? "видео" : ""}звонок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 4),
            Text(peer?.name ?? '', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                onPressed: () => ref.read(callSessionProvider.notifier).rejectCall(),
                icon: const Icon(Icons.call_end, size: 18),
                label: const Text('Отклонить'),
                style: ElevatedButton.styleFrom(backgroundColor: c.error, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => ref.read(callSessionProvider.notifier).acceptCall(),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Принять'),
                style: ElevatedButton.styleFrom(backgroundColor: c.success, foregroundColor: Colors.white),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _OutgoingCallOverlay extends StatelessWidget {
  final CallState call;
  final ColorSet c;
  final WidgetRef ref;
  const _OutgoingCallOverlay({required this.call, required this.c, required this.ref});

  static String _errorText(String code) {
    switch (code) {
      case 'TARGET_OFFLINE': return 'Не в сети';
      case 'CALL_BUSY_TARGET': return 'Абонент занят';
      case 'CALL_BUSY_SELF': return 'У вас уже есть звонок';
      case 'timeout': return 'Не отвечает';
      case 'rejected': return 'Вызов отклонён';
      default: return 'Вызов завершён';
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = call.peer;
    final hasError = call.errorCode != null;
    final statusText = hasError
        ? _errorText(call.errorCode!)
        : (call.status == CallStatus.connecting ? 'Подключение...' : 'Вызов...');
    return Positioned(
      top: 80, right: 24,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: c.surface,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!hasError)
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
            else
              Icon(Icons.call_end, size: 28, color: c.error),
            const SizedBox(height: 12),
            Text(statusText, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: hasError ? c.error : c.text)),
            const SizedBox(height: 4),
            Text(peer?.name ?? '', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            if (!hasError) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref.read(callSessionProvider.notifier).endCall(),
                icon: Icon(Icons.call_end, size: 18, color: c.error),
                label: Text('Отмена', style: TextStyle(color: c.error)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final ColorSet c;
  final bool filled;
  const _SmallButton({required this.label, required this.onTap, required this.c, this.filled = false});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      backgroundColor: filled ? c.accent : null,
      side: filled ? null : BorderSide(color: c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: filled ? Colors.white : c.text)),
  );
}
