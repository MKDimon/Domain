import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../data/api/users_api.dart';
import '../../../data/api/uploads_api.dart';
import '../../../data/models/user.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/utils/avatar_color.dart';
import '../../../core/utils/image_url.dart';
import 'package:file_picker/file_picker.dart';

class AccountTab extends ConsumerStatefulWidget {
  const AccountTab({super.key});

  @override
  ConsumerState<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends ConsumerState<AccountTab> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();

  User? _profile;
  String _avatarUrl = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saveError;
  bool _saveSuccess = false;
  bool _avatarUploading = false;
  int _avatarProgress = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  bool get _dirty {
    if (_profile == null) return false;
    return _usernameController.text != _profile!.username ||
        _displayNameController.text != (_profile!.displayName ?? '') ||
        _emailController.text != _profile!.email ||
        _bioController.text != (_profile!.bio) ||
        _avatarUrl != (_profile!.avatarUrl);
  }

  Future<void> _fetchProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = UsersApi(ref.read(apiClientProvider));
      _profile = await api.getMe();
      _usernameController.text = _profile!.username;
      _displayNameController.text = _profile!.displayName ?? '';
      _emailController.text = _profile!.email;
      _bioController.text = _profile!.bio;
      _avatarUrl = _profile!.avatarUrl;
    } catch (e) {
      _error = 'Не удалось загрузить профиль';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_profile == null || _saving || !_dirty) return;
    setState(() { _saving = true; _saveError = null; _saveSuccess = false; });

    final updates = <String, dynamic>{};
    if (_usernameController.text != _profile!.username) updates['username'] = _usernameController.text.trim();
    if (_displayNameController.text != (_profile!.displayName ?? '')) updates['display_name'] = _displayNameController.text.trim();
    if (_emailController.text != _profile!.email) updates['email'] = _emailController.text.trim();
    if (_bioController.text != _profile!.bio) updates['bio'] = _bioController.text;
    if (_avatarUrl != _profile!.avatarUrl) updates['avatar_url'] = _avatarUrl;

    try {
      final api = UsersApi(ref.read(apiClientProvider));
      _profile = await api.updateProfile(updates);
      ref.read(authProvider.notifier).refreshProfile();
      setState(() => _saveSuccess = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saveSuccess = false);
      });
    } catch (e) {
      setState(() => _saveError = 'Не удалось сохранить');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    if (_profile == null) return;
    _usernameController.text = _profile!.username;
    _displayNameController.text = _profile!.displayName ?? '';
    _emailController.text = _profile!.email;
    _bioController.text = _profile!.bio;
    _avatarUrl = _profile!.avatarUrl;
    setState(() => _saveError = null);
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) return;

    setState(() { _avatarUploading = true; _avatarProgress = 0; });
    try {
      final api = UploadsApi(ref.read(apiClientProvider));
      final uploaded = await api.upload(
        bytes: bytes,
        filename: file.name,
        contentType: 'image/${file.extension ?? 'png'}',
        onProgress: (p) => setState(() => _avatarProgress = p),
      );
      setState(() => _avatarUrl = uploaded.url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить аватар')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)));
    }
    if (_profile == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Аккаунт', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Управление профилем', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),

          // Avatar card
          _card(theme, child: Row(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: avatarColor(_profile!.id),
                backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(fullImageUrl(_avatarUrl)) : null,
                child: _avatarUrl.isEmpty
                    ? Text(_profile!.initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Аватар', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 4),
                    Text('JPG, PNG, макс. 5 МБ', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _avatarUploading ? null : _pickAvatar,
                          child: Text(_avatarUploading ? 'Загрузка $_avatarProgress%' : 'Загрузить'),
                        ),
                        if (_avatarUrl.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _avatarUrl = ''),
                            child: Text('Удалить', style: TextStyle(color: theme.colorScheme.error)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 16),

          // Basic info card
          _card(theme, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Основная информация', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 16),
              _field('Имя пользователя', _usernameController),
              _field('Отображаемое имя', _displayNameController),
              _field('Email', _emailController, inputType: TextInputType.emailAddress),
              _field('О себе', _bioController, maxLines: 3),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_saveError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                ),
              if (_saveSuccess)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Сохранено', style: TextStyle(color: theme.colorScheme.primary, fontSize: 13)),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: _dirty ? _reset : null, child: const Text('Отмена')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _dirty && !_saving ? _save : null,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? inputType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: inputType,
              maxLines: maxLines,
              decoration: const InputDecoration(isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
