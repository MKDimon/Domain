import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/chat_message.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../content/widgets/inline_markup.dart';

String _fmtMsgTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '0:${seconds.toString().padLeft(2, '0')}';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m < 60) return '$m:${s.toString().padLeft(2, '0')}';
  final h = m ~/ 60;
  final rm = m % 60;
  return '$h:${rm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final bool showAuthor;
  final bool wideMode;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final List<ChatAttachment> allChatImages;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.showAuthor = true,
    this.wideMode = false,
    this.onReply,
    this.onDelete,
    this.allChatImages = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.messageType == 'missed_call' || message.messageType == 'call_ended') {
      return _SystemCallBubble(message: message, isOwn: isOwn, theme: theme);
    }

    final bubbleColor = message.chatBubbleColor != null
        ? _parseColor(message.chatBubbleColor!)
        : isOwn
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.surface;

    final textColor = message.chatTextColor != null
        ? _parseColor(message.chatTextColor!)
        : null;

    final usernameColor = message.chatUsernameColor != null
        ? _parseColor(message.chatUsernameColor!)
        : theme.colorScheme.primary;

    final images = message.attachments.where((a) => a.type.startsWith('image/')).toList();
    final files = message.attachments.where((a) => !a.type.startsWith('image/')).toList();
    final hasText = message.text.trim().isNotEmpty;

    return Align(
      alignment: isOwn && !wideMode ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wideMode ? 700 : MediaQuery.of(context).size.width * 0.75),
        child: GestureDetector(
          onLongPress: () => _showContextMenu(context),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.replyTo != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _ReplyPreview(reply: message.replyTo!, theme: theme),
                  ),
                if (showAuthor && (!isOwn || wideMode))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: avatarColor(message.userId),
                          backgroundImage: message.avatarUrl?.isNotEmpty == true
                              ? NetworkImage(fullImageUrl(message.avatarUrl!))
                              : null,
                          child: message.avatarUrl?.isNotEmpty != true
                              ? Text(
                                  message.authorName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          message.authorName,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: usernameColor),
                        ),
                      ],
                    ),
                  ),
                if (hasText)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: InlineMarkupText(
                      text: message.text,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: message.chatFont,
                        fontSize: message.chatFontSize?.toDouble(),
                      ),
                    ),
                  ),
                if (images.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, hasText ? 6 : 4, 4, 0),
                    child: _ImageGrid(images: images, allChatImages: allChatImages),
                  ),
                if (files.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: _FileList(files: files, theme: theme),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                  child: Text(
                    _fmtMsgTime(message.createdAt),
                    style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(AppLocalizations.of(context)!.chatReply),
                onTap: () { Navigator.pop(ctx); onReply!(); },
              ),
            if (isOwn && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(AppLocalizations.of(context)!.chatDelete, style: const TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); onDelete!(); },
              ),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
    } catch (_) {}
    return null;
  }
}

// ---------------------------------------------------------------------------
// Reply preview
// ---------------------------------------------------------------------------

class _ReplyPreview extends StatelessWidget {
  final ChatReplyRef reply;
  final ThemeData theme;
  const _ReplyPreview({required this.reply, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(width: 2, color: theme.colorScheme.primary)),
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply.username != null)
            Text((reply.displayName?.isNotEmpty == true ? reply.displayName! : reply.username) ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
          Text(
            reply.deleted == true ? AppLocalizations.of(context)!.chatDeleteConfirm : (reply.text ?? ''),
            style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image grid — 1 image full width, 2 side-by-side, 3+ grid
// ---------------------------------------------------------------------------

class _ImageGrid extends StatelessWidget {
  final List<ChatAttachment> images;
  final List<ChatAttachment> allChatImages;
  const _ImageGrid({required this.images, this.allChatImages = const []});

  @override
  Widget build(BuildContext context) {
    Widget grid;
    if (images.length == 1) {
      grid = _imageItem(context, images[0], 0, height: 220);
    } else if (images.length == 2) {
      grid = Row(
        children: [
          Expanded(child: _imageItem(context, images[0], 0, height: 160)),
          const SizedBox(width: 2),
          Expanded(child: _imageItem(context, images[1], 1, height: 160)),
        ],
      );
    } else if (images.length == 3) {
      grid = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _imageItem(context, images[0], 0, height: 200)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                _imageItem(context, images[1], 1, height: 99),
                const SizedBox(height: 2),
                _imageItem(context, images[2], 2, height: 99),
              ],
            ),
          ),
        ],
      );
    } else if (images.length == 4) {
      grid = Column(
        children: [
          Row(children: [
            Expanded(child: _imageItem(context, images[0], 0, height: 120)),
            const SizedBox(width: 2),
            Expanded(child: _imageItem(context, images[1], 1, height: 120)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(child: _imageItem(context, images[2], 2, height: 120)),
            const SizedBox(width: 2),
            Expanded(child: _imageItem(context, images[3], 3, height: 120)),
          ]),
        ],
      );
    } else {
      final rows = <Widget>[];
      for (var i = 0; i < images.length; i += 3) {
        final rowItems = images.sublist(i, (i + 3).clamp(0, images.length));
        rows.add(Row(
          children: rowItems.asMap().entries.map((e) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: e.key > 0 ? 2 : 0),
                child: _imageItem(context, e.value, i + e.key, height: 100),
              ),
            );
          }).toList(),
        ));
        if (i + 3 < images.length) rows.add(const SizedBox(height: 2));
      }
      grid = Column(children: rows);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: grid,
      ),
    );
  }

  Widget _imageItem(BuildContext context, ChatAttachment img, int index, {double height = 160}) {
    return GestureDetector(
      onTap: () => _openGallery(context, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Image.network(
            fullImageUrl(img.url),
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey.shade800,
              child: const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
            ),
          ),
        ),
      ),
    );
  }

  void _openGallery(BuildContext context, int localIndex) {
    final gallery = allChatImages.isNotEmpty ? allChatImages : images;
    int globalIndex = localIndex;
    if (allChatImages.isNotEmpty) {
      final url = images[localIndex].url;
      globalIndex = allChatImages.indexWhere((a) => a.url == url);
      if (globalIndex < 0) globalIndex = 0;
    }
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (c, a1, a2) => _ImageGalleryViewer(images: gallery, initialIndex: globalIndex),
    ));
  }
}

// ---------------------------------------------------------------------------
// Full-screen image gallery with swipe
// ---------------------------------------------------------------------------

class _ImageGalleryViewer extends StatefulWidget {
  final List<ChatAttachment> images;
  final int initialIndex;
  const _ImageGalleryViewer({required this.images, required this.initialIndex});

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late int _current;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _prev() {
    if (_current > 0) setState(() => _current--);
  }

  void _next() {
    if (_current < widget.images.length - 1) setState(() => _current++);
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_current];
    final multi = widget.images.length > 1;
    final pad = MediaQuery.of(context).padding;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _prev();
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) _next();
          if (event.logicalKey == LogicalKeyboardKey.escape) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          onHorizontalDragEnd: multi ? (details) {
            final v = details.primaryVelocity ?? 0;
            if (v > 200) _prev();
            if (v < -200) _next();
          } : null,
          child: Stack(
            children: [
              Center(
                child: Image.network(
                  fullImageUrl(img.url),
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
              // Top bar
              Positioned(
                top: pad.top + 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    _circleButton(Icons.close, () => Navigator.pop(context)),
                    const Spacer(),
                    if (multi)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_current + 1} / ${widget.images.length}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    const SizedBox(width: 8),
                    _circleButton(Icons.download, () {
                      final uri = Uri.tryParse(fullImageUrl(img.url));
                      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                    }),
                  ],
                ),
              ),
              // Left arrow
              if (multi && _current > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _circleButton(Icons.chevron_left, _prev, size: 40)),
                ),
              // Right arrow
              if (multi && _current < widget.images.length - 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _circleButton(Icons.chevron_right, _next, size: 40)),
                ),
              // Filename
              Positioned(
                bottom: pad.bottom + 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      img.filename,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {double size = 36}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File attachments list with size and download
// ---------------------------------------------------------------------------

class _FileList extends StatelessWidget {
  final List<ChatAttachment> files;
  final ThemeData theme;
  const _FileList({required this.files, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: files.map((f) {
        final isAudio = f.type.startsWith('audio/');
        final isVideo = f.type.startsWith('video/');
        final icon = isAudio
            ? Icons.audiotrack
            : isVideo
                ? Icons.videocam
                : Icons.insert_drive_file;

        return InkWell(
          onTap: () {
            final uri = Uri.tryParse(fullImageUrl(f.url));
            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.filename,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _formatFileSize(f.size),
                        style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.download, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// System call messages (missed_call + call_ended)
// ---------------------------------------------------------------------------

class _SystemCallBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final ThemeData theme;
  const _SystemCallBubble({required this.message, required this.isOwn, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isMissed = message.messageType == 'missed_call';
    final isVideo = message.meta?['video'] == true;
    final l10n = AppLocalizations.of(context)!;

    String text;
    IconData icon;
    Color color;

    if (isMissed) {
      final reason = (message.meta?['reason'] as String?) ?? 'timeout';
      if (isOwn) {
        if (reason == 'rejected') {
          text = l10n.chatCallDeclined;
        } else if (reason == 'ended') {
          text = l10n.chatCallCancelled;
        } else {
          text = l10n.chatMissedCallOut;
        }
      } else {
        if (reason == 'rejected') {
          text = '${l10n.chatCallYouDeclined} ${message.authorName}';
        } else {
          text = '${l10n.chatMissedCallIn} ${message.authorName}';
        }
      }
      icon = Icons.phone_missed;
      color = theme.colorScheme.error;
    } else {
      final dur = (message.meta?['duration'] as num?)?.toInt() ?? 0;
      final callType = isVideo ? l10n.chatVideoCall : l10n.chatVoiceCall;
      text = '$callType · ${_formatDuration(dur)}';
      icon = isVideo ? Icons.videocam : Icons.phone;
      color = theme.colorScheme.primary;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text, style: TextStyle(fontSize: 12, color: color)),
            ),
            const SizedBox(width: 8),
            Text(
              _fmtMsgTime(message.createdAt),
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
