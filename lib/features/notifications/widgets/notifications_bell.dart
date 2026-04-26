import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../data/api/notifications_api.dart';

final unreadCountProvider = StateProvider<int>((ref) => 0);

class NotificationsBell extends ConsumerStatefulWidget {
  final Color iconColor;
  final Color? hoverColor;
  final Color? badgeColor;
  final Color? highlightColor;
  final VoidCallback onTap;
  const NotificationsBell({
    super.key,
    required this.iconColor,
    this.hoverColor,
    this.badgeColor,
    this.highlightColor,
    required this.onTap,
  });

  @override
  ConsumerState<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends ConsumerState<NotificationsBell> {
  Timer? _pollTimer;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final api = NotificationsApi(ref.read(apiClientProvider));
      final count = await api.unreadCount();
      if (mounted) ref.read(unreadCountProvider.notifier).state = count;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: () {},
        child: Listener(
          onPointerDown: (_) => widget.onTap(),
          child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _hovered ? (widget.highlightColor ?? Colors.white.withValues(alpha: 0.08)) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              Center(child: Icon(
                Icons.notifications_outlined, size: 20,
                color: _hovered ? (widget.hoverColor ?? widget.iconColor) : widget.iconColor,
              )),
              if (count > 0)
                Positioned(
                  top: 2, right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: widget.badgeColor ?? Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
