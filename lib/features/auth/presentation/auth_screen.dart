import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignIn = true;
  String _selectedRole = 'user';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    // 全角のアットマークを半角に自動変換
    final email = _emailController.text.trim().replaceAll('＠', '@');
    final name = _nameController.text.trim();

    if (email.isEmpty || (_isSignIn && _passwordController.text.isEmpty)) {
      String message = _isSignIn
          ? 'メールアドレスとパスワードを入力してください'
          : 'メールアドレスを入力してください';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // メールアドレスの形式チェック（より一般的な形式に変更）
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('有効なメールアドレスの形式で入力してください')));
      return;
    }

    if (!_isSignIn && name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('お名前を入力してください')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignIn) {
        await ref
            .read(authRepositoryProvider)
            .signInWithEmail(email, _passwordController.text.trim());
      } else {
        // サインアップ処理開始（リダイレクトを阻止するためにグローバルフラグを立てる）
        ref.read(signingUpProvider.notifier).state = true;

        await ref
            .read(authRepositoryProvider)
            .signUpWithEmailAndSendReset(email, name, _selectedRole);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'パスワード設定用のメールを送信しました。メール内のリンクをクリックしてパスワードを設定してください。',
              ),
              duration: Duration(seconds: 10),
            ),
          );
          setState(() {
            _isSignIn = true;
          });
          ref.read(signingUpProvider.notifier).state = false;
        }
      }
    } catch (e) {
      ref.read(signingUpProvider.notifier).state = false;
      if (mounted) {
        String message = _isSignIn ? 'サインインエラー' : 'サインアップエラー';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user == null && mounted) {
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google認証エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordReset() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスを入力してください')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードリセットメールを送信しました。メールをご確認ください。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ゲストログインエラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E293B).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_parking,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Parking Manager',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignIn ? '管理システムへサインイン' : 'アカウントを作成',
                      style: GoogleFonts.notoSansJp(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AutofillGroup(
                      child: Column(
                        children: [
                          if (!_isSignIn) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: 'お名前',
                              icon: Icons.person_outline,
                              autofillHints: [AutofillHints.name],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildRoleButton(
                                    '契約者',
                                    'user',
                                    Icons.person_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildRoleButton(
                                    '管理者',
                                    'admin',
                                    Icons.admin_panel_settings_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildTextField(
                            controller: _emailController,
                            label: 'メールアドレス',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: [AutofillHints.email],
                          ),
                          if (_isSignIn) ...[
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'パスワード',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              autofillHints: [AutofillHints.password],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isSignIn ? 'サインイン' : 'サインアップ',
                                style: GoogleFonts.notoSansJp(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    if (_isSignIn) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handlePasswordReset,
                          child: Text(
                            'パスワードを忘れた場合',
                            style: GoogleFonts.notoSansJp(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isSignIn = !_isSignIn),
                      child: Text(
                        _isSignIn
                            ? 'アカウントをお持ちでない方（サインアップ）'
                            : '既にアカウントをお持ちの方（サインイン）',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 13,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'または',
                            style: GoogleFonts.notoSansJp(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          onTap: _isLoading ? null : _googleSignIn,
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.network(
                                  'https://www.gstatic.com/images/branding/googleg/2x/googleg_standard_color_64dp.png',
                                  height: 20,
                                  width: 20,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.g_mobiledata,
                                        size: 24,
                                        color: Colors.blue,
                                      ),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _isSignIn
                                        ? 'Google でサインイン'
                                        : 'Google でサインアップ',
                                    style: GoogleFonts.roboto(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 44),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        Text(
                          'まずは機能を体験してみたい方は',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleGuestSignIn,
                            icon: const Icon(
                              Icons.rocket_launch_outlined,
                              size: 18,
                            ),
                            label: Text(
                              'ゲストモードで試す',
                              style: GoogleFonts.notoSansJp(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E293B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '※作成したデータは1時間後に自動消去されます',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String label, String role, IconData icon) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E293B) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.notoSansJp(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFFBFDFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
    );
  }
}
