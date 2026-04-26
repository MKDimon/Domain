import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? token;
  const VerifyEmailScreen({super.key, this.token});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  String _status = 'loading'; // loading | success | error
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() { _status = 'error'; _errorMessage = 'Некорректная ссылка'; });
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      await api.get('/auth/verify-email', queryParameters: {'token': widget.token!});
      if (mounted) {
        setState(() => _status = 'success');
        if (ref.read(authProvider).isAuthenticated) {
          ref.read(authProvider.notifier).refreshProfile();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _status = 'error'; _errorMessage = e.toString(); });
    }
  }

  void _goNext() {
    if (ref.read(authProvider).isAuthenticated) {
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == 'loading') ...[
                SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(c.accent), backgroundColor: c.border),
                ),
                const SizedBox(height: 12),
                Text('Проверка...', style: TextStyle(color: c.textSecondary, fontSize: 14.4)),
              ] else if (_status == 'success') ...[
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: c.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, size: 32, color: c.success),
                ),
                const SizedBox(height: 20),
                Text('Email подтверждён', style: TextStyle(fontSize: 20.8, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 12),
                Text('Ваш email успешно подтверждён.', style: TextStyle(fontSize: 14.4, color: c.textSecondary)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(ref.watch(authProvider).isAuthenticated ? 'На главную' : 'Войти'),
                  ),
                ),
              ] else ...[
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, size: 32, color: c.error),
                ),
                const SizedBox(height: 20),
                Text('Ошибка проверки', style: TextStyle(fontSize: 20.8, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 12),
                Text(_errorMessage, style: TextStyle(fontSize: 14.4, color: c.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(ref.watch(authProvider).isAuthenticated ? 'На главную' : 'Войти'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
