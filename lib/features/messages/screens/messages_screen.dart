import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/websocket/ws_manager.dart';
import '../../../data/api/dm_api.dart';
import '../../../data/api/uploads_api.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/dm_conversation.dart';
import '../../../providers/auth_provider.dart';
import '../../chat/widgets/chat_composer.dart';
import '../../chat/widgets/message_bubble.dart';
import '../../voice/state/call_session.dart';
import '../../voice/state/voice_session.dart';
import '../../voice/widgets/voice_room_view.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  final int? openWithUserId;
  const MessagesScreen({super.key, this.openWithUserId});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  List<DmConversation> _conversations = [];
  List<DmConversation> _requests = [];
  String _dmPolicy = 'everyone';
  String _activeTab = 'messages';
  bool _loadingConvs = true;
  DmConversation? _active;
  final _searchCtrl = TextEditingController();

  String _wsKey = '';

  @override
  void initState() {
    super.initState();
    _loadConversations().then((_) => _resolveOpenWith());
    _setupWs();
  }

  Future<void> _resolveOpenWith() async {
    final targetId = widget.openWithUserId;
    if (targetId == null || targetId == 0) return;
    final existing = _conversations.where((c) => c.other.id == targetId).firstOrNull;
    if (existing != null) {
      if (mounted) setState(() => _active = existing);
      return;
    }
    try {
      final conv = await DmApi(ref.read(apiClientProvider)).createConversation(targetId);
      if (!_conversations.any((c) => c.id == conv.id)) {
        _conversations.insert(0, conv);
      }
      if (mounted) setState(() => _active = conv);
    } catch (_) {}
  }

  void _setupWs() {
    final ws = ref.read(wsManagerProvider);
    _wsKey = ws.addListener((_) {});
    ws.on(_wsKey, WsEventType.dmMessage, (event) {
      final data = event.data;
      if (data == null) return;
      final convId = data['conversation_id'] as int? ?? 0;
      final idx = _conversations.indexWhere((c) => c.id == convId);
      if (idx >= 0) {
        final conv = _conversations.removeAt(idx);
        final msgData = data['data'] as Map<String, dynamic>? ?? data;
        final isActive = _active?.id == convId;
        final newUnread = isActive ? 0 : conv.unreadCount + 1;
        final updated = conv.copyWith(
          lastMessage: DmLastMessage(
            id: msgData['id'] as int? ?? 0,
            text: msgData['text'] as String? ?? '',
            userId: msgData['user_id'] as int? ?? 0,
            createdAt: msgData['created_at'] as String?,
          ),
          unreadCount: newUnread,
        );
        if (mounted) setState(() => _conversations.insert(0, updated));
      } else {
        _loadConversations();
      }
    });

    ws.on(_wsKey, WsEventType.dmRequestStatus, (event) {
      _loadConversations();
    });
  }

  @override
  void dispose() {
    ref.read(wsManagerProvider).removeListener(_wsKey);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final api = DmApi(ref.read(apiClientProvider));
      final results = await Future.wait([
        api.listConversations(),
        api.listRequests(),
        api.getPolicy(),
      ]);
      if (mounted) {
        setState(() {
          _conversations = results[0] as List<DmConversation>;
          _requests = results[1] as List<DmConversation>;
          _dmPolicy = results[2] as String;
          _loadingConvs = false;
          if (_dmPolicy != 'friends' && _activeTab == 'requests') {
            _activeTab = 'messages';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingConvs = false);
    }
  }

  void _selectConversation(DmConversation conv) {
    setState(() => _active = conv);
  }

  Future<void> _acceptRequest(int convId) async {
    try {
      final api = DmApi(ref.read(apiClientProvider));
      await api.acceptRequest(convId);
      final idx = _requests.indexWhere((c) => c.id == convId);
      if (idx >= 0) {
        final conv = _requests.removeAt(idx);
        final updated = conv.copyWith(requestStatus: 'none');
        _conversations.insert(0, updated);
        if (_active?.id == convId) _active = updated;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _rejectRequest(int convId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отклонить запрос?'),
        content: const Text('Отправитель узнает об этом и не сможет написать снова, пока вы не станете друзьями.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отклонить')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = DmApi(ref.read(apiClientProvider));
      await api.rejectRequest(convId);
      _requests.removeWhere((c) => c.id == convId);
      if (_active?.id == convId) _active = null;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final auth = ref.watch(authProvider);

    return isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 320,
                  child: _ConversationList(
                    conversations: _filteredConvs,
                    loading: _loadingConvs,
                    activeId: _active?.id,
                    c: c,
                    currentUserId: auth.user?.id ?? 0,
                    searchCtrl: _searchCtrl,
                    onSearch: () => setState(() {}),
                    onSelect: _selectConversation,
                    showTabs: _dmPolicy == 'friends',
                    activeTab: _activeTab,
                    requestCount: _requests.length,
                    onTabChanged: (tab) => setState(() => _activeTab = tab),
                    onAccept: _acceptRequest,
                    onReject: _rejectRequest,
                  ),
                ),
                VerticalDivider(width: 1, color: c.border),
                Expanded(
                  child: _active != null
                      ? _MessageThread(
                          key: ValueKey(_active!.id),
                          conversation: _active!,
                          c: c,
                          ref: ref,
                          onBack: null,
                          onConversationUpdated: _loadConversations,
                          onAccept: _acceptRequest,
                          onReject: _rejectRequest,
                        )
                      : Center(child: Text('Выберите диалог', style: TextStyle(color: c.textSecondary, fontSize: 15))),
                ),
              ],
            )
          : _active != null
              ? _MessageThread(
                  key: ValueKey(_active!.id),
                  conversation: _active!,
                  c: c,
                  ref: ref,
                  onBack: () => setState(() => _active = null),
                  onConversationUpdated: _loadConversations,
                  onAccept: _acceptRequest,
                  onReject: _rejectRequest,
                )
              : _ConversationList(
                  conversations: _filteredConvs,
                  loading: _loadingConvs,
                  activeId: null,
                  c: c,
                  currentUserId: auth.user?.id ?? 0,
                  searchCtrl: _searchCtrl,
                  onSearch: () => setState(() {}),
                  onSelect: _selectConversation,
                  showTabs: _dmPolicy == 'friends',
                  activeTab: _activeTab,
                  requestCount: _requests.length,
                  onTabChanged: (tab) => setState(() => _activeTab = tab),
                  onAccept: _acceptRequest,
                  onReject: _rejectRequest,
                );
  }

  List<DmConversation> get _currentList {
    final showTabs = _dmPolicy == 'friends';
    return (_activeTab == 'requests' && showTabs) ? _requests : _conversations;
  }

  List<DmConversation> get _filteredConvs {
    final list = _currentList;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) => c.other.name.toLowerCase().contains(q)).toList();
  }
}

// ─── CONVERSATION LIST ─────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final List<DmConversation> conversations;
  final bool loading;
  final int? activeId;
  final ColorSet c;
  final int currentUserId;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final void Function(DmConversation) onSelect;
  final bool showTabs;
  final String activeTab;
  final int requestCount;
  final void Function(String) onTabChanged;
  final Future<void> Function(int) onAccept;
  final Future<void> Function(int) onReject;

  const _ConversationList({
    required this.conversations, required this.loading, this.activeId,
    required this.c, required this.currentUserId, required this.searchCtrl,
    required this.onSearch, required this.onSelect,
    required this.showTabs, required this.activeTab, required this.requestCount,
    required this.onTabChanged, required this.onAccept, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isRequestsTab = activeTab == 'requests' && showTabs;
    final emptyText = isRequestsTab ? 'Нет новых запросов' : 'Нет диалогов';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchCtrl,
            onChanged: (_) => onSearch(),
            style: TextStyle(fontSize: 14, color: c.text),
            decoration: InputDecoration(
              hintText: 'Поиск...',
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 14),
              prefixIcon: Icon(Icons.search, size: 18, color: c.textSecondary),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
              filled: true, fillColor: c.surface, isDense: true,
            ),
          ),
        ),
        if (showTabs && searchCtrl.text.trim().length < 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(child: _buildTab('messages', 'Сообщения', null)),
                const SizedBox(width: 4),
                Expanded(child: _buildTab('requests', 'Запросы', requestCount > 0 ? requestCount : null)),
              ],
            ),
          ),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : conversations.isEmpty
                  ? Center(child: Text(emptyText, style: TextStyle(color: c.textSecondary)))
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final isActive = conv.id == activeId;
                        return _ConversationTile(
                          key: ValueKey(conv.id),
                          conversation: conv, c: c, active: isActive,
                          currentUserId: currentUserId,
                          onTap: () => onSelect(conv),
                          isRequestsTab: isRequestsTab,
                          onAccept: () => onAccept(conv.id),
                          onReject: () => onReject(conv.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildTab(String tab, String label, int? count) {
    final isActive = activeTab == tab;
    return GestureDetector(
      onTap: () => onTabChanged(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : c.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withValues(alpha: 0.25) : c.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final DmConversation conversation;
  final ColorSet c;
  final bool active;
  final int currentUserId;
  final VoidCallback onTap;
  final bool isRequestsTab;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  const _ConversationTile({super.key, required this.conversation, required this.c, required this.active, required this.currentUserId, required this.onTap, this.isRequestsTab = false, this.onAccept, this.onReject});

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovered = false;

  static String _fmtConvTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
      return 'Вчера';
    }
    if (dt.year == now.year) {
      const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${dt.day} ${months[dt.month - 1]}';
    }
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _preview(DmConversation conv) {
    final lm = conv.lastMessage;
    if (lm == null) return '';
    final msgType = lm.messageType;
    if (msgType == 'missed_call') {
      return lm.userId == widget.currentUserId ? 'Исходящий звонок' : 'Пропущенный звонок';
    }
    if (msgType == 'call_ended') return 'Звонок завершён';
    if (lm.text.isNotEmpty) return lm.text;
    final att = lm.attachmentCount;
    final img = lm.imageCount;
    if (att > 0) {
      if (img == att) return img == 1 ? 'Фото' : 'Фото ($img)';
      if (img == 0) return att == 1 ? 'Файл' : 'Файлы ($att)';
      return 'Вложения ($att)';
    }
    return '';
  }

  IconData? _previewIcon(DmConversation conv) {
    final lm = conv.lastMessage;
    if (lm == null) return null;
    if (lm.messageType == 'missed_call' || lm.messageType == 'call_ended') return Icons.call;
    if (lm.attachmentCount > 0 && lm.imageCount == lm.attachmentCount) return Icons.photo_outlined;
    if (lm.attachmentCount > 0) return Icons.attach_file;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final conv = widget.conversation;
    final other = conv.other;
    final preview = _preview(conv);
    final previewIcon = _previewIcon(conv);
    final rawTime = conv.lastMessageAt ?? conv.lastMessage?.createdAt ?? '';
    final timeStr = rawTime.isNotEmpty ? _fmtConvTime(DateTime.tryParse(rawTime)) : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active ? c.activeOverlay : (_hovered ? c.hoverOverlay : Colors.transparent),
            border: widget.active ? Border(left: BorderSide(color: c.accent, width: 3)) : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor(other.id),
                backgroundImage: other.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(other.avatarUrl!)) : null,
                child: other.avatarUrl?.isNotEmpty != true
                    ? Text(other.initial, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(other.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (timeStr.isNotEmpty)
                          Text(timeStr, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (previewIcon != null) ...[
                          Icon(previewIcon, size: 13, color: conv.lastMessage?.messageType == 'missed_call' ? c.error : c.textSecondary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            style: TextStyle(fontSize: 13, color: c.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!widget.isRequestsTab && conv.isPending)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFF5B518), borderRadius: BorderRadius.circular(10)),
                            child: const Text('ЖДЁТ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: 0.3)),
                          )
                        else if (conv.isRejected)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFDD1144), borderRadius: BorderRadius.circular(10)),
                            child: const Text('ОТКЛОНЕНО', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                          )
                        else if (conv.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    if (widget.isRequestsTab) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onAccept,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(6)),
                                alignment: Alignment.center,
                                child: const Text('Принять', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: widget.onReject,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: c.border),
                                ),
                                alignment: Alignment.center,
                                child: Text('Отклонить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MESSAGE THREAD ────────────────────────────────────────────────

class _MessageThread extends ConsumerStatefulWidget {
  final DmConversation conversation;
  final ColorSet c;
  final WidgetRef ref;
  final VoidCallback? onBack;
  final VoidCallback onConversationUpdated;
  final Future<void> Function(int) onAccept;
  final Future<void> Function(int) onReject;

  const _MessageThread({
    super.key, required this.conversation, required this.c,
    required this.ref, this.onBack, required this.onConversationUpdated,
    required this.onAccept, required this.onReject,
  });

  @override
  ConsumerState<_MessageThread> createState() => _MessageThreadState();
}

class _MessageThreadState extends ConsumerState<_MessageThread> {
  static const _maxMessages = 150;

  late final DmApi _dmApi;
  late final WsManager _ws;
  final _messages = <ChatMessage>[];
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  String _floatingDate = '';
  bool _floatingDateVisible = false;
  Timer? _floatingDateTimer;
  bool _hasMore = true;
  bool _hasNewer = false;
  ChatMessage? _replyTo;
  // ignore: unused_field
  int? _otherLastReadId;
  bool _peerTyping = false;
  Timer? _typingTimer;
  String _listenerKey = '';
  final _searchCtrl = TextEditingController();
  List<ChatMessage> _searchResults = [];
  bool _searchLoading = false;
  int? _highlightedMessageId;
  Timer? _highlightTimer;
  double _voicePanelHeight = 0;

  @override
  void initState() {
    super.initState();
    _dmApi = DmApi(ref.read(apiClientProvider));
    _ws = ref.read(wsManagerProvider);
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _setupWs();
  }

  void _setupWs() {
    _listenerKey = _ws.addListener((_) {});

    _ws.on(_listenerKey, WsEventType.dmMessage, (event) {
      final data = event.data;
      if (data == null) return;
      final convId = data['conversation_id'] as int? ?? 0;
      if (convId != widget.conversation.id) return;
      final msgData = data['data'] as Map<String, dynamic>? ?? data;
      final msg = ChatMessage.fromJson(msgData);
      if (mounted && !_hasNewer) {
        setState(() {
          _messages.insert(0, msg);
          _peerTyping = false;
        });
        _markAsRead(msg.id);
      }
    });

    _ws.on(_listenerKey, WsEventType.dmMessageDeleted, (event) {
      final data = event.data;
      if (data == null) return;
      final msgId = data['message_id'] as int? ?? 0;
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == msgId));
    });

    _ws.on(_listenerKey, WsEventType.dmRead, (event) {
      final data = event.data;
      if (data == null) return;
      final convId = data['conversation_id'] as int? ?? 0;
      if (convId != widget.conversation.id) return;
      final lastReadId = data['last_read_message_id'] as int?;
      if (lastReadId != null && mounted) {
        setState(() => _otherLastReadId = lastReadId);
      }
    });

    _ws.on(_listenerKey, WsEventType.dmTyping, (event) {
      final data = event.data;
      if (data == null) return;
      final convId = data['conversation_id'] as int? ?? 0;
      if (convId != widget.conversation.id) return;
      final stop = data['stop'] as bool? ?? (data['data'] as Map<String, dynamic>?)?['stop'] as bool? ?? false;
      if (mounted) {
        setState(() => _peerTyping = !stop);
        _typingTimer?.cancel();
        if (!stop) {
          _typingTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _peerTyping = false);
          });
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final result = await _dmApi.listMessages(widget.conversation.id);
      if (mounted) {
        setState(() {
          _messages.addAll(result.messages.reversed);
          _otherLastReadId = result.otherLastReadId;
          _loading = false;
          _hasMore = result.messages.length >= 50;
          _hasNewer = false;
        });
        if (_messages.isNotEmpty) _markAsRead(_messages.first.id);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _dmApi.listMessages(widget.conversation.id, before: _messages.last.id);
      if (mounted) {
        setState(() {
          _messages.addAll(result.messages.reversed);
          _hasMore = result.messages.length >= 50;
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

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
    if (_hasNewer && pos.pixels <= 100) {
      _reloadLatest();
    }
    _updateFloatingDate();
  }

  Future<void> _reloadLatest() async {
    if (!_hasNewer) return;
    setState(() { _loading = true; _messages.clear(); });
    await _loadMessages();
  }

  Future<void> _jumpToDate(DateTime date) async {
    try {
      final iso = date.toIso8601String().split('T').first;
      final anchorId = await _dmApi.findMessageByDate(widget.conversation.id, iso);
      if (anchorId <= 0 || !mounted) return;
      final data = await _dmApi.messagesAround(widget.conversation.id, anchorId);
      final items = (data['items'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [];
      if (items.isEmpty || !mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(items.toList()..sort((a, b) => b.id.compareTo(a.id)));
        _hasMore = true;
        _hasNewer = true;
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
        setState(() {
          _floatingDate = formatted;
          _floatingDateVisible = true;
        });
      } else if (!_floatingDateVisible) {
        setState(() => _floatingDateVisible = true);
      }
    }
    _floatingDateTimer?.cancel();
    _floatingDateTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _floatingDateVisible = false);
    });
  }

  Widget _buildMessageList(ColorSet c, int? currentUserId) {
    final allImages = _messages.reversed.expand((m) => m.attachments.where((a) => a.type.startsWith('image/'))).toList();
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
            final showAuthor = !isOwn && (prevMsg == null || prevMsg.userId != msg.userId);

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
                          _formatDate(msgDate!),
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
                  child: MessageBubble(
                    key: ValueKey(msg.id),
                    message: msg,
                    isOwn: isOwn,
                    showAuthor: showAuthor,
                    allChatImages: allImages,
                    onReply: () => setState(() => _replyTo = msg),
                    onDelete: isOwn ? () => _deleteMessage(msg.id) : null,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.92),
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: Text(_floatingDate, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _sendMessageComposer(String text, {int replyToMessageId = 0, List<Map<String, dynamic>>? attachments}) async {
    final msg = await _dmApi.sendMessage(
      widget.conversation.id,
      text,
      replyToId: replyToMessageId > 0 ? replyToMessageId : null,
      attachments: attachments,
    );
    if (mounted && !_messages.any((m) => m.id == msg.id)) {
      setState(() => _messages.insert(0, msg));
    }
    widget.onConversationUpdated();
  }

  Future<String?> _uploadFile(Uint8List bytes, String filename, String contentType) async {
    final uploadsApi = UploadsApi(ref.read(apiClientProvider));
    final result = await uploadsApi.upload(bytes: bytes, filename: filename, contentType: contentType);
    return result.url;
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await _dmApi.deleteMessage(messageId);
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == messageId));
    } catch (_) {}
  }

  void _markAsRead(int messageId) {
    _dmApi.markAsRead(widget.conversation.id, messageId).catchError((_) {});
  }

  Widget _buildSearchResults(ColorSet c) {
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
                        Text(
                          r.text.isNotEmpty ? r.text : (r.attachments.isNotEmpty ? 'Вложение' : ''),
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
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
      final results = await _dmApi.searchMessages(query, conversationId: widget.conversation.id);
      if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _jumpToSearchResult(int anchorId) async {
    try {
      final data = await _dmApi.messagesAround(widget.conversation.id, anchorId);
      final items = (data['items'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [];
      if (items.isEmpty || !mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(items.toList()..sort((a, b) => b.id.compareTo(a.id)));
        _hasMore = true;
        _hasNewer = true;
        _searchResults = [];
        _searchCtrl.clear();
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

  void _onTypingChanged(bool hasText) {
    _ws.sendRaw({
      'action': 'dm.typing',
      'conversation_id': widget.conversation.id,
      'target_user_id': widget.conversation.other.id,
      'stop': !hasText,
    });
  }

  bool _isComposerHidden(int? currentUserId) {
    final conv = widget.conversation;
    if (conv.isRejected) return true;
    if (conv.isPending && conv.lastMessage?.userId != currentUserId) return true;
    return false;
  }

  Widget _buildRequestBanner(ColorSet c, int? currentUserId) {
    final conv = widget.conversation;
    if (conv.isPending && conv.lastMessage?.userId == currentUserId) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5B518).withValues(alpha: 0.14),
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Text(
          'Ожидаем, пока получатель примет ваш запрос',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFC78900)),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (conv.isPending && conv.lastMessage?.userId != currentUserId) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Этот человек хочет вам написать. Примите, чтобы продолжить диалог.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.text),
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => widget.onAccept(conv.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Принять', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => widget.onReject(conv.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: c.border),
                    ),
                    child: Text('Отклонить', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (conv.isRejected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDD1144).withValues(alpha: 0.12),
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: const Text(
          'Ваш запрос отклонён — отправка сообщений недоступна',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFDD1144)),
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _ws.removeListener(_listenerKey);
    _scrollController.dispose();
    _searchCtrl.dispose();
    _typingTimer?.cancel();
    _floatingDateTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final other = widget.conversation.other;
    final currentUserId = ref.watch(authProvider).user?.id;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(icon: Icon(Icons.arrow_back, size: 20, color: c.text), onPressed: widget.onBack, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
                const SizedBox(width: 2),
              ],
              CircleAvatar(
                radius: 16,
                backgroundColor: avatarColor(other.id),
                backgroundImage: other.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(other.avatarUrl!)) : null,
                child: other.avatarUrl?.isNotEmpty != true
                    ? Text(other.initial, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(other.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                  if (_peerTyping)
                    Text('печатает...', style: TextStyle(fontSize: 11, color: c.accent)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: _searchCtrl,
                    style: TextStyle(fontSize: 12, color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Поиск...',
                      hintStyle: TextStyle(color: c.textSecondary, fontSize: 12),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 4),
                        child: Icon(Icons.search, size: 14, color: c.textSecondary),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _searchCtrl.clear(); setState(() => _searchResults = []); },
                              child: Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.close, size: 12, color: c.textSecondary)),
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
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (_hasNewer)
                IconButton(icon: Icon(Icons.arrow_downward, size: 16, color: c.accent), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), onPressed: () { setState(() { _loading = true; _messages.clear(); }); _loadMessages(); }),
              IconButton(
                icon: Icon(Icons.calendar_month, size: 18, color: c.textSecondary),
                tooltip: 'Перейти к дате',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) _jumpToDate(picked);
                },
              ),
              IconButton(
                icon: Icon(Icons.call_outlined, size: 18, color: c.textSecondary),
                tooltip: 'Аудиозвонок',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  final cs = ref.read(callSessionProvider.notifier);
                  cs.startCall(other.id, peerHint: CallPeer(userId: other.id, username: other.username, displayName: other.displayName, avatarUrl: other.avatarUrl));
                },
              ),
              IconButton(
                icon: Icon(Icons.videocam_outlined, size: 18, color: c.textSecondary),
                tooltip: 'Видеозвонок',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  final cs = ref.read(callSessionProvider.notifier);
                  cs.startCall(other.id, peerHint: CallPeer(userId: other.id, username: other.username, displayName: other.displayName, avatarUrl: other.avatarUrl), video: true);
                },
              ),
            ],
          ),
        ),
        if (_searchResults.isNotEmpty)
          _buildSearchResults(c),
        _buildRequestBanner(c, currentUserId),
        Consumer(builder: (ctx, ref, _) {
          final call = ref.watch(callSessionProvider);
          final vs = ref.watch(voiceSessionProvider);
          if (call.status == CallStatus.active && call.peer?.userId == other.id && call.voicePageId != null && call.voicePageId! > 0) {
            final screenH = MediaQuery.of(context).size.height;
            if (_voicePanelHeight == 0) _voicePanelHeight = screenH * 0.4;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _voicePanelHeight.clamp(200.0, screenH * 0.7),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: VoiceRoomView(
                      pageId: call.voicePageId!,
                      pageTitle: other.name,
                      communitySlug: '',
                      c: c,
                      embedded: true,
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) {
                      setState(() => _voicePanelHeight = (_voicePanelHeight + d.delta.dy).clamp(200.0, screenH * 0.7));
                    },
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Center(child: Container(width: 32, height: 3, decoration: BoxDecoration(color: c.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
                    ),
                  ),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        }),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : _messages.isEmpty
                  ? Center(child: Text('Начните диалог', style: TextStyle(color: c.textSecondary)))
                  : _buildMessageList(c, currentUserId),
        ),

        if (_peerTyping && !_isComposerHidden(currentUserId))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            alignment: Alignment.centerLeft,
            child: Text('${other.name} печатает...', style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
          ),
        if (!_isComposerHidden(currentUserId))
          ChatComposer(
            onSend: _sendMessageComposer,
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            enabled: true,
            onUpload: _uploadFile,
            onTypingChanged: (isTyping) => _onTypingChanged(isTyping),
          ),
      ],
    );
  }
}
