// ============================================================
// Quest Types — Kaynak: core/data/QuestData.gd
// ============================================================

export type QuestDifficulty = "easy" | "medium" | "hard" | "elite" | "dungeon";
export type QuestStatus = "available" | "active" | "completed" | "failed";

export interface QuestData {
  id: string;
  quest_id: string; // alias for id
  name: string;
  description: string;
  difficulty: QuestDifficulty;
  required_level: number;
  energy_cost: number;
  gold_reward: number;
  xp_reward: number;
  gem_reward: number;
  item_rewards: string[];
  status: QuestStatus;
  progress: number;
  progress_max: number;
  target: number;
  expires_at: string | null;
}
