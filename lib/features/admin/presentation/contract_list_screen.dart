import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/parking_provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/admin_scaffold.dart';

class ContractListScreen extends ConsumerWidget {
  const ContractListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(contractsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 1024;

    return AdminScaffold(
      selectedPath: '/admin/contracts',
      title: '契約者一覧',
      onBack: () => context.go('/admin'),
      actions: [
        Padding(
          padding: isMobile ? const EdgeInsets.only(right: 8) : EdgeInsets.zero,
          child: IconButton(
            onPressed: () => context.push('/admin/contracts/add'),
            icon: const Icon(Icons.add),
            color: const Color(0xFF1E293B),
            tooltip: '新規契約',
          ),
        ),
      ],
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
          child: contractsAsync.when(
            data: (contracts) => contracts.isEmpty
                ? const Center(child: Text('契約データがありません'))
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
                              columnSpacing: isMobile ? 24 : 48, // PCでは間隔を広げる
                              columns: const [
                                DataColumn(label: Text('契約者名')),
                                DataColumn(label: Text('区画番号')),
                                DataColumn(label: Text('月額料金')),
                                DataColumn(label: Text('開始日')),
                                DataColumn(label: Text('状態')),
                                DataColumn(label: Text('操作')),
                              ],
                              rows: contracts.map((contract) {
                                return DataRow(
                                  onSelectChanged: (selected) {
                                    if (selected != null && selected) {
                                      context.push(
                                        '/admin/contracts/detail',
                                        extra: contract,
                                      );
                                    }
                                  },
                                  cells: [
                                    DataCell(Text(contract.userName)),
                                    DataCell(Text(contract.slotNumber)),
                                    DataCell(
                                      Text(
                                        '¥${NumberFormat('#,###').format(contract.monthlyFee)}',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        DateFormat(
                                          'yyyy/MM/dd',
                                        ).format(contract.startDate),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          '契約中',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.more_vert),
                                        onPressed: () {},
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
