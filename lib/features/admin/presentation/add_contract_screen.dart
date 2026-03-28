import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/contract_model.dart';
import '../providers/parking_provider.dart';

class AddContractScreen extends ConsumerStatefulWidget {
  final String? initialLotId;
  final String? initialSlotNumber;

  const AddContractScreen({
    super.key,
    this.initialLotId,
    this.initialSlotNumber,
  });

  @override
  ConsumerState<AddContractScreen> createState() => _AddContractScreenState();
}

class _AddContractScreenState extends ConsumerState<AddContractScreen> {
  final _formKey = GlobalKey<FormState>();

  // 契約者情報
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _feeController = TextEditingController();
  final _paymentDayController = TextEditingController(text: '25');

  // 車両情報
  final _carMakerController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carNumberController = TextEditingController();

  String? _selectedLotId;
  String? _selectedSlotNumber;
  String _paymentMethod = '振込';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLotId = widget.initialLotId;
    _selectedSlotNumber = widget.initialSlotNumber;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _feeController.dispose();
    _paymentDayController.dispose();
    _carMakerController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final managerId = ref.read(activeManagerIdProvider);

      final contract = Contract(
        id: '', // Firestore generates ID
        userName: _nameController.text,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}', // Dummy ID
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        slotNumber: _selectedSlotNumber!,
        monthlyFee: int.parse(_feeController.text.replaceAll(',', '')),
        startDate: DateTime.now(),
        endDate: null,
        carMaker: _carMakerController.text,
        carModel: _carModelController.text,
        carColor: _carColorController.text,
        carNumber: _carNumberController.text,
        lotId: _selectedLotId,
        managerId: managerId,
        paymentDay: int.tryParse(_paymentDayController.text) ?? 25,
        paymentMethod: _paymentMethod,
        status: 'active',
      );

      await ref.read(parkingRepositoryProvider).addContract(contract);

      // リストを更新するためにproviderを再取得
      ref.invalidate(contractsProvider);
      ref.invalidate(parkingStatsProvider);
      if (_selectedLotId != null) {
        ref.invalidate(parkingSlotsProvider(_selectedLotId!));
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('契約を登録しました')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新規契約登録', style: GoogleFonts.notoSansJp()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('契約者情報'),
              _buildCard([
                _buildTextField(
                  '契約者名',
                  _nameController,
                  Icons.person_outline,
                  hint: '駐車太郎',
                  formatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Zぁ-んァ-ン一-龠\s]'),
                    ),
                  ],
                ),
                _buildTextField(
                  '電話番号',
                  _phoneController,
                  Icons.phone_android_outlined,
                  hint: '09012345678',
                  isNumber: true,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                _buildTextField(
                  '住所',
                  _addressController,
                  Icons.home_outlined,
                  hint: '飯田市松尾代田1234-5',
                ),
                _buildParkingLotDropdown(),
                _buildSlotDropdown(),
                _buildTextField(
                  '月額料金',
                  _feeController,
                  Icons.payments_outlined,
                  hint: '3,000',
                  isNumber: true,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CurrencyInputFormatter(),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        '支払日（日）',
                        _paymentDayController,
                        Icons.calendar_today_outlined,
                        isNumber: true,
                        hint: '25',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildDropdownField<String>(
                        label: '支払い方法',
                        value: _paymentMethod,
                        icon: Icons.payment,
                        items: ['振込', '口座振替', 'クレカ', '現金']
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _paymentMethod = v ?? '振込'),
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle('車両情報'),
              _buildCard([
                _buildTextField(
                  'メーカー',
                  _carMakerController,
                  Icons.factory_outlined,
                ),
                _buildTextField(
                  '車種',
                  _carModelController,
                  Icons.minor_crash_outlined,
                ),
                _buildTextField(
                  '色',
                  _carColorController,
                  Icons.palette_outlined,
                ),
                _buildTextField(
                  'ナンバー（4桁）',
                  _carNumberController,
                  Icons.pin_outlined,
                  textInputAction: TextInputAction.done,
                ),
              ]),
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
                          'この内容で登録する',
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
    String? hint,
    List<TextInputFormatter>? formatters,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: formatters,
      textInputAction: textInputAction,
      scrollPadding: const EdgeInsets.only(bottom: 120), // キーボードより上に余白を持たせる
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26),
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFFBFDFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? '入力してください' : null,
    );
  }

  Widget _buildParkingLotDropdown() {
    final parkingLotsAsync = ref.watch(parkingLotsProvider);

    return parkingLotsAsync.when(
      data: (lots) => _buildDropdownField<String>(
        label: '駐車場',
        value: _selectedLotId,
        icon: Icons.local_parking,
        items: lots
            .map(
              (lot) => DropdownMenuItem(value: lot.id, child: Text(lot.name)),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedLotId = value;
            _selectedSlotNumber = null; // 駐車場が変わったら区画をリセット
          });
        },
      ),
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => Text('エラー: $err'),
    );
  }

  Widget _buildSlotDropdown() {
    if (_selectedLotId == null) {
      return const SizedBox.shrink();
    }

    final slotsAsync = ref.watch(parkingSlotsProvider(_selectedLotId!));

    return slotsAsync.when(
      data: (slots) {
        final availableSlots = slots
            .where((s) => s.status == 'available')
            .toList();
        return _buildDropdownField<String>(
          label: '区画番号',
          value: _selectedSlotNumber,
          icon: Icons.directions_car_outlined,
          items: availableSlots
              .map(
                (slot) => DropdownMenuItem(
                  value: slot.slotNumber,
                  child: Text(slot.slotNumber),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedSlotNumber = value),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => Text('エラー: $err'),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFFBFDFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: (value) => value == null ? '選択してください' : null,
    );
  }
}

/// 金額表示用のフォーマッター
class _CurrencyInputFormatter extends TextInputFormatter {
  final _formatter = NumberFormat("#,###");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // カンマを除去して数値のみにする
    final intValue = int.tryParse(newValue.text.replaceAll(',', ''));
    if (intValue == null) return oldValue;

    final formatted = _formatter.format(intValue);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
