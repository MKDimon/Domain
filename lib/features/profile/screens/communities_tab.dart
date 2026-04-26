import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/api/communities_api.dart';
import '../../../data/models/community.dart';
import '../../../providers/auth_provider.dart';

class CommunitiesTab extends ConsumerStatefulWidget {
  const CommunitiesTab({super.key});

  @override
  ConsumerState<CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<CommunitiesTab> {
  List<Community> _communities = [];
  List<_DeletedCommunity> _deleted = [];
  int _graceDays = 30;
  bool _loading = true;
  int? _restoringId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final comms = await api.listForMe();
      final enriched = await api.enrichListWithCounts(comms);

      List<_DeletedCommunity> deleted = [];
      int grace = 30;
      try {
        final data = await ref.read(apiClientProvider).get<Map<String, dynamic>>('/users/me/deleted-communities');
        grace = data['grace_days'] as int? ?? 30;
        final items = data['items'] as List<dynamic>? ?? [];
        deleted = items.map((e) => _DeletedCommunity.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _communities = enriched;
          _deleted = deleted;
          _graceDays = grace;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(int id) async {
    setState(() => _restoringId = id);
    try {
      await ref.read(apiClientProvider).post('/communities/$id/restore');
      _load();
    } catch (_) {
      if (mounted) setState(() => _restoringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final tier = user?.subscription?.tier ?? 'free';
    final limit = tier == 'pro' ? 10 : 3;
    final owned = _communities.where((c) => c.myRole == 'owner').toList();
    final overLimit = owned.length > limit ? owned.length - limit : 0;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сообщества', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Ваш лимит: $limit сообществ ($tier)',
                      style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => context.goNamed('explore'),
                child: const Text('Найти'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (overLimit > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF59E0B).withValues(alpha: 0.08), const Color(0xFFF59E0B).withValues(alpha: 0.02)],
                ),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'У вас $overLimit сообществ сверх лимита. Перейдите на Pro.',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/app/profile/billing'),
                    child: const Text('Upgrade'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_communities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined, size: 48, color: theme.textTheme.bodySmall?.color),
                    const SizedBox(height: 12),
                    Text('Вы не состоите ни в одном сообществе', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.goNamed('explore'),
                      child: const Text('Найти сообщество'),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(_communities.length, (i) {
                  final comm = _communities[i];
                  final isOwner = comm.myRole == 'owner';
                  final isOverLimit = isOwner && owned.indexOf(comm) >= limit;
                  final role = _roleLabel(comm.myRole);

                  return InkWell(
                    onTap: () => context.goNamed('community', pathParameters: {'slug': comm.slug}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: i < _communities.length - 1
                          ? BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor)))
                          : null,
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [theme.colorScheme.primary, const Color(0xFF8456DD)],
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: comm.avatarUrl?.isNotEmpty == true
                                ? Image.network(fullImageUrl(comm.avatarUrl!), fit: BoxFit.cover, width: 42, height: 42)
                                : Center(child: Text(comm.initial, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(comm.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                    if (isOverLimit) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Text('ЛИМИТ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${comm.memberCount} участников · ${comm.pageCount} страниц',
                                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                                ),
                              ],
                            ),
                          ),
                          Text(role, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

          if (_deleted.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Удалённые', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Сообщества можно восстановить в течение $_graceDays дней.',
              style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: _deleted.map((d) {
                  final daysLeft = d.daysLeft(_graceDays);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                daysLeft > 0 ? '$daysLeft дней осталось' : 'Скоро будет удалено',
                                style: TextStyle(fontSize: 12, color: const Color(0xFFF59E0B)),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _restoringId == d.id ? null : () => _restore(d.id),
                          child: _restoringId == d.id
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Восстановить'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(String? role) => switch (role) {
    'owner' => 'Владелец',
    'moderator' => 'Модератор',
    _ => 'Участник',
  };
}

class _DeletedCommunity {
  final int id;
  final String name;
  final String deletedAt;

  _DeletedCommunity({required this.id, required this.name, required this.deletedAt});

  int daysLeft(int graceDays) {
    try {
      final deleted = DateTime.parse(deletedAt);
      final deadline = deleted.add(Duration(days: graceDays));
      return deadline.difference(DateTime.now()).inDays;
    } catch (_) {
      return graceDays;
    }
  }

  factory _DeletedCommunity.fromJson(Map<String, dynamic> json) => _DeletedCommunity(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    deletedAt: json['deleted_at'] as String? ?? '',
  );
}
