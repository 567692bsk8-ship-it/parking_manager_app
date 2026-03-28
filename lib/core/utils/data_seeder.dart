// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class DataSeeder {
  static Future<void> importSeedData() async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      // JSONファイルの読み込み
      final String response = await rootBundle.loadString('seed_data.json');
      final data = await json.decode(response);

      print('=== インポート開始 (リファクタリング版) ===');

      // 既存データの削除 (slots, contracts, payments, parking_lots)
      await _deleteCollection(db, 'slots');
      await _deleteCollection(db, 'contracts');
      await _deleteCollection(db, 'payments');
      await _deleteCollection(db, 'parking_lots');

      // 1. parking_lots のインポート
      final parkingLotsData = data['parking_lots'] as Map<String, dynamic>;
      for (var entry in parkingLotsData.entries) {
        final lotId = entry.key;
        final lotData = entry.value;
        await db.collection('parking_lots').doc(lotId).set(lotData);
        print('駐車場追加: $lotId');

        // 2. slots の自動生成 (lot_id_001 形式)
        final int totalSlots = lotData['total_slots'] ?? 0;
        for (int i = 1; i <= totalSlots; i++) {
          final slotNumber = i.toString().padLeft(3, '0');
          final slotDocId = '${lotId}_$slotNumber';

          // 契約データがあるか確認 (簡易的なステータス設定のため)
          bool isContracted = false;
          if (data['contracts'] != null) {
            final List contracts = data['contracts'];
            isContracted = contracts.any(
              (c) => c['lot_id'] == lotId && c['slot_number'] == slotNumber,
            );
          }

          await db.collection('slots').doc(slotDocId).set({
            'lot_id': lotId,
            'slot_number': slotNumber,
            'price': 3000, // デフォルト価格
            'status': isContracted ? 'contracted' : 'available',
          });
          print('区画追加: $slotDocId');
        }
      }

      // 3. contracts のインポート
      final List contractsData = data['contracts'] ?? [];
      for (var contract in contractsData) {
        await db.collection('contracts').add(contract);
        print('契約追加: ${contract['user_name']}');
      }

      // 4. payments のインポート
      final List paymentsData = data['payments'] ?? [];
      for (var payment in paymentsData) {
        await db.collection('payments').add(payment);
        print('支払い履歴追加: ${payment['user_name']} - ${payment['target_month']}');
      }

      print('=== インポート完了 ===');
    } catch (e) {
      print('インポート中にエラーが発生しました: $e');
    }
  }

  static Future<void> _deleteCollection(
    FirebaseFirestore db,
    String collectionPath,
  ) async {
    final snapshot = await db.collection(collectionPath).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    print('コレクション削除完了: $collectionPath');
  }
}
