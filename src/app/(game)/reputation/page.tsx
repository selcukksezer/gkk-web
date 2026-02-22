// ============================================================
// Reputation Page — Kaynak: scenes/ui/screens/ReputationScreen.gd (220 satır)
// İtibar: Kara Liste → Efsane Kahraman (-1000 to +1000)
// API: GET /v1/player/reputation
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";

interface ReputationFaction {
  id: string;
  name: string;
  icon: string;
  current: number;
  nextTierAt: number;
  tier: string;
  tierColor: string;
  bonuses: string[];
}

const REPUTATION_TIERS = ["Kara Liste", "Nefret", "Düşman", "Soğuk", "Nötr", "Dost", "Saygın", "Onurlu", "Efsane Kahraman"];

const FALLBACK_FACTIONS: ReputationFaction[] = [
  {
    id: "f1", name: "Başlangıç Kasabası", icon: "🏘️",
    current: 3200, nextTierAt: 5000, tier: "Dost", tierColor: "#4ade80",
    bonuses: ["Mağaza fiyatlarında %5 indirim", "Ek görev açılır"],
  },
  {
    id: "f2", name: "Tüccar Loncası", icon: "🏪",
    current: 1800, nextTierAt: 3000, tier: "Nötr", tierColor: "#9ca3af",
    bonuses: ["Market komisyonunda %3 indirim"],
  },
  {
    id: "f3", name: "Savaşçı Tarikatı", icon: "⚔️",
    current: 500, nextTierAt: 1500, tier: "Soğuk", tierColor: "#60a5fa",
    bonuses: ["PvP bonus puanı +%2"],
  },
  {
    id: "f4", name: "Simyacılar Birliği", icon: "⚗️",
    current: 2500, nextTierAt: 3000, tier: "Dost", tierColor: "#4ade80",
    bonuses: ["İksir üretim süresi -%10", "Nadir tariflere erişim"],
  },
  {
    id: "f5", name: "Gizli Kardeşlik", icon: "🗝️",
    current: 0, nextTierAt: 1000, tier: "Nefret", tierColor: "#ef4444",
    bonuses: ["Gizli görevlere erişim"],
  },
];

export default function ReputationPage() {
  const [factions, setFactions] = useState<ReputationFaction[]>(FALLBACK_FACTIONS);
  const [isLoading, setIsLoading] = useState(true);

  // Fetch from API — Godot: GET /v1/player/reputation
  const fetchReputation = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<ReputationFaction[]>("/rest/v1/rpc/get_player_reputation");
      if (res.success && res.data && Array.isArray(res.data) && res.data.length > 0) {
        setFactions(res.data);
      }
    } catch {
      // Keep fallback data
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchReputation(); }, [fetchReputation]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">⭐ İtibar</h1>

      <p className="text-xs text-[var(--text-muted)]">
        Farklı gruplarla itibarınızı geliştirerek özel bonuslar ve görevler açın.
      </p>

      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
      <div className="space-y-3">
        {factions.map((faction) => (
          <Card key={faction.id}>
            <div className="p-4">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-2xl">{faction.icon}</span>
                <div className="flex-1">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-bold text-[var(--text-primary)]">{faction.name}</h3>
                    <span className="text-xs font-semibold px-2 py-0.5 rounded-full"
                      style={{ color: faction.tierColor, backgroundColor: `${faction.tierColor}20` }}>
                      {faction.tier}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-[10px] text-[var(--text-muted)] mt-1">
                    <span>{faction.current.toLocaleString("tr-TR")} / {faction.nextTierAt.toLocaleString("tr-TR")}</span>
                    <span>Sonraki: {REPUTATION_TIERS[REPUTATION_TIERS.indexOf(faction.tier) + 1] || "Maks"}</span>
                  </div>
                </div>
              </div>

              <ProgressBar value={faction.current} max={faction.nextTierAt} color="accent" size="sm" />

              {/* Bonuses */}
              <div className="mt-2 space-y-0.5">
                {faction.bonuses.map((bonus, i) => (
                  <p key={i} className="text-[10px] text-[var(--text-secondary)]">✦ {bonus}</p>
                ))}
              </div>
            </div>
          </Card>
        ))}
      </div>
      )}
    </motion.div>
  );
}
