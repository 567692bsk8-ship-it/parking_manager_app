import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../admin/providers/parking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../admin/data/contract_model.dart';
import '../../admin/data/parking_lot_model.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);
    final contractsAsync = ref.watch(userContractsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'マイページ',
          style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: userAsync.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, user?.displayName ?? 'ゲスト'),
              const SizedBox(height: 32),
              Text(
                '現在のご契約内容',
                style: GoogleFonts.notoSansJp(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              contractsAsync.when(
                data: (contracts) => contracts.isEmpty
                    ? _buildNoContractView()
                    : Column(
                        children: contracts
                            .map((c) => _ContractCard(contract: c))
                            .toList(),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('契約情報の取得に失敗しました: $err'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('エラー: $err')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'こんにちは',
                  style: GoogleFonts.notoSansJp(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$name 様',
                        style: GoogleFonts.notoSansJp(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 契約を追加するボタン (名前の右側)
                    TextButton(
                      onPressed: () {
                        context.push('/user/home/contracts/add');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '契約を追加する',
                        style: GoogleFonts.notoSansJp(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoContractView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            '現在有効な契約はありません',
            style: GoogleFonts.notoSansJp(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _ContractCard extends ConsumerWidget {
  final Contract contract;

  const _ContractCard({required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotAsync = contract.lotId != null
        ? ref.watch(parkingLotByIdProvider(contract.lotId!))
        : const AsyncValue<ParkingLot?>.data(null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFF1F5F9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_parking,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      lotAsync.when(
                        data: (lot) => Text(
                          lot?.name ?? '不明な駐車場',
                          style: GoogleFonts.notoSansJp(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 80,
                          height: 14,
                          child: LinearProgressIndicator(minHeight: 1),
                        ),
                        error: (_, __) => Text(
                          '不明な駐車場',
                          style: GoogleFonts.notoSansJp(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(contract.status),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildMainInfo('駐車区画', contract.slotNumber),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      Expanded(
                        child: _buildMainInfo(
                          '利用料',
                          '¥${NumberFormat('#,###').format(contract.monthlyFee)}',
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow(
                    Icons.calendar_today,
                    '契約日',
                    DateFormat('yyyy/MM/dd').format(contract.startDate),
                  ),
                  _buildDetailRow(
                    Icons.payment,
                    '支払日',
                    '毎月 ${contract.paymentDay} 日',
                  ),
                  _buildDetailRow(
                    Icons.credit_card,
                    '支払い方法',
                    contract.paymentMethod,
                  ),
                  _buildDetailRow(
                    Icons.directions_car,
                    '車情報',
                    '${contract.carMaker} ${contract.carModel}',
                  ),
                  _buildDetailRow(Icons.tag, '車番', contract.carNumber),
                  if (contract.contractFileUrl != null) ...[
                    const Divider(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // StorageのURLを開く
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('契約書を表示'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            color: const Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.notoSansJp(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.notoSansJp(
              color: const Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? '有効' : '終了',
        style: GoogleFonts.notoSansJp(
          color: isActive ? Colors.green : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
