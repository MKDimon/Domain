import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/oauth_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final l = AppLocalizations.of(context)!;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = l.authFillAllFields);
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(authProvider.notifier).login(username, password);
      if (mounted) context.goNamed('main');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = l.authLoginFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.authLoginTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 6),
                Text(l.authLoginSubtitle, style: TextStyle(fontSize: 14.4, color: c.textSecondary)),
                const SizedBox(height: 24),
                OAuthButtons(c: c),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEB5757).withValues(alpha: 0.10),
                      border: Border.all(color: const Color(0xFFEB5757).withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(fontSize: 13.6, color: Color(0xFFE53935))),
                  ),
                  const SizedBox(height: 16),
                ],
                _FormField(
                  label: l.authUsernameOrEmail,
                  controller: _usernameController,
                  c: c,
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                _FormField(
                  label: l.authPassword,
                  controller: _passwordController,
                  c: c,
                  obscure: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: c.textSecondary),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: _loading ? null : _handleLogin,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _loading ? c.accent.withValues(alpha: 0.5) : c.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l.authSignIn, style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w500, color: c.textOnAccent)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${l.authNoAccount} ', style: TextStyle(fontSize: 14.1, color: c.textSecondary)),
                    GestureDetector(
                      onTap: () => context.goNamed('register'),
                      child: Text(l.authRegister, style: TextStyle(fontSize: 14.1, color: c.accent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          ),
          Positioned(
            top: 16, left: 16,
            child: IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.goNamed('main'),
              icon: Icon(Icons.arrow_back, color: c.textSecondary),
              tooltip: 'Назад',
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ColorSet c;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final bool autofocus;

  const _FormField({
    required this.label,
    required this.controller,
    required this.c,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w500, color: c.text)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          style: TextStyle(fontSize: 15.2, color: c.text),
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}
