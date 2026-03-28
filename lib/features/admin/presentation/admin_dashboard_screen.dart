import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/data/auth_user.dart';
import '../../auth/data/auth_repository.dart';
import 'dev_dashboard_screen.dart';
import '../providers/parking_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  final String? adminId;
  const AdminDashboardScreen({super.key, this.adminId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    if (adminId != null) {
      Future.microtask(() {
        final current = ref.read(viewingAdminIdProvider);
        if (current != adminId) {
          ref.read(viewingAdminIdProvider.notifier).state = adminId;
        }
      });
    }

    final viewingAdminId = adminId ?? ref.watch(viewingAdminIdProvider);

    if (role == 'dev' && viewingAdminId == null) {
      return const DevDashboardScreen();
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    String title = 'ダッシュボード';
    if (role == 'dev' && viewingAdminId != null) {
      final admins = ref.watch(adminUsersProvider).value ?? [];
      final viewingAdmin = admins.firstWhere(
        (a) => a.uid == viewingAdminId,
        orElse: () => AuthUser(uid: '', email: '', role: ''),
      );
      title = '${viewingAdmin.displayName ?? "管理者"} の状況';
    } else if (role == 'admin') {
      title = '管理者ダッシュボード';
    }

    final statsAsync = ref.watch(parkingStatsProvider);

    return AdminScaffold(
      selectedPath: '/admin',
      title: title,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(parkingLotsProvider);
            ref.invalidate(contractsProvider);
          },
        ),
      ],
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラーが発生しました: $err')),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SummaryCard(
                    title: '駐車場数',
                    value: '${stats['totalLots']}',
                    icon: Icons.local_parking,
                    color: Colors.indigo,
                    onTap: () => context.go('/admin/parking_lots'),
                    isMobile: isMobile,
                  ),
                  _SummaryCard(
                    title: '全区画数',
                    value: '${stats['totalSlots']}',
                    icon: Icons.grid_view,
                    color: Colors.orange,
                    onTap: () => context.go('/admin/parking_lots'),
                    isMobile: isMobile,
                  ),
                  _SummaryCard(
                    title: '契約数',
                    value: '${stats['occupiedSlots']}',
                    icon: Icons.people_outline,
                    color: Colors.blue,
                    onTap: () => context.go('/admin/contracts'),
                    isMobile: isMobile,
                  ),
                  _SummaryCard(
                    title: '空き区画',
                    value: '${stats['freeSlots']}',
                    icon: Icons.directions_car_outlined,
                    color: Colors.green,
                    onTap: () => context.go('/admin/parking_lots'),
                    isMobile: isMobile,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildOccupancyCard(stats, isMobile),
              const SizedBox(height: 48),
              if (ref.watch(authUserProvider).value?.isGuest ?? false)
                Center(
                  child: Column(
                    children: [
                      Text(
                        'デモを終了して、サインイン画面に戻るには',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('ゲストモードを終了'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
    );
  }

  Widget _buildOccupancyCard(Map<String, int> stats, bool isMobile) {
    final total = stats['totalSlots'] ?? 0;
    final occupied = stats['occupiedSlots'] ?? 0;
    final rate = total > 0 ? (occupied / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '全区画の稼働状況',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 12,
              backgroundColor: Colors.blue.shade50,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('契約済み', occupied, Colors.blue.shade600),
              const SizedBox(width: 24),
              _buildMiniStat('空き', (total - occupied), Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $count',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isMobile;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: isMobile ? 20 : 24),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
