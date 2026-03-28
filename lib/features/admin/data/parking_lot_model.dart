class ParkingLot {
  final String id;
  final String name;
  final String address;
  final int totalSlots;
  final String? managerId;

  ParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.totalSlots,
    this.managerId,
  });

  factory ParkingLot.fromFirestore(String id, Map<String, dynamic> data) {
    return ParkingLot(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      totalSlots: (data['total_slots'] as num?)?.toInt() ?? 0,
      managerId: data['manager_id'],
    );
  }
}
