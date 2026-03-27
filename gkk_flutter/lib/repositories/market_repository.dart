import '../core/errors/app_exception.dart';
import '../core/services/supabase_service.dart';
import '../models/market_model.dart';

abstract class MarketRepository {
  Future<List<MarketTicker>> fetchTickers();
  Future<List<MarketOrder>> fetchMyOrders();
  Future<bool> createOrder({
    required String itemRowId,
    required int quantity,
    required int price,
  });
  Future<bool> cancelOrder({required String orderId});
}

class SupabaseMarketRepository implements MarketRepository {
  @override
  Future<List<MarketTicker>> fetchTickers() async {
    _ensureReady();

    try {
      final List<dynamic> rows = await SupabaseService.client
          .from('market_orders')
          .select('*')
          .eq('status', 'open')
          .order('price', ascending: true);

      final Map<String, _TickerAgg> grouped = <String, _TickerAgg>{};
      for (final dynamic row in rows) {
        if (row is! Map) continue;
        final Map<String, dynamic> data = Map<String, dynamic>.from(row);
        final String itemId = (data['item_id'] ?? '').toString();
        if (itemId.isEmpty) continue;

        final String itemName = (data['item_name'] ?? 'Bilinmeyen Eşya').toString();
        final int price = (data['price'] as num?)?.toInt() ?? 0;
        final int quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        final String rarity = (data['rarity'] ?? 'common').toString();
        final String itemType = (data['item_type'] ?? '').toString();

        final _TickerAgg agg = grouped.putIfAbsent(
          itemId,
          () => _TickerAgg(
            itemId: itemId,
            itemName: itemName,
            itemType: itemType,
            rarity: rarity,
            lowestPrice: price,
            volume: 0,
          ),
        );

        if (price < agg.lowestPrice) {
          agg.lowestPrice = price;
        }
        agg.volume += quantity;
      }

      return grouped.values
          .map((agg) => MarketTicker(
                itemId: agg.itemId,
                itemName: agg.itemName,
                itemType: agg.itemType,
                rarity: agg.rarity,
                lowestPrice: agg.lowestPrice,
                volume: agg.volume,
                priceChange: 0,
              ))
          .toList();
    } catch (_) {
      throw AppException('Pazar verisi yuklenemedi.', code: 'MARKET_TICKERS_FAILED');
    }
  }

  @override
  Future<List<MarketOrder>> fetchMyOrders() async {
    _ensureReady();

    try {
      final List<dynamic> rows = await SupabaseService.client
          .from('market_orders')
          .select('*')
          .eq('status', 'open')
          .order('created_at', ascending: false);

      return rows
          .whereType<Map>()
          .map((row) => MarketOrder.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      throw AppException('Siparisler yuklenemedi.', code: 'MARKET_ORDERS_FAILED');
    }
  }

  @override
  Future<bool> createOrder({
    required String itemRowId,
    required int quantity,
    required int price,
  }) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'market_list_item',
        params: <String, dynamic>{
          'p_item_row_id': itemRowId,
          'p_quantity': quantity,
          'p_price': price,
        },
      );
      return true;
    } catch (_) {
      throw AppException('Siparis olusturulamadi.', code: 'MARKET_CREATE_FAILED');
    }
  }

  @override
  Future<bool> cancelOrder({required String orderId}) async {
    _ensureReady();

    try {
      await SupabaseService.client.rpc(
        'cancel_sell_order',
        params: <String, dynamic>{'p_order_id': orderId},
      );
      return true;
    } catch (_) {
      throw AppException('Siparis iptal edilemedi.', code: 'MARKET_CANCEL_FAILED');
    }
  }

  void _ensureReady() {
    if (!SupabaseService.isConfigured || !SupabaseService.isInitialized) {
      throw AppException(
        'Supabase baglantisi hazir degil. Once app_constants.dart degerlerini guncelleyin.',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
  }
}

class _TickerAgg {
  _TickerAgg({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    required this.rarity,
    required this.lowestPrice,
    required this.volume,
  });

  final String itemId;
  final String itemName;
  final String itemType;
  final String rarity;
  int lowestPrice;
  int volume;
}
