export type MekanType = 'bar' | 'kahvehane' | 'dovus_kulubu' | 'luks_lounge' | 'yeralti';

export interface Mekan {
  id: string;
  owner_id: string;
  mekan_type: MekanType;
  name: string;
  level: number;
  fame: number;
  suspicion: number;
  is_open: boolean;
  closed_until: string | null;
  monthly_rent_paid_at: string;
  created_at: string;
}

export interface MekanStock {
  id: string;
  mekan_id: string;
  item_id: string;
  quantity: number;
  sell_price: number;
  stocked_at: string;
}

export interface MekanSale {
  id: string;
  mekan_id: string;
  buyer_id: string;
  item_id: string;
  quantity: number;
  price_per_unit: number;
  total_price: number;
  owner_profit: number;
  created_at: string;
}

export interface MekanPvpMatch {
  id: string;
  mekan_id: string;
  attacker_id: string;
  defender_id: string;
  winner_id: string | null;
  gold_wagered: number;
  gold_won: number;
  mekan_commission: number;
  attacker_rating_change: number;
  defender_rating_change: number;
  created_at: string;
}
