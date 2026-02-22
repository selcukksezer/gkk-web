// ============================================================
// Guild Types — Kaynak: core/data/GuildData.gd + GuildMemberData.gd
// ============================================================

export type GuildRole = "leader" | "officer" | "member";

export interface GuildData {
  id: string;
  guild_id: string;
  name: string;
  description: string;
  level: number;
  leader_id: string;
  member_count: number;
  max_members: number;
  total_power: number;
  treasury_gold: number;
  treasury_gems: number;
  tax_rate: number;
  icon_url: string | null;
  created_at: string;
}

export interface GuildMemberData {
  id: string;
  guild_id: string;
  player_id: string;
  username: string;
  level: number;
  role: GuildRole;
  is_online: boolean;
  contribution: number;
  joined_at: string;
  last_active: string;
}
