// ============================================================
// Guild War Page — Kaynak: scenes/ui/screens/GuildWarScreen.gd (237 satır)
// Turnuvalar, Bölgeler, Sıralama
// API: GET /v1/guild_war/season, /tournaments, /territories, /rankings
// POST /v1/guild_war/join, /attack
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { api } from "@/lib/api";
import { useUiStore } from "@/stores/uiStore";

type GWTab = "tournaments" | "territories" | "rankings";

interface Tournament {
  id: string;
  name: string;
  status: "upcoming" | "active" | "completed";
  guildCount: number;
  prizePool: string;
}

interface Territory {
  id: string;
  name: string;
  owner_guild: string;
  defense_power: number;
  reward: string;
}

interface GuildRanking {
  rank: number;
  guild_name: string;
  points: number;
  wins: number;
  losses: number;
}

const FALLBACK_TOURNAMENTS: Tournament[] = [
  { id: "t1", name: "Haftalık Arena", status: "active", guildCount: 8, prizePool: "50,000 Altın" },
  { id: "t2", name: "Sezon Finali", status: "upcoming", guildCount: 0, prizePool: "250,000 Altın + Efsanevi Eşya" },
];

const FALLBACK_TERRITORIES: Territory[] = [
  { id: "tr1", name: "Demir Kalesi", owner_guild: "—", defense_power: 1200, reward: "5,000 Altın/gün" },
  { id: "tr2", name: "Altın Ovası", owner_guild: "—", defense_power: 800, reward: "3,000 Altın/gün" },
  { id: "tr3", name: "Ejderha Tepesi", owner_guild: "—", defense_power: 2500, reward: "Efsanevi Eşya Şansı" },
  { id: "tr4", name: "Karanlık Liman", owner_guild: "—", defense_power: 600, reward: "2,000 Altın/gün" },
];

const FALLBACK_RANKINGS: GuildRanking[] = [
  { rank: 1, guild_name: "Gölge Ordosu", points: 15000, wins: 42, losses: 8 },
  { rank: 2, guild_name: "Demir Kalkan", points: 12500, wins: 38, losses: 12 },
  { rank: 3, guild_name: "Altın Ejderha", points: 10200, wins: 31, losses: 19 },
  { rank: 4, guild_name: "Kuzey Rüzgarı", points: 8800, wins: 27, losses: 23 },
  { rank: 5, guild_name: "Karanlık Ateş", points: 7500, wins: 22, losses: 28 },
];

const STATUS_LABELS = { upcoming: "Yaklaşan", active: "Aktif", completed: "Tamamlandı" };
const STATUS_COLORS = { upcoming: "text-blue-400", active: "text-green-400", completed: "text-[var(--text-muted)]" };

export default function GuildWarPage() {
  const [activeTab, setActiveTab] = useState<GWTab>("tournaments");
  const [tournaments, setTournaments] = useState<Tournament[]>(FALLBACK_TOURNAMENTS);
  const [territories, setTerritories] = useState<Territory[]>(FALLBACK_TERRITORIES);
  const [rankings, setRankings] = useState<GuildRanking[]>(FALLBACK_RANKINGS);
  const [isLoading, setIsLoading] = useState(true);
  const [joiningId, setJoiningId] = useState<string | null>(null);
  const [seasonInfo, setSeasonInfo] = useState<{ season: number; week: number } | null>(null);
  const addToast = useUiStore((s) => s.addToast);

  // Fetch guild war data — Godot: GET /v1/guild_war/*
  const fetchData = useCallback(async () => {
    setIsLoading(true);
    try {
      const [seasonRes, tourRes, terrRes, rankRes] = await Promise.all([
        api.get<{ season: number; week: number }>("/rest/v1/rpc/get_guild_war_season"),
        api.get<Tournament[]>("/rest/v1/rpc/get_guild_war_tournaments"),
        api.get<Territory[]>("/rest/v1/rpc/get_guild_war_territories"),
        api.get<GuildRanking[]>("/rest/v1/rpc/get_guild_war_rankings"),
      ]);

      if (seasonRes.success && seasonRes.data) setSeasonInfo(seasonRes.data);
      if (tourRes.success && tourRes.data && tourRes.data.length > 0) setTournaments(tourRes.data);
      if (terrRes.success && terrRes.data && terrRes.data.length > 0) setTerritories(terrRes.data);
      if (rankRes.success && rankRes.data && rankRes.data.length > 0) setRankings(rankRes.data);
    } catch {
      // Keep fallback
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Join tournament — Godot: POST /v1/guild_war/join
  const joinTournament = async (tournamentId: string) => {
    setJoiningId(tournamentId);
    try {
      const res = await api.post("/rest/v1/rpc/join_guild_war", { p_tournament_id: tournamentId });
      if (res.success) {
        addToast("Turnuvaya katıldınız!", "success");
        await fetchData();
      } else {
        addToast(res.error || "Katılım başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setJoiningId(null);
    }
  };

  // Attack territory
  const attackTerritory = async (territoryId: string) => {
    try {
      const res = await api.post("/rest/v1/rpc/attack_guild_war_territory", { p_territory_id: territoryId });
      if (res.success) {
        addToast("Saldırı başlatıldı!", "success");
        await fetchData();
      } else {
        addToast(res.error || "Saldırı başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    }
  };

  const tabs: { key: GWTab; label: string }[] = [
    { key: "tournaments", label: "🏆 Turnuvalar" },
    { key: "territories", label: "🗺️ Bölgeler" },
    { key: "rankings", label: "📊 Sıralama" },
  ];

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🏴 Lonca Savaşı</h1>
        {seasonInfo && (
          <span className="text-[10px] text-[var(--text-muted)]">
            Sezon {seasonInfo.season} · Hafta {seasonInfo.week}
          </span>
        )}
      </div>

      <div className="flex gap-2">
        {tabs.map((tab) => (
          <button key={tab.key}
            className={`flex-1 py-2 rounded-lg text-xs font-medium transition-colors ${
              activeTab === tab.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(tab.key)}>
            {tab.label}
          </button>
        ))}
      </div>

      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
        <>
          {activeTab === "tournaments" && (
            <div className="space-y-3">
              {tournaments.map((t) => (
                <Card key={t.id}>
                  <div className="p-4">
                    <div className="flex items-center justify-between mb-1">
                      <h3 className="font-bold text-sm text-[var(--text-primary)]">{t.name}</h3>
                      <span className={`text-[10px] font-medium ${STATUS_COLORS[t.status]}`}>{STATUS_LABELS[t.status]}</span>
                    </div>
                    <div className="text-xs text-[var(--text-muted)] mb-3">
                      <p>Loncalar: {t.guildCount} | Ödül: {t.prizePool}</p>
                    </div>
                    <Button
                      variant={t.status === "active" ? "primary" : "secondary"}
                      size="sm"
                      fullWidth
                      disabled={t.status !== "active" || joiningId === t.id}
                      onClick={() => joinTournament(t.id)}
                    >
                      {joiningId === t.id ? "Katılınıyor..." : t.status === "active" ? "Katıl" : t.status === "upcoming" ? "Yakında" : "Sonuçlar"}
                    </Button>
                  </div>
                </Card>
              ))}
            </div>
          )}

          {activeTab === "territories" && (
            <div className="space-y-2">
              {territories.length === 0 ? (
                <Card><div className="p-8 text-center text-sm text-[var(--text-muted)]">Bölge verisi henüz yüklenmedi</div></Card>
              ) : territories.map((t) => (
                <Card key={t.id}>
                  <div className="p-3 flex items-center justify-between">
                    <div>
                      <h3 className="text-sm font-bold text-[var(--text-primary)]">{t.name}</h3>
                      <p className="text-[10px] text-[var(--text-muted)]">
                        Sahip: {t.owner_guild || "Boş"} | Savunma: {t.defense_power}
                      </p>
                    </div>
                    <Button variant="primary" size="sm" onClick={() => attackTerritory(t.id)}>⚔️ Saldır</Button>
                  </div>
                </Card>
              ))}
            </div>
          )}

          {activeTab === "rankings" && (
            <div className="space-y-1">
              {rankings.length === 0 ? (
                <Card><div className="p-8 text-center text-sm text-[var(--text-muted)]">Sıralama verisi henüz yüklenmedi</div></Card>
              ) : rankings.map((r) => (
                <Card key={r.rank}>
                  <div className="p-3 flex items-center gap-3">
                    <span className={`text-lg font-bold ${r.rank <= 3 ? "text-[var(--gold)]" : "text-[var(--text-muted)]"}`}>
                      #{r.rank}
                    </span>
                    <div className="flex-1">
                      <p className="text-sm font-medium text-[var(--text-primary)]">{r.guild_name}</p>
                      <p className="text-[10px] text-[var(--text-muted)]">
                        {r.wins}G / {r.losses}M | {r.points} puan
                      </p>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </>
      )}
    </motion.div>
  );
}
