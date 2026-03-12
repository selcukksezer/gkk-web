// ============================================================
// Guild Types — Kaynak: core/data/GuildData.gd + GuildMemberData.gd
// ============================================================

export type GuildRole = "leader" | "officer" | "member";

export interface GuildData {
  guild_id: string;
  name: string;
  description?: string;
  level: number;
  leader_id: string;
  member_count: number;
  max_members: number;
  total_power: number;
  monument_level: number;
  monument_structural: number;
  monument_mystical: number;
  monument_critical: number;
  monument_gold_pool: number;
  members?: GuildMemberData[];
}

export interface GuildMemberData {
  player_id: string;
  user_id?: string;
  username: string;
  level: number;
  role: GuildRole;
  power: number;
  is_online?: boolean;
  contribution?: number;
}
