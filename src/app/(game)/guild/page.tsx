// ============================================================
// Guild Page — Kaynak: scenes/ui/screens/GuildScreen.gd
// Lonca bilgisi, üye listesi, arama & katılma
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Modal } from "@/components/ui/Modal";
import { api } from "@/lib/api";
import { formatGold, formatCompact } from "@/lib/utils/string";
import type { GuildData, GuildMemberData, GuildRole } from "@/types/guild";

const roleEmoji: Record<GuildRole, string> = {
  leader: "👑",
  officer: "⭐",
  member: "🛡️",
};

const roleLabel: Record<GuildRole, string> = {
  leader: "Lider",
  officer: "Subay",
  member: "Üye",
};

export default function GuildPage() {
  const player = usePlayerStore((s) => s.player);
  const gold = usePlayerStore((s) => s.gold);
  const addToast = useUiStore((s) => s.addToast);

  const [guild, setGuild] = useState<GuildData | null>(null);
  const [members, setMembers] = useState<GuildMemberData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<GuildData[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [createModal, setCreateModal] = useState(false);
  const [guildName, setGuildName] = useState("");
  const [guildDesc, setGuildDesc] = useState("");
  const [memberActionModal, setMemberActionModal] = useState<GuildMemberData | null>(null);
  const [isActionLoading, setIsActionLoading] = useState(false);

  // Current player's role in the guild (derived from members list)
  const playerRole: GuildRole = members.find((m) => m.player_id === player?.id)?.role ?? "member";

  useEffect(() => {
    loadGuild();
  }, []);

  const loadGuild = async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<{ guild: GuildData; members: GuildMemberData[] }>(
        "get_my_guild",
        {}
      );
      const guildData = res.data;
      if (guildData?.guild) {
        setGuild(guildData.guild);
        setMembers(
          (guildData.members || []).sort((a, b) => {
            const order: Record<GuildRole, number> = { leader: 0, officer: 1, member: 2 };
            return (order[a.role] ?? 2) - (order[b.role] ?? 2) || b.level - a.level;
          })
        );
      }
    } catch {
      // No guild
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setIsSearching(true);
    try {
      const res = await api.rpc<GuildData[]>("search_guilds", {
        p_query: searchQuery,
      });
      setSearchResults(res.data || []);
    } catch {
      addToast("Arama başarısız", "error");
    } finally {
      setIsSearching(false);
    }
  };

  const handleJoin = async (guildId: string) => {
    try {
      await api.rpc("join_guild", { p_guild_id: guildId });
      addToast("Loncaya katıldın!", "success");
      await loadGuild();
    } catch {
      addToast("Katılma başarısız", "error");
    }
  };

  const handleLeave = async () => {
    try {
      await api.rpc("leave_guild", {});
      addToast("Loncadan ayrıldın", "info");
      setGuild(null);
      setMembers([]);
    } catch {
      addToast("Ayrılma başarısız", "error");
    }
  };

  const handleCreate = async () => {
    if (!guildName.trim()) {
      addToast("Lonca adı gerekli", "warning");
      return;
    }
    if (gold < 10000) {
      addToast("Lonca kurmak 10.000 altın gerektirir", "warning");
      return;
    }
    try {
      await api.rpc("create_guild", {
        p_name: guildName,
        p_description: guildDesc,
      });
      addToast("Lonca kuruldu!", "success");
      setCreateModal(false);
      await loadGuild();
    } catch {
      addToast("Lonca kurulamadı", "error");
    }
  };

  // Member management — Godot: GuildScreen._promote_member/_demote_member/_kick_member
  const handleMemberAction = async (action: "promote" | "demote" | "kick") => {
    if (!memberActionModal) return;
    setIsActionLoading(true);
    const rpcMap = { promote: "promote_guild_member", demote: "demote_guild_member", kick: "kick_guild_member" };
    const msgMap = { promote: "Yükseltildi!", demote: "Rütbesi düşürüldü", kick: "Atıldı!" };
    try {
      const res = await api.rpc(rpcMap[action], { p_member_id: memberActionModal.player_id });
      if (res.success) {
        addToast(`${memberActionModal.username} ${msgMap[action]}`, action === "kick" ? "warning" : "success");
        setMemberActionModal(null);
        await loadGuild();
      } else {
        addToast(res.error || "İşlem başarısız", "error");
      }
    } catch {
      addToast("İşlem başarısız", "error");
    } finally {
      setIsActionLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="p-4 text-center text-sm text-[var(--text-muted)] py-12">
        Yükleniyor...
      </div>
    );
  }

  // Has guild
  if (guild) {
    return (
      <div className="p-4 space-y-4">
        {/* Guild Header */}
        <Card variant="elevated">
          <div className="p-4">
            <h2 className="text-lg font-bold text-[var(--accent-light)]">
              {guild.name}
            </h2>
            <p className="text-xs text-[var(--text-muted)] mt-1">
              {guild.description || "Açıklama yok"}
            </p>
            <div className="grid grid-cols-3 gap-2 mt-3 text-center text-xs">
              <div>
                <p className="font-bold text-[var(--text-primary)]">{guild.level}</p>
                <p className="text-[var(--text-muted)]">Seviye</p>
              </div>
              <div>
                <p className="font-bold text-[var(--text-primary)]">
                  {guild.member_count}/{guild.max_members}
                </p>
                <p className="text-[var(--text-muted)]">Üye</p>
              </div>
              <div>
                <p className="font-bold text-[var(--text-primary)]">
                  {formatCompact(guild.total_power || 0)}
                </p>
                <p className="text-[var(--text-muted)]">Toplam Güç</p>
              </div>
            </div>
          </div>
        </Card>

        {/* Members */}
        <div>
          <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
            👥 Üyeler
          </h3>
          <div className="space-y-1">
            {members.map((m) => (
              <Card key={m.player_id}>
                <div className="p-2 flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-sm">{roleEmoji[m.role]}</span>
                    <div>
                      <p className="text-xs font-medium text-[var(--text-primary)]">
                        {m.username}
                      </p>
                      <p className="text-[10px] text-[var(--text-muted)]">
                        Lv.{m.level} • {roleLabel[m.role]}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`w-2 h-2 rounded-full ${
                        m.is_online ? "bg-[var(--color-success)]" : "bg-[var(--text-muted)]"
                      }`}
                    />
                    {/* Manage button — only leader/officer can act, cannot act on self or leader */}
                    {(playerRole === "leader" || playerRole === "officer") &&
                      m.player_id !== player?.id &&
                      m.role !== "leader" && (
                        <button
                          className="text-[10px] px-2 py-0.5 rounded bg-[var(--border-default)] text-[var(--text-muted)] hover:bg-[var(--primary)] hover:text-white transition-colors"
                          onClick={() => setMemberActionModal(m)}
                        >
                          Yönet
                        </button>
                      )}
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>

        <Button variant="danger" size="sm" fullWidth onClick={handleLeave}>
          Loncadan Ayrıl
        </Button>

        {/* Member Action Modal */}
        <Modal
          isOpen={!!memberActionModal}
          onClose={() => setMemberActionModal(null)}
          title={`👤 ${memberActionModal?.username ?? ""}`}
          size="sm"
        >
          <div className="space-y-2">
            <p className="text-xs text-[var(--text-muted)]">
              Rol: {roleLabel[memberActionModal?.role ?? "member"]} • Lv.{memberActionModal?.level}
            </p>
            {playerRole === "leader" && memberActionModal?.role === "member" && (
              <Button variant="primary" size="sm" fullWidth
                isLoading={isActionLoading}
                onClick={() => handleMemberAction("promote")}>
                ⬆️ Subay Yap
              </Button>
            )}
            {playerRole === "leader" && memberActionModal?.role === "officer" && (
              <Button variant="secondary" size="sm" fullWidth
                isLoading={isActionLoading}
                onClick={() => handleMemberAction("demote")}>
                ⬇️ Rütbeyi Düşür
              </Button>
            )}
            <Button variant="danger" size="sm" fullWidth
              isLoading={isActionLoading}
              onClick={() => handleMemberAction("kick")}>
              🚪 Loncadan At
            </Button>
            <Button variant="secondary" size="sm" fullWidth onClick={() => setMemberActionModal(null)}>
              Vazgeç
            </Button>
          </div>
        </Modal>
      </div>
    );
  }

  // No guild
  return (
    <div className="p-4 space-y-4">
      <h2 className="text-lg font-bold text-[var(--text-primary)]">🏰 Lonca</h2>

      <Card>
        <div className="p-4 text-center">
          <p className="text-sm text-[var(--text-muted)] mb-3">
            Henüz bir loncaya katılmadın
          </p>
          <Button
            variant="primary"
            size="sm"
            onClick={() => setCreateModal(true)}
          >
            🏗️ Lonca Kur (10.000 🪙)
          </Button>
        </div>
      </Card>

      {/* Search */}
      <div className="flex gap-2">
        <input
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Lonca ara..."
          className="flex-1 px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)]"
          onKeyDown={(e) => e.key === "Enter" && handleSearch()}
        />
        <Button
          variant="secondary"
          size="sm"
          isLoading={isSearching}
          onClick={handleSearch}
        >
          Ara
        </Button>
      </div>

      {/* Search results */}
      {searchResults.length > 0 && (
        <div className="space-y-2">
          {searchResults.map((g) => (
            <Card key={g.guild_id}>
              <div className="p-3 flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-[var(--text-primary)]">
                    {g.name}
                  </p>
                  <p className="text-xs text-[var(--text-muted)]">
                    Lv.{g.level} • {g.member_count}/{g.max_members} üye
                  </p>
                </div>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => handleJoin(g.guild_id)}
                >
                  Katıl
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* Create Guild Modal */}
      <Modal
        isOpen={createModal}
        onClose={() => setCreateModal(false)}
        title="🏗️ Lonca Kur"
        size="md"
      >
        <div className="space-y-3">
          <div>
            <label className="block text-xs text-[var(--text-secondary)] mb-1">
              Lonca Adı
            </label>
            <input
              value={guildName}
              onChange={(e) => setGuildName(e.target.value)}
              className="w-full px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)]"
              placeholder="Karanlık Şövalyeler"
            />
          </div>
          <div>
            <label className="block text-xs text-[var(--text-secondary)] mb-1">
              Açıklama
            </label>
            <textarea
              value={guildDesc}
              onChange={(e) => setGuildDesc(e.target.value)}
              className="w-full px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)]"
              rows={3}
              placeholder="Lonca hakkında kısa bilgi..."
            />
          </div>
          <p className="text-xs text-[var(--text-muted)]">
            Maliyet: 🪙 10.000 altın
          </p>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              size="sm"
              fullWidth
              onClick={() => setCreateModal(false)}
            >
              Vazgeç
            </Button>
            <Button
              variant="primary"
              size="sm"
              fullWidth
              onClick={handleCreate}
            >
              Kur
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
