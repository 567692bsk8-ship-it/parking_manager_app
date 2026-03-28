// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contract_model.dart';
import 'parking_lot_model.dart';
import 'parking_slot_model.dart';

/// 駐車場データの取得を抽象化するRepository
abstract class ParkingRepository {
  Future<int> getContractorsCount({String? lotId, String? managerId});
  Future<int> getEmptySlotsCount({String? lotId, String? managerId});
  Future<int> getNonPayersCount({String? lotId, String? managerId});
  Future<List<Contract>> getContracts();
  Future<void> addContract(Contract contract);
  Future<void> updateContract(Contract contract);
  Future<void> deleteContract(String id);
  Future<List<ParkingLot>> getParkingLots();
  Future<List<ParkingSlot>> getSlotsByLotId(String lotId);
  Future<void> addParkingLot(ParkingLot lot, {String? managerId});
  Future<void> updateParkingLot(ParkingLot lot);
  Future<void> updateSlotPrice(String lotId, String slotNumber, int newPrice);
  Future<void> addSlot(ParkingSlot slot);
  Future<void> deleteSlot(String lotId, String slotNumber);
  Future<void> deleteParkingLot(String lotId);
  Future<Contract?> getContractBySlot(String lotId, String slotNumber);
  Future<ParkingLot?> getParkingLotById(String id);

  // Stream methods for real-time updates
  Stream<List<ParkingLot>> getParkingLotsStream({String? managerId});
  Stream<List<Contract>> getContractsStream({String? managerId});
  Stream<List<Contract>> getContractsStreamByUserId(String userId);
  Stream<List<ParkingSlot>> getSlotsByLotIdStream(String lotId);
  Stream<int> getContractorsCountStream({String? lotId, String? managerId});
  Stream<int> getEmptySlotsCountStream({String? lotId, String? managerId});
  Future<void> migrateData(String targetManagerId);
  Future<void> fixMissingManagerIds();
}

/// Firestoreからの実装
class ParkingRepositoryImpl implements ParkingRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Future<int> getContractorsCount({String? lotId, String? managerId}) async {
    Query query = _db
        .collection('slots')
        .where('status', isEqualTo: 'contracted');
    if (lotId != null) {
      query = query.where('lot_id', isEqualTo: lotId);
    } else if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<int> getEmptySlotsCount({String? lotId, String? managerId}) async {
    Query query = _db
        .collection('slots')
        .where('status', isEqualTo: 'available');
    if (lotId != null) {
      query = query.where('lot_id', isEqualTo: lotId);
    } else if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<int> getNonPayersCount({String? lotId, String? managerId}) async {
    Query query = _db
        .collection('payments')
        .where('status', isEqualTo: 'unpaid');
    if (lotId != null) {
      // 支払いにlot_idがない場合は一旦0、将来的に対応
      return 0;
    } else if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<List<Contract>> getContracts() async {
    final snapshot = await _db.collection('contracts').get();
    return snapshot.docs
        .map((doc) => Contract.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> addContract(Contract contract) async {
    final batch = _db.batch();

    // 1. 契約ドキュメントの作成 (Auto-ID)
    final contractDoc = _db.collection('contracts').doc();
    final managerId = contract.managerId;
    if (managerId == null) throw 'manager_id is required to add a contract';

    batch.set(contractDoc, {
      'user_name': contract.userName,
      'user_id': contract.userId,
      'phone_number': contract.phoneNumber,
      'address': contract.address,
      'slot_number': contract.slotNumber,
      'lot_id': contract.lotId,
      'monthly_fee': contract.monthlyFee,
      'payment_day': contract.paymentDay,
      'payment_method': contract.paymentMethod,
      'status': contract.status,
      'contract_file_url': contract.contractFileUrl,
      'start_date': contract.startDate,
      'end_date': contract.endDate,
      'car_maker': contract.carMaker,
      'car_model': contract.carModel,
      'car_color': contract.carColor,
      'car_number': contract.carNumber,
      'manager_id': managerId,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. 区画ステータスの更新 ('contracted' に変更)
    if (contract.lotId != null) {
      final slotDocId = '${contract.lotId}_${contract.slotNumber}';
      batch.update(_db.collection('slots').doc(slotDocId), {
        'status': 'contracted',
        'manager_id': managerId,
      });
    }

    print('Saving contract to ${contractDoc.path}');
    print('Updating slot ${contract.lotId}_${contract.slotNumber}');

    await batch.commit();
    print('Batch commit successful');
  }

  @override
  Future<void> updateContract(Contract contract) async {
    await _db.collection('contracts').doc(contract.id).update({
      'user_name': contract.userName,
      'phone_number': contract.phoneNumber,
      'address': contract.address,
      'slot_number': contract.slotNumber,
      'monthly_fee': contract.monthlyFee,
      'payment_day': contract.paymentDay,
      'payment_method': contract.paymentMethod,
      'status': contract.status,
      'car_maker': contract.carMaker,
      'car_model': contract.carModel,
      'car_color': contract.carColor,
      'car_number': contract.carNumber,
    });
  }

  @override
  Future<void> deleteContract(String id) async {
    final batch = _db.batch();

    // 1. 契約情報を取得して、対象の駐車場IDと区画番号を特定する
    final contractDoc = await _db.collection('contracts').doc(id).get();
    if (!contractDoc.exists) return;

    final data = contractDoc.data()!;
    final String? lotId = data['lot_id'];
    final String? slotNumber = data['slot_number'];

    // 2. 契約ドキュメントの削除
    batch.delete(_db.collection('contracts').doc(id));

    // 3. 区画ステータスを 'available' (空き) に戻す
    if (lotId != null && slotNumber != null) {
      final slotDocId = '${lotId}_$slotNumber';
      batch.update(_db.collection('slots').doc(slotDocId), {
        'status': 'available',
      });
    }

    await batch.commit();
  }

  @override
  Future<List<ParkingLot>> getParkingLots() async {
    final snapshot = await _db.collection('parking_lots').get();
    return snapshot.docs
        .map((doc) => ParkingLot.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<ParkingSlot>> getSlotsByLotId(String lotId) async {
    final snapshot = await _db
        .collection('slots')
        .where('lot_id', isEqualTo: lotId)
        .get();
    return snapshot.docs
        .map((doc) => ParkingSlot.fromFirestore(doc.data()))
        .toList();
  }

  @override
  Future<void> addParkingLot(ParkingLot lot, {String? managerId}) async {
    final batch = _db.batch();

    // 1. 駐車場ドキュメントの作成 (Auto-IDによる自動生成)
    final lotDoc = _db.collection('parking_lots').doc();
    final newLotId = lotDoc.id;

    if (managerId == null) throw 'manager_id is required to add a parking lot';

    batch.set(lotDoc, {
      'name': lot.name,
      'address': lot.address,
      'total_slots': lot.totalSlots,
      'manager_id': managerId,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. 区画ドキュメントの生成 ({駐車場ID}_{区画番号} 形式)
    for (int i = 1; i <= lot.totalSlots; i++) {
      final slotNumber = i.toString().padLeft(3, '0');
      final slotDocId = '${newLotId}_$slotNumber';
      final slotDoc = _db.collection('slots').doc(slotDocId);

      batch.set(slotDoc, {
        'lot_id': newLotId,
        'slot_number': slotNumber,
        'price': 3000,
        'status': 'available',
        'manager_id': managerId,
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  @override
  Future<void> updateParkingLot(ParkingLot lot) async {
    await _db.collection('parking_lots').doc(lot.id).update({
      'name': lot.name,
      'address': lot.address,
    });
  }

  @override
  Future<void> updateSlotPrice(
    String lotId,
    String slotNumber,
    int newPrice,
  ) async {
    final slotDocId = '${lotId}_$slotNumber';
    await _db.collection('slots').doc(slotDocId).update({'price': newPrice});
  }

  @override
  Future<void> addSlot(ParkingSlot slot) async {
    final batch = _db.batch();
    final slotDocId = '${slot.lotId}_${slot.slotNumber}';
    final slotDoc = _db.collection('slots').doc(slotDocId);

    batch.set(slotDoc, {
      'lot_id': slot.lotId,
      'slot_number': slot.slotNumber,
      'price': slot.price,
      'status': 'available',
      'manager_id': slot.managerId ?? '', // Should be provided in slot model
    });

    // 駐車場の総区画数をインクリメント
    final lotDoc = _db.collection('parking_lots').doc(slot.lotId);
    batch.update(lotDoc, {'total_slots': FieldValue.increment(1)});

    await batch.commit();
  }

  @override
  Future<ParkingLot?> getParkingLotById(String id) async {
    final doc = await _db.collection('parking_lots').doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ParkingLot.fromFirestore(doc.id, doc.data()!);
    }
    return null;
  }

  @override
  Future<void> deleteSlot(String lotId, String slotNumber) async {
    final batch = _db.batch();
    final slotDocId = '${lotId}_$slotNumber';
    final slotDoc = _db.collection('slots').doc(slotDocId);

    batch.delete(slotDoc);

    // 駐車場の総区画数をデクリメント
    final lotDoc = _db.collection('parking_lots').doc(lotId);
    batch.update(lotDoc, {'total_slots': FieldValue.increment(-1)});

    await batch.commit();
  }

  @override
  Future<void> deleteParkingLot(String lotId) async {
    final batch = _db.batch();

    // 1. 駐車場の削除
    batch.delete(_db.collection('parking_lots').doc(lotId));

    // 2. 関連する区画の削除
    final slotsSnapshot = await _db
        .collection('slots')
        .where('lot_id', isEqualTo: lotId)
        .get();

    for (var doc in slotsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  @override
  Future<Contract?> getContractBySlot(String lotId, String slotNumber) async {
    final snapshot = await _db
        .collection('contracts')
        .where('lot_id', isEqualTo: lotId)
        .where('slot_number', isEqualTo: slotNumber)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Contract.fromFirestore(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  @override
  Stream<List<ParkingLot>> getParkingLotsStream({String? managerId}) {
    Query query = _db.collection('parking_lots');
    if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => ParkingLot.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    });
  }

  @override
  Stream<List<Contract>> getContractsStream({String? managerId}) {
    Query query = _db.collection('contracts');
    if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => Contract.fromFirestore(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
    });
  }

  @override
  Stream<List<Contract>> getContractsStreamByUserId(String userId) {
    return _db
        .collection('contracts')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Contract.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  @override
  Stream<List<ParkingSlot>> getSlotsByLotIdStream(String lotId) {
    return _db
        .collection('slots')
        .where('lot_id', isEqualTo: lotId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ParkingSlot.fromFirestore(doc.data()))
              .toList();
        });
  }

  @override
  Stream<int> getContractorsCountStream({String? lotId, String? managerId}) {
    Query query = _db
        .collection('slots')
        .where('status', isEqualTo: 'contracted');
    if (lotId != null) {
      // 特定の駐車場のカウントならマネージャーIDフィルターを外す（古いデータ対応）
      query = query.where('lot_id', isEqualTo: lotId);
    } else if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  @override
  Stream<int> getEmptySlotsCountStream({String? lotId, String? managerId}) {
    Query query = _db
        .collection('slots')
        .where('status', isEqualTo: 'available');
    if (lotId != null) {
      query = query.where('lot_id', isEqualTo: lotId);
    } else if (managerId != null) {
      query = query.where('manager_id', isEqualTo: managerId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  @override
  Future<void> migrateData(String targetManagerId) async {
    final Map<String, String> lotIdMap = {};

    // 1. parking_lots の移行 (Auto-IDへ)
    final lots = await _db.collection('parking_lots').get();
    for (var doc in lots.docs) {
      final oldId = doc.id;
      // 古い形式(lot_xxx)の場合、新しいドキュメントとして作り直す
      if (oldId.startsWith('lot_')) {
        final data = doc.data();
        data['manager_id'] = targetManagerId;
        data['updated_at'] = FieldValue.serverTimestamp();

        final newDoc = _db.collection('parking_lots').doc();
        await newDoc.set(data);
        lotIdMap[oldId] = newDoc.id;
        await doc.reference.delete();
      } else {
        lotIdMap[oldId] = oldId;
        await doc.reference.update({
          'manager_id': targetManagerId,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    }

    // 2. slots の移行 ({newLotId}_{slotNumber} へ再構築)
    final slots = await _db.collection('slots').get();
    for (var doc in slots.docs) {
      final data = doc.data();
      final oldLotId = data['lot_id'] as String?;
      final newLotId = lotIdMap[oldLotId] ?? oldLotId;
      final slotNumber = data['slot_number'] as String?;

      if (newLotId != null && slotNumber != null) {
        final newSlotId = '${newLotId}_$slotNumber';
        data['lot_id'] = newLotId;
        data['manager_id'] = targetManagerId;

        // IDが変わる場合、新規作成して旧ドキュメントを削除
        if (doc.id != newSlotId) {
          await _db.collection('slots').doc(newSlotId).set(data);
          await doc.reference.delete();
        } else {
          // IDが維持される場合でも、中身を最新化
          await doc.reference.update({
            'lot_id': newLotId,
            'manager_id': targetManagerId,
          });
        }
      }
    }

    // 3. contracts の移行 (lot_idフィールドの紐付け更新)
    final contracts = await _db.collection('contracts').get();
    for (var doc in contracts.docs) {
      final oldLotId = doc.data()['lot_id'] as String?;
      final newLotId = lotIdMap[oldLotId];

      final updates = <String, dynamic>{'manager_id': targetManagerId};
      if (newLotId != null) {
        updates['lot_id'] = newLotId;
      }
      await doc.reference.update(updates);
    }
  }

  @override
  Future<void> fixMissingManagerIds() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // 1. 全ての駐車場を取得
    final lots = await _db.collection('parking_lots').get();

    for (var lotDoc in lots.docs) {
      final lotData = lotDoc.data();
      String? managerId = lotData['manager_id'] as String?;

      // 管理者が設定されていない、または古いデフォルトIDの場合は、現在のユーザーを割り当てる
      if (managerId == null || managerId == 'ppLVSMR8s8gJg6mITuKjfQ7yIkG3') {
        managerId = currentUser.uid;
        await lotDoc.reference.update({'manager_id': managerId});
      }

      // 2. その駐車場に紐付く全スロット（slots）のマネージャーIDを同期
      final slots = await _db
          .collection('slots')
          .where('lot_id', isEqualTo: lotDoc.id)
          .get();

      final slotBatch = _db.batch();
      for (var slotDoc in slots.docs) {
        // IDが違う、または未設定なら更新
        if (slotDoc.data()['manager_id'] != managerId) {
          slotBatch.update(slotDoc.reference, {'manager_id': managerId});
        }
      }
      if (slots.docs.isNotEmpty) await slotBatch.commit();

      // 3. その駐車場に紐付く全契約（contracts）のマネージャーIDを同期
      final contracts = await _db
          .collection('contracts')
          .where('lot_id', isEqualTo: lotDoc.id)
          .get();

      final contractedSlotNumbers = contracts.docs
          .map((d) => d.data()['slot_number'] as String)
          .toSet();

      final contractBatch = _db.batch();
      for (var cDoc in contracts.docs) {
        if (cDoc.data()['manager_id'] != managerId) {
          contractBatch.update(cDoc.reference, {'manager_id': managerId});
        }
      }
      if (contracts.docs.isNotEmpty) await contractBatch.commit();

      // 4. スロットのステータス（空き/契約中）を契約実態と同期させる
      final statusBatch = _db.batch();
      for (var slotDoc in slots.docs) {
        final slotNumber = slotDoc.data()['slot_number'] as String;
        final currentStatus = slotDoc.data()['status'] as String;

        // 契約が存在するのに「空き」になっている、またはIDが違う場合に修正
        if (contractedSlotNumbers.contains(slotNumber)) {
          if (currentStatus != 'contracted' ||
              slotDoc.data()['manager_id'] != managerId) {
            statusBatch.update(slotDoc.reference, {
              'status': 'contracted',
              'manager_id': managerId,
            });
          }
        } else {
          // 契約がないのに「契約中」になっている場合は「空き」に戻す
          if (currentStatus != 'available' ||
              slotDoc.data()['manager_id'] != managerId) {
            statusBatch.update(slotDoc.reference, {
              'status': 'available',
              'manager_id': managerId,
            });
          }
        }
      }
      await statusBatch.commit();
    }
  }
}
