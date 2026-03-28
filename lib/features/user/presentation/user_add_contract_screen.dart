import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../admin/data/contract_model.dart';
import '../../admin/data/parking_lot_model.dart';
import '../../admin/data/parking_slot_model.dart';
import '../../admin/providers/parking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/data/auth_repository.dart';

class UserAddContractScreen extends ConsumerStatefulWidget {
  const UserAddContractScreen({super.key});

  @override
  ConsumerState<UserAddContractScreen> createState() =>
      _UserAddContractScreenState();
}

class _UserAddContractScreenState extends ConsumerState<UserAddContractScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _managerId;
  String? _selectedLotId;
  String? _selectedSlotNumber;

  final _carMakerController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  int _currentStep = 0; // 0: Scan, 1: Details
  bool _isLoading = false;
  final MobileScannerController _mobileScannerController =
      MobileScannerController(autoStart: false);
  bool _showManualFallback = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _currentStep == 0) {
        setState(() => _showManualFallback = true);
      }
    });
  }

  @override
  void dispose() {
    _carMakerController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carNumberController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _mobileScannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_managerId != null) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _managerId = barcode.rawValue;
          _currentStep = 1;
        });
        break;
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLotId == null || _selectedSlotNumber == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('駐車場と区画を選択してください')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authUserProvider).value;
      if (user == null) throw 'ログインが必要です';

      // 駐車場情報をIDで直接取得 (全件取得によるエラー回避)
      final selectedLot = await ref
          .read(parkingRepositoryProvider)
          .getParkingLotById(_selectedLotId!);

      if (selectedLot == null) throw '駐車場情報が取得できませんでした。';

      // スロット情報を取得
      final slots = await ref
          .read(parkingRepositoryProvider)
          .getSlotsByLotId(_selectedLotId!);
      final selectedSlot = slots.firstWhere(
        (s) => s.slotNumber == _selectedSlotNumber,
      );

      final contract = Contract(
        id: '',
        userName: user.displayName ?? '無名',
        userId: user.uid,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        slotNumber: _selectedSlotNumber!,
        monthlyFee: selectedSlot.price,
        startDate: DateTime.now(),
        carMaker: _carMakerController.text,
        carModel: _carModelController.text,
        carColor: _carColorController.text,
        carNumber: _carNumberController.text,
        lotId: _selectedLotId,
        managerId: selectedLot.managerId,
        paymentDay: 25,
        paymentMethod: '振込',
        status: 'active',
      );

      debugPrint(
        'Saving contract for ${user.uid} on slot ${selectedSlot.slotNumber}',
      );
      await ref.read(parkingRepositoryProvider).addContract(contract);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('契約を申請しました')));
        context.pop();
      }
    } catch (e) {
      debugPrint('Contract Application Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新規契約の追加', style: GoogleFonts.notoSansJp()),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentStep == 0
          ? _buildScannerStep()
          : _buildFormStep(),
    );
  }

  Widget _buildScannerStep() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                controller: _mobileScannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'カメラの起動に失敗しました',
                          style: GoogleFonts.notoSansJp(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.errorCode.name == 'permissionDenied'
                              ? 'カメラの使用が許可されていません。'
                              : 'エラー: ${error.errorCode.name}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _mobileScannerController.start(),
                          child: const Text('再試行'),
                        ),
                      ],
                    ),
                  );
                },
                placeholderBuilder: (context) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 64,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _mobileScannerController.start();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('カメラ起動エラー: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.videocam),
                          label: const Text('カメラを起動する'),
                        ),
                        if (_showManualFallback) ...[
                          const SizedBox(height: 32),
                          TextButton(
                            onPressed: _showManualEntryDialog,
                            child: const Text('IDを直接入力する場合はこちら'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              ValueListenableBuilder(
                valueListenable: _mobileScannerController,
                builder: (context, value, child) {
                  if (!value.isRunning) return const SizedBox();
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(32),
          color: Colors.white,
          child: Column(
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 48,
                color: Color(0xFF1E293B),
              ),
              const SizedBox(height: 16),
              const Text(
                '管理者のQRコードをスキャンしてください',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _showManualEntryDialog,
                child: const Text('手動でIDを入力する'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();
    bool resolving = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('管理者の入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '管理者の6桁コード、または管理者IDを入力してください。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'コード or ID',
                  border: OutlineInputBorder(),
                ),
                enabled: !resolving,
              ),
              if (resolving) const LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: resolving
                  ? null
                  : () async {
                      final input = controller.text.trim();
                      if (input.isEmpty) return;
                      setDialogState(() => resolving = true);
                      try {
                        String finalId = input;
                        if (input.length == 6 && int.tryParse(input) != null) {
                          final manager = await ref
                              .read(authRepositoryProvider)
                              .getManagerByCode(input);
                          if (manager != null) {
                            finalId = manager.uid;
                          } else {
                            throw 'コードが見つかりませんでした。';
                          }
                        }
                        if (context.mounted) {
                          setState(() {
                            _managerId = finalId;
                            _currentStep = 1;
                          });
                          context.pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('エラー: $e')));
                        }
                      } finally {
                        if (mounted) setDialogState(() => resolving = false);
                      }
                    },
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('駐車場選択'),
            _buildParkingSelection(),
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
              _buildTextField('色', _carColorController, Icons.palette_outlined),
              _buildTextField(
                'ナンバー（4桁）',
                _carNumberController,
                Icons.pin_outlined,
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionTitle('ご連絡先'),
            _buildCard([
              _buildTextField(
                '電話番号',
                _phoneController,
                Icons.phone_android_outlined,
                isNumber: true,
              ),
              _buildTextField(
                '現住所',
                _addressController,
                Icons.home_outlined,
                textInputAction: TextInputAction.done,
              ),
            ]),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '契約を申請する',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingSelection() {
    if (_managerId == null) return const SizedBox();
    final lotsAsync = ref
        .watch(parkingRepositoryProvider)
        .getParkingLotsStream(managerId: _managerId);
    return StreamBuilder<List<ParkingLot>>(
      stream: lotsAsync,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final lots = snapshot.data!;
        if (lots.isEmpty) return const Text('駐車場が見つかりませんでした。');
        return _buildCard([
          DropdownButtonFormField<String>(
            initialValue: _selectedLotId,
            decoration: const InputDecoration(
              labelText: '駐車場',
              prefixIcon: Icon(Icons.local_parking),
            ),
            items: lots
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (value) => setState(() {
              _selectedLotId = value;
              _selectedSlotNumber = null;
            }),
            validator: (value) => value == null ? '選択してください' : null,
          ),
          const SizedBox(height: 16),
          if (_selectedLotId != null) _buildSlotSelection(_selectedLotId!),
        ]);
      },
    );
  }

  Widget _buildSlotSelection(String lotId) {
    final slotsStream = ref
        .watch(parkingRepositoryProvider)
        .getSlotsByLotIdStream(lotId);
    return StreamBuilder<List<ParkingSlot>>(
      stream: slotsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final availableSlots = snapshot.data!
            .where((s) => s.status == 'available')
            .toList();
        if (availableSlots.isEmpty) {
          return const Text('空き区画がありません。', style: TextStyle(color: Colors.red));
        }
        return DropdownButtonFormField<String>(
          initialValue: _selectedSlotNumber,
          decoration: const InputDecoration(
            labelText: '区画番号',
            prefixIcon: Icon(Icons.apps),
          ),
          items: availableSlots
              .map(
                (s) => DropdownMenuItem(
                  value: s.slotNumber,
                  child: Text(
                    '区画 ${s.slotNumber} (¥${NumberFormat('#,###').format(s.price)})',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedSlotNumber = value),
          validator: (value) => value == null ? '選択してください' : null,
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.notoSansJp(
          fontSize: 18,
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
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textInputAction: textInputAction,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? '入力してください' : null,
    );
  }
}
