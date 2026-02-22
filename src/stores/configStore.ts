// ============================================================
// Config Store — Kaynak: ConfigManager.gd (218 satır)
// Remote config fetch + local fallback + cache
// ============================================================

import { create } from "zustand";
import { api } from "@/lib/api";
import { GAME_CONFIG } from "@/data/GameConstants";

interface ConfigState {
  remoteConfig: Record<string, unknown> | null;
  lastFetchTime: number;
  isLoading: boolean;

  fetchConfig: () => Promise<void>;
  getEnergyConfig: () => typeof GAME_CONFIG.energy;
  getPotionConfig: () => typeof GAME_CONFIG.potion;
  getPvpConfig: () => typeof GAME_CONFIG.pvp;
  getMarketConfig: () => typeof GAME_CONFIG.market;
  getQuestConfig: () => typeof GAME_CONFIG.quest;
  getGuildConfig: () => typeof GAME_CONFIG.guild;
  getMonetizationConfig: () => typeof GAME_CONFIG.monetization;
  getDungeonConfig: () => typeof GAME_CONFIG.dungeon;
  getHospitalConfig: () => typeof GAME_CONFIG.hospital;
  getEnhancementConfig: () => typeof GAME_CONFIG.enhancement;
  isFeatureEnabled: (feature: string) => boolean;
  isMaintenanceMode: () => boolean;
}

const CACHE_TTL = 3600_000; // 1 hour

export const useConfigStore = create<ConfigState>()((set, get) => ({
  remoteConfig: null,
  lastFetchTime: 0,
  isLoading: false,

  fetchConfig: async () => {
    const { lastFetchTime } = get();
    if (Date.now() - lastFetchTime < CACHE_TTL) return;

    set({ isLoading: true });
    try {
      const res = await api.get<Record<string, unknown>>("/rest/v1/rpc/get_game_config");
      if (res.success && res.data) {
        set({ remoteConfig: res.data, lastFetchTime: Date.now(), isLoading: false });
      } else {
        set({ isLoading: false });
      }
    } catch {
      set({ isLoading: false });
    }
  },

  getEnergyConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.energy) return { ...GAME_CONFIG.energy, ...(remote.energy as object) };
    return GAME_CONFIG.energy;
  },

  getPotionConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.potion) return { ...GAME_CONFIG.potion, ...(remote.potion as object) };
    return GAME_CONFIG.potion;
  },

  getPvpConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.pvp) return { ...GAME_CONFIG.pvp, ...(remote.pvp as object) };
    return GAME_CONFIG.pvp;
  },

  getMarketConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.market) return { ...GAME_CONFIG.market, ...(remote.market as object) };
    return GAME_CONFIG.market;
  },

  getQuestConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.quest) return { ...GAME_CONFIG.quest, ...(remote.quest as object) };
    return GAME_CONFIG.quest;
  },

  getGuildConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.guild) return { ...GAME_CONFIG.guild, ...(remote.guild as object) };
    return GAME_CONFIG.guild;
  },

  getMonetizationConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.monetization) return { ...GAME_CONFIG.monetization, ...(remote.monetization as object) };
    return GAME_CONFIG.monetization;
  },

  getDungeonConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.dungeon) return { ...GAME_CONFIG.dungeon, ...(remote.dungeon as object) };
    return GAME_CONFIG.dungeon;
  },

  getHospitalConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.hospital) return { ...GAME_CONFIG.hospital, ...(remote.hospital as object) };
    return GAME_CONFIG.hospital;
  },

  getEnhancementConfig: () => {
    const remote = get().remoteConfig;
    if (remote?.enhancement) return { ...GAME_CONFIG.enhancement, ...(remote.enhancement as object) };
    return GAME_CONFIG.enhancement;
  },

  isFeatureEnabled: (feature: string) => {
    const remote = get().remoteConfig;
    const features = (remote?.features ?? {}) as Record<string, boolean>;
    return features[feature] ?? true;
  },

  isMaintenanceMode: () => {
    const remote = get().remoteConfig;
    return (remote?.maintenance as boolean) ?? false;
  },
}));
