import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_url.dart';
import '../../../l10n/app_localizations.dart';
import '../state/voice_session.dart';

/// Draggable floating PiP widget — shown when user is in a voice call but
/// navigated away from the voice page. Discord-style: glass bg, avatar
/// cluster, speaking dot, compact controls.
class FloatingCallWidget extends ConsumerStatefulWidget {
  final ColorSet c;
  final Color? commColor;
  final VoidCallback? onExpand;

  const FloatingCallWidget({super.key, required this.c, this.commColor, this.onExpand});

  @override
  ConsumerState<FloatingCallWidget> createState() => _FloatingCallWidgetState();
}

class _FloatingCallWidgetState extends ConsumerState<FloatingCallWidget> {
  Offset _offset = Offset.zero;
  bool _initialized = false;

  static const _palette = [0xFFd94066, 0xFF4d9966, 0xFF804d99, 0xFF997333, 0xFF338c8c, 0xFFb36626, 0xFF336699];
  Color _avatarColor(int uid) => Color(_palette[uid % _palette.length]);

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final vs = ref.watch(voiceSessionProvider);
    final notifier = ref.read(voiceSessionProvider.notifier);
    if (!vs.inCall) return const SizedBox.shrink();

    final members = vs.membersOn(vs.joinedPageId!);
    final size = MediaQuery.of(context).size;
    const w = 220.0;

    if (!_initialized) {
      _offset = Offset(size.width - w - 20, size.height - 200);
      _initialized = true;
    }

    return Positioned(
      left: _offset.dx.clamp(8.0, size.width - w - 8),
      top: _offset.dy.clamp(64.0, size.height - 180),
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _offset += d.delta),
        child: Container(
          width: w,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle (header) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.border)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.volume_up_outlined, size: 12, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vs.joinedPageTitle ?? AppLocalizations.of(context)!.voiceFloatingTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar cluster
                    _buildAvatarCluster(members, c),
                    const SizedBox(height: 10),

                    // Speaking indicator
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: c.success,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: c.success.withValues(alpha: 0.5), blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.of(context)!.voiceParticipants(members.length),
                          style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Controls row
                    Row(
                      children: [
                        _pipBtn(
                          icon: vs.isMuted ? Icons.mic_off : Icons.mic,
                          active: vs.isMuted,
                          activeColor: c.error,
                          c: c,
                          onTap: notifier.toggleMute,
                        ),
                        const SizedBox(width: 6),
                        if (widget.onExpand != null) _pipBtn(
                          icon: Icons.open_in_full,
                          c: c,
                          activeColor: c.accent,
                          active: true,
                          onTap: widget.onExpand,
                        ),
                        const SizedBox(width: 6),
                        _pipBtn(
                          icon: Icons.call_end,
                          active: true,
                          activeColor: c.error,
                          c: c,
                          onTap: notifier.leave,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCluster(List<VoiceMember> members, ColorSet c) {
    final show = members.take(5).toList();
    final extra = members.length - show.length;
    final totalCount = show.length + (extra > 0 ? 1 : 0);
    const size = 28.0;
    const overlap = 8.0;
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
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))
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
                child: Text('+$extra', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pipBtn({
    required IconData icon,
    required ColorSet c,
    bool active = false,
    Color? activeColor,
    VoidCallback? onTap,
  }) {
    final bg = active ? (activeColor ?? c.surface) : c.surface;
    final fg = active ? Colors.white : c.text;
    final border = active ? (activeColor ?? c.border) : c.border;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: fg),
        ),
      ),
    );
  }
}
