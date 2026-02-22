// ============================================================
// Crafting Types — Kaynak: CraftingManager.gd
// ============================================================

export interface CraftRecipe {
  id: string;
  recipe_id?: string; // alias
  name: string;
  output_name?: string;
  description: string;
  recipe_type: string;
  item_type: string; // weapon, armor, potion, rune, scroll, accessory — Godot category
  output_item_id: string;
  output_quantity: number;
  output_rarity: string;
  required_level: number;
  required_facility: string | null;
  required_facility_level: number;
  craft_time_seconds: number;
  production_time_seconds?: number; // alias used by Godot RPC
  success_rate: number; // 0-100 or 0.0-1.0
  ingredients: CraftIngredient[];
  gem_cost: number;
  gold_cost: number;
}

export interface CraftIngredient {
  item_id: string;
  item_name: string;
  quantity: number;
}

export interface CraftQueueItem {
  id: string;
  recipe_id: string;
  recipe_name: string;
  batch_count: number;
  started_at: string;
  completes_at: string;
  is_completed: boolean;
  claimed: boolean;
}
