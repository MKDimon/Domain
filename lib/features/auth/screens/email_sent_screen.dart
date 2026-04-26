import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';

class EmailSentScreen extends ConsumerStatefulWidget {
  final String? email;
  const EmailSentScreen({super.key, this.email});

  @override
  ConsumerState<EmailSentScreen> createState() => _EmailSentScreenState();
}

class _EmailSentScreenState extends ConsumerState<EmailSentScreen> {
  bool _resending = false;
  bool _resent = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendVerification();
      if (mounted) setState(() => _resent = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final email = widget.email ?? ref.watch(authProvider).user?.email ?? '';

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon — 72x72, accent 12%
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mail_outline, size: 40, color: c.accent),
              ),
              const SizedBox(height: 20),
              // h1 — 1.5rem = 24px
              Text('Подтвердите email', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: c.text,
              )),
              const SizedBox(height: 12),
              // message
              Text.rich(
                TextSpan(
                  text: 'Мы отправили письмо на ',
                  style: TextStyle(fontSize: 15.2, height: 1.6, color: c.text),
                  children: [
                    TextSpan(text: email, style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // hint — 0.85rem = 13.6px
              Text(
                'Перейдите по ссылке в письме для подтверждения. Проверьте папку «Спам».',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.6, height: 1.5, color: c.textSecondary),
              ),
              const SizedBox(height: 24),
              // button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('На главную'),
                ),
              ),
              const SizedBox(height: 20),
              // resend block
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Не получили?', style: TextStyle(fontSize: 13.6, color: c.textSecondary)),
                    const SizedBox(width: 8),
                    if (!_resent)
                      GestureDetector(
                        onTap: _resending ? null : _resend,
                        child: Text(
                          _resending ? 'Отправка...' : 'Отправить повторно',
                          style: TextStyle(
                            fontSize: 13.6,
                            color: _resending ? c.textSecondary.withValues(alpha: 0.5) : c.accent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    else
                      Text('Отправлено!', style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w500, color: c.success)),
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
