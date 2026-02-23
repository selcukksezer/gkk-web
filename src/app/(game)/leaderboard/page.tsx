// ============================================================
// Leaderboard Page — Kaynak: LeaderboardScreen.gd
// 5 kategori: Servet, PvP, Görev, Güç, Lonca
// Top 3 podyum, sıralama listesi, oyuncu sıra bandı, arama, haftalık/tüm
// ============================================================

"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useSeason } from "@/hooks/useSeason";
import { usePlayerStore } from "@/stores/playerStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import type { LeaderboardCategory, LeaderboardEntry } from "@/hooks/useSeason";
import { formatCompact } from "@/lib/utils/string";

// ── Categories ─────────────────────────────────────────────
const CATEGORIES: { key: LeaderboardCategory; label: string; icon: string; unit: string }[] = [
  { key: "gold",       label: "Servet", icon: "💰", unit: "🪙" },
  { key: "pvp_rating", label: "PvP",    icon: "⚔️", unit: "puan" },
  { key: "level",      label: "Görev",  icon: "📜", unit: "lv" },
  { key: "power",      label: "Güç",    icon: "💪", unit: "güç" },
  { key: "guild_power",label: "Lonca",  icon: "🏰", unit: "güç" },
];

// ── Rich fallback data (30 entries) ────────────────────────
const generateFallback = (): LeaderboardEntry[] => [
  { rank: 1,  player_id: "p1",  username: "GölgeKral",      value: 9_999_999, level: 99, guild_name: "Gölge Ordosu"   },
  { rank: 2,  player_id: "p2",  username: "DemirKılıç",     value: 8_500_000, level: 95, guild_name: "Demir Kalkan"   },
  { rank: 3,  player_id: "p3",  username: "AltınEjder",     value: 7_200_000, level: 90, guild_name: "Altın Ejderha"  },
  { rank: 4,  player_id: "p4",  username: "KuzeyRüzgar",   value: 6_100_000, level: 85, guild_name: null              },
  { rank: 5,  player_id: "p5",  username: "KaranlıkAteş",  value: 5_500_000, level: 82, guild_name: "Karanlık Ateş"  },
  { rank: 6,  player_id: "p6",  username: "YıldızAvcı",    value: 4_900_000, level: 78, guild_name: null              },
  { rank: 7,  player_id: "p7",  username: "BuzSavaşçı",    value: 4_200_000, level: 74, guild_name: "Kuzey Rüzgarı"  },
  { rank: 8,  player_id: "p8",  username: "CemreMihr",      value: 3_700_000, level: 70, guild_name: null              },
  { rank: 9,  player_id: "p9",  username: "ŞahinGözü",     value: 3_100_000, level: 66, guild_name: "Demir Kalkan"   },
  { rank: 10, player_id: "p10", username: "Karanlıkçı",    value: 2_800_000, level: 62, guild_name: null              },
  { rank: 11, player_id: "p11", username: "AtılganKurt",   value: 2_500_000, level: 59, guild_name: "Gölge Ordosu"   },
  { rank: 12, player_id: "p12", username: "DağKartalı",    value: 2_200_000, level: 55, guild_name: null              },
  { rank: 13, player_id: "p13", username: "SertKaya",       value: 2_000_000, level: 52, guild_name: "Altın Ejderha"  },
  { rank: 14, player_id: "p14", username: "HızlıKılıç",   value: 1_800_000, level: 50, guild_name: null              },
  { rank: 15, player_id: "p15", username: "GeceAvcısı",    value: 1_650_000, level: 48, guild_name: "Karanlık Ateş"  },
  { rank: 16, player_id: "p16", username: "UçanOk",         value: 1_500_000, level: 45, guild_name: null              },
  { rank: 17, player_id: "p17", username: "DemirYumruk",   value: 1_350_000, level: 43, guild_name: "Demir Kalkan"   },
  { rank: 18, player_id: "p18", username: "KızılŞimşek",  value: 1_200_000, level: 41, guild_name: null              },
  { rank: 19, player_id: "p19", username: "Bozkurt",        value: 1_100_000, level: 39, guild_name: "Kuzey Rüzgarı"  },
  { rank: 20, player_id: "p20", username: "SiyahGölge",    value: 1_000_000, level: 37, guild_name: null              },
  { rank: 21, player_id: "p21", username: "GümüşKılıç",   value:   900_000, level: 35, guild_name: "Gölge Ordosu"   },
  { rank: 22, player_id: "p22", username: "OtekinFırıldak",value:   800_000, level: 33, guild_name: null              },
  { rank: 23, player_id: "p23", username: "Kasırga",        value:   700_000, level: 31, guild_name: "Altın Ejderha"  },
  { rank: 24, player_id: "p24", username: "ÇelikBilek",   value:   600_000, level: 29, guild_name: null              },
  { rank: 25, player_id: "p25", username: "UğurluKılıç",  value:   500_000, level: 27, guild_name: "Karanlık Ateş"  },
  { rank: 26, player_id: "p26", username: "SonsuzSavaşçı",value:   420_000, level: 25, guild_name: null              },
  { rank: 27, player_id: "p27", username: "KaraFırtına",  value:   350_000, level: 23, guild_name: "Demir Kalkan"   },
  { rank: 28, player_id: "p28", username: "Yıldırım",      value:   280_000, level: 21, guild_name: null              },
  { rank: 29, player_id: "p29", username: "SahilKoruyucu",value:   210_000, level: 19, guild_name: "Kuzey Rüzgarı"  },
  { rank: 30, player_id: "p30", username: "BaşlangıçKahramanı", value: 150_000, level: 17, guild_name: null          },
];

const FALLBACK_DATA = generateFallback();
const MY_MOCK_RANK: LeaderboardEntry = {
  rank: 42, player_id: "me", username: "Sen", value: 85_000, level: 15, guild_name: null,
};

// ── Medal helpers ───────────────────────────────────────────
const MEDALS = ["🥇", "🥈", "🥉"];
const MEDAL_COLORS = ["text-yellow-400", "text-gray-300", "text-amber-600"];
const MEDAL_BG     = ["bg-yellow-400/10", "bg-gray-400/10", "bg-amber-600/10"];
const MEDAL_BORDER = ["border-yellow-400/40", "border-gray-400/40", "border-amber-600/40"];

type Timeframe = "weekly" | "alltime";

export default function LeaderboardPage() {
  const { leaderboard, playerRank, isLoading, fetchLeaderboard, fetchPlayerRank } = useSeason();
  const player = usePlayerStore((s) => s.player);

  const [activeCategory, setActiveCategory] = useState<LeaderboardCategory>("gold");
  const [timeframe, setTimeframe] = useState<Timeframe>("alltime");
  const [searchQuery, setSearchQuery] = useState("");
  const [isRefreshing, setIsRefreshing] = useState(false);

  const loadData = useCallback(async (cat: LeaderboardCategory, tf: Timeframe) => {
    setIsRefreshing(true);
    await Promise.all([fetchLeaderboard(cat), fetchPlayerRank(cat)]);
    setIsRefreshing(false);
  }, [fetchLeaderboard, fetchPlayerRank]);

  // loadData is stable (useCallback with stable useSeason deps); included in deps
  useEffect(() => {
    loadData(activeCategory, timeframe);
  }, [activeCategory, timeframe, loadData]);

  // Resolve data: real API or fallback
  const rawData = leaderboard.length > 0 ? leaderboard : FALLBACK_DATA;

  // Search filter
  const filteredData = useMemo(() => {
    if (!searchQuery.trim()) return rawData;
    const q = searchQuery.toLowerCase();
    return rawData.filter(
      (e) =>
        e.username.toLowerCase().includes(q) ||
        (e.guild_name?.toLowerCase().includes(q) ?? false)
    );
  }, [rawData, searchQuery]);

  const podiumEntries = filteredData.slice(0, 3);
  const regularEntries = filteredData.slice(3, 30);

  // My rank — either from API or mock
  const myRank = playerRank
    ? { ...MY_MOCK_RANK, rank: playerRank, username: player?.username || "Sen" }
    : MY_MOCK_RANK;

  const activeCategoryInfo = CATEGORIES.find((c) => c.key === activeCategory)!;

  const formatValue = (value: number): string => {
    if (activeCategory === "gold") return `🪙 ${formatCompact(value)}`;
    if (activeCategory === "level") return `Lv.${value}`;
    return `${formatCompact(value)} ${activeCategoryInfo.unit}`;
  };

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🏆 Sıralama</h1>
        <div className="flex items-center gap-2">
          {playerRank && (
            <span className="text-xs text-[var(--text-muted)] bg-[var(--bg-elevated)] px-2.5 py-1 rounded-full">
              Sıranız: #{playerRank}
            </span>
          )}
          <button
            onClick={() => loadData(activeCategory, timeframe)}
            disabled={isRefreshing || isLoading}
            className="text-xs text-[var(--accent)] bg-[var(--accent)]/10 px-2.5 py-1 rounded-full disabled:opacity-50 transition-colors hover:bg-[var(--accent)]/20"
          >
            {isRefreshing ? "⏳" : "🔄"} Yenile
          </button>
        </div>
      </div>

      {/* ── Weekly / All-Time Toggle ─────────────────────────── */}
      <div className="flex gap-1 bg-[var(--bg-elevated)] rounded-xl p-1">
        {(["alltime", "weekly"] as Timeframe[]).map((tf) => (
          <button
            key={tf}
            onClick={() => setTimeframe(tf)}
            className={`flex-1 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              timeframe === tf
                ? "bg-[var(--accent)] text-white"
                : "text-[var(--text-muted)]"
            }`}
          >
            {tf === "alltime" ? "🌐 Tüm Zamanlar" : "📅 Haftalık"}
          </button>
        ))}
      </div>

      {/* ── Category Tabs ────────────────────────────────────── */}
      <div className="flex gap-1.5 overflow-x-auto pb-1 scrollbar-hide">
        {CATEGORIES.map((cat) => (
          <button
            key={cat.key}
            className={`flex-shrink-0 px-3 py-2 rounded-xl text-xs font-medium transition-colors border ${
              activeCategory === cat.key
                ? "bg-[var(--accent)] text-white border-[var(--accent)]"
                : "bg-[var(--bg-card)] text-[var(--text-secondary)] border-[var(--border-default)] hover:border-[var(--accent)]/50"
            }`}
            onClick={() => setActiveCategory(cat.key)}
          >
            {cat.icon} {cat.label}
          </button>
        ))}
      </div>

      {/* ── Search Box ───────────────────────────────────────── */}
      <div className="relative">
        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)] text-sm">🔍</span>
        <input
          type="text"
          placeholder="Oyuncu veya lonca ara..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full bg-[var(--bg-elevated)] border border-[var(--border-default)] rounded-xl pl-9 pr-4 py-2.5 text-xs text-[var(--text-primary)] placeholder-[var(--text-muted)] focus:outline-none focus:border-[var(--accent)]/50 transition-colors"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery("")}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--text-muted)] text-sm"
          >
            ✕
          </button>
        )}
      </div>

      {/* ── Loading State ────────────────────────────────────── */}
      {(isLoading && !isRefreshing) ? (
        <div className="text-center py-12 space-y-2">
          <div className="text-3xl animate-spin inline-block">🏆</div>
          <p className="text-sm text-[var(--text-muted)]">Sıralama yükleniyor...</p>
        </div>
      ) : filteredData.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-3xl mb-2">🔍</p>
          <p className="text-sm text-[var(--text-muted)]">"{searchQuery}" için sonuç bulunamadı.</p>
          <button onClick={() => setSearchQuery("")} className="text-xs text-[var(--accent)] underline mt-2">
            Aramayı temizle
          </button>
        </div>
      ) : (
        <>
          {/* ── Top 3 Podium ───────────────────────────────── */}
          {!searchQuery && (
            <div>
              <p className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider mb-3">
                {activeCategoryInfo.icon} {activeCategoryInfo.label} — {timeframe === "alltime" ? "Tüm Zamanlar" : "Bu Hafta"}
              </p>
              <div className="flex items-end gap-2">
                {/* 2nd place */}
                {podiumEntries[1] && (
                  <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.1 }}
                    className={`flex-1 rounded-2xl border p-3 text-center ${MEDAL_BG[1]} ${MEDAL_BORDER[1]}`}
                    style={{ marginBottom: 0 }}
                  >
                    <p className="text-3xl mb-1">{MEDALS[1]}</p>
                    <p className="text-xs font-bold text-[var(--text-primary)] truncate">{podiumEntries[1].username}</p>
                    {podiumEntries[1].guild_name && (
                      <p className="text-[9px] text-[var(--text-muted)] truncate">{podiumEntries[1].guild_name}</p>
                    )}
                    <p className="text-[10px] text-gray-300 font-bold mt-1">Lv.{podiumEntries[1].level}</p>
                    <p className="text-xs font-bold text-gray-300 mt-1">{formatValue(podiumEntries[1].value)}</p>
                  </motion.div>
                )}

                {/* 1st place — tallest */}
                {podiumEntries[0] && (
                  <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0 }}
                    className={`flex-1 rounded-2xl border p-4 text-center ${MEDAL_BG[0]} ${MEDAL_BORDER[0]} shadow-lg shadow-yellow-400/10`}
                  >
                    <p className="text-4xl mb-1.5">{MEDALS[0]}</p>
                    <p className="text-sm font-bold text-[var(--text-primary)] truncate">{podiumEntries[0].username}</p>
                    {podiumEntries[0].guild_name && (
                      <p className="text-[10px] text-[var(--text-muted)] truncate">{podiumEntries[0].guild_name}</p>
                    )}
                    <p className="text-xs text-yellow-400 font-bold mt-1">Lv.{podiumEntries[0].level}</p>
                    <p className="text-sm font-bold text-yellow-400 mt-1">{formatValue(podiumEntries[0].value)}</p>
                  </motion.div>
                )}

                {/* 3rd place */}
                {podiumEntries[2] && (
                  <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.2 }}
                    className={`flex-1 rounded-2xl border p-3 text-center ${MEDAL_BG[2]} ${MEDAL_BORDER[2]}`}
                    style={{ marginBottom: 0 }}
                  >
                    <p className="text-3xl mb-1">{MEDALS[2]}</p>
                    <p className="text-xs font-bold text-[var(--text-primary)] truncate">{podiumEntries[2].username}</p>
                    {podiumEntries[2].guild_name && (
                      <p className="text-[9px] text-[var(--text-muted)] truncate">{podiumEntries[2].guild_name}</p>
                    )}
                    <p className="text-[10px] text-amber-600 font-bold mt-1">Lv.{podiumEntries[2].level}</p>
                    <p className="text-xs font-bold text-amber-600 mt-1">{formatValue(podiumEntries[2].value)}</p>
                  </motion.div>
                )}
              </div>
            </div>
          )}

          {/* ── Regular Entries (4–30) ───────────────────────── */}
          <div className="space-y-1">
            {(searchQuery ? filteredData : regularEntries).map((entry, i) => {
              const rank = searchQuery ? entry.rank : i + 4;
              const isMe = entry.player_id === "me" || entry.username === (player?.username ?? "__none__");
              return (
                <motion.div
                  key={entry.player_id}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: Math.min(i * 0.02, 0.3) }}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-xl transition-colors ${
                    isMe
                      ? "bg-[var(--accent)]/15 border border-[var(--accent)]/40"
                      : "bg-[var(--bg-card)] hover:bg-[var(--bg-elevated)]"
                  }`}
                >
                  {/* Rank number */}
                  <span className={`text-xs font-bold w-6 text-right shrink-0 ${
                    isMe ? "text-[var(--accent)]" : "text-[var(--text-muted)]"
                  }`}>
                    #{rank}
                  </span>

                  {/* Player info */}
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5">
                      <p className={`text-xs font-medium truncate ${isMe ? "text-[var(--accent)]" : "text-[var(--text-primary)]"}`}>
                        {entry.username}
                        {isMe && <span className="ml-1 text-[9px]">(sen)</span>}
                      </p>
                    </div>
                    <p className="text-[10px] text-[var(--text-muted)]">
                      Lv.{entry.level}
                      {entry.guild_name && ` • ${entry.guild_name}`}
                    </p>
                  </div>

                  {/* Value */}
                  <span className={`text-xs font-bold shrink-0 ${
                    isMe ? "text-[var(--accent)]" : "text-[var(--text-secondary)]"
                  }`}>
                    {formatValue(entry.value)}
                  </span>
                </motion.div>
              );
            })}
          </div>

          {/* ── My Rank Banner (fixed at bottom of list) ─────── */}
          {!searchQuery && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-2"
            >
              <div className="flex items-center gap-3 px-4 py-3 rounded-xl bg-[var(--accent)]/10 border-2 border-[var(--accent)]/50 shadow-lg shadow-[var(--accent)]/10">
                <span className="text-lg shrink-0">👤</span>
                <div className="flex items-center gap-1.5 shrink-0">
                  <span className="text-sm font-black text-[var(--accent)]">#{myRank.rank}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-bold text-[var(--accent)] truncate">
                    {player?.username || myRank.username}
                    <span className="text-[9px] ml-1 font-normal opacity-70">(senin sıran)</span>
                  </p>
                  <p className="text-[10px] text-[var(--text-muted)]">
                    Lv.{player?.level || myRank.level}
                    {myRank.guild_name && ` • ${myRank.guild_name}`}
                  </p>
                </div>
                <span className="text-xs font-bold text-[var(--accent)] shrink-0">
                  {formatValue(myRank.value)}
                </span>
              </div>
              <p className="text-center text-[10px] text-[var(--text-muted)] mt-2">
                İlk 10'a girmek için {formatValue(rawData[9]?.value ? rawData[9].value - myRank.value : 0)} daha kazan
              </p>
            </motion.div>
          )}
        </>
      )}
    </motion.div>
  );
}
