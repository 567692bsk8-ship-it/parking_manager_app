import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../data/parking_lot_model.dart';
import '../providers/parking_provider.dart';
import '../../../shared/widgets/admin_scaffold.dart';

class ParkingLotSlotsScreen extends ConsumerStatefulWidget {
  final ParkingLot parkingLot;

  const ParkingLotSlotsScreen({super.key, required this.parkingLot});

  @override
  ConsumerState<ParkingLotSlotsScreen> createState() =>
      _ParkingLotSlotsScreenState();
}

class _ParkingLotSlotsScreenState extends ConsumerState<ParkingLotSlotsScreen> {
  String? _selectedSlotNumber;
  final ScrollController _scrollController = ScrollController();
  final _currencyFormatter = NumberFormat("#,###");
  bool _isAnnual = false; // 年額表示フラグ

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSlotTap(String slotNumber, String status) {
    if (status == 'available') {
      setState(() {
        _selectedSlotNumber = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('この区画は空きです')));
      return;
    }

    setState(() {
      _selectedSlotNumber = slotNumber;
    });

    // 詳細部分までスクロール
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(parkingSlotsProvider(widget.parkingLot.id));
    final contractsAsync = ref.watch(contractsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    return AdminScaffold(
      selectedPath: '/admin/parking_lots',
      title: '${widget.parkingLot.name} の状況',
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, size: 20),
          onPressed: () => context.push(
            '/admin/parking_lots/edit',
            extra: widget.parkingLot,
          ),
          color: const Color(0xFF64748B),
          tooltip: '駐車場情報の編集',
        ),
      ],
      onBack: () => context.go('/admin/parking_lots'),
      body: slotsAsync.when(
        data: (slots) => contractsAsync.when(
          data: (allContracts) {
            if (slots.isEmpty) {
              return const Center(child: Text('区画データがありません'));
            }

            final lotContracts = allContracts
                .where((c) => c.lotId == widget.parkingLot.id)
                .toList();
            final contractMap = {for (var c in lotContracts) c.slotNumber: c};

            final sortedSlots = [...slots]
              ..sort((a, b) => a.slotNumber.compareTo(b.slotNumber));

            return SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(isMobile ? 16 : 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryStats(slots, isMobile, lotContracts),
                  const SizedBox(height: 24),
                  _buildLegend(),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: isMobile ? 8 : 16,
                      mainAxisSpacing: isMobile ? 8 : 16,
                      childAspectRatio: isMobile ? 0.9 : 1.3,
                    ),
                    itemCount: sortedSlots.length,
                    itemBuilder: (context, index) {
                      final slot = sortedSlots[index];
                      final isSelected = _selectedSlotNumber == slot.slotNumber;
                      final contract = contractMap[slot.slotNumber];

                      return _SlotCard(
                        slot: slot,
                        contractFee: contract?.monthlyFee,
                        isSelected: isSelected,
                        isMobile: isMobile,
                        onTap: () => _onSlotTap(slot.slotNumber, slot.status),
                      );
                    },
                  ),
                  if (_selectedSlotNumber != null) ...[
                    const SizedBox(height: 24),
                    _buildContractDetailSection(_selectedSlotNumber!),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('契約データ取得エラー: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
      ),
    );
  }

  Widget _buildSummaryStats(
    List<dynamic> slots,
    bool isMobile,
    List<dynamic> contracts,
  ) {
    final totalSlots = slots.length;
    final contractedSlotsCount = slots
        .where((s) => s.status == 'contracted')
        .length;
    final occupancyRate = (contractedSlotsCount / totalSlots) * 100;

    final contractMap = {for (var c in contracts) c.slotNumber: c};

    // 実際の収益計算 (契約があれば契約の金額、なければ0)
    final currentMonthlyRevenue = slots
        .where((s) => s.status == 'contracted')
        .fold<int>(0, (sum, s) {
          final contract = contractMap[s.slotNumber];
          final fee = (contract?.monthlyFee as int?) ?? (s.price as int);
          return sum + fee;
        });

    // 満車時収益計算 (各区画のデフォルト設定金額の合計)
    final potentialMonthlyRevenue = slots.fold<int>(
      0,
      (sum, s) => sum + (s.price as int),
    );

    final multiplier = _isAnnual ? 12 : 1;
    final currentRevenue = currentMonthlyRevenue * multiplier;
    final potentialRevenue = potentialMonthlyRevenue * multiplier;
    final revenueRate = potentialRevenue > 0
        ? (currentRevenue / potentialRevenue) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '運用状況指標',
                style: GoogleFonts.notoSansJp(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<bool>(
                    value: _isAnnual,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _isAnnual = value;
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: false, child: Text('月額表示')),
                      DropdownMenuItem(value: true, child: Text('年額表示')),
                    ],
                    style: GoogleFonts.notoSansJp(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '稼働率',
                  '${occupancyRate.toStringAsFixed(1)}%',
                  '$contractedSlotsCount / $totalSlots 台',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  '収益状況 (${revenueRate.toStringAsFixed(1)}%)',
                  '¥${_currencyFormatter.format(currentRevenue)}',
                  '満車時: ¥${_currencyFormatter.format(potentialRevenue)}',
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    String subValue,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.notoSansJp(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          subValue,
          style: GoogleFonts.notoSansJp(
            fontSize: 11,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _buildLegendItem('空き', Colors.green),
        const SizedBox(width: 24),
        _buildLegendItem('契約済み', Colors.red),
        const Spacer(),
        IconButton(
          onPressed: () {
            ref.invalidate(parkingSlotsProvider(widget.parkingLot.id));
            ref.invalidate(contractsProvider);
            ref.invalidate(parkingStatsProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('最新の情報を読み込みました'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
          tooltip: '最新情報に更新',
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push(
            '/admin/contracts/add?lotId=${widget.parkingLot.id}',
          ),
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: Text(
            '契約者追加',
            style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildContractDetailSection(String slotNumber) {
    final contractAsync = ref.watch(
      slotContractProvider((
        lotId: widget.parkingLot.id,
        slotNumber: slotNumber,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF1E293B), size: 18),
            const SizedBox(width: 8),
            Text(
              '区画 No.$slotNumber の契約詳細',
              style: GoogleFonts.notoSansJp(
                fontSize: 18, // 20から18に縮小
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        contractAsync.when(
          data: (contract) {
            if (contract == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('契約情報が見つかりませんでした'),
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(16), // 24から16に縮小
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF1E293B,
                    ).withValues(alpha: 0.03), // 影をより薄く
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow('契約者名', contract.userName, Icons.person),
                  const Divider(height: 16), // 32から16に短縮
                  _buildDetailRow(
                    '月額料金',
                    '¥${_currencyFormatter.format(contract.monthlyFee)}',
                    Icons.payments,
                  ),
                  const Divider(height: 16), // 32から16に短縮
                  _buildDetailRow('電話番号', contract.phoneNumber, Icons.phone),
                  const Divider(height: 16), // 32から16に短縮
                  _buildDetailRow(
                    '車両情報',
                    '${contract.carMaker} ${contract.carModel} (${contract.carNumber})',
                    Icons.directions_car,
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('エラー: $err'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.notoSansJp(
            fontSize: 16,
            color: const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.notoSansJp(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final dynamic slot;
  final int? contractFee;
  final bool isSelected;
  final bool isMobile;
  final VoidCallback onTap;

  const _SlotCard({
    required this.slot,
    this.contractFee,
    required this.isSelected,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = slot.status == 'available';
    final baseColor = isAvailable ? Colors.green : Colors.red;
    final color = isSelected ? Colors.blue : baseColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isSelected ? 0.8 : 0.3),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.slotNumber,
              style: GoogleFonts.notoSansJp(
                fontSize: isMobile ? 16 : 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '¥${NumberFormat('#,###').format(contractFee ?? slot.price)}',
                    style: GoogleFonts.notoSansJp(
                      fontSize: isMobile ? 10 : 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (contractFee != null && contractFee != slot.price) ...[
                    Text(
                      ' / ¥${NumberFormat('#,###').format(slot.price)}',
                      style: GoogleFonts.notoSansJp(
                        fontSize: isMobile ? 8 : 10,
                        fontWeight: FontWeight.normal,
                        color: color.withValues(alpha: 0.5),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(height: 4),
              Text(
                isAvailable ? '空き' : '契約中',
                style: GoogleFonts.notoSansJp(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
