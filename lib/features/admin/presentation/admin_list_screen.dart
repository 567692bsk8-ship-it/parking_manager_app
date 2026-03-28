import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:my_first_app/features/auth/providers/auth_provider.dart';

import '../../../shared/widgets/admin_scaffold.dart';

class AdminListScreen extends ConsumerWidget {
  const AdminListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(adminUsersProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    return AdminScaffold(
      selectedPath: '/admin/admins',
      title: '管理者一覧',
      onBack: () => context.go('/admin'),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: adminsAsync.when(
            data: (admins) => admins.isEmpty
                ? const Center(child: Text('管理者が存在しません'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingTextStyle: GoogleFonts.notoSansJp(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                              columnSpacing: isMobile ? 24 : 48,
                              columns: const [
                                DataColumn(label: Text('名前')),
                                DataColumn(label: Text('メールアドレス')),
                                DataColumn(label: Text('状態')),
                                DataColumn(label: Text('操作')),
                              ],
                              rows: admins.map((admin) {
                                return DataRow(
                                  onSelectChanged: (selected) {
                                    if (selected != null && selected) {
                                      // 1. プロバイダーを更新して代行状態にする
                                      ref
                                          .read(viewingAdminIdProvider.notifier)
                                          .state = admin
                                          .uid;
                                      // 2. その後、該当管理者のダッシュボードへ遷移
                                      context.go('/admin?adminId=${admin.uid}');
                                    }
                                  },
                                  cells: [
                                    DataCell(Text(admin.displayName ?? '未設定')),
                                    DataCell(Text(admin.email)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          '有効',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(
                                          Icons.dashboard_outlined,
                                        ),
                                        onPressed: () {
                                          // 1. プロバイダーを更新
                                          ref
                                              .read(
                                                viewingAdminIdProvider.notifier,
                                              )
                                              .state = admin
                                              .uid;
                                          // 2. 遷移
                                          context.go(
                                            '/admin?adminId=${admin.uid}',
                                          );
                                        },
                                        tooltip: 'ダッシュボードを表示',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                              showCheckboxColumn: false,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('エラー: $err')),
          ),
        ),
      ),
    );
  }
}
