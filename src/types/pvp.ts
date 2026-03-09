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

export interface PvpMatch {
  id: string;
  mekan_id: string;
  attacker_id: string;
  defender_id: string;
  winner_id: string | null;
  attacker_power: number;
  defender_power: number;
  attacker_hp_remaining: number;
  defender_hp_remaining: number;
  gold_stolen: number;
  rep_change_winner: number;
  rep_change_loser: number;
  attacker_rating_before: number;
  attacker_rating_after: number;
  defender_rating_before: number;
  defender_rating_after: number;
  is_critical_success: boolean;
  hospital_triggered: boolean;
  rounds: number;
  created_at: string;
}
