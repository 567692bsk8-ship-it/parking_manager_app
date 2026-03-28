import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'qr_display_dialog.dart';

class SideNavigation extends ConsumerWidget {
  final String selectedPath;

  const SideNavigation({super.key, required this.selectedPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final role = ref.watch(userRoleProvider);
    final viewingAdminId = ref.watch(viewingAdminIdProvider);

    return Container(
      width: 260,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // ユーザー名表示
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_circle,
                    color: Colors.white60,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ようこそ',
                    style: GoogleFonts.notoSansJp(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user.displayName ?? "ユーザー"} 様',
                    style: GoogleFonts.notoSansJp(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ] else ...[
            const FlutterLogo(size: 48),
          ],
          const SizedBox(height: 40),
          // --- Role Based Menu ---
          if (role == 'dev') ...[
            if (viewingAdminId != null) ...[
              // 管理者代行モードのメニュー
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '管理者代行中',
                              style: GoogleFonts.notoSansJp(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SideMenuItem(
                      icon: Icons.settings_backup_restore,
                      label: '開発者モードに戻る',
                      isSelected: false,
                      onTap: () {
                        ref.read(viewingAdminIdProvider.notifier).state = null;
                        context.go('/admin');
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
              _SideMenuItem(
                icon: Icons.dashboard,
                label: 'ダッシュボード',
                isSelected: selectedPath == '/admin',
                onTap: () => context.go('/admin?adminId=$viewingAdminId'),
              ),
              _SideMenuItem(
                icon: Icons.people,
                label: '契約者一覧',
                isSelected: selectedPath == '/admin/contracts',
                onTap: () => context.go('/admin/contracts'),
              ),
              _SideMenuItem(
                icon: Icons.local_parking,
                label: '駐車場一覧',
                isSelected: selectedPath == '/admin/parking_lots',
                onTap: () => context.go('/admin/parking_lots'),
              ),
            ] else ...[
              // 通常の開発者メニュー
              _SideMenuItem(
                icon: Icons.dashboard,
                label: '開発者ダッシュボード',
                isSelected: selectedPath == '/admin' || selectedPath == '/dev',
                onTap: () => context.go('/admin'),
              ),
              _SideMenuItem(
                icon: Icons.admin_panel_settings,
                label: '管理者一覧',
                isSelected: selectedPath == '/admin/admins',
                onTap: () => context.go('/admin/admins'),
              ),
              _SideMenuItem(
                icon: Icons.people,
                label: '契約者一覧',
                isSelected: selectedPath == '/admin/contracts',
                onTap: () => context.go('/admin/contracts'),
              ),
            ],
          ] else if (role == 'admin') ...[
            _SideMenuItem(
              icon: Icons.dashboard,
              label: 'ダッシュボード',
              isSelected: selectedPath == '/admin',
              onTap: () => context.go('/admin'),
            ),
            _SideMenuItem(
              icon: Icons.people,
              label: '契約者一覧',
              isSelected: selectedPath == '/admin/contracts',
              onTap: () => context.go('/admin/contracts'),
            ),
            _SideMenuItem(
              icon: Icons.local_parking,
              label: '駐車場一覧',
              isSelected: selectedPath == '/admin/parking_lots',
              onTap: () => context.go('/admin/parking_lots'),
            ),
          ] else ...[
            _SideMenuItem(
              icon: Icons.home,
              label: 'ホーム',
              isSelected: selectedPath == '/user',
              onTap: () => context.go('/user'),
            ),
          ],

          _SideMenuItem(
            icon: Icons.settings,
            label: '設定',
            isSelected:
                selectedPath == '/admin/settings' ||
                selectedPath == '/settings',
            onTap: () => context.go('/admin/settings'),
          ),
          if (role == 'admin' || (role == 'dev' && viewingAdminId != null))
            _SideMenuItem(
              icon: Icons.qr_code_2,
              label: 'QRコード',
              isSelected: false,
              onTap: () {
                final managerId = role == 'admin' ? user?.uid : viewingAdminId;
                if (managerId != null) {
                  showDialog(
                    context: context,
                    builder: (context) => QrDisplayDialog(
                      data: managerId,
                      title: '管理者QRコード',
                      managerCode: role == 'admin' ? user?.managerCode : null,
                    ),
                  );
                }
              },
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('v1.0.0', style: TextStyle(color: Colors.white24)),
          ),
        ],
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        // Drawerが開いている場合は閉じる
        if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
        onTap();
      },
    );
  }
}
