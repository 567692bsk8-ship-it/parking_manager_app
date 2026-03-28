import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../data/parking_lot_model.dart';
import '../providers/parking_provider.dart';

class AddParkingLotScreen extends ConsumerStatefulWidget {
  const AddParkingLotScreen({super.key});

  @override
  ConsumerState<AddParkingLotScreen> createState() =>
      _AddParkingLotScreenState();
}

class _AddParkingLotScreenState extends ConsumerState<AddParkingLotScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _slotsController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _slotsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final managerId = ref.read(activeManagerIdProvider);

      final lot = ParkingLot(
        id: '', // Firestore generates ID
        name: _nameController.text,
        address: _addressController.text,
        totalSlots: int.parse(_slotsController.text),
        managerId: managerId,
      );

      await ref
          .read(parkingRepositoryProvider)
          .addParkingLot(lot, managerId: managerId);

      ref.invalidate(parkingLotsProvider);
      ref.invalidate(parkingStatsProvider);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('駐車場を追加しました')));
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
        title: Text('新規駐車場登録', style: GoogleFonts.notoSansJp()),
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
                _buildTextField(
                  '総区画数',
                  _slotsController,
                  Icons.grid_view,
                  isNumber: true,
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: const Color(0xFFFBFDFF),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? '入力してください' : null,
    );
  }
}
