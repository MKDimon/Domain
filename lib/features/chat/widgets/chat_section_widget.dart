import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/websocket/ws_manager.dart';
import '../../../data/api/chat_api.dart';
import '../../../data/api/uploads_api.dart';
import '../../../data/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import 'message_bubble.dart';
import 'chat_composer.dart';
import 'chat_customize_panel.dart';
import 'typing_indicator.dart';

class ChatSectionWidget extends ConsumerStatefulWidget {
  final int sectionId;
  final int? conversationId;

  const ChatSectionWidget({super.key, required this.sectionId, this.conversationId});

  @override
  ConsumerState<ChatSectionWidget> createState() => _ChatSectionWidgetState();
}

class _ChatSectionWidgetState extends ConsumerState<ChatSectionWidget> {
  static const _maxMessages = 150;

  late final ChatApi _chatApi;
  late final WsManager _ws;
  final _messages = <ChatMessage>[];
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _hasNewer = false;
  String? _error;
  ChatMessage? _replyTo;
  String _listenerKey = '';
  final _typingUsers = <String>{};
  Timer? _typingClearTimer;
  String _floatingDate = '';
  bool _floatingDateVisible = false;
  Timer? _floatingDateTimer;
  final _searchCtrl = TextEditingController();
  List<ChatMessage> _searchResults = [];
  bool _searchLoading = false;
  int? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _showCustomize = false;
  bool _selectionMode = false;
  final _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _chatApi = ChatApi(ref.read(apiClientProvider));
    _ws = ref.read(wsManagerProvider);
    _scrollController.addListener(_onScroll);
    _load();
    _setupWs();
  }

  @override
  void didUpdateWidget(covariant ChatSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId != widget.sectionId || oldWidget.conversationId != widget.conversationId) {
      _ws.unsubscribe(oldWidget.sectionId);
      _ws.removeListener(_listenerKey);
      setState(() {
        _messages.clear();
        _loading = true;
        _hasMore = true;
        _hasNewer = false;
        _error = null;
        _replyTo = null;
      });
      _load();
      _setupWs();
    }
  }

  void _setupWs() {
    _listenerKey = _ws.addListener((_) {});
    _ws.subscribe(widget.sectionId);

    _ws.on(_listenerKey, WsEventType.messageCreated, (event) {
      final data = event.data;
      if (data == null) return;
      final sectionId = data['section_id'] as int? ?? 0;
      if (sectionId != widget.sectionId) return;
      final convId = data['conversation_id'] as int?;
      if (widget.conversationId != null && convId != widget.conversationId) return;

      final msg = ChatMessage.fromJson(data);
      if (mounted && !_hasNewer) {
        setState(() {
          _messages.insert(0, msg);
          _typingUsers.remove(msg.username);
        });
        _markAsRead(msg.id);
      }
    });

    _ws.on(_listenerKey, WsEventType.messageDeleted, (event) {
      final data = event.data;
      if (data == null) return;
      final msgId = data['message_id'] as int? ?? data['id'] as int? ?? 0;
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == msgId));
      }
    });

    _ws.on(_listenerKey, WsEventType.typing, (event) {
      final data = event.data;
      if (data == null) return;
      final sectionId = data['section_id'] as int? ?? 0;
      if (sectionId != widget.sectionId) return;
      final username = data['username'] as String? ?? '';
      final stop = data['stop'] as bool? ?? false;
      final currentUser = ref.read(authProvider).user?.username;
      if (username == currentUser || username.isEmpty) return;

      if (mounted) {
        setState(() {
          if (stop) {
            _typingUsers.remove(username);
          } else {
            _typingUsers.add(username);
            _typingClearTimer?.cancel();
            _typingClearTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) setState(() => _typingUsers.remove(username));
            });
          }
        });
      }
    });

    _ws.on(_listenerKey, WsEventType.reconnected, (_) {
      _loadNew();
    });
  }

  Future<void> _load() async {
    try {
      final res = await _chatApi.getMessages(
        widget.sectionId,
        conversationId: widget.conversationId ?? 0,
      );
      if (mounted) {
        setState(() {
          _messages.addAll(res.items.reversed);
          _loading = false;
          _hasMore = res.items.length >= 50;
          _hasNewer = false;
        });
        if (_messages.isNotEmpty) _markAsRead(_messages.first.id);
      }
    } catch (e) {
      if (mounted) setState(() { _error = AppLocalizations.of(context)!.pageViewLoadFailed; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final res = await _chatApi.getMessages(
        widget.sectionId,
        before: _messages.last.id,
        conversationId: widget.conversationId ?? 0,
      );
      if (mounted) {
        setState(() {
          _messages.addAll(res.items.reversed);
          _hasMore = res.items.length >= 50;
          _loadingMore = false;
          if (_messages.length > _maxMessages) {
            _messages.removeRange(0, _messages.length - _maxMessages);
            _hasNewer = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadNew() async {
    if (_messages.isEmpty || _hasNewer) return;
    try {
      final res = await _chatApi.pollMessages(
        widget.sectionId,
        _messages.first.id,
        conversationId: widget.conversationId ?? 0,
      );
      if (res.items.isNotEmpty && mounted) {
        setState(() {
          for (final msg in res.items) {
            if (!_messages.any((m) => m.id == msg.id)) {
              _messages.insert(0, msg);
            }
          }
        });
        _markAsRead(_messages.first.id);
      }
    } catch (_) {}
  }

  Future<void> _loadNewer() async {
    if (!_hasNewer || _messages.isEmpty) return;
    try {
      final res = await _chatApi.pollMessages(
        widget.sectionId,
        _messages.first.id,
        conversationId: widget.conversationId ?? 0,
      );
      if (mounted) {
        setState(() {
          for (final msg in res.items) {
            if (!_messages.any((m) => m.id == msg.id)) {
              _messages.insert(0, msg);
            }
          }
          if (res.items.length < 200) _hasNewer = false;
          if (_messages.length > _maxMessages) {
            _messages.removeRange(_maxMessages, _messages.length);
            _hasMore = true;
          }
        });
        if (_messages.isNotEmpty) _markAsRead(_messages.first.id);
      }
    } catch (_) {}
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
    if (_hasNewer && pos.pixels <= 100) {
      _loadNewer();
    }
    _updateFloatingDate();
  }

  void _updateFloatingDate() {
    if (_messages.isEmpty || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final totalContent = pos.maxScrollExtent + pos.viewportDimension;
    final itemCount = _messages.length + (_loadingMore ? 1 : 0);
    final avgHeight = itemCount > 0 ? totalContent / itemCount : 80.0;
    final topIdx = ((pos.pixels + pos.viewportDimension - avgHeight) / avgHeight).round().clamp(0, _messages.length - 1);
    final msg = _messages[topIdx];
    final dt = DateTime.tryParse(msg.createdAt);
    if (dt != null) {
      final formatted = _formatDate(dt);
      if (formatted != _floatingDate) {
        setState(() { _floatingDate = formatted; _floatingDateVisible = true; });
      } else if (!_floatingDateVisible) {
        setState(() => _floatingDateVisible = true);
      }
    }
    _floatingDateTimer?.cancel();
    _floatingDateTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _floatingDateVisible = false);
    });
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return 'Сегодня';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) return 'Вчера';
    const months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    return '${dt.day} ${months[dt.month - 1]}${dt.year != now.year ? ' ${dt.year}' : ''}';
  }

  Future<void> _doSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.length < 2) {
      setState(() { _searchResults = []; _searchLoading = false; });
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await _chatApi.searchMessages(
        widget.sectionId,
        query,
        conversationId: widget.conversationId ?? 0,
      );
      if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _jumpToSearchResult(int anchorId) async {
    try {
      final data = await _chatApi.getMessagesAround(
        widget.sectionId,
        anchorId,
        conversationId: widget.conversationId ?? 0,
      );
      final items = (data['items'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [];
      if (items.isEmpty || !mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(items.toList()..sort((a, b) => b.id.compareTo(a.id)));
        _hasMore = data['has_before'] as bool? ?? true;
        _hasNewer = data['has_after'] as bool? ?? true;
        _highlightedMessageId = anchorId;
      });
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
      final idx = _messages.indexWhere((m) => m.id == anchorId);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(idx * 60.0);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage(String text, {int replyToMessageId = 0, List<Map<String, dynamic>>? attachments}) async {
    final msg = await _chatApi.sendMessage(
      widget.sectionId,
      text,
      conversationId: widget.conversationId ?? 0,
      replyToMessageId: replyToMessageId,
      attachments: attachments,
    );
    if (mounted && !_messages.any((m) => m.id == msg.id)) {
      setState(() => _messages.insert(0, msg));
    }
  }

  Future<String?> _uploadFile(Uint8List bytes, String filename, String contentType) async {
    final uploadsApi = UploadsApi(ref.read(apiClientProvider));
    final result = await uploadsApi.upload(bytes: bytes, filename: filename, contentType: contentType);
    return result.url;
  }

  void _markAsRead(int messageId) {
    _chatApi.markAsRead(widget.sectionId, messageId, conversationId: widget.conversationId ?? 0);
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await _chatApi.deleteMessage(widget.sectionId, messageId);
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == messageId));
      }
    } catch (_) {}
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _cancelSelection() {
    setState(() { _selectionMode = false; _selectedIds.clear(); });
  }

  Future<void> _bulkDelete() async {
    final ids = List<int>.from(_selectedIds);
    _cancelSelection();
    for (final id in ids) {
      await _deleteMessage(id);
    }
  }

  Future<void> _jumpToDate(DateTime date) async {
    try {
      final iso = date.toIso8601String().split('T').first;
      final anchorId = await _chatApi.findMessageByDate(
        widget.sectionId,
        iso,
        conversationId: widget.conversationId ?? 0,
      );
      if (anchorId <= 0 || !mounted) return;
      final data = await _chatApi.getMessagesAround(
        widget.sectionId,
        anchorId,
        conversationId: widget.conversationId ?? 0,
      );
      final items = (data['items'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [];
      if (items.isEmpty || !mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(items.toList()..sort((a, b) => b.id.compareTo(a.id)));
        _hasMore = data['has_before'] as bool? ?? true;
        _hasNewer = data['has_after'] as bool? ?? true;
        _highlightedMessageId = anchorId;
      });
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
      final idx = _messages.indexWhere((m) => m.id == anchorId);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(idx * 60.0);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ws.unsubscribe(widget.sectionId);
    _ws.removeListener(_listenerKey);
    _scrollController.dispose();
    _typingClearTimer?.cancel();
    _floatingDateTimer?.cancel();
    _highlightTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final currentUserId = ref.watch(authProvider).user?.id;
    final currentUsername = ref.watch(authProvider).user?.username;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)));
    }

    final allImages = _messages.reversed.expand((m) => m.attachments.where((a) => a.type.startsWith('image/'))).toList();

    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideMode = constraints.maxWidth > 1000;
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: c.chatPanel.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Column(
          children: [
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  if (currentUserId != null)
                    IconButton(
                      icon: Icon(Icons.tune, size: 16, color: _showCustomize ? c.text : c.textSecondary),
                      tooltip: 'Настройки',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => setState(() => _showCustomize = !_showCustomize),
                    ),
                  IconButton(
                    icon: Icon(Icons.calendar_month, size: 16, color: c.textSecondary),
                    tooltip: l10n.chatJumpToDate,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) _jumpToDate(picked);
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(fontSize: 12, color: c.text),
                        decoration: InputDecoration(
                          hintText: l10n.chatSearchHint,
                          hintStyle: TextStyle(color: c.textSecondary, fontSize: 12),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: Icon(Icons.search, size: 14, color: c.textSecondary),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () { _searchCtrl.clear(); setState(() => _searchResults = []); },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.close, size: 12, color: c.textSecondary),
                                  ),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.accent)),
                          filled: true, fillColor: c.activeOverlay, isDense: true,
                        ),
                        onSubmitted: (_) => _doSearch(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_searchLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_hasNewer)
                    IconButton(
                      icon: Icon(Icons.arrow_downward, size: 16, color: c.accent),
                      tooltip: l10n.chatScrollToBottom,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        setState(() { _messages.clear(); _loading = true; _hasNewer = false; });
                        _load();
                      },
                    ),
                ],
              ),
            ),
            if (_showCustomize)
              ChatCustomizePanel(
                sectionId: widget.sectionId,
                onClose: () => setState(() => _showCustomize = false),
              ),
            if (_searchResults.isNotEmpty)
              _buildSearchResults(c, l10n),
            Expanded(
              child: _messages.isEmpty
                  ? Center(child: Text(l10n.chatNoMessages, style: theme.textTheme.bodySmall))
                  : _buildMessageList(c, wideMode, currentUserId, allImages, l10n),
            ),
            if (_typingUsers.isNotEmpty)
              TypingIndicator(usernames: _typingUsers.toList()),
            if (_selectionMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Color.lerp(c.accent, c.surface, 0.92),
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32, height: 32,
                      child: IconButton(
                        onPressed: _cancelSelection,
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.close, size: 16, color: c.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Выбрано: ${_selectedIds.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text)),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _selectedIds.isEmpty ? null : _bulkDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete, size: 16, color: c.error),
                            const SizedBox(width: 6),
                            Text('Удалить', style: TextStyle(fontSize: 13, color: c.error)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ChatComposer(
              onSend: _sendMessage,
              replyTo: _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
              enabled: currentUserId != null,
              onUpload: _uploadFile,
              onTypingChanged: (isTyping) {
                if (currentUsername != null) {
                  Future(() => _ws.sendTyping(widget.sectionId, currentUsername, conversationId: widget.conversationId, stop: !isTyping));
                }
              },
            ),
          ],
        ),
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildSearchResults(ColorSet c, AppLocalizations l10n) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.3))),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, i) {
          final r = _searchResults[i];
          final dt = DateTime.tryParse(r.createdAt);
          final timeStr = dt != null ? '${dt.day}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';
          return InkWell(
            onTap: () => _jumpToSearchResult(r.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(r.authorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                            const SizedBox(width: 6),
                            Text(timeStr, style: TextStyle(fontSize: 10, color: c.textSecondary)),
                          ],
                        ),
                        Text(r.text, style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 12, color: c.textSecondary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList(ColorSet c, bool wideMode, int? currentUserId, List<ChatAttachment> allImages, AppLocalizations l10n) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _messages.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ));
            }
            final msg = _messages[index];
            final isOwn = msg.userId == currentUserId;
            final prevMsg = index + 1 < _messages.length ? _messages[index + 1] : null;
            final showAuthor = wideMode
                ? (prevMsg == null || prevMsg.userId != msg.userId)
                : (!isOwn && (prevMsg == null || prevMsg.userId != msg.userId));

            final msgDate = DateTime.tryParse(msg.createdAt);
            final prevDate = prevMsg != null ? DateTime.tryParse(prevMsg.createdAt) : null;
            final showDateSep = msgDate != null && (prevDate == null ||
                msgDate.year != prevDate.year || msgDate.month != prevDate.month || msgDate.day != prevDate.day);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDateSep)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatDate(msgDate),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  decoration: BoxDecoration(
                    color: _highlightedMessageId == msg.id
                        ? c.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    onTap: _selectionMode ? () => _toggleSelect(msg.id) : null,
                    onLongPress: () {
                      if (!_selectionMode) {
                        setState(() { _selectionMode = true; _selectedIds.add(msg.id); });
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectionMode)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: Checkbox(
                                value: _selectedIds.contains(msg.id),
                                onChanged: (_) => _toggleSelect(msg.id),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        Flexible(
                          child: MessageBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            isOwn: isOwn,
                            showAuthor: showAuthor,
                            wideMode: wideMode,
                            allChatImages: allImages,
                            onReply: _selectionMode ? null : () => setState(() => _replyTo = msg),
                            onDelete: _selectionMode ? null : (isOwn ? () => _deleteMessage(msg.id) : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (_floatingDate.isNotEmpty)
          Positioned(
            top: 8, left: 0, right: 0,
            child: Center(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _floatingDateVisible ? 1.0 : 0.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_floatingDate, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
