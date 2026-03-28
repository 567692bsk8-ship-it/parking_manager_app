import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/parking_repository.dart';
import '../data/parking_lot_model.dart';
import '../data/parking_slot_model.dart';
import '../data/contract_model.dart';
import '../../auth/providers/auth_provider.dart';

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepositoryImpl();
});

/// 現在のユーザーまたは表示対象の管理者のIDを取得
final activeManagerIdProvider = Provider<String?>((ref) {
  final role = ref.watch(userRoleProvider);
  if (role == 'dev') {
    return ref.watch(viewingAdminIdProvider);
  }
  if (role == 'admin') {
    return ref.watch(authUserProvider).value?.uid;
  }
  return null;
});

final parkingLotsProvider = StreamProvider<List<ParkingLot>>((ref) {
  final managerId = ref.watch(activeManagerIdProvider);
  if (managerId == null) return Stream.value([]);
  return ref
      .watch(parkingRepositoryProvider)
      .getParkingLotsStream(managerId: managerId);
});

final parkingLotByIdProvider = FutureProvider.family<ParkingLot?, String>((
  ref,
  lotId,
) {
  return ref.watch(parkingRepositoryProvider).getParkingLotById(lotId);
});

final parkingSlotsProvider = StreamProvider.family<List<ParkingSlot>, String>((
  ref,
  lotId,
) {
  return ref.watch(parkingRepositoryProvider).getSlotsByLotIdStream(lotId);
});

final contractsProvider = StreamProvider<List<Contract>>((ref) {
  final managerId = ref.watch(activeManagerIdProvider);
  if (managerId == null) return Stream.value([]);
  return ref
      .watch(parkingRepositoryProvider)
      .getContractsStream(managerId: managerId);
});

final userContractsProvider = StreamProvider<List<Contract>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref
      .watch(parkingRepositoryProvider)
      .getContractsStreamByUserId(user.uid);
});

typedef SlotArg = ({String lotId, String slotNumber});
final slotContractProvider = FutureProvider.family<Contract?, SlotArg>((
  ref,
  arg,
) {
  return ref
      .watch(parkingRepositoryProvider)
      .getContractBySlot(arg.lotId, arg.slotNumber);
});

final parkingStatsProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  final lotsAsync = ref.watch(parkingLotsProvider);
  final contractsAsync = ref.watch(contractsProvider);

  if (lotsAsync.hasError || contractsAsync.hasError) {
    return AsyncValue.error(
      lotsAsync.error ?? contractsAsync.error!,
      StackTrace.current,
    );
  }
  if (!lotsAsync.hasValue || !contractsAsync.hasValue) {
    return const AsyncValue.loading();
  }

  final lotsList = lotsAsync.value!;
  final contractsList = contractsAsync.value!;

  return AsyncValue.data({
    'totalLots': lotsList.length,
    'totalSlots': lotsList.fold(0, (sum, lot) => sum + lot.totalSlots),
    'occupiedSlots': contractsList.length,
    'freeSlots':
        lotsList.fold(0, (sum, lot) => sum + lot.totalSlots) -
        contractsList.length,
  });
});
