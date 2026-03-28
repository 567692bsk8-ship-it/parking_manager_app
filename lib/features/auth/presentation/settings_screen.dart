import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/admin_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isEditingName = false;
  bool _isEditingEmail = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateName(String uid) async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateDisplayName(uid, _nameController.text.trim());
      setState(() => _isEditingName = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('名前の更新に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmail(String uid) async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateEmail(uid, _emailController.text.trim());
      setState(() => _isEditingEmail = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メールアドレスを更新しました。')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('メールアドレスの更新に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordReset(String? email) async {
    if (email == null || email.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('パスワードリセットメールを送信しました。')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('送信に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPasswordReset(String? email) async {
    if (email == null || email.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パスワードリセット'),
        content: const Text(
          'パスワード再設定用のメールを送信します。\n\n'
          '※メールが届かない場合は、迷惑メールフォルダに入っていないかご確認ください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _sendPasswordReset(email);
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).linkWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Googleアカウントを連携しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('連携に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).unlinkGoogle();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Googleアカウントの連携を解除しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('解除に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authUserProvider);
    final userRole = ref.watch(userRoleProvider);

    return AdminScaffold(
      selectedPath: userRole == 'admin' || userRole == 'dev'
          ? '/admin/settings'
          : '/user/settings',
      title: '設定',
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('ユーザー情報が見つかりません'));
          if (!_isEditingName) {
            _nameController.text = user.displayName ?? '';
          }

          final firebaseUser = FirebaseAuth.instance.currentUser;
          final isGoogleLinked =
              firebaseUser?.providerData.any(
                (p) => p.providerId == 'google.com',
              ) ??
              false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('基本情報'),
                const SizedBox(height: 16),
                _buildSettingsCard(
                  child: Column(
                    children: [
                      _buildSettingItem(
                        label: 'お名前',
                        value: _isEditingName
                            ? null
                            : (user.displayName ?? '未設定'),
                        trailing: _isEditingName
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _isEditingName = false),
                                    child: const Text('キャンセル'),
                                  ),
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _updateName(user.uid),
                                    child: const Text('保存'),
                                  ),
                                ],
                              )
                            : TextButton(
                                onPressed: () =>
                                    setState(() => _isEditingName = true),
                                child: const Text('編集'),
                              ),
                        editor: _isEditingName
                            ? TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  hintText: '新しい名前を入力',
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : null,
                      ),
                      const Divider(),
                      _buildSettingItem(
                        label: 'メールアドレス',
                        value: _isEditingEmail ? null : user.email,
                        trailing: _isEditingEmail
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _isEditingEmail = false),
                                    child: const Text('キャンセル'),
                                  ),
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => _updateEmail(user.uid),
                                    child: const Text('保存'),
                                  ),
                                ],
                              )
                            : TextButton(
                                onPressed: () {
                                  _emailController.text = user.email;
                                  setState(() => _isEditingEmail = true);
                                },
                                child: const Text('編集'),
                              ),
                        editor: _isEditingEmail
                            ? TextField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  hintText: '新しいメールアドレスを入力',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                              )
                            : null,
                      ),
                      const Divider(),
                      _buildSettingItem(
                        label: 'パスワード',
                        value: '********',
                        trailing: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => _confirmPasswordReset(user.email),
                          child: const Text('リセット'),
                        ),
                      ),
                      const Divider(),
                      _buildSettingItem(
                        label: '権限',
                        value: _getRoleLabel(user.role),
                      ),
                    ],
                  ),
                ),
                if (userRole == 'admin' || userRole == 'dev') ...[
                  const SizedBox(height: 32),
                  _buildSectionTitle('管理者プロフィール'),
                  const SizedBox(height: 16),
                  _buildSettingsCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '管理コード',
                                      style: GoogleFonts.notoSansJp(
                                        fontSize: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.managerCode ?? '未生成',
                                      style: GoogleFonts.outfit(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: QrImageView(
                                  data: user.managerCode ?? '',
                                  version: QrVersions.auto,
                                  size: 100.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.indigo.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'このQRコードを契約希望者に見せることで、あなたの管理する駐車場をすぐに見つけることができます。',
                                    style: GoogleFonts.notoSansJp(
                                      fontSize: 12,
                                      color: Colors.indigo.shade900,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _buildSectionTitle('ソーシャル連携'),
                const SizedBox(height: 16),
                _buildSettingsCard(
                  child: _buildSettingItem(
                    label: 'Google連携',
                    value: isGoogleLinked ? '連携済み' : '未連携',
                    trailing: Switch(
                      value: isGoogleLinked,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value) {
                                _linkGoogle();
                              } else {
                                _unlinkGoogle();
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Center(
                  child: TextButton.icon(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'サインアウト',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return '管理者';
      case 'user':
        return '契約者';
      case 'dev':
        return '開発者';
      default:
        return role;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.notoSansJp(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSettingItem({
    required String label,
    String? value,
    Widget? trailing,
    Widget? editor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.notoSansJp(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (editor != null) ...[const SizedBox(height: 16), editor],
        ],
      ),
    );
  }
}
