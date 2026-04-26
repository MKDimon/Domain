import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/oauth_buttons.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _agreed = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _passwordController.text.length >= 6;
  bool get _hasUpper => _passwordController.text.contains(RegExp(r'[A-Z]'));

  Future<void> _handleRegister() async {
    final l = AppLocalizations.of(context)!;
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = l.authFillAllFields);
      return;
    }
    if (password != confirm) {
      setState(() => _error = l.authPasswordsDontMatch);
      return;
    }
    if (password.length < 6) {
      setState(() => _error = l.authPasswordTooShort);
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(authProvider.notifier).register(username, email, password);
      if (mounted) {
        final auth = ref.read(authProvider);
        context.goNamed(auth.isAuthenticated ? 'main' : 'login');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = l.authRegistrationFailed);
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
      body: Center(
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
                Text(l.authRegisterTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 6),
                Text(l.authRegisterSubtitle, style: TextStyle(fontSize: 14.4, color: c.textSecondary)),
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
                _FormField(label: l.authUsername, controller: _usernameController, c: c, textInputAction: TextInputAction.next, autofocus: true),
                const SizedBox(height: 16),
                _FormField(label: l.authEmail, controller: _emailController, c: c, textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _FormField(
                  label: l.authPassword,
                  controller: _passwordController,
                  c: c,
                  obscure: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: c.textSecondary),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _PasswordReq(label: l.authPasswordMinLength, met: _hasMinLength, c: c),
                    _PasswordReq(label: l.authPasswordUppercase, met: _hasUpper, c: c),
                  ],
                ),
                const SizedBox(height: 16),
                _FormField(
                  label: l.authConfirmPassword,
                  controller: _confirmController,
                  c: c,
                  obscure: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegister(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Text(
                          l.authAgreeTerms,
                          style: TextStyle(fontSize: 13.1, color: c.textSecondary, height: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: (!_agreed || _loading) ? null : _handleRegister,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (!_agreed || _loading) ? c.accent.withValues(alpha: 0.5) : c.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l.authRegister, style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w500, color: c.textOnAccent)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${l.authHasAccount} ', style: TextStyle(fontSize: 14.1, color: c.textSecondary)),
                    GestureDetector(
                      onTap: () => context.goNamed('login'),
                      child: Text(l.authSignIn, style: TextStyle(fontSize: 14.1, color: c.accent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final bool autofocus;
  final TextInputType? keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    required this.c,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.suffixIcon,
    this.autofocus = false,
    this.keyboardType,
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
          onChanged: onChanged,
          autofocus: autofocus,
          keyboardType: keyboardType,
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

class _PasswordReq extends StatelessWidget {
  final String label;
  final bool met;
  final ColorSet c;
  const _PasswordReq({required this.label, required this.met, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(met ? Icons.check_circle : Icons.circle_outlined, size: 14, color: met ? c.success : c.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12.5, color: met ? c.success : c.textSecondary)),
      ],
    );
  }
}
