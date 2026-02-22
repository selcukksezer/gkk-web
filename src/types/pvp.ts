// ============================================================
// PvP Types — Kaynak: core/data/PvPData.gd
// ============================================================

export interface PvPTarget {
  id: string;
  player_id: string;
  username: string;
  level: number;
  power: number;
  pvp_rating: number;
  rating: number;
  attack: number;
  defense: number;
  health: number;
  estimated_gold: number;
  guild_name: string | null;
}

export interface PvPResult {
  success: boolean;
  won: boolean;
  opponent_name: string;
  attacker_damage: number;
  defender_damage: number;
  gold_stolen: number;
  gold_change: number;
  rating_change: number;
  is_critical: boolean;
  defender_hospitalized: boolean;
}

export interface PvPHistoryEntry {
  id: string;
  opponent_id: string;
  opponent_name: string;
  opponent_username: string;
  is_attacker: boolean;
  won: boolean;
  result: "win" | "loss" | "draw";
  gold_change: number;
  rating_change: number;
  timestamp: string;
  created_at: string;
  battle_log: string[];
}
