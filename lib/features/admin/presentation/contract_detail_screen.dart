import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../data/contract_model.dart';
import '../data/parking_lot_model.dart';
import '../providers/parking_provider.dart';

class ContractDetailScreen extends ConsumerWidget {
  final Contract contract;

  const ContractDetailScreen({super.key, required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${contract.userName} さんの契約詳細',
          style: GoogleFonts.notoSansJp(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailCard(),
            const SizedBox(height: 32),
            _buildVehicleCard(),
            const SizedBox(height: 32),
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF1E293B)),
                  const SizedBox(width: 12),
                  Text(
                    '契約者情報',
                    style: GoogleFonts.notoSansJp(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              _buildStatusChip(contract.status),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('契約者名', contract.userName, Icons.person_outline),
          const Divider(height: 32),
          _buildDetailRow(
            '電話番号',
            contract.phoneNumber,
            Icons.phone_android_outlined,
          ),
          const Divider(height: 32),
          _buildDetailRow('住所', contract.address, Icons.home_outlined),
          const Divider(height: 32),
          Consumer(
            builder: (context, ref, child) {
              final lotAsync = contract.lotId != null
                  ? ref.watch(parkingLotByIdProvider(contract.lotId!))
                  : const AsyncValue<ParkingLot?>.data(null);
              return lotAsync.when(
                data: (lot) => _buildDetailRow(
                  '駐車場名',
                  lot?.name ?? '不明',
                  Icons.local_parking,
                ),
                loading: () =>
                    _buildDetailRow('駐車場名', '...', Icons.local_parking),
                error: (_, __) =>
                    _buildDetailRow('駐車場名', '不明', Icons.local_parking),
              );
            },
          ),
          const Divider(height: 32),
          _buildDetailRow(
            '区画番号',
            contract.slotNumber,
            Icons.directions_car_outlined,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            '月額料金',
            '¥${NumberFormat('#,###').format(contract.monthlyFee)}',
            Icons.payments_outlined,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            '支払日',
            '毎月 ${contract.paymentDay} 日',
            Icons.calendar_today_outlined,
          ),
          const Divider(height: 32),
          _buildDetailRow('支払い方法', contract.paymentMethod, Icons.credit_card),
          const Divider(height: 32),
          _buildDetailRow(
            '契約開始日',
            DateFormat('yyyy/MM/dd').format(contract.startDate),
            Icons.event_available,
          ),
          const Divider(height: 32),
          _buildDetailRow(
            '契約終了日',
            contract.endDate != null
                ? DateFormat('yyyy/MM/dd').format(contract.endDate!)
                : '設定なし',
            Icons.event_busy_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 22),
        const SizedBox(width: 16),
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            color: const Color(0xFF64748B),
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.notoSansJp(
            color: const Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFF1E293B)),
              const SizedBox(width: 12),
              Text(
                '車両情報',
                style: GoogleFonts.notoSansJp(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('メーカー', contract.carMaker, Icons.factory_outlined),
          const Divider(height: 32),
          _buildDetailRow('車種', contract.carModel, Icons.minor_crash_outlined),
          const Divider(height: 32),
          _buildDetailRow('色', contract.carColor, Icons.palette_outlined),
          const Divider(height: 32),
          _buildDetailRow('ナンバー', contract.carNumber, Icons.pin_outlined),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              context.push('/admin/contracts/edit', extra: contract);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('契約を編集'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFF1E293B)),
              foregroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteDialog(context, ref),
            icon: const Icon(Icons.no_accounts_outlined),
            label: const Text('解約処理'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? '有効' : '終了',
        style: GoogleFonts.notoSansJp(
          color: isActive ? Colors.green : Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解約の確認'),
        content: Text('${contract.userName} さんの契約を解除し、データを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('解約する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(parkingRepositoryProvider).deleteContract(contract.id);
        ref.invalidate(contractsProvider);
        ref.invalidate(parkingStatsProvider);
        if (contract.lotId != null) {
          ref.invalidate(parkingSlotsProvider(contract.lotId!));
        }
        if (context.mounted) {
          context.pop(); // 詳細画面を閉じる
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('契約を解除しました')));
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
