import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/slug.dart';
import '../../../data/api/communities_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../billing/widgets/upgrade_modal.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = true;
  bool _slugManual = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (!_slugManual) {
      _slugController.text = generateSlug(_nameController.text);
      setState(() {});
    }
  }

  void _onSlugInput(String val) {
    _slugManual = true;
    final sanitized = val
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[-_]+'), '');
    if (sanitized != val) {
      _slugController.text = sanitized;
      _slugController.selection = TextSelection.collapsed(offset: sanitized.length);
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim();
    if (name.isEmpty || slug.isEmpty) {
      setState(() => _error = l.createCommunityNameSlugRequired);
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final api = CommunitiesApi(ref.read(apiClientProvider));
      final settings = <String, dynamic>{'public': _isPublic};
      if (_descController.text.trim().isNotEmpty) {
        settings['description'] = _descController.text.trim();
      }
      await api.create(name: name, slug: slug, settings: settings);
      if (mounted) context.goNamed('community', pathParameters: {'slug': slug});
    } on ApiException catch (e) {
      if (e.code == 'COMMUNITY_LIMIT_REACHED' && mounted) {
        final current = e.details?['current'];
        final limit = e.details?['limit'];
        showUpgradeModal(context, trigger: UpgradeTrigger.communityLimit, currentValue: current, limitValue: limit);
      }
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = l.createCommunityFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(ColorSet c, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textSecondary.withValues(alpha: 0.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c.accent)),
      filled: true,
      fillColor: c.surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title — web: 1.5rem = 24px, w700
                Text(l.createCommunityTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 24),

                // Name
                _label(l.createCommunityName, c),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: 15.2, color: c.text),
                  textInputAction: TextInputAction.next,
                  autofocus: true,
                  decoration: _inputDecoration(c, hint: l.createCommunityNamePlaceholder),
                ),
                const SizedBox(height: 16),

                // Slug
                _label(l.createCommunitySlug, c),
                const SizedBox(height: 6),
                TextField(
                  controller: _slugController,
                  style: TextStyle(fontSize: 15.2, color: c.text),
                  onChanged: _onSlugInput,
                  decoration: _inputDecoration(c, hint: l.createCommunitySlugPlaceholder),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('URL: /${_slugController.text.isEmpty ? '...' : _slugController.text}',
                      style: TextStyle(fontSize: 12.8, color: c.textSecondary)),
                ),
                const SizedBox(height: 16),

                // Description
                _label(l.createCommunityDescription, c),
                const SizedBox(height: 6),
                TextField(
                  controller: _descController,
                  style: TextStyle(fontSize: 15.2, color: c.text),
                  maxLines: 3,
                  decoration: _inputDecoration(c, hint: l.createCommunityDescriptionPlaceholder),
                ),
                const SizedBox(height: 16),

                // Visibility
                _label(l.createCommunityVisibility, c),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Checkbox(
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v ?? true),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isPublic = !_isPublic),
                      child: Text(
                        _isPublic ? l.createCommunityPublic : l.createCommunityPrivate,
                        style: TextStyle(fontSize: 14, color: c.text),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 24),
                  child: Text(
                    _isPublic ? l.createCommunityPublicHint : l.createCommunityPrivateHint,
                    style: TextStyle(fontSize: 12.8, color: c.textSecondary),
                  ),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 16),
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
                ],

                // Submit
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: _loading ? null : _submit,
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
                          : Text(l.createCommunityButton, style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w500, color: c.textOnAccent)),
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

  Widget _label(String text, ColorSet c) {
    return Text(text, style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w500, color: c.text));
  }
}
