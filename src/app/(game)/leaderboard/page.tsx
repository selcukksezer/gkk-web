// ============================================================
// Leaderboard Page — Kaynak: scenes/ui/screens/LeaderboardScreen.gd
// Global sıralama: Servet, PvP, Görev, Ekonomi, Lonca
// ============================================================

"use client";

import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import { useSeason } from "@/hooks/useSeason";
import { Card } from "@/components/ui/Card";
import type { LeaderboardCategory, LeaderboardEntry } from "@/hooks/useSeason";

const CATEGORIES: { key: LeaderboardCategory; label: string; icon: string }[] = [
  { key: "gold", label: "Servet", icon: "💰" },
  { key: "pvp_rating", label: "PvP", icon: "⚔️" },
  { key: "level", label: "Görev", icon: "📜" },
  { key: "power", label: "Güç", icon: "💪" },
  { key: "guild_power", label: "Lonca", icon: "🏰" },
];

const FALLBACK_LEADERBOARD: LeaderboardEntry[] = [
  { rank: 1, player_id: "p1", username: "GölgeKral", value: 9999999, level: 99, guild_name: "Gölge Ordosu" },
  { rank: 2, player_id: "p2", username: "DemirKılıç", value: 8500000, level: 95, guild_name: "Demir Kalkan" },
  { rank: 3, player_id: "p3", username: "AltınEjder", value: 7200000, level: 90, guild_name: "Altın Ejderha" },
  { rank: 4, player_id: "p4", username: "KuzeyRüzgar", value: 6100000, level: 85, guild_name: null },
  { rank: 5, player_id: "p5", username: "KaranlıkAteş", value: 5500000, level: 82, guild_name: "Karanlık Ateş" },
  { rank: 6, player_id: "p6", username: "YıldızAvcı", value: 4900000, level: 78, guild_name: null },
  { rank: 7, player_id: "p7", username: "BuzSavaşçı", value: 4200000, level: 74, guild_name: "Kuzey Rüzgarı" },
  { rank: 8, player_id: "p8", username: "CemreMihr", value: 3700000, level: 70, guild_name: null },
  { rank: 9, player_id: "p9", username: "ŞahinGözü", value: 3100000, level: 66, guild_name: "Demir Kalkan" },
  { rank: 10, player_id: "p10", username: "Karanlıkçı", value: 2800000, level: 62, guild_name: null },
];

export default function LeaderboardPage() {
  const { leaderboard, playerRank, isLoading, fetchLeaderboard, fetchPlayerRank } = useSeason();
  const [activeCategory, setActiveCategory] = useState<LeaderboardCategory>("gold");

  useEffect(() => {
    fetchLeaderboard(activeCategory);
    fetchPlayerRank(activeCategory);
  }, [activeCategory, fetchLeaderboard, fetchPlayerRank]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🏆 Sıralama</h1>
        {playerRank && (
          <span className="text-xs text-[var(--text-muted)]">Sıranız: #{playerRank}</span>
        )}
      </div>

      {/* Category Tabs */}
      <div className="flex gap-1.5 overflow-x-auto pb-1">
        {CATEGORIES.map((cat) => (
          <button key={cat.key}
            className={`flex-shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
              activeCategory === cat.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveCategory(cat.key)}>
            {cat.icon} {cat.label}
          </button>
        ))}
      </div>

      {/* Leaderboard */}
      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
        <div className="space-y-1.5">
          {/* Use fallback if API returned nothing */}
          {(leaderboard.length > 0 ? leaderboard : FALLBACK_LEADERBOARD).slice(0, 3).map((entry, i) => (
            <Card key={entry.player_id} variant={i === 0 ? "elevated" : undefined}>
              <div className="flex items-center gap-3 p-3">
                <span className={`text-xl font-bold ${i === 0 ? "text-[var(--gold)]" : i === 1 ? "text-gray-300" : "text-amber-600"}`}>
                  {i === 0 ? "🥇" : i === 1 ? "🥈" : "🥉"}
                </span>
                <div className="flex-1">
                  <p className="text-sm font-bold text-[var(--text-primary)]">{entry.username}</p>
                  <p className="text-[10px] text-[var(--text-muted)]">Lv.{entry.level}{entry.guild_name ? ` • ${entry.guild_name}` : ""}</p>
                </div>
                <span className="text-sm font-bold text-[var(--accent)]">{entry.value.toLocaleString("tr-TR")}</span>
              </div>
            </Card>
          ))}

          {/* Rest */}
          {(leaderboard.length > 0 ? leaderboard : FALLBACK_LEADERBOARD).slice(3).map((entry) => (
            <div key={entry.player_id} className="flex items-center gap-3 px-3 py-2 rounded-lg bg-[var(--card-bg)]">
              <span className="text-xs font-bold text-[var(--text-muted)] w-6 text-right">#{entry.rank}</span>
              <div className="flex-1">
                <p className="text-xs font-medium text-[var(--text-primary)]">{entry.username}</p>
              </div>
              <span className="text-xs text-[var(--text-secondary)]">{entry.value.toLocaleString("tr-TR")}</span>
            </div>
          ))}
        </div>
      )}
    </motion.div>
  );
}
