import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../data/api/friends_api.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import '../../../core/utils/time_ago.dart';

class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FriendListEntry>? _friends;
  List<FriendRequestEntry>? _incoming;
  List<FriendRequestEntry>? _outgoing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = FriendsApi(ref.read(apiClientProvider));
    try {
      final results = await Future.wait([api.list(), api.incoming(), api.outgoing()]);
      if (mounted) {
        setState(() {
          _friends = results[0] as List<FriendListEntry>;
          _incoming = results[1] as List<FriendRequestEntry>;
          _outgoing = results[2] as List<FriendRequestEntry>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(int friendshipId) async {
    final api = FriendsApi(ref.read(apiClientProvider));
    await api.accept(friendshipId);
    _load();
  }

  Future<void> _reject(int friendshipId) async {
    final api = FriendsApi(ref.read(apiClientProvider));
    await api.reject(friendshipId);
    _load();
  }

  Future<void> _unfriend(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить из друзей?'),
        content: const Text('Пользователь будет удалён из списка друзей.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = FriendsApi(ref.read(apiClientProvider));
    await api.unfriend(userId);
    _load();
  }

  Future<void> _cancelRequest(int friendshipId) async {
    final api = FriendsApi(ref.read(apiClientProvider));
    await api.reject(friendshipId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Друзья', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Управление списком друзей и запросами', style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color)),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Друзья${_friends != null ? ' (${_friends!.length})' : ''}'),
            Tab(text: 'Входящие${_incoming != null ? ' (${_incoming!.length})' : ''}'),
            Tab(text: 'Исходящие${_outgoing != null ? ' (${_outgoing!.length})' : ''}'),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(theme),
                _buildIncoming(theme),
                _buildOutgoing(theme),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFriendsList(ThemeData theme) {
    if (_friends == null || _friends!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: theme.textTheme.bodySmall?.color),
            const SizedBox(height: 12),
            Text('Друзей пока нет', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _friends!.length,
      itemBuilder: (context, i) {
        final f = _friends![i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor(f.user.id),
                backgroundImage: f.user.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(f.user.avatarUrl!)) : null,
                child: f.user.avatarUrl?.isNotEmpty != true
                    ? Text(f.user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.user.effectiveName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Друзья с ${_safeTimeAgo(f.friendSince)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.message_outlined, size: 18),
                tooltip: 'Написать',
                onPressed: () => context.push('/messages?open=${f.user.id}'),
              ),
              IconButton(
                icon: Icon(Icons.person_remove_outlined, size: 18, color: theme.colorScheme.error),
                tooltip: 'Удалить из друзей',
                onPressed: () => _unfriend(f.user.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncoming(ThemeData theme) {
    if (_incoming == null || _incoming!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: theme.textTheme.bodySmall?.color),
            const SizedBox(height: 12),
            Text('Нет входящих запросов', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _incoming!.length,
      itemBuilder: (context, i) {
        final r = _incoming![i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor(r.user.id),
                backgroundImage: r.user.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(r.user.avatarUrl!)) : null,
                child: r.user.avatarUrl?.isNotEmpty != true
                    ? Text(r.user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(r.user.effectiveName, style: const TextStyle(fontWeight: FontWeight.w500))),
              OutlinedButton(
                onPressed: () => _accept(r.friendshipId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Принять', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _reject(r.friendshipId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Отклонить', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutgoing(ThemeData theme) {
    if (_outgoing == null || _outgoing!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_outlined, size: 48, color: theme.textTheme.bodySmall?.color),
            const SizedBox(height: 12),
            Text('Нет исходящих запросов', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _outgoing!.length,
      itemBuilder: (context, i) {
        final r = _outgoing![i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor(r.user.id),
                backgroundImage: r.user.avatarUrl?.isNotEmpty == true ? NetworkImage(fullImageUrl(r.user.avatarUrl!)) : null,
                child: r.user.avatarUrl?.isNotEmpty != true
                    ? Text(r.user.username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.user.effectiveName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Отправлено ${_safeTimeAgo(r.createdAt)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _cancelRequest(r.friendshipId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Отменить', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _safeTimeAgo(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return timeAgo(dt);
  }
}
