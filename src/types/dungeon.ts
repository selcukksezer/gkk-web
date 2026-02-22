// ============================================================
// Dungeon Types — Kaynak: core/data/DungeonData.gd + DungeonInstance.gd
// ============================================================

export type DungeonDifficulty =
  | "easy"
  | "medium"
  | "hard"
  | "dungeon"
  | "dungeon_solo"
  | "dungeon_group";

export interface DungeonData {
  id: string;
  dungeon_id: string;
  name: string;
  description: string;
  difficulty: DungeonDifficulty;
  required_level: number;
  min_level: number;
  max_players: number;
  energy_cost: number;
  min_gold: number;
  max_gold: number;
  xp_reward: number;
  base_gold_reward: number;
  base_xp_reward: number;
  success_rate: number;
  is_group: boolean;
  loot_table: string[];
  boss_name: string | null;
}

export interface DungeonInstance {
  id: string;
  dungeon_id: string;
  player_id: string;
  difficulty: DungeonDifficulty;
  started_at: string;
  completed_at: string | null;
  success: boolean | null;
  rewards: DungeonReward[];
}

export interface DungeonReward {
  type: "gold" | "xp" | "item";
  amount?: number;
  item_id?: string;
  rarity?: string;
}
