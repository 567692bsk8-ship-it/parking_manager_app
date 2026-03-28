class ParkingSlot {
  final String lotId;
  final String slotNumber;
  final int price;
  final String status; // 'available' or 'contracted'
  final String? managerId;

  ParkingSlot({
    required this.lotId,
    required this.slotNumber,
    required this.price,
    required this.status,
    this.managerId,
  });

  factory ParkingSlot.fromFirestore(Map<String, dynamic> data) {
    return ParkingSlot(
      lotId: data['lot_id'] ?? '',
      slotNumber: data['slot_number'] ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'available',
      managerId: data['manager_id'],
    );
  }
}
