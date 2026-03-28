import 'package:cloud_firestore/cloud_firestore.dart';

class Contract {
  final String id;
  final String userName; // 契約時点の名前（履歴として保持することが多いため残す）
  final String userId;
  final String phoneNumber;
  final String address;
  final String slotNumber;
  final int monthlyFee;
  final DateTime startDate;
  final DateTime? endDate;
  final String carMaker;
  final String carModel;
  final String carColor;
  final String carNumber;
  final String? lotId;
  final String? managerId;

  // 契約固有の情報（正規化として適切）
  final int paymentDay; // 1-31
  final String paymentMethod;
  final String status; // 'active' | 'inactive'
  final String? contractFileUrl;

  Contract({
    required this.id,
    required this.userName,
    required this.userId,
    required this.phoneNumber,
    required this.address,
    required this.slotNumber,
    required this.monthlyFee,
    required this.startDate,
    this.endDate,
    required this.carMaker,
    required this.carModel,
    required this.carColor,
    required this.carNumber,
    this.lotId,
    this.managerId,
    required this.paymentDay,
    required this.paymentMethod,
    required this.status,
    this.contractFileUrl,
  });

  factory Contract.fromFirestore(String id, Map<String, dynamic> data) {
    return Contract(
      id: id,
      userName: data['user_name'] ?? '',
      userId: data['user_id'] ?? '',
      phoneNumber: data['phone_number'] ?? '',
      address: data['address'] ?? '',
      slotNumber: data['slot_number'] ?? '',
      monthlyFee: (data['monthly_fee'] as num?)?.toInt() ?? 0,
      startDate: _parseDate(data['start_date']),
      endDate: data['end_date'] != null ? _parseDate(data['end_date']) : null,
      carMaker: data['car_maker'] ?? '',
      carModel: data['car_model'] ?? '',
      carColor: data['car_color'] ?? '',
      carNumber: data['car_number'] ?? '',
      lotId: data['lot_id'],
      managerId: data['manager_id'],
      paymentDay: (data['payment_day'] as num?)?.toInt() ?? 25,
      paymentMethod: data['payment_method'] ?? '振込',
      status: data['status'] ?? 'active',
      contractFileUrl: data['contract_file_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_name': userName,
      'user_id': userId,
      'phone_number': phoneNumber,
      'address': address,
      'slot_number': slotNumber,
      'monthly_fee': monthlyFee,
      'payment_day': paymentDay,
      'payment_method': paymentMethod,
      'status': status,
      'contract_file_url': contractFileUrl,
      'start_date': startDate,
      'end_date': endDate,
      'car_maker': carMaker,
      'car_model': carModel,
      'car_color': carColor,
      'car_number': carNumber,
      'lot_id': lotId,
      'manager_id': managerId,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
