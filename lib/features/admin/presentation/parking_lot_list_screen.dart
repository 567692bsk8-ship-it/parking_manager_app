import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/parking_provider.dart';
import 'package:go_router/go_router.dart';
import '../data/parking_lot_model.dart';
import '../../../shared/widgets/admin_scaffold.dart';

class ParkingLotListScreen extends ConsumerWidget {
  const ParkingLotListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkingLotsAsync = ref.watch(parkingLotsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

    return AdminScaffold(
      selectedPath: '/admin/parking_lots',
      title: '駐車場一覧',
      onBack: () => context.go('/admin'),
      actions: [
        Padding(
          padding: isMobile ? const EdgeInsets.only(right: 8) : EdgeInsets.zero,
          child: IconButton(
            onPressed: () => context.push('/admin/parking_lots/add'),
            icon: const Icon(Icons.add),
            color: const Color(0xFF1E293B),
            tooltip: '駐車場追加',
          ),
        ),
      ],
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: parkingLotsAsync.when(
          data: (lots) => lots.isEmpty
              ? const Center(child: Text('駐車場データがありません'))
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? (isTablet ? 2 : 1) : 3,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: isMobile ? 1.6 : 1.5,
                  ),
                  itemCount: lots.length,
                  itemBuilder: (context, index) {
                    final lot = lots[index];
                    return _ParkingLotCard(lot: lot, isMobile: isMobile);
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('エラー: $err')),
        ),
      ),
    );
  }
}

class _ParkingLotCard extends ConsumerWidget {
  final ParkingLot lot;
  final bool isMobile;
  const _ParkingLotCard({required this.lot, this.isMobile = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      child: Stack(
        children: [
          InkWell(
            onTap: () => context.push('/admin/parking_lots/slots', extra: lot),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_parking,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        lot.id,
                        style: GoogleFonts.notoSansJp(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lot.name,
                    style: GoogleFonts.notoSansJp(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lot.address,
                          style: GoogleFonts.notoSansJp(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '総区画数',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '${lot.totalSlots} 区画',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('駐車場の削除'),
        content: Text('${lot.name} (${lot.id}) を削除しますか？\n関連する区画データもすべて削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(parkingRepositoryProvider).deleteParkingLot(lot.id);
        ref.invalidate(parkingLotsProvider);
        ref.invalidate(parkingStatsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('駐車場を削除しました')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
        }
      }
    }
  }
}
