import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:my_first_app/features/auth/providers/auth_provider.dart';
import '../../admin/providers/parking_provider.dart';
import '../../../shared/widgets/admin_scaffold.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
// import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class DevDashboardScreen extends ConsumerWidget {
  const DevDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    final userCountAsync = ref.watch(totalContractorsCountProvider);
    final adminCountAsync = ref.watch(adminCountProvider);

    return AdminScaffold(
      selectedPath: '/admin',
      title: '開発者ダッシュボード',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: TextButton.icon(
            onPressed: () async {
              // 全データの統合修復を実行してからリロード
              await ref.read(parkingRepositoryProvider).fixMissingManagerIds();
              // html.window.location.reload();
              if (kIsWeb) {
                // ウェブの場合は本来リロードしたいが、コンパイルエラー回避のため現在は無効化
              }
            },
            icon: const Icon(Icons.refresh, size: 18, color: Colors.blue),
            label: Text(
              '更新',
              style: GoogleFonts.notoSansJp(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: '契約者数',
                    valueAsync: userCountAsync,
                    icon: Icons.people_outline,
                    color: Colors.blue,
                    onTap: () => context.go('/admin/contracts'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    title: '管理者数',
                    valueAsync: adminCountAsync,
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.indigo,
                    onTap: () => context.go('/admin/admins'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    title: '備考',
                    value: '-',
                    icon: Icons.note_outlined,
                    color: Colors.grey,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Container(
              height: 400,
              width: double.infinity,
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
              child: const Center(child: Text('システム全体の稼働状況やログをここに表示できます')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final AsyncValue<int>? valueAsync;
  final String? value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    this.valueAsync,
    this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.notoSansJp(
                color: const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            if (valueAsync != null)
              valueAsync!.when(
                data: (val) => Text(
                  '$val',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                loading: () => const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Text('?'),
              )
            else
              Text(
                value ?? '',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
