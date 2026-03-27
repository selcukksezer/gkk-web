import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../models/market_model.dart';
import '../repositories/market_repository.dart';

enum MarketStatus {
  initial,
  loading,
  ready,
  error,
}

class MarketState {
  const MarketState({
    required this.status,
    required this.tickers,
    required this.myOrders,
    this.errorMessage,
  });

  final MarketStatus status;
  final List<MarketTicker> tickers;
  final List<MarketOrder> myOrders;
  final String? errorMessage;

  factory MarketState.initial() => const MarketState(
        status: MarketStatus.initial,
        tickers: <MarketTicker>[],
        myOrders: <MarketOrder>[],
      );

  MarketState copyWith({
    MarketStatus? status,
    List<MarketTicker>? tickers,
    List<MarketOrder>? myOrders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MarketState(
      status: status ?? this.status,
      tickers: tickers ?? this.tickers,
      myOrders: myOrders ?? this.myOrders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<MarketRepository> marketRepositoryProvider = Provider<MarketRepository>((Ref ref) {
  return SupabaseMarketRepository();
});

class MarketNotifier extends Notifier<MarketState> {
  MarketRepository get _repository => ref.read(marketRepositoryProvider);

  @override
  MarketState build() => MarketState.initial();

  Future<void> loadTickers() async {
    state = state.copyWith(status: MarketStatus.loading, clearError: true);
    try {
      final List<MarketTicker> tickers = await _repository.fetchTickers();
      state = state.copyWith(status: MarketStatus.ready, tickers: tickers);
    } on AppException catch (e) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: 'Pazar verisi yuklenemedi.');
    }
  }

  Future<void> loadMyOrders() async {
    state = state.copyWith(status: MarketStatus.loading, clearError: true);
    try {
      final List<MarketOrder> orders = await _repository.fetchMyOrders();
      state = state.copyWith(status: MarketStatus.ready, myOrders: orders);
    } on AppException catch (e) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(status: MarketStatus.error, errorMessage: 'Siparisler yuklenemedi.');
    }
  }

  Future<bool> createOrder({
    required String itemRowId,
    required int quantity,
    required int price,
  }) async {
    try {
      final bool ok = await _repository.createOrder(
        itemRowId: itemRowId,
        quantity: quantity,
        price: price,
      );
      if (ok) {
        await loadMyOrders();
        await loadTickers();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Siparis olusturulamadi.');
      return false;
    }
  }

  Future<bool> cancelOrder({required String orderId}) async {
    try {
      final bool ok = await _repository.cancelOrder(orderId: orderId);
      if (ok) {
        await loadMyOrders();
        await loadTickers();
      }
      return ok;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(errorMessage: 'Siparis iptal edilemedi.');
      return false;
    }
  }
}

final NotifierProvider<MarketNotifier, MarketState> marketProvider =
    NotifierProvider<MarketNotifier, MarketState>(MarketNotifier.new);
