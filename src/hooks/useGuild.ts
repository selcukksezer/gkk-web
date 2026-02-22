// ============================================================
// useGuild — Lonca yönetimi hook'u
// Kaynak: GuildManager.gd (236 satır)
// ============================================================

"use client";

import { useState, useCallback } from "react";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { APIEndpoints } from "@/lib/endpoints";
import { GAME_CONFIG } from "@/data/GameConstants";
import type { GuildData, GuildMemberData, GuildRole } from "@/types/guild";

const ROLE_PERMISSIONS: Record<GuildRole, string[]> = {
  leader: ["kick", "promote", "demote", "invite", "donate", "settings", "treasury"],
  officer: ["kick", "invite", "donate"],
  member: ["donate"],
};

export function useGuild() {
  const [guild, setGuild] = useState<GuildData | null>(null);
  const [members, setMembers] = useState<GuildMemberData[]>([]);
  const [guildList, setGuildList] = useState<GuildData[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const player = usePlayerStore((s) => s.player);
  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  /** Check role permission */
  const hasPermission = useCallback(
    (permission: string, role?: GuildRole): boolean => {
      const playerRole = role ?? (player as unknown as Record<string, unknown>)?.guild_role as GuildRole ?? "member";
      return ROLE_PERMISSIONS[playerRole]?.includes(permission) ?? false;
    },
    [player]
  );

  /** Fetch guild list */
  const fetchGuildList = useCallback(async () => {
    setIsLoading(true);
    const res = await api.get<GuildData[]>(APIEndpoints.GUILD_LIST);
    if (res.success && res.data) setGuildList(res.data);
    setIsLoading(false);
  }, []);

  /** Fetch my guild info */
  const fetchMyGuild = useCallback(async () => {
    const guildId = (player as unknown as Record<string, unknown>)?.guild_id as string | null;
    if (!guildId) return;
    setIsLoading(true);
    const res = await api.get<GuildData>(`${APIEndpoints.GUILD_INFO}?guild_id=${guildId}`);
    if (res.success && res.data) setGuild(res.data);
    setIsLoading(false);
  }, [player]);

  /** Fetch guild members */
  const fetchMembers = useCallback(async (guildId: string) => {
    const res = await api.get<GuildMemberData[]>(
      `${APIEndpoints.GUILD_MEMBERS}?guild_id=${guildId}`
    );
    if (res.success && res.data) setMembers(res.data);
  }, []);

  /** Create guild */
  const createGuild = useCallback(
    async (name: string, tag: string, description: string): Promise<boolean> => {
      const cost = GAME_CONFIG.guild.creationCost;
      if (gold < cost) {
        addToast(`Yetersiz altın! (${cost} gerekli)`, "error");
        return false;
      }
      setIsLoading(true);
      const res = await api.post<GuildData>(APIEndpoints.GUILD_CREATE, {
        name,
        tag,
        description,
      });
      setIsLoading(false);
      if (res.success && res.data) {
        setGuild(res.data);
        updateGold(gold - cost);
        addToast(`"${name}" loncası kuruldu!`, "success");
        return true;
      }
      addToast(res.error ?? "Lonca kurulamadı", "error");
      return false;
    },
    [gold, updateGold, addToast]
  );

  /** Join guild */
  const joinGuild = useCallback(
    async (guildId: string): Promise<boolean> => {
      setIsLoading(true);
      const res = await api.post(APIEndpoints.GUILD_JOIN, { guild_id: guildId });
      setIsLoading(false);
      if (res.success) {
        addToast("Loncaya katıldınız!", "success");
        return true;
      }
      addToast(res.error ?? "Katılma başarısız", "error");
      return false;
    },
    [addToast]
  );

  /** Leave guild */
  const leaveGuild = useCallback(async (): Promise<boolean> => {
    setIsLoading(true);
    const res = await api.post(APIEndpoints.GUILD_LEAVE);
    setIsLoading(false);
    if (res.success) {
      setGuild(null);
      setMembers([]);
      addToast("Loncadan ayrıldınız", "info");
      return true;
    }
    addToast(res.error ?? "Ayrılma başarısız", "error");
    return false;
  }, [addToast]);

  /** Kick member */
  const kickMember = useCallback(
    async (playerId: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.GUILD_KICK, { player_id: playerId });
      if (res.success) {
        setMembers((prev) => prev.filter((m) => m.player_id !== playerId));
        addToast("Üye atıldı", "success");
        return true;
      }
      addToast(res.error ?? "İşlem başarısız", "error");
      return false;
    },
    [addToast]
  );

  /** Promote member */
  const promoteMember = useCallback(
    async (playerId: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.GUILD_PROMOTE, { player_id: playerId });
      if (res.success) {
        addToast("Üye terfi ettirildi", "success");
        return true;
      }
      addToast(res.error ?? "İşlem başarısız", "error");
      return false;
    },
    [addToast]
  );

  /** Demote member */
  const demoteMember = useCallback(
    async (playerId: string): Promise<boolean> => {
      const res = await api.post(APIEndpoints.GUILD_DEMOTE, { player_id: playerId });
      if (res.success) {
        addToast("Üye indirgenmiş", "success");
        return true;
      }
      addToast(res.error ?? "İşlem başarısız", "error");
      return false;
    },
    [addToast]
  );

  /** Donate to treasury */
  const donateToTreasury = useCallback(
    async (amount: number): Promise<boolean> => {
      if (gold < amount) {
        addToast("Yetersiz altın!", "error");
        return false;
      }
      const res = await api.post(APIEndpoints.GUILD_DONATE, { amount });
      if (res.success) {
        updateGold(gold - amount);
        addToast(`${amount} altın bağışlandı!`, "success");
        return true;
      }
      addToast(res.error ?? "Bağış başarısız", "error");
      return false;
    },
    [gold, updateGold, addToast]
  );

  return {
    guild,
    members,
    guildList,
    isLoading,
    hasPermission,
    fetchGuildList,
    fetchMyGuild,
    fetchMembers,
    createGuild,
    joinGuild,
    leaveGuild,
    kickMember,
    promoteMember,
    demoteMember,
    donateToTreasury,
  };
}
