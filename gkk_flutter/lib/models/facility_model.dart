class FacilityQueueItem {
  const FacilityQueueItem({
    required this.id,
    required this.quantity,
    required this.rarity,
    required this.startedAt,
    required this.completesAt,
    required this.isCompleted,
  });

  final String id;
  final int quantity;
  final String rarity;
  final String startedAt;
  final String completesAt;
  final bool isCompleted;

  factory FacilityQueueItem.fromJson(Map<String, dynamic> json) {
    final String rarity = (json['rarity_outcome'] ?? json['rarity'] ?? 'common').toString().toLowerCase();
    final bool completed =
        json['is_completed'] == true || json['collected'] == true || json['status'] == 'completed' || json['completed_at'] != null;
    return FacilityQueueItem(
      id: (json['id'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      rarity: rarity,
      startedAt: (json['started_at'] ?? '').toString(),
      completesAt: (json['completes_at'] ?? json['completed_at'] ?? '').toString(),
      isCompleted: completed,
    );
  }
}

class PlayerFacility {
  const PlayerFacility({
    required this.id,
    required this.facilityType,
    required this.level,
    required this.suspicion,
    required this.isActive,
    required this.productionStartedAt,
    required this.facilityQueue,
  });

  final String id;
  final String facilityType;
  final int level;
  final int suspicion;
  final bool isActive;
  final String? productionStartedAt;
  final List<FacilityQueueItem> facilityQueue;

  factory PlayerFacility.fromJson(Map<String, dynamic> json) {
    final dynamic queue = json['facility_queue'];
    final List<FacilityQueueItem> facilityQueue = queue is List
        ? queue
            .whereType<Map>()
            .map((item) => FacilityQueueItem.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <FacilityQueueItem>[];

    return PlayerFacility(
      id: (json['id'] ?? '').toString(),
      facilityType: (json['facility_type'] ?? json['type'] ?? '').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      suspicion: (json['suspicion'] as num?)?.toInt() ?? (json['suspicion_level'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      productionStartedAt: json['production_started_at']?.toString(),
      facilityQueue: facilityQueue,
    );
  }
}
