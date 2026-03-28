import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/contract_model.dart';
import '../providers/parking_provider.dart';

class EditContractScreen extends ConsumerStatefulWidget {
  final Contract contract;
  const EditContractScreen({super.key, required this.contract});

  @override
  ConsumerState<EditContractScreen> createState() => _EditContractScreenState();
}

class _EditContractScreenState extends ConsumerState<EditContractScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _slotController;
  late TextEditingController _feeController;
  late TextEditingController _paymentDayController;
  late TextEditingController _carMakerController;
  late TextEditingController _carModelController;
  late TextEditingController _carColorController;
  late TextEditingController _carNumberController;

  late String _paymentMethod;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contract.userName);
    _phoneController = TextEditingController(text: widget.contract.phoneNumber);
    _addressController = TextEditingController(text: widget.contract.address);
    _slotController = TextEditingController(text: widget.contract.slotNumber);
    _feeController = TextEditingController(
      text: NumberFormat("#,###").format(widget.contract.monthlyFee),
    );
    _paymentDayController = TextEditingController(
      text: widget.contract.paymentDay.toString(),
    );
    _carMakerController = TextEditingController(text: widget.contract.carMaker);
    _carModelController = TextEditingController(text: widget.contract.carModel);
    _carColorController = TextEditingController(text: widget.contract.carColor);
    _carNumberController = TextEditingController(
      text: widget.contract.carNumber,
    );
    _paymentMethod = widget.contract.paymentMethod;
    _status = widget.contract.status;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _slotController.dispose();
    _feeController.dispose();
    _paymentDayController.dispose();
    _carMakerController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedContract = Contract(
        id: widget.contract.id,
        userName: _nameController.text,
        userId: widget.contract.userId,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        slotNumber: _slotController.text,
        monthlyFee: int.parse(_feeController.text.replaceAll(',', '')),
        startDate: widget.contract.startDate,
        endDate: widget.contract.endDate,
        carMaker: _carMakerController.text,
        carModel: _carModelController.text,
        carColor: _carColorController.text,
        carNumber: _carNumberController.text,
        lotId: widget.contract.lotId,
        managerId: widget.contract.managerId,
        paymentDay: int.tryParse(_paymentDayController.text) ?? 25,
        paymentMethod: _paymentMethod,
        status: _status,
        contractFileUrl: widget.contract.contractFileUrl,
      );

      await ref.read(parkingRepositoryProvider).updateContract(updatedContract);

      ref.invalidate(contractsProvider);
      ref.invalidate(parkingStatsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('契約内容を更新しました')));
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
        title: Text('契約内容の編集', style: GoogleFonts.notoSansJp()),
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
                  isNumber: true,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                _buildTextField('住所', _addressController, Icons.home_outlined),
                _buildTextField(
                  '区画番号',
                  _slotController,
                  Icons.directions_car_outlined,
                ),
                _buildTextField(
                  '月額料金',
                  _feeController,
                  Icons.payments_outlined,
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
                _buildDropdownField<String>(
                  label: '契約状況',
                  value: _status,
                  icon: Icons.info_outline,
                  items: [
                    const DropdownMenuItem(value: 'active', child: Text('有効')),
                    const DropdownMenuItem(
                      value: 'inactive',
                      child: Text('終了'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
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
                ),
              ]),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _update,
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
                          '変更を保存する',
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: formatters,
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
