// ============================================================
// Player Store — Kaynak: StateStore.gd (801 satır)
// Oyuncu profili, enerji, istatistikler, hospital/prison durumu
// Server-authoritative: _sync_to_supabase() ile PATCH çağrılır
// ============================================================

import { create } from "zustand";
import { persist } from "zustand/middleware";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import type { PlayerProfile } from "@/types/player";
import { isActive } from "@/lib/utils/datetime";
import { supabase } from "@/lib/supabase";

// Debounce sync timer
let syncTimer: ReturnType<typeof setTimeout> | null = null;
const SYNC_DEBOUNCE_MS = 2000;

function debouncedSync() {
  if (syncTimer) clearTimeout(syncTimer);
  syncTimer = setTimeout(() => {
    usePlayerStore.getState().syncToSupabase();
  }, SYNC_DEBOUNCE_MS);
}

interface PlayerState {
  // State
  player: PlayerProfile | null;
  profile: PlayerProfile | null;
  energy: number;
  maxEnergy: number;
  gold: number;
  gems: number;
  level: number;
  xp: number;
  nextLevelXp: number;
  tolerance: number;
  pvpRating: number;
  pvpWins: number;
  pvpLosses: number;
  inHospital: boolean;
  hospitalUntil: string | null;
  hospitalReason: string | null;
  inPrison: boolean;
  prisonUntil: string | null;
  prisonReason: string | null;
  lastBribeAt: string | null;
  isLoading: boolean;

  // Computed
  isRestricted: () => boolean;

  // Actions
  loadPlayerData: (data: Record<string, unknown>) => void;
  fetchProfile: () => Promise<void>;
  updateEnergy: (current: number, max?: number) => void;
  consumeEnergy: (amount: number) => boolean;
  updateGold: (amount: number, isDelta?: boolean) => void;
  updateGems: (amount: number, isDelta?: boolean) => void;
  updateTolerance: (value: number) => void;
  addXp: (amount: number) => void;
  updatePlayerData: (updates: Partial<Record<string, unknown>>) => void;
  syncToSupabase: () => Promise<void>;
  refreshData: () => Promise<void>;
  payBail: () => Promise<{ success: boolean; gems_spent?: number; error?: string }>;
  reset: () => void;
}

function calculateNextLevelXp(level: number): number {
  return Math.floor(1000 * Math.pow(level, 1.5));
}

const initialState = {
  player: null as PlayerProfile | null,
  profile: null as PlayerProfile | null,
  energy: 100,
  maxEnergy: 100,
  gold: 0,
  gems: 0,
  level: 1,
  xp: 0,
  nextLevelXp: 1000,
  tolerance: 0,
  pvpRating: 1000,
  pvpWins: 0,
  pvpLosses: 0,
  inHospital: false,
  hospitalUntil: null as string | null,
  hospitalReason: null as string | null,
  inPrison: false,
  prisonUntil: null as string | null,
  prisonReason: null as string | null,
  lastBribeAt: null as string | null,
  isLoading: false,
};

export const usePlayerStore = create<PlayerState>()(
  persist(
    (set, get) => ({
      ...initialState,

      isRestricted: () => get().inHospital || get().inPrison,

  loadPlayerData: (data: Record<string, unknown>) => {
    // Attempt to drill down to the actual DB row or user_metadata if it's nested
    const dbData = (data.player || data.user || data.data || data) as Record<string, unknown>;
    const metadata = (dbData.user_metadata || dbData.raw_user_meta_data || {}) as Record<string, unknown>;

    // Explicitly reconstruct the player object to guarantee username is attached
    const username = (dbData.username || metadata.username || data.username || "Oyuncu") as string;
    const finalPlayerObject = { ...dbData, username } as unknown as PlayerProfile;

    const energy = ((dbData.energy || data.energy) as number) ?? 100;
    const maxEnergy = ((dbData.max_energy || dbData.maxEnergy || data.max_energy) as number) ?? 100;
    const gold = ((dbData.gold || data.gold) as number) ?? 0;
    const gems = ((dbData.gems || data.gems) as number) ?? 0;
    const level = ((dbData.level || data.level) as number) ?? 1;
    const xp = ((dbData.xp || data.xp) as number) ?? 0;
    const tolerance = ((dbData.addiction_level || dbData.tolerance || data.addiction_level) as number) ?? 0;
    const pvpRating = ((dbData.pvp_rating || dbData.pvpRating || data.pvp_rating) as number) ?? 1000;
    const pvpWins = ((dbData.pvp_wins || dbData.pvpWins || data.pvp_wins) as number) ?? 0;
    const pvpLosses = ((dbData.pvp_losses || dbData.pvpLosses || data.pvp_losses) as number) ?? 0;

    const hospitalUntil = ((dbData.hospital_until || dbData.hospitalUntil || data.hospital_until) as string) ?? null;
    const hospitalReason = ((dbData.hospital_reason || dbData.hospitalReason || data.hospital_reason) as string) ?? null;
    const prisonUntil = ((dbData.prison_until || dbData.prisonUntil || data.prison_until) as string) ?? null;
    const prisonReason = ((dbData.prison_reason || dbData.prisonReason || data.prison_reason) as string) ?? null;

    const lastBribeAt = ((dbData.last_bribe_at || data.last_bribe_at) as string) ?? null;

    set({
      player: finalPlayerObject,
      profile: finalPlayerObject,
      energy,
      maxEnergy,
      gold,
      gems,
      level,
      xp,
      nextLevelXp: calculateNextLevelXp(level),
      tolerance,
      pvpRating,
      pvpWins,
      pvpLosses,
      inHospital: isActive(hospitalUntil),
      hospitalUntil,
      hospitalReason,
      inPrison: isActive(prisonUntil),
      prisonUntil,
      prisonReason,
      lastBribeAt,
    });
  },

  fetchProfile: async () => {
    set({ isLoading: true });

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user?.id) {
        // Query directly from the 'public.users' table using the authenticated session
        const { data: dbData, error } = await supabase
          .from("users")
          .select("*")
          .eq("auth_id", session.user.id)
          .single();

        if (dbData && !error) {
          console.log("[PlayerStore] profile payload from public.users:", dbData);
          get().loadPlayerData(dbData);

          // Also sync to authStore so it stays updated
          const { useAuthStore } = await import("@/stores/authStore");
          useAuthStore.setState({ user: dbData as any });

          set({ isLoading: false });
          return;
        }

        if (error) {
          console.warn("[PlayerStore] Failed to fetch from public.users:", error.message);
        }
      }
    } catch (e) {
      console.warn("[PlayerStore] Direct DB fetch failed:", e);
    }

    set({ isLoading: false });
  },

  updateEnergy: (current: number, max?: number) => {
    set((s) => ({
      energy: current,
      maxEnergy: max ?? s.maxEnergy,
    }));
  },

  consumeEnergy: (amount: number) => {
    const { energy } = get();
    if (energy < amount) return false;
    set({ energy: energy - amount });
    debouncedSync();
    return true;
  },

  updateGold: (amount: number, isDelta = false) => {
    set((s) => ({
      gold: isDelta ? s.gold + amount : amount,
    }));
    debouncedSync();
  },

  updateGems: (amount: number, isDelta = false) => {
    set((s) => ({
      gems: isDelta ? s.gems + amount : amount,
    }));
    debouncedSync();
  },

  updateTolerance: (value: number) => {
    set({ tolerance: value });
  },

  addXp: (amount: number) => {
    let { xp, level, nextLevelXp } = get();
    xp += amount;

    // Level-up loop
    while (xp >= nextLevelXp) {
      xp -= nextLevelXp;
      level += 1;
      nextLevelXp = calculateNextLevelXp(level);
    }

    set({ xp, level, nextLevelXp });
    debouncedSync();
  },

  updatePlayerData: (updates) => {
    set((state) => {
      if (!state.player) return state;
      const updated = { ...state.player, ...updates } as unknown as PlayerProfile;
      return { player: updated, profile: updated };
    });
  },

  syncToSupabase: async () => {
    const s = get();
    if (!s.profile?.id) return;
    try {
      await api.patch(`/rest/v1/users?id=eq.${s.profile.id}`, {
        xp: s.xp,
        gold: s.gold,
        gems: s.gems,
        level: s.level,
        energy: s.energy,
        max_energy: Math.max(s.maxEnergy, s.energy),
        addiction_level: s.tolerance,
      });
    } catch (err) {
      console.warn("[PlayerStore] syncToSupabase failed:", err);
    }
  },

  // ── Pay bail / Release from prison via RPC ─────────────────
  payBail: async () => {
    set({ isLoading: true });
    try {
      const res = await api.rpc<any>("release_from_prison", { p_use_bail: true });
      if (res && (res as any).success) {
        const gemsSpent = (res.gems_spent || res.data?.gems_spent || (res as any).gems_spent || 0) as number;
        if (gemsSpent > 0) {
          // subtract gems (delta)
          get().updateGems(-gemsSpent, true);
        }
        // Clear prison flags
        set({ inPrison: false, prisonUntil: null, prisonReason: null });
        // Refresh profile from server to ensure authoritative state
        await get().fetchProfile();
        set({ isLoading: false });
        return { success: true, gems_spent: gemsSpent };
      }
      set({ isLoading: false });
      return { success: false, error: (res as any)?.error || (res as any)?.message || "Kefalet başarısız" };
    } catch (err) {
      set({ isLoading: false });
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  },

  refreshData: async () => {
    await get().fetchProfile();
  },

  reset: () => set(initialState),
    }),
    {
      name: "gkk-player",
      partialize: (state) => ({
        player: state.player,
        profile: state.profile,
        energy: state.energy,
        maxEnergy: state.maxEnergy,
        gold: state.gold,
        gems: state.gems,
        level: state.level,
        xp: state.xp,
        nextLevelXp: state.nextLevelXp,
        tolerance: state.tolerance,
        pvpRating: state.pvpRating,
        pvpWins: state.pvpWins,
        pvpLosses: state.pvpLosses,
        inHospital: state.inHospital,
        hospitalUntil: state.hospitalUntil,
        hospitalReason: state.hospitalReason,
        inPrison: state.inPrison,
        prisonUntil: state.prisonUntil,
        prisonReason: state.prisonReason,
        lastBribeAt: state.lastBribeAt,
      }),
    }
  )
);
