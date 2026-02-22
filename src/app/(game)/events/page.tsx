// ============================================================
// Events Page — Kaynak: scenes/ui/screens/EventScreen.gd (195 satır)
// Etkinlikler: Aktif, Yaklaşan, Geçmiş
// API: GET /v1/events/active, GET /v1/events/upcoming, GET /v1/events/history
// POST /v1/events/participate, POST /v1/events/claim_reward
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { api } from "@/lib/api";
import { useUiStore } from "@/stores/uiStore";

type EventTab = "active" | "upcoming" | "history";

interface GameEvent {
  id: string;
  name: string;
  description: string;
  icon: string;
  status: "active" | "upcoming" | "completed";
  startDate: string;
  endDate: string;
  rewards: string[];
  progress?: number;
  maxProgress?: number;
  participated?: boolean;
}

const FALLBACK_EVENTS: GameEvent[] = [
  {
    id: "e1", name: "Kış Festivali", description: "Özel kış görevlerini tamamlayarak nadir ödüller kazan!",
    icon: "❄️", status: "active", startDate: "2026-01-15", endDate: "2026-02-15",
    rewards: ["Kış Zırhı (Nadir)", "5,000 Altın", "100 Gem"],
    progress: 7, maxProgress: 20,
  },
  {
    id: "e2", name: "Çifte XP Haftası", description: "Tüm aktivitelerden 2x XP kazan!",
    icon: "⚡", status: "active", startDate: "2026-01-20", endDate: "2026-01-27",
    rewards: ["2x XP Boost"],
  },
  {
    id: "e3", name: "Lonca Turnuvası", description: "En güçlü lonca ödülü alır!",
    icon: "🏰", status: "upcoming", startDate: "2026-02-01", endDate: "2026-02-07",
    rewards: ["Efsanevi Sandık x3", "Özel Unvan", "10,000 Altın"],
  },
  {
    id: "e4", name: "Hazine Avı", description: "Zindanlarda gizli hazineleri bul!",
    icon: "💎", status: "upcoming", startDate: "2026-02-10", endDate: "2026-02-17",
    rewards: ["Nadir Malzeme Paketi", "3,000 Altın"],
  },
  {
    id: "e5", name: "Sonbahar Hasadı", description: "Üretim görevlerini tamamla",
    icon: "🍂", status: "completed", startDate: "2025-10-01", endDate: "2025-10-31",
    rewards: ["Hasat Yüzüğü (Nadir)"],
  },
];

export default function EventsPage() {
  const [activeTab, setActiveTab] = useState<EventTab>("active");
  const [events, setEvents] = useState<GameEvent[]>(FALLBACK_EVENTS);
  const [isLoading, setIsLoading] = useState(true);
  const [participatingId, setParticipatingId] = useState<string | null>(null);
  const addToast = useUiStore((s) => s.addToast);

  // Fetch events from API — Godot: GET /v1/events/{tab}
  const fetchEvents = useCallback(async () => {
    setIsLoading(true);
    try {
      // Try loading all events at once or per tab
      const [activeRes, upcomingRes, historyRes] = await Promise.all([
        api.get<GameEvent[]>("/rest/v1/rpc/get_active_events"),
        api.get<GameEvent[]>("/rest/v1/rpc/get_upcoming_events"),
        api.get<GameEvent[]>("/rest/v1/rpc/get_event_history"),
      ]);

      const allEvents: GameEvent[] = [];
      if (activeRes.success && activeRes.data) allEvents.push(...activeRes.data);
      if (upcomingRes.success && upcomingRes.data) allEvents.push(...upcomingRes.data);
      if (historyRes.success && historyRes.data) allEvents.push(...historyRes.data);

      if (allEvents.length > 0) {
        setEvents(allEvents);
      }
    } catch {
      // Keep fallback data
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => { fetchEvents(); }, [fetchEvents]);

  // Participate in event — Godot: POST /v1/events/participate
  const participateInEvent = async (eventId: string) => {
    setParticipatingId(eventId);
    try {
      const res = await api.post("/rest/v1/rpc/participate_in_event", { p_event_id: eventId });
      if (res.success) {
        addToast("Etkinliğe katıldınız!", "success");
        setEvents((prev) => prev.map((e) => e.id === eventId ? { ...e, participated: true } : e));
      } else {
        addToast(res.error || "Katılım başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setParticipatingId(null);
    }
  };

  const tabs: { key: EventTab; label: string }[] = [
    { key: "active", label: "🔥 Aktif" },
    { key: "upcoming", label: "📅 Yaklaşan" },
    { key: "history", label: "📜 Geçmiş" },
  ];

  const statusMap: Record<EventTab, GameEvent["status"]> = { active: "active", upcoming: "upcoming", history: "completed" };
  const filtered = events.filter((e) => e.status === statusMap[activeTab]);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🎪 Etkinlikler</h1>

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
      ) : filtered.length === 0 ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">
          {activeTab === "active" ? "Aktif etkinlik yok" : activeTab === "upcoming" ? "Yaklaşan etkinlik yok" : "Geçmiş etkinlik yok"}
        </p>
      ) : (
        <div className="space-y-3">
          {filtered.map((event) => (
            <Card key={event.id} variant="elevated">
              <div className="p-4">
                <div className="flex items-start gap-3">
                  <span className="text-3xl">{event.icon}</span>
                  <div className="flex-1">
                    <h3 className="text-sm font-bold text-[var(--text-primary)]">{event.name}</h3>
                    <p className="text-[10px] text-[var(--text-muted)] mt-0.5">{event.description}</p>
                    <p className="text-[10px] text-[var(--text-secondary)] mt-1">
                      📅 {event.startDate} — {event.endDate}
                    </p>
                  </div>
                </div>

                {/* Progress */}
                {event.progress !== undefined && event.maxProgress !== undefined && (
                  <div className="mt-3">
                    <ProgressBar value={event.progress} max={event.maxProgress} color="accent" size="sm"
                      label={`${event.progress}/${event.maxProgress}`} />
                  </div>
                )}

                {/* Rewards */}
                <div className="mt-2 flex flex-wrap gap-1">
                  {event.rewards.map((r, i) => (
                    <span key={i} className="text-[10px] px-2 py-0.5 bg-[var(--bg-input)] rounded-full text-[var(--text-secondary)]">
                      🎁 {r}
                    </span>
                  ))}
                </div>

                {event.status === "active" && (
                  <Button variant="primary" size="sm" fullWidth className="mt-3"
                    onClick={() => participateInEvent(event.id)}
                    disabled={event.participated || participatingId === event.id}>
                    {event.participated ? "✅ Katıldınız" : participatingId === event.id ? "Katılınıyor..." : "Katıl"}
                  </Button>
                )}
              </div>
            </Card>
          ))}
        </div>
      )}
    </motion.div>
  );
}
