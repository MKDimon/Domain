import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../l10n/app_localizations.dart';
import '../state/call_session.dart';
import '../state/voice_session.dart';
import '../state/voice_settings.dart';
import 'audio_settings_modal.dart';
import 'screen_source_picker.dart';

/// Full voice room view — Discord-style with gradient backdrop, glass header/footer,
/// grid tiles with speaking glow, and round control buttons.
class VoiceRoomView extends ConsumerStatefulWidget {
  final int pageId;
  final String pageTitle;
  final String communitySlug;
  final ColorSet c;
  final Color? commColor;
  final bool embedded;

  const VoiceRoomView({
    super.key,
    required this.pageId,
    required this.pageTitle,
    required this.communitySlug,
    required this.c,
    this.commColor,
    this.embedded = false,
  });

  @override
  ConsumerState<VoiceRoomView> createState() => _VoiceRoomViewState();
}

class _Tile {
  final String id;
  final int userId;
  final String kind; // 'main' | 'screen'
  final VoiceMember member;
  const _Tile({required this.id, required this.userId, required this.kind, required this.member});
}

class _VoiceRoomViewState extends ConsumerState<VoiceRoomView> {
  /// Focused tile ID: 'u{userId}' for main, 's{userId}' for screen. null = grid mode.
  String? _focusedTileId;
  bool _stripVisible = true;
  bool _chromeVisible = true;
  Timer? _chromeTimer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceSessionProvider.notifier).subscribePages([widget.pageId]);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _chromeTimer?.cancel();
    if (!widget.embedded && ref.read(voiceSessionProvider).isFullscreen) {
      ref.read(voiceSessionProvider.notifier).setFullscreen(false);
      windowManager.setFullScreen(false);
    }
    super.dispose();
  }

  void _onMouseMove() {
    if (!ref.read(voiceSessionProvider).isFullscreen) return;
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && ref.read(voiceSessionProvider).isFullscreen) setState(() => _chromeVisible = false);
    });
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && ref.read(voiceSessionProvider).isFullscreen) {
      _toggleFullscreen();
      return true;
    }
    return false;
  }

  // Avatar color palette (matches web PALETTE)
  bool get _isFs => !widget.embedded && ref.read(voiceSessionProvider).isFullscreen;

  static const _palette = [0xFFd94066, 0xFF4d9966, 0xFF804d99, 0xFF997333, 0xFF338c8c, 0xFFb36626, 0xFF336699];
  Color _avatarColor(int userId) => Color(_palette[userId % _palette.length]);

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final accent = widget.commColor ?? c.accent;
    final vs = ref.watch(voiceSessionProvider);
    final notifier = ref.read(voiceSessionProvider.notifier);
    final l = AppLocalizations.of(context)!;
    final isJoinedHere = vs.joinedPageId == widget.pageId;
    final members = vs.membersOn(widget.pageId);

    final body = _buildBody(c, accent, vs, notifier, l, isJoinedHere, members);
    if (_isFs) {
      return MouseRegion(
        onHover: (_) => _onMouseMove(),
        child: body,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: body,
    );
  }

  void _toggleFullscreen() {
    final goFull = !ref.read(voiceSessionProvider).isFullscreen;
    _chromeTimer?.cancel();
    ref.read(voiceSessionProvider.notifier).setFullscreen(goFull);
    windowManager.setFullScreen(goFull);
    if (!mounted) return;
    setState(() => _chromeVisible = true);
    if (goFull) {
      _chromeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && ref.read(voiceSessionProvider).isFullscreen) {
          setState(() => _chromeVisible = false);
        }
      });
    }
  }

  Widget _buildBody(ColorSet c, Color accent, VoiceSessionState vs, VoiceSessionNotifier notifier, AppLocalizations l, bool isJoinedHere, List<VoiceMember> members) {

    return Stack(
      children: [
        // ─── Background gradient (community-colored radial like web ::before) ───
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.8),
                radius: 1.2,
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.08),
                  accent.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // ─── Content ───
        if (_isFs) ...[
          // Roster fills everything
          Positioned.fill(
            child: members.isEmpty
                ? _emptyState(c)
                : _focusedTileId != null
                    ? _buildFocusMode(members, vs, c, accent)
                    : _buildGridMode(members, vs, c, accent),
          ),
          // Header — slides down from top
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: 0, right: 0,
            top: _chromeVisible ? 0 : -80,
            child: _buildCallBar(c, accent, members, isJoinedHere),
          ),
          // Footer — slides up from bottom
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: 0, right: 0,
            bottom: _chromeVisible ? 0 : -80,
            child: _buildFooter(c, accent, isJoinedHere, vs, notifier, l),
          ),
        ] else ...[
          Column(
            children: [
              _buildCallBar(c, accent, members, isJoinedHere),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: members.isEmpty
                      ? _emptyState(c)
                      : _focusedTileId != null
                          ? _buildFocusMode(members, vs, c, accent)
                          : _buildGridMode(members, vs, c, accent),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildFooter(c, accent, isJoinedHere, vs, notifier, l),
          ),
        ],

        // ── Error toast ──
        if (vs.error != null)
          Positioned(
            top: 60, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.92),
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16)],
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, size: 16, color: c.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(vs.error!, style: TextStyle(fontSize: 12, color: c.error))),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Tile model (Discord-style: main + screen tiles) ───────────────────

  /// Each user gets a 'main' tile (avatar/camera). If sharing screen, they
  /// also get a separate 'screen' tile — exactly like web/Discord.
  List<_Tile> _buildTiles(List<VoiceMember> members) {
    final tiles = <_Tile>[];
    for (final m in _sortedMembers(members)) {
      tiles.add(_Tile(id: 'u${m.userId}', userId: m.userId, kind: 'main', member: m));
      if (m.isScreenSharing) {
        tiles.add(_Tile(id: 's${m.userId}', userId: m.userId, kind: 'screen', member: m));
      }
    }
    return tiles;
  }

  void _clickTileById(String id) {
    setState(() {
      _focusedTileId = (_focusedTileId == id) ? null : id;
    });
  }

  VoiceMember? _focusedMember(List<VoiceMember> members) {
    if (_focusedTileId == null) return null;
    final uid = int.tryParse(_focusedTileId!.substring(1));
    if (uid == null) return null;
    return members.cast<VoiceMember?>().firstWhere((m) => m!.userId == uid, orElse: () => null);
  }

  // ─── Grid mode (no focus — all tiles uniform) ────────────────────────

  /// Sort: screen-sharers first, then video, then by userId (stable).
  List<VoiceMember> _sortedMembers(List<VoiceMember> members) {
    final sorted = List<VoiceMember>.from(members);
    sorted.sort((a, b) {
      if (a.isScreenSharing != b.isScreenSharing) return a.isScreenSharing ? -1 : 1;
      if (a.isVideo != b.isVideo) return a.isVideo ? -1 : 1;
      return a.userId.compareTo(b.userId);
    });
    return sorted;
  }

  /// Adaptive tile size: fewer users → bigger tiles, more → smaller.
  double _tileWidth(int count, double stageWidth) {
    if (count <= 1) return (stageWidth - 40).clamp(200, 400);
    if (count <= 2) return (stageWidth / 2 - 30).clamp(180, 350);
    if (count <= 4) return (stageWidth / 2 - 30).clamp(160, 300);
    if (count <= 6) return (stageWidth / 3 - 30).clamp(140, 250);
    return (stageWidth / 4 - 30).clamp(120, 220);
  }

  Widget _buildGridMode(List<VoiceMember> members, VoiceSessionState vs, ColorSet c, Color accent) {
    final tiles = _buildTiles(members);
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final tileW = _tileWidth(tiles.length, w);
      final rawTileH = tileW * 10 / 16;
      final cols = (w / (tileW + 12)).floor().clamp(1, tiles.length);
      final rows = (tiles.length / cols).ceil();
      final maxH = rows > 0 ? (h - (rows - 1) * 12 - 20) / rows : rawTileH;
      final tileH = rawTileH > maxH && maxH > 60 ? maxH : rawTileH;
      final content = Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: tiles.map((t) => SizedBox(
          width: tileW,
          height: tileH,
          child: _tileWidget(t, vs, c, accent),
        )).toList(),
      );
      final contentH = rows * tileH + (rows - 1) * 12;
      if (contentH < h) {
        return Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: content,
        ));
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
        child: Center(child: content),
      );
    });
  }

  // ─── Focus mode (main-stage + horizontal strip) ──────────────────────

  Widget _buildFocusMode(List<VoiceMember> members, VoiceSessionState vs, ColorSet c, Color accent) {
    final focused = _focusedMember(members);
    if (focused == null) {
      // Focused user left — fall back to grid
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _focusedTileId = null));
      return _buildGridMode(members, vs, c, accent);
    }

    final isSpeaking = vs.speakingUserIds.contains(focused.userId);
    final name = focused.displayName?.isNotEmpty == true ? focused.displayName! : focused.username;
    final avatarBg = _avatarColor(focused.userId);

    return Column(
      children: [
        // ── Main stage (large tile) ──
        Expanded(
          child: GestureDetector(
            onTap: () => _clickTileById(_focusedTileId!),
            child: Container(
              margin: _isFs ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: BoxDecoration(
                color: Color.lerp(avatarBg, const Color(0xFF12131a), 0.68),
                borderRadius: _isFs ? BorderRadius.zero : BorderRadius.circular(12),
                border: isSpeaking && !_isFs
                    ? Border.all(color: c.success, width: 2)
                    : null,
                boxShadow: isSpeaking && !_isFs
                    ? [BoxShadow(color: c.success.withValues(alpha: 0.3), blurRadius: 20)]
                    : null,
              ),
              child: Stack(
                children: [
                  // Avatar or video
                  Center(
                    child: Builder(builder: (_) {
                      final isMe = focused.userId == ref.read(voiceSessionProvider.notifier).myUserId;
                      final isScreenTile = _focusedTileId?.startsWith('s') == true;
                      final hasVideo = isScreenTile ? focused.isScreenSharing : focused.isVideo;
                      if (hasVideo || isScreenTile) {
                        final notifier = ref.read(voiceSessionProvider.notifier);
                        if (isMe) {
                          final selfRenderer = notifier.getSelfRenderer();
                          if (selfRenderer != null) {
                            final r = _isFs ? BorderRadius.zero : BorderRadius.circular(12);
                            return ClipRRect(
                              borderRadius: r,
                              child: RTCVideoView(selfRenderer,
                                objectFit: isScreenTile
                                    ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                                    : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                mirror: !isScreenTile && focused.isVideo,
                              ),
                            );
                          }
                        } else {
                          final rendererKey = isScreenTile ? -focused.userId : focused.userId;
                          var renderer = notifier.getRemoteRenderer(rendererKey);
                          if (renderer == null) {
                            notifier.ensureRemoteRenderer(rendererKey, preferScreen: isScreenTile).then((r) {
                              if (r != null) notifier.notifyUi();
                            });
                          }
                          if (renderer != null) {
                            final rad = _isFs ? BorderRadius.zero : BorderRadius.circular(12);
                            return ClipRRect(
                              borderRadius: rad,
                              child: RTCVideoView(renderer,
                                objectFit: isScreenTile
                                    ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                                    : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                mirror: !isScreenTile && focused.isVideo,
                              ),
                            );
                          }
                        }
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 140, height: 140,
                            decoration: BoxDecoration(
                              color: avatarBg,
                              shape: BoxShape.circle,
                              image: focused.avatarUrl?.isNotEmpty == true
                                  ? DecorationImage(image: NetworkImage(fullImageUrl(focused.avatarUrl!)), fit: BoxFit.cover)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: focused.avatarUrl?.isNotEmpty != true
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: Colors.white))
                                : null,
                          ),
                        ],
                      );
                    }),
                  ),
                  // Bottom overlay — inline, wraps content (like web .main-overlay)
                  Positioned(
                    left: 14, bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (focused.isMuted) ...[
                            Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
                              child: const Icon(Icons.mic_off, size: 10, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (focused.isScreenSharing) ...[
                            Icon(Icons.screen_share, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                          ],
                          if (focused.isVideo) ...[
                            Icon(Icons.videocam, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                          ],
                          Text(name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Toggle strip chevron + tiles (hidden in fullscreen) ──
        if (!_isFs) GestureDetector(
          onTap: () => setState(() => _stripVisible = !_stripVisible),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Icon(
              _stripVisible ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 20, color: c.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ),
        if (!_isFs && _stripVisible) SizedBox(
          height: 98,
          child: LayoutBuilder(builder: (ctx, box) {
            final allTiles = _buildTiles(members);
            const tileW = 150.0;
            const gap = 10.0;
            final totalW = allTiles.length * tileW + (allTiles.length - 1) * gap + 40;
            final centered = totalW <= box.maxWidth;
            final row = Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: allTiles.asMap().entries.map((e) {
                final t = e.value;
                final isFocused = t.id == _focusedTileId;
                return Padding(
                  padding: EdgeInsets.only(left: e.key > 0 ? gap : 0),
                  child: SizedBox(
                    width: tileW,
                    child: _tileWidget(t, vs, c, accent, compact: true, highlighted: isFocused),
                  ),
                );
              }).toList(),
            );
            if (centered) {
              return Center(child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: row,
              ));
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: row,
            );
          }),
        ),
      ],
    );
  }

  // ─── Call bar (top, glass effect) ──────────────────────────────────────

  Widget _buildCallBar(ColorSet c, Color accent, List<VoiceMember> members, bool joined) {
    if (_isFs) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: _callBarContent(c, accent, members, joined),
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.surfaceAlt.withValues(alpha: 0.65),
                c.surfaceAlt.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: _callBarContent(c, accent, members, joined),
        ),
      ),
    );
  }

  Widget _callBarContent(ColorSet c, Color accent, List<VoiceMember> members, bool joined) {
    return Row(
            children: [
              Icon(Icons.volume_up_outlined, size: 18, color: accent),
              const SizedBox(width: 10),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(widget.pageTitle,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (joined) ...[
                          const SizedBox(width: 8),
                          _liveDot(c),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (members.isNotEmpty) Text(
                          AppLocalizations.of(context)!.voiceParticipants(members.length),
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                        if (ref.watch(voiceSettingsProvider).isPtt) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('PTT: ${ref.watch(voiceSettingsProvider).pttKey}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.warning, fontFamily: 'monospace')),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Quality indicator
              if (joined) _qualityBars(c),
              const SizedBox(width: 8),
              // Mini avatar cluster
              _avatarCluster(members, c),
              const SizedBox(width: 8),
              // Settings gear — always visible (like web)
              InkWell(
                onTap: () => showDialog(context: context, builder: (_) => AudioSettingsModal(c: c)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings_outlined, size: 16, color: c.textSecondary),
                ),
              ),
            ],
    );
  }

  Widget _liveDot(ColorSet c) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: c.success,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.success.withValues(alpha: 0.5), blurRadius: 6)],
      ),
    );
  }

  Widget _qualityBars(ColorSet c) {
    // Aggregate worst quality across all peers.
    final notifier = ref.read(voiceSessionProvider.notifier);
    String overallQuality = 'good';
    for (final q in notifier.peerQuality.values) {
      if (q.quality == 'bad') { overallQuality = 'bad'; break; }
      if (q.quality == 'ok') overallQuality = 'ok';
    }
    final color = overallQuality == 'bad' ? c.error
        : overallQuality == 'ok' ? const Color(0xFFe8b33a) : c.success;
    final dim3 = overallQuality == 'ok' || overallQuality == 'bad' ? 0.3 : 1.0;
    final dim2 = overallQuality == 'bad' ? 0.3 : 1.0;

    return Tooltip(
      message: overallQuality == 'good' ? AppLocalizations.of(context)!.voiceConnectionGood
          : overallQuality == 'ok' ? AppLocalizations.of(context)!.voiceConnectionOk
          : AppLocalizations.of(context)!.voiceConnectionBad,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.surfaceAlt.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 3, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 2),
            Opacity(opacity: dim2, child: Container(width: 3, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)))),
            const SizedBox(width: 2),
            Opacity(opacity: dim3, child: Container(width: 3, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)))),
          ],
        ),
      ),
    );
  }

  Widget _avatarCluster(List<VoiceMember> members, ColorSet c) {
    final show = members.take(4).toList();
    final extra = members.length - show.length;
    final totalCount = show.length + (extra > 0 ? 1 : 0);
    const size = 22.0;
    const overlap = 6.0;
    final totalWidth = totalCount > 0 ? size + (totalCount - 1) * (size - overlap) : 0.0;

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < show.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: _avatarColor(show[i].userId),
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surfaceAlt, width: 2),
                  image: show[i].avatarUrl?.isNotEmpty == true
                      ? DecorationImage(image: NetworkImage(fullImageUrl(show[i].avatarUrl!)), fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: show[i].avatarUrl?.isNotEmpty != true
                    ? Text(show[i].username.isNotEmpty ? show[i].username[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))
                    : null,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: show.length * (size - overlap),
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.surfaceAlt, width: 2),
                ),
                alignment: Alignment.center,
                child: Text('+$extra', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: c.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Roster tile ──────────────────────────────────────────────────────

  /// Wrapper that dispatches to the right tile type.
  Widget _tileWidget(_Tile t, VoiceSessionState s, ColorSet c, Color accent, {bool compact = false, bool highlighted = false}) {
    return _tile(t.member, s, c, accent,
      compact: compact, highlighted: highlighted,
      tileKind: t.kind, tileId: t.id);
  }

  Widget _tile(VoiceMember m, VoiceSessionState s, ColorSet c, Color accent, {bool compact = false, bool highlighted = false, String tileKind = 'main', String? tileId}) {
    final isSpeaking = s.speakingUserIds.contains(m.userId);
    final name = m.displayName?.isNotEmpty == true ? m.displayName! : m.username;
    final avatarBg = _avatarColor(m.userId);
    final isMe = m.userId == ref.read(voiceSessionProvider.notifier).myUserId;
    final notifier = ref.read(voiceSessionProvider.notifier);
    final isLocallyMuted = !isMe && notifier.isUserLocallyMuted(m.userId);
    final isScreenTile = tileKind == 'screen';
    final hasVideo = isScreenTile ? m.isScreenSharing : m.isVideo;

    Widget? videoWidget;
    if (hasVideo || isScreenTile) {
      if (isMe) {
        final selfRenderer = notifier.getSelfRenderer();
        if (selfRenderer != null) {
          videoWidget = RTCVideoView(selfRenderer,
            objectFit: isScreenTile
                ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: !isScreenTile && m.isVideo,
          );
        }
      } else {
        final rendererKey = isScreenTile ? -m.userId : m.userId;
        var renderer = notifier.getRemoteRenderer(rendererKey);
        if (renderer == null) {
          notifier.ensureRemoteRenderer(rendererKey, preferScreen: isScreenTile).then((r) {
            if (r != null) notifier.notifyUi();
          });
        }
        if (renderer != null) {
          videoWidget = RTCVideoView(renderer,
            objectFit: isScreenTile
                ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: !isScreenTile && m.isVideo,
          );
        }
      }
    }

    final tileBgColor = videoWidget != null
        ? Color.lerp(avatarBg, const Color(0xFF12131a), 0.68)!
        : c.surface;

    return GestureDetector(
      onTap: () => _clickTileById(tileId ?? 'u${m.userId}'),
      onSecondaryTapUp: isMe ? null : (details) {
        _showUserMenu(context, details.globalPosition, m, c);
      },
      onLongPress: isMe ? null : () {
        _showUserMenu(context, Offset.zero, m, c);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tileBgColor,
          border: Border.all(
            color: highlighted ? c.accent : isSpeaking ? c.success : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSpeaking
              ? [BoxShadow(color: c.success.withValues(alpha: 0.4), blurRadius: 14)]
              : null,
        ),
        child: Stack(
          children: [
            // Video or avatar — centered, fills tile
            if (videoWidget != null)
              Positioned.fill(child: videoWidget)
            else
              Center(
                child: Builder(builder: (_) {
                  final avatarSize = compact ? 44.0 : 64.0;
                  final fontSize = compact ? 16.0 : 22.0;
                  return Container(
                    width: avatarSize, height: avatarSize,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      shape: BoxShape.circle,
                      image: m.avatarUrl?.isNotEmpty == true
                          ? DecorationImage(image: NetworkImage(fullImageUrl(m.avatarUrl!)), fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: m.avatarUrl?.isNotEmpty != true
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white))
                        : null,
                  );
                }),
              ),
            // Name badge — bottom-left, inline (like web .tile-name)
            Positioned(
              left: 6, bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isScreenTile) ...[
                      Icon(Icons.screen_share, size: 11, color: c.success),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isScreenTile ? '$name — экран' : name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 11.0 : 12.0, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    if (m.isMuted && !isScreenTile) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(color: c.error, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off, size: 9, color: Colors.white),
                      ),
                    ],
                    if (isLocallyMuted && !isScreenTile) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.volume_off, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context, Offset position, VoiceMember m, ColorSet c) {
    final notifier = ref.read(voiceSessionProvider.notifier);
    final locallyMuted = notifier.isUserLocallyMuted(m.userId);
    final name = m.displayName?.isNotEmpty == true ? m.displayName! : m.username;

    final pos = position == Offset.zero
        ? const RelativeRect.fromLTRB(100, 300, 200, 0)
        : RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1);

    showMenu<String>(
      context: context,
      position: pos,
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(
          enabled: false,
          height: 36,
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: _avatarColor(m.userId),
                shape: BoxShape.circle,
                image: m.avatarUrl?.isNotEmpty == true
                    ? DecorationImage(image: NetworkImage(fullImageUrl(m.avatarUrl!)), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: m.avatarUrl?.isNotEmpty != true
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 8),
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'volume',
          height: 44,
          child: StatefulBuilder(builder: (ctx, setLocal) {
            var vol = notifier.getUserVolume(m.userId);
            return Row(children: [
              Icon(Icons.volume_up, size: 16, color: c.textSecondary),
              const SizedBox(width: 6),
              SizedBox(width: 28, child: Text('$vol%', style: TextStyle(fontSize: 11, color: c.textSecondary))),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: c.accent, inactiveTrackColor: c.border,
                    thumbColor: c.accent, trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                  ),
                  child: Slider(
                    value: vol.toDouble(), min: 0, max: 100,
                    onChanged: (v) {
                      notifier.setUserVolume(m.userId, v.round());
                      setLocal(() => vol = v.round());
                    },
                  ),
                ),
              ),
            ]);
          }),
        ),
        PopupMenuItem(
          value: 'mute',
          height: 36,
          child: Row(children: [
            Icon(locallyMuted ? Icons.volume_up : Icons.volume_off, size: 16,
              color: locallyMuted ? c.success : c.error),
            const SizedBox(width: 8),
            Text(locallyMuted ? 'Включить звук' : 'Заглушить',
              style: TextStyle(fontSize: 13, color: c.text)),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'mute') {
        notifier.setUserLocallyMuted(m.userId, !locallyMuted);
      }
    });
  }

  // ─── Footer (controls, glass) ─────────────────────────────────────────

  Widget _footerButtons(ColorSet c, Color accent, bool joined, VoiceSessionState vs, VoiceSessionNotifier notifier, AppLocalizations l) {
    return Row(
      children: [
        const Spacer(),
        if (!joined) ...[
          _circleButton(icon: vs.isMuted ? Icons.mic_off : Icons.mic, active: vs.isMuted, activeColor: c.error, c: c, tooltip: vs.isMuted ? l.voiceUnmute : l.voiceMute, onTap: notifier.toggleMute),
          const SizedBox(width: 10),
          _pillButton(icon: Icons.call, color: c.success, onTap: vs.isJoining ? null : () => notifier.join(widget.pageId, pageTitle: widget.pageTitle, communitySlug: widget.communitySlug)),
        ] else ...[
          _circleButton(icon: vs.isMuted ? Icons.mic_off : Icons.mic, active: vs.isMuted, activeColor: c.error, c: c, tooltip: vs.isMuted ? l.voiceUnmute : l.voiceMute, onTap: notifier.toggleMute),
          const SizedBox(width: 10),
          _circleButton(icon: vs.isVideo ? Icons.videocam : Icons.videocam_off, active: !vs.isVideo, activeColor: c.error, c: c, tooltip: vs.isVideo ? 'Выкл. камеру' : 'Вкл. камеру', onTap: notifier.toggleCamera),
          const SizedBox(width: 10),
          _circleButton(
            icon: vs.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share_outlined,
            active: vs.isScreenSharing, activeColor: c.success, c: c,
            tooltip: vs.isScreenSharing ? 'Остановить трансляцию' : 'Поделиться экраном',
            onTap: vs.isScreenSharing ? notifier.toggleScreenShare : () async {
              final source = await ScreenSourcePicker.show(context, c);
              if (source != null) notifier.startScreenShareWithSource(source.id);
            },
          ),
          const SizedBox(width: 10),
          _pillButton(icon: Icons.call_end, color: c.error, onTap: () {
            if (widget.pageId >= 1000000000000) {
              ref.read(callSessionProvider.notifier).leaveCall();
            } else {
              notifier.leave();
            }
          }),
        ],
        const Spacer(),
        _circleButton(
            icon: _isFs ? Icons.fullscreen_exit : Icons.fullscreen,
            c: c,
            tooltip: _isFs ? 'Выйти из полного экрана' : 'Полный экран',
            onTap: _toggleFullscreen,
          ),
      ],
    );
  }

  Widget _buildFooter(ColorSet c, Color accent, bool joined, VoiceSessionState vs, VoiceSessionNotifier notifier, AppLocalizations l) {
    final buttons = _footerButtons(c, accent, joined, vs, notifier, l);
    if (_isFs) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: buttons,
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceAlt.withValues(alpha: 0.45),
          ),
          child: buttons,
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon, required ColorSet c,
    bool active = false, Color? activeColor,
    String? tooltip, required VoidCallback onTap,
  }) {
    final bg = active ? (activeColor ?? c.error) : c.surface;
    final fg = active ? Colors.white : c.text;
    final border = active ? (activeColor ?? c.error) : c.border;

    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _pillButton({required IconData icon, required Color color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 66, height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────

  Widget _emptyState(ColorSet c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headset_mic_outlined, size: 48, color: c.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.voiceChannelEmpty, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.voiceChannelEmptyHint, style: TextStyle(fontSize: 12, color: c.textSecondary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
