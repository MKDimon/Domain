import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../data/api/invites_api.dart';

class InviteJoinScreen extends ConsumerStatefulWidget {
  final String token;
  const InviteJoinScreen({super.key, required this.token});

  @override
  ConsumerState<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends ConsumerState<InviteJoinScreen> {
  bool _loading = true;
  String? _error;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      final api = InvitesApi(ref.read(apiClientProvider));
      await api.joinByToken(widget.token);
      if (mounted) setState(() { _joined = true; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Failed to join'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _joined ? Icons.check_circle_outline : Icons.error_outline,
                    size: 64,
                    color: _joined ? Colors.green : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _joined ? 'You have joined the community!' : (_error ?? 'Failed'),
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.goNamed('main'),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
      ),
    );
  }
}
