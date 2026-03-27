class MarketOrder {
  const MarketOrder({
    required this.orderId,
    required this.itemId,
    required this.itemName,
    required this.side,
    required this.quantity,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  final String orderId;
  final String itemId;
  final String itemName;
  final String side;
  final int quantity;
  final int price;
  final String status;
  final String createdAt;

  factory MarketOrder.fromJson(Map<String, dynamic> json) {
    return MarketOrder(
      orderId: (json['order_id'] ?? json['id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString(),
      itemName: (json['item_name'] ?? 'Bilinmeyen Eşya').toString(),
      side: (json['side'] ?? 'sell').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'open').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class MarketTicker {
  const MarketTicker({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.rarity,
    required this.lowestPrice,
    required this.volume,
    required this.priceChange,
  });

  final String itemId;
  final String itemName;
  final String itemType;
  final String rarity;
  final int lowestPrice;
  final int volume;
  final int priceChange;
}
