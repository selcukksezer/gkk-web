// ============================================================
// Market Types — Kaynak: scenes/ui/MarketScreen.gd + APIEndpoints
// ============================================================

export type OrderSide = "buy" | "sell";
export type OrderStatus = "open" | "filled" | "cancelled" | "expired";

export interface MarketOrder {
  id: string;
  order_id: string;
  player_id: string;
  player_username: string;
  item_id: string;
  item_name: string;
  side: OrderSide;
  quantity: number;
  price: number;
  fee: number;
  status: OrderStatus;
  region: string;
  created_at: string;
  expires_at: string;
  filled_at: string | null;
}

export interface MarketTicker {
  item_id: string;
  item_name: string;
  item_type?: string;
  rarity: import("./item").Rarity;
  lowest_price: number;
  last_price: number;
  avg_price_24h: number;
  high_24h: number;
  low_24h: number;
  volume_24h: number;
  volume?: number;
  price_change_24h: number;
  price_change?: number;
}

export interface OrderBookEntry {
  price: number;
  quantity: number;
  order_count: number;
}

export interface OrderBook {
  item_id: string;
  bids: OrderBookEntry[];
  asks: OrderBookEntry[];
}

export const MARKET_REGIONS = [
  "central",
  "north",
  "south",
  "east",
  "west",
] as const;

export type MarketRegion = (typeof MARKET_REGIONS)[number];
