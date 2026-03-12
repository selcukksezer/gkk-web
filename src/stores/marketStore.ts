// ============================================================
// Market Store — Kaynak: PazarScreen.gd + APIEndpoints
// DB RPCs: market_list_item, cancel_sell_order, purchase_market_listing
// DB Tables: market_orders (REST), market_history (REST)
// ============================================================

import { create } from "zustand";
import { api } from "@/lib/api";
import type {
  MarketOrder,
  MarketTicker,
  OrderBook,
  OrderSide,
  MarketRegion,
} from "@/types/market";

interface MarketState {
  // State
  tickers: MarketTicker[];
  orderBook: OrderBook | null;
  myOrders: MarketOrder[];
  selectedRegion: MarketRegion;
  isLoading: boolean;
  error: string | null;

  // Actions
  fetchTickers: () => Promise<void>;
  fetchOrderBook: (itemId: string) => Promise<void>;
  fetchMyOrders: () => Promise<void>;
  createOrder: (
    itemId: string,
    side: OrderSide,
    quantity: number,
    price: number,
    region?: MarketRegion
  ) => Promise<boolean>;
  cancelOrder: (orderId: string) => Promise<boolean>;
  setRegion: (region: MarketRegion) => void;
  reset: () => void;
}

export const useMarketStore = create<MarketState>()((set, get) => ({
  tickers: [],
  orderBook: null,
  myOrders: [],
  selectedRegion: "central",
  isLoading: false,
  error: null,

  fetchTickers: async () => {
    set({ isLoading: true });
    // Query market_orders table — group by item to build ticker-like view
    const res = await api.get<MarketOrder[]>(
      "/rest/v1/market_orders?select=*&status=eq.open&order=price.asc"
    );
    if (res.success && res.data && Array.isArray(res.data)) {
      // Build tickers by grouping orders by item_id
      const map = new Map<string, MarketTicker>();
      for (const order of res.data) {
        const existing = map.get(order.item_id);
        if (!existing) {
          map.set(order.item_id, {
            item_id: order.item_id,
            item_name: order.item_name,
            item_type: undefined,
            rarity: "common" as MarketTicker["rarity"],
            lowest_price: order.price,
            last_price: order.price,
            avg_price_24h: order.price,
            high_24h: order.price,
            low_24h: order.price,
            volume_24h: order.quantity,
            volume: order.quantity,
            price_change_24h: 0,
            price_change: 0,
          });
        } else {
          existing.volume_24h = (existing.volume_24h || 0) + order.quantity;
          existing.volume = existing.volume_24h;
          if (order.price < existing.lowest_price) existing.lowest_price = order.price;
          if (order.price > existing.high_24h) existing.high_24h = order.price;
        }
      }
      set({ tickers: Array.from(map.values()), isLoading: false });
    } else {
      set({ isLoading: false, error: res.error });
    }
  },

  fetchOrderBook: async (itemId: string) => {
    const res = await api.get<MarketOrder[]>(
      `/rest/v1/market_orders?select=*&item_id=eq.${itemId}&status=eq.open&order=price.asc`
    );
    if (res.success && res.data && Array.isArray(res.data)) {
      const asks = res.data.filter((o) => o.side === "sell").map((o) => ({
        price: o.price, quantity: o.quantity, order_count: 1,
      }));
      const bids = res.data.filter((o) => o.side === "buy").map((o) => ({
        price: o.price, quantity: o.quantity, order_count: 1,
      }));
      set({ orderBook: { item_id: itemId, bids, asks } });
    }
  },

  fetchMyOrders: async () => {
    set({ isLoading: true });
    // RLS ensures we only see our own orders
    const res = await api.get<MarketOrder[]>(
      "/rest/v1/market_orders?select=*&status=eq.open&order=created_at.desc"
    );
    if (res.success && res.data) {
      set({ myOrders: Array.isArray(res.data) ? res.data : [], isLoading: false });
    } else {
      set({ isLoading: false, error: res.error });
    }
  },

  createOrder: async (
    itemId: string,
    side: OrderSide,
    quantity: number,
    price: number,
    _region?: MarketRegion
  ) => {
    if (side !== "sell") {
      set({ error: "Sadece satış emri destekleniyor" });
      return false;
    }

    // DB RPC: market_list_item(p_item_row_id uuid, p_quantity int, p_price int)
    const res = await api.rpc("market_list_item", {
      p_item_row_id: itemId,
      p_quantity: quantity,
      p_price: price,
    });

    if (res.success) {
      await get().fetchMyOrders();
      return true;
    }
    set({ error: res.error || "Sipariş oluşturulamadı" });
    return false;
  },

  cancelOrder: async (orderId: string) => {
    // DB RPC: cancel_sell_order(p_order_id uuid)
    const res = await api.rpc("cancel_sell_order", { p_order_id: orderId });

    if (res.success) {
      set((s) => ({
        myOrders: s.myOrders.filter((o) => o.order_id !== orderId && o.id !== orderId),
      }));
      return true;
    }
    set({ error: res.error || "Sipariş iptal edilemedi" });
    return false;
  },

  setRegion: (region: MarketRegion) => set({ selectedRegion: region }),

  reset: () =>
    set({
      tickers: [],
      orderBook: null,
      myOrders: [],
      isLoading: false,
      error: null,
    }),
}));
