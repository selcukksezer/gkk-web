// ============================================================
// Auth Types — Kaynak: SessionManager.gd
// ============================================================

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_at: number;
}

export interface LoginRequest {
  email: string;
  password: string;
  device_id: string;
}

export interface RegisterRequest {
  email: string;
  username: string;
  password: string;
  device_id: string;
  referral_code?: string;
}

export interface AuthUser {
  id: string;
  username: string;
  email: string;
  level: number;
  gold: number;
  gems: number;
  energy: number;
  max_energy: number;
  attack: number;
  defense: number;
  health: number;
  max_health: number;
  power: number;
  guild_id: string | null;
  guild_role: string | null;
}

export interface AuthResponse {
  session: AuthSession;
  user: AuthUser;
}
