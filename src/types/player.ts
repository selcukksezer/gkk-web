// ============================================================
// Player Types — Kaynak: core/data/PlayerData.gd
// ============================================================

export interface PlayerProfile {
  id: string;
  auth_id: string;
  username: string;
  email: string;
  display_name: string | null;
  avatar_url: string | null;
  level: number;
  xp: number;
  gold: number;
  gems: number;
  energy: number;
  max_energy: number;
  attack: number;
  defense: number;
  health: number;
  max_health: number;
  power: number;
  is_online: boolean;
  is_banned: boolean;
  tutorial_completed: boolean;
  guild_id: string | null;
  guild_role: string | null;
  referral_code: string | null;
  referred_by: string | null;
  pvp_rating: number;
  pvp_wins: number;
  pvp_losses: number;
  addiction_level: number; // tolerance
  hospital_until: string | null;
  prison_until: string | null;
  prison_reason: string | null;
  global_suspicion_level: number;
  last_bribe_at: string | null;
  last_login_at: string | null;
  last_login?: string | null;
  created_at: string;
  updated_at: string;

  // Extended profile fields (may come from API)
  reputation?: number;
  guild_name?: string | null;
  title?: string | null;
  endurance?: number;
  agility?: number;
  intelligence?: number;
  luck?: number;
  hp?: number;
}

export interface PlayerStats {
  totalPower: number;
  winRate: number;
  questsCompleted: number;
  dungeonClears: number;
}
