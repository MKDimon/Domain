import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/websocket/ws_manager.dart';
import '../../../data/api/chat_api.dart';
import '../../../data/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import 'chat_section_widget.dart';

class InboxChatWidget extends ConsumerStatefulWidget {
  final int sectionId;
  final bool isStaff;

  const InboxChatWidget({
    super.key,
    required this.sectionId,
    required this.isStaff,
  });

  @override
  ConsumerState<InboxChatWidget> createState() => _InboxChatWidgetState();
}

class _InboxChatWidgetState extends ConsumerState<InboxChatWidget> {
  late final ChatApi _chatApi;
  late final WsManager _ws;
  String _wsKey = '';

  List<ChatConversation> _conversations = [];
  bool _loadingConvs = true;
  ChatConversation? _active;
  final _searchCtrl = TextEditingController();
  int? _userConvId;
  bool _loadingUserConv = true;

  @override
  void initState() {
    super.initState();
    _chatApi = ChatApi(ref.read(apiClientProvider));
    _ws = ref.read(wsManagerProvider);
    if (widget.isStaff) {
      _loadConversations();
    } else {
      _loadUserConversation();
    }
    _setupWs();
  }

  void _setupWs() {
    _wsKey = _ws.addListener((_) {});
    _ws.subscribe(widget.sectionId);

    _ws.on(_wsKey, WsEventType.messageCreated, (event) {
      final data = event.data;
      if (data == null) return;
      final sectionId = data['section_id'] as int? ?? 0;
      if (sectionId != widget.sectionId) return;

      if (widget.isStaff) {
        _loadConversations();
      }
    });

    _ws.on(_wsKey, WsEventType.conversationUpdated, (event) {
      if (widget.isStaff) _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    try {
      final convs = await _chatApi.getConversations(widget.sectionId);
      convs.sort((a, b) {
        if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
        if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
        return (b.updatedAt).compareTo(a.updatedAt);
      });
      if (mounted) setState(() { _conversations = convs; _loadingConvs = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingConvs = false);
    }
  }

  Future<void> _loadUserConversation() async {
    try {
      final convs = await _chatApi.getConversations(widget.sectionId);
      final userId = ref.read(authProvider).user?.id;
      final myConv = convs.where((c) => c.userId == userId).toList();
      if (myConv.isNotEmpty) {
        _userConvId = myConv.first.id;
      }
      if (mounted) setState(() => _loadingUserConv = false);
    } catch (_) {
      if (mounted) setState(() => _loadingUserConv = false);
    }
  }

  @override
  void dispose() {
    _ws.unsubscribe(widget.sectionId);
    _ws.removeListener(_wsKey);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (!widget.isStaff) return _buildUserView(c);

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: _glassWrap(c, child: _buildSidebar(c)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _active != null
                  ? ChatSectionWidget(
                      key: ValueKey('inbox_${_active!.id}'),
                      sectionId: widget.sectionId,
                      conversationId: _active!.id,
                    )
                  : _glassWrap(c, child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.inboxSelectConversation,
                        style: TextStyle(color: c.textSecondary, fontSize: 15),
                      ),
                    )),
            ),
          ],
        ),
      );
    }

    if (_active != null) {
      return Column(
        children: [
          _buildMobileHeader(c),
          Expanded(
            child: ChatSectionWidget(
              key: ValueKey('inbox_${_active!.id}'),
              sectionId: widget.sectionId,
              conversationId: _active!.id,
            ),
          ),
        ],
      );
    }

    return _buildSidebar(c);
  }

  Widget _glassWrap(ColorSet c, {required Widget child}) {
    return ClipRRect(
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
          child: child,
        ),
      ),
    );
  }

  Widget _buildUserView(ColorSet c) {
    if (_loadingUserConv) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }
    return ChatSectionWidget(
      key: ValueKey('inbox_user_${_userConvId ?? 0}'),
      sectionId: widget.sectionId,
      conversationId: _userConvId,
    );
  }

  Widget _buildMobileHeader(ColorSet c) {
    final conv = _active!;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: 20, color: c.text),
            onPressed: () => setState(() => _active = null),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 14,
            backgroundColor: avatarColor(conv.userId),
            backgroundImage: conv.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(conv.avatarUrl!)) : null,
            child: conv.avatarUrl?.isNotEmpty != true
                ? Text(conv.initial, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(conv.authorName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ColorSet c) {
    final l10n = AppLocalizations.of(context)!;
    final filteredConvs = _filteredConversations;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.inboxConversations, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13, color: c.text),
                decoration: InputDecoration(
                  hintText: l10n.chatSearchMessages,
                  hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 16, color: c.textSecondary),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.accent)),
                  filled: true, fillColor: c.surfaceAlt, isDense: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingConvs
              ? Center(child: CircularProgressIndicator(color: c.accent))
              : filteredConvs.isEmpty
                  ? Center(child: Text(l10n.inboxNoConversations, style: TextStyle(color: c.textSecondary, fontSize: 14)))
                  : ListView.builder(
                      itemCount: filteredConvs.length,
                      itemBuilder: (context, index) {
                        final conv = filteredConvs[index];
                        final isActive = conv.id == _active?.id;
                        return _InboxConvTile(
                          conv: conv,
                          c: c,
                          active: isActive,
                          onTap: () => setState(() => _active = conv),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  List<ChatConversation> get _filteredConversations {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((c) =>
        c.authorName.toLowerCase().contains(q) ||
        (c.lastMessageText ?? '').toLowerCase().contains(q)
    ).toList();
  }
}

class _InboxConvTile extends StatefulWidget {
  final ChatConversation conv;
  final ColorSet c;
  final bool active;
  final VoidCallback onTap;

  const _InboxConvTile({required this.conv, required this.c, required this.active, required this.onTap});

  @override
  State<_InboxConvTile> createState() => _InboxConvTileState();
}

class _InboxConvTileState extends State<_InboxConvTile> {
  bool _hovered = false;

  static String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '';
    if (diff.inMinutes < 60) return '${diff.inMinutes}м';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) return 'Вчера';
    if (dt.year == now.year) {
      const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${dt.day} ${months[dt.month - 1]}';
    }
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final conv = widget.conv;
    final timeStr = _fmtTime(conv.lastMessageAt ?? conv.updatedAt);
    final rawText = conv.lastMessageText ?? '';
    final preview = rawText.isNotEmpty ? rawText : (conv.messageCount > 0 ? 'Вложение' : '');

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
                radius: 18,
                backgroundColor: avatarColor(conv.userId),
                backgroundImage: conv.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(conv.avatarUrl!)) : null,
                child: conv.avatarUrl?.isNotEmpty != true
                    ? Text(conv.initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.authorName,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(timeStr, style: TextStyle(fontSize: 10, color: c.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
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
}
