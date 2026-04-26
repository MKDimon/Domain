import 'dart:typed_data';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';

class PendingAttachment {
  final String filename;
  final String type;
  final int size;
  final Uint8List bytes;
  bool uploading;
  int progress;
  String? url;
  String? error;

  PendingAttachment({
    required this.filename,
    required this.type,
    required this.size,
    required this.bytes,
    this.uploading = false,
    this.progress = 0,
    this.url,
    this.error,
  });

  Map<String, dynamic> toAttachmentJson() => {
    'url': url!,
    'filename': filename,
    'type': type,
    'size': size,
  };
}

class ChatComposer extends StatefulWidget {
  final Future<void> Function(String text, {int replyToMessageId, List<Map<String, dynamic>>? attachments}) onSend;
  final void Function(bool isTyping)? onTypingChanged;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  final bool enabled;
  final Future<String?> Function(Uint8List bytes, String filename, String contentType)? onUpload;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.onTypingChanged,
    this.replyTo,
    this.onCancelReply,
    this.enabled = true,
    this.onUpload,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _sending = false;
  bool _wasTyping = false;
  bool _showEmoji = false;
  final _attachments = <PendingAttachment>[];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _controller.addListener(_onTextChanged);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored;
      }
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTextChanged() {
    final isTyping = _controller.text.trim().isNotEmpty;
    if (isTyping != _wasTyping) {
      _wasTyping = isTyping;
      widget.onTypingChanged?.call(isTyping);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final att = PendingAttachment(
        filename: file.name,
        type: _mimeFromName(file.name),
        size: file.size,
        bytes: file.bytes!,
      );
      setState(() => _attachments.add(att));
      _uploadAttachment(att);
    }
  }

  Future<void> _uploadAttachment(PendingAttachment att) async {
    if (widget.onUpload == null) return;
    setState(() => att.uploading = true);
    try {
      final url = await widget.onUpload!(att.bytes, att.filename, att.type);
      if (mounted) {
        setState(() {
          att.url = url;
          att.uploading = false;
          att.progress = 100;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          att.error = e.toString();
          att.uploading = false;
        });
      }
    }
  }

  static String _mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mp3' => 'audio/mpeg',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _controller.text = text.replaceRange(start, end, emoji.emoji);
    _controller.selection = TextSelection.collapsed(offset: start + emoji.emoji.length);
    _focusNode.requestFocus();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final readyAttachments = _attachments.where((a) => a.url != null).toList();
    if (text.isEmpty && readyAttachments.isEmpty) return;
    if (_sending) return;

    setState(() => _sending = true);
    try {
      final attJson = readyAttachments.isNotEmpty
          ? readyAttachments.map((a) => a.toAttachmentJson()).toList()
          : null;
      await widget.onSend(text, replyToMessageId: widget.replyTo?.id ?? 0, attachments: attJson);
      _controller.clear();
      setState(() => _attachments.clear());
      widget.onCancelReply?.call();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.replyTo!.authorName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                      Text(widget.replyTo!.text, style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: widget.onCancelReply,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        if (_attachments.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _attachments.map((att) {
                final isImage = att.type.startsWith('image/');
                return Chip(
                  avatar: att.uploading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(isImage ? Icons.image : Icons.attach_file, size: 14),
                  label: Text(att.filename, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _attachments.remove(att)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: att.error != null ? theme.colorScheme.error.withValues(alpha: 0.1) : null,
                );
              }).toList(),
            ),
          ),
        if (_showEmoji)
          SizedBox(
            height: 260,
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              config: Config(
                height: 260,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28,
                  backgroundColor: theme.colorScheme.surface,
                ),
                categoryViewConfig: CategoryViewConfig(
                  iconColorSelected: theme.colorScheme.primary,
                  indicatorColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surface,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: theme.colorScheme.surface,
                  hintText: 'Поиск...',
                ),
                bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.onUpload != null)
                _ComposerButton(
                  icon: Icons.attach_file,
                  onTap: widget.enabled ? _pickFiles : null,
                  theme: theme,
                ),
              const SizedBox(width: 4),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.chatTypeMessage,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: theme.dividerColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: theme.dividerColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: theme.colorScheme.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _ComposerButton(
                icon: _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                onTap: widget.enabled ? () => setState(() => _showEmoji = !_showEmoji) : null,
                theme: theme,
              ),
              const SizedBox(width: 4),
              _SendButton(
                sending: _sending,
                onTap: _send,
                theme: theme,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ThemeData theme;

  const _ComposerButton({required this.icon, this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20, color: onTap != null ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.disabledColor),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(shape: const CircleBorder()),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback onTap;
  final ThemeData theme;

  const _SendButton({required this.sending, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: sending
          ? Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)))
          : IconButton(
              icon: Icon(Icons.send, size: 18, color: Colors.white),
              onPressed: onTap,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: const CircleBorder(),
              ),
            ),
    );
  }
}
