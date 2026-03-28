enum MekanType { bar, kahvehane, dovusKulubu, luksLounge, yeralti }

MekanType _parseMekanType(dynamic value) {
  switch (value?.toString()) {
    case 'bar':
      return MekanType.bar;
    case 'kahvehane':
      return MekanType.kahvehane;
    case 'dovus_kulubu':
      return MekanType.dovusKulubu;
    case 'luks_lounge':
      return MekanType.luksLounge;
    case 'yeralti':
      return MekanType.yeralti;
    default:
      return MekanType.bar;
  }
}

String _mekanTypeToString(MekanType type) {
  switch (type) {
    case MekanType.bar:
      return 'bar';
    case MekanType.kahvehane:
      return 'kahvehane';
    case MekanType.dovusKulubu:
      return 'dovus_kulubu';
    case MekanType.luksLounge:
      return 'luks_lounge';
    case MekanType.yeralti:
      return 'yeralti';
  }
}

class Mekan {
  const Mekan({
    required this.id,
    required this.ownerId,
    required this.mekanType,
    required this.name,
    required this.level,
    required this.fame,
    required this.suspicion,
    required this.isOpen,
    this.closedUntil,
    required this.monthlyRentPaidAt,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final MekanType mekanType;
  final String name;
  final int level;
  final int fame;
  final int suspicion;
  final bool isOpen;
  final String? closedUntil;
  final String monthlyRentPaidAt;
  final String createdAt;

  factory Mekan.fromJson(Map<String, dynamic> json) {
    return Mekan(
      id: (json['id'] ?? '').toString(),
      ownerId: (json['owner_id'] ?? '').toString(),
      mekanType: _parseMekanType(json['mekan_type']),
      name: (json['name'] ?? '').toString(),
      level: _asInt(json['level'], fallback: 1),
      fame: _asInt(json['fame']),
      suspicion: _asInt(json['suspicion']),
      isOpen: json['is_open'] == true,
      closedUntil: json['closed_until']?.toString(),
      monthlyRentPaidAt: (json['monthly_rent_paid_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'mekan_type': _mekanTypeToString(mekanType),
        'name': name,
        'level': level,
        'fame': fame,
        'suspicion': suspicion,
        'is_open': isOpen,
        'closed_until': closedUntil,
        'monthly_rent_paid_at': monthlyRentPaidAt,
        'created_at': createdAt,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class MekanStock {
  const MekanStock({
    required this.id,
    required this.mekanId,
    required this.itemId,
    required this.quantity,
    required this.sellPrice,
    required this.stockedAt,
  });

  final String id;
  final String mekanId;
  final String itemId;
  final int quantity;
  final int sellPrice;
  final String stockedAt;

  factory MekanStock.fromJson(Map<String, dynamic> json) {
    return MekanStock(
      id: (json['id'] ?? '').toString(),
      mekanId: (json['mekan_id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      quantity: _asInt(json['quantity']),
      sellPrice: _asInt(json['sell_price']),
      stockedAt: (json['stocked_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mekan_id': mekanId,
        'item_id': itemId,
        'quantity': quantity,
        'sell_price': sellPrice,
        'stocked_at': stockedAt,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class MekanSale {
  const MekanSale({
    required this.id,
    required this.mekanId,
    required this.buyerId,
    required this.itemId,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    required this.ownerProfit,
    required this.createdAt,
  });

  final String id;
  final String mekanId;
  final String buyerId;
  final String itemId;
  final int quantity;
  final int pricePerUnit;
  final int totalPrice;
  final int ownerProfit;
  final String createdAt;

  factory MekanSale.fromJson(Map<String, dynamic> json) {
    return MekanSale(
      id: (json['id'] ?? '').toString(),
      mekanId: (json['mekan_id'] ?? '').toString(),
      buyerId: (json['buyer_id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      quantity: _asInt(json['quantity']),
      pricePerUnit: _asInt(json['price_per_unit']),
      totalPrice: _asInt(json['total_price']),
      ownerProfit: _asInt(json['owner_profit']),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mekan_id': mekanId,
        'buyer_id': buyerId,
        'item_id': itemId,
        'quantity': quantity,
        'price_per_unit': pricePerUnit,
        'total_price': totalPrice,
        'owner_profit': ownerProfit,
        'created_at': createdAt,
      };

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
