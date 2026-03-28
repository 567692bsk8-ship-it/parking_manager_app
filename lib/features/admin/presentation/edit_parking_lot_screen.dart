import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../data/parking_lot_model.dart';
import '../data/parking_slot_model.dart';
import '../providers/parking_provider.dart';

class EditParkingLotScreen extends ConsumerStatefulWidget {
  final ParkingLot parkingLot;

  const EditParkingLotScreen({super.key, required this.parkingLot});

  @override
  ConsumerState<EditParkingLotScreen> createState() =>
      _EditParkingLotScreenState();
}

class _EditParkingLotScreenState extends ConsumerState<EditParkingLotScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  String? _selectedSlotNumber;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parkingLot.name);
    _addressController = TextEditingController(text: widget.parkingLot.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final lot = ParkingLot(
        id: widget.parkingLot.id,
        name: _nameController.text,
        address: _addressController.text,
        totalSlots: widget.parkingLot.totalSlots,
      );

      await ref.read(parkingRepositoryProvider).updateParkingLot(lot);

      ref.invalidate(parkingLotsProvider);
      ref.invalidate(parkingStatsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('駐車場情報を更新しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSlot(List<dynamic> slots) async {
    // 空き番号の中で一番小さいものを計算 (例: 001, 002, 004 -> 003)
    final existingNums =
        slots
            .map((s) => int.tryParse(s.slotNumber) ?? 0)
            .where((n) => n > 0)
            .toList()
          ..sort();

    int nextAvailable = 1;
    for (final n in existingNums) {
      if (n == nextAvailable) {
        nextAvailable++;
      } else if (n > nextAvailable) {
        break;
      }
    }
    final suggestedId = nextAvailable.toString().padLeft(3, '0');

    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) {
        final slotController = TextEditingController(text: suggestedId);
        final priceController = TextEditingController(text: '3000');
        return AlertDialog(
          title: const Text('区画の追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slotController,
                decoration: const InputDecoration(labelText: '区画番号 (例: 011)'),
                keyboardType: TextInputType.text,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: '設定料金 (¥)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final price = int.tryParse(priceController.text);
                if (slotController.text.isNotEmpty && price != null) {
                  Navigator.pop(context, (slotController.text, price));
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final newSlot = ParkingSlot(
          lotId: widget.parkingLot.id,
          slotNumber: result.$1,
          price: result.$2,
          status: 'available',
        );
        await ref.read(parkingRepositoryProvider).addSlot(newSlot);
        ref.invalidate(parkingSlotsProvider(widget.parkingLot.id));
        ref.invalidate(parkingLotsProvider);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('区画を追加しました')));
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
  }

  Future<void> _deleteSlot() async {
    if (_selectedSlotNumber == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('区画の削除'),
        content: Text('区画 No.$_selectedSlotNumber を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(parkingRepositoryProvider)
            .deleteSlot(widget.parkingLot.id, _selectedSlotNumber!);
        ref.invalidate(parkingSlotsProvider(widget.parkingLot.id));
        ref.invalidate(parkingLotsProvider);
        setState(() => _selectedSlotNumber = null);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('区画を削除しました')));
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
  }

  Future<void> _updateSlotPrice() async {
    if (_selectedSlotNumber == null) return;
    final newPrice = int.tryParse(_priceController.text);
    if (newPrice == null) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(parkingRepositoryProvider)
          .updateSlotPrice(
            widget.parkingLot.id,
            _selectedSlotNumber!,
            newPrice,
          );
      ref.invalidate(parkingSlotsProvider(widget.parkingLot.id));
      setState(() => _selectedSlotNumber = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('区画の料金を更新しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('価格更新エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(parkingSlotsProvider(widget.parkingLot.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('駐車場情報の編集', style: GoogleFonts.notoSansJp()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('基本情報'),
              _buildCard([
                _buildTextField('駐車場名', _nameController, Icons.local_parking),
                _buildTextField(
                  '所在地',
                  _addressController,
                  Icons.location_on_outlined,
                ),
              ]),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('区画データベース編集'),
                  Row(
                    children: [
                      if (_selectedSlotNumber != null)
                        IconButton(
                          onPressed: _isLoading ? null : _deleteSlot,
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          tooltip: '選択中の区画を削除',
                        ),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => slotsAsync.whenData((s) => _addSlot(s)),
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.indigo,
                        tooltip: '新しい区画を追加',
                      ),
                    ],
                  ),
                ],
              ),
              slotsAsync.when(
                data: (slots) => _buildSlotGridEditor(slots),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('エラー: $e'),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '基本情報を保存する',
                          style: GoogleFonts.notoSansJp(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotGridEditor(List<dynamic> slots) {
    final sortedSlots = [...slots]
      ..sort((a, b) => a.slotNumber.compareTo(b.slotNumber));

    // 5個ずつの行に分ける
    final List<List<dynamic>> rows = [];
    for (var i = 0; i < sortedSlots.length; i += 5) {
      final end = (i + 5 < sortedSlots.length) ? i + 5 : sortedSlots.length;
      rows.add(sortedSlots.sublist(i, end));
    }

    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          // 行を表示
          Row(
            children: [
              for (var slot in rows[rowIndex])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _buildSlotTile(slot),
                  ),
                ),
              // 空きスペースを埋める（最後の行が5個未満の場合）
              for (var i = 0; i < (5 - rows[rowIndex].length); i++)
                const Expanded(child: SizedBox()),
            ],
          ),
          // 選択中の区画がこの行にあれば、すぐ下に入力欄を出す
          if (_selectedSlotNumber != null &&
              rows[rowIndex].any((s) => s.slotNumber == _selectedSlotNumber))
            _buildExpendingEditor(),
        ],
      ],
    );
  }

  Widget _buildSlotTile(dynamic slot) {
    final isSelected = _selectedSlotNumber == slot.slotNumber;
    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedSlotNumber == slot.slotNumber) {
            _selectedSlotNumber = null;
          } else {
            _selectedSlotNumber = slot.slotNumber;
            _priceController.text = slot.price.toString();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.indigo.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.indigo : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              slot.slotNumber,
              style: GoogleFonts.notoSansJp(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.indigo : const Color(0xFF475569),
              ),
            ),
            Text(
              '¥${slot.price}',
              style: GoogleFonts.notoSansJp(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpendingEditor() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(
              'No.$_selectedSlotNumber の設定料金',
              _priceController,
              Icons.payments_outlined,
              isNumber: true,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _updateSlotPrice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.notoSansJp(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
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
        children:
            children.expand((w) => [w, const SizedBox(height: 16)]).toList()
              ..removeLast(),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: enabled ? const Color(0xFFFBFDFF) : const Color(0xFFF1F5F9),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? '入力してください' : null,
    );
  }
}
