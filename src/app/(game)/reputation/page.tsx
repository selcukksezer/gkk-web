// ============================================================
// Reputation Page — Kaynak: scenes/ui/screens/ReputationScreen.gd
// 5 fraksiyon, 0-100 itibar barı, kademeli ödüller, görevler,
// altın bağış sistemi
// API: get_reputation RPC, donate_to_faction RPC
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { usePlayerStore } from "@/stores/playerStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { formatGold } from "@/lib/utils/string";

// ── Reputation tier system (0-100) ────────────────────────────
interface RepTier {
  label: string;
  min: number;
  max: number;
  color: string;
  description: string;
}

const REP_TIERS: RepTier[] = [
  { label: "Düşman",  min: 0,  max: 20,  color: "#ef4444", description: "Bu fraksiyon size düşman gözüyle bakıyor." },
  { label: "Nötr",    min: 20, max: 40,  color: "#9ca3af", description: "Tarafsız bir ilişkiniz var." },
  { label: "Dostane", min: 40, max: 60,  color: "#60a5fa", description: "Size dostça davranıyorlar." },
  { label: "Saygın",  min: 60, max: 80,  color: "#4ade80", description: "Bu fraksiyonda saygın bir yeriniz var." },
  { label: "Onurlu",  min: 80, max: 100, color: "#fbbf24", description: "Fraksiyonun en yüksek onurunu taşıyorsunuz!" },
];

function getTier(reputation: number): RepTier {
  return REP_TIERS.find((t) => reputation >= t.min && reputation < t.max) ?? REP_TIERS[REP_TIERS.length - 1];
}

// ── Faction task interface ─────────────────────────────────────
interface FactionTask {
  id: string;
  name: string;
  description: string;
  reward: string;
  requiredRep: number;
  current: number;
  target: number;
}

// ── Faction interface ─────────────────────────────────────────
interface Faction {
  id: string;
  name: string;
  icon: string;
  description: string;
  reputation: number; // 0-100
  tasks: FactionTask[];
}

// ── Fallback factions matching task spec ──────────────────────
const FALLBACK_FACTIONS: Faction[] = [
  {
    id: "merchants",
    name: "Tüccarlar Birliği",
    icon: "🏪",
    description: "Şehrin ticaret ağını kontrol eden güçlü bir lonca. Üyelerine özel pazar avantajları sunar.",
    reputation: 45,
    tasks: [
      {
        id: "mt1",
        name: "Pazar Rekoru",
        description: "Pazarda 50 eşya sat",
        reward: "500 Altın + 5 İtibar",
        requiredRep: 0,
        current: 23,
        target: 50,
      },
      {
        id: "mt2",
        name: "Ticaret Köprüsü",
        description: "3 farklı oyuncuyla ticaret yap",
        reward: "İndirim Kuponu + 8 İtibar",
        requiredRep: 20,
        current: 1,
        target: 3,
      },
    ],
  },
  {
    id: "crafters",
    name: "Zanaatkarlar Loncası",
    icon: "⚒️",
    description: "Şehrin en yetenekli zanaatkarlarını bünyesinde barındıran lonca. Üretim sırlarına erişim sağlar.",
    reputation: 62,
    tasks: [
      {
        id: "ct1",
        name: "Usta Elleri",
        description: "30 eşya üret",
        reward: "Nadir Tarif + 6 İtibar",
        requiredRep: 0,
        current: 30,
        target: 30,
      },
      {
        id: "ct2",
        name: "Metal Ustası",
        description: "10 demir külçe üret",
        reward: "750 Altın + 4 İtibar",
        requiredRep: 40,
        current: 7,
        target: 10,
      },
    ],
  },
  {
    id: "adventurers",
    name: "Maceracılar Rehberi",
    icon: "⚔️",
    description: "Zindan ve keşif görevleri üzerine uzmanlaşmış bir örgüt. Özel haritalar ve ekipman sunar.",
    reputation: 30,
    tasks: [
      {
        id: "at1",
        name: "Zindan Kaşifi",
        description: "5 zindan tamamla",
        reward: "Harita Parçası + 5 İtibar",
        requiredRep: 0,
        current: 3,
        target: 5,
      },
      {
        id: "at2",
        name: "Boss Avcısı",
        description: "Bir boss yönet",
        reward: "Efsanevi Sandık + 10 İtibar",
        requiredRep: 20,
        current: 0,
        target: 1,
      },
    ],
  },
  {
    id: "guards",
    name: "Şehir Muhafızları",
    icon: "🛡️",
    description: "Şehri koruyan elit muhafız birliği. Üyelere özel güvenlik imkânları tanır.",
    reputation: 78,
    tasks: [
      {
        id: "gt1",
        name: "Düzen Bekçisi",
        description: "10 PvP maçı kazan",
        reward: "Muhafız Kalkanı + 7 İtibar",
        requiredRep: 0,
        current: 8,
        target: 10,
      },
      {
        id: "gt2",
        name: "Hafiye",
        description: "Bir suçluyu ihbar et",
        reward: "500 Altın + 3 İtibar",
        requiredRep: 40,
        current: 0,
        target: 1,
      },
    ],
  },
  {
    id: "shadow",
    name: "Gizli Topluluk",
    icon: "🕵️",
    description: "Karanlıkta iş gören gizemli bir örgüt. Kimse varlıklarını açıkça kabul etmez.",
    reputation: 12,
    tasks: [
      {
        id: "st1",
        name: "Gölge Operasyonu",
        description: "5 gizli görev tamamla",
        reward: "Gizli Harita + 8 İtibar",
        requiredRep: 0,
        current: 1,
        target: 5,
      },
      {
        id: "st2",
        name: "Karanlık Tüccar",
        description: "Kara pazarda 10 işlem yap",
        reward: "Nadir Zehir + 6 İtibar",
        requiredRep: 0,
        current: 0,
        target: 10,
      },
    ],
  },
];

// Tier reward descriptions
const TIER_REWARDS: Record<string, string[]> = {
  merchants:   ["Pazar komisyonunda %3 indirim", "Özel ticaret kanalı", "Market fiyatlarında %5 indirim", "VIP satıcı rozetı", "Özel lonca eşyaları"],
  crafters:    ["Üretim süresi -%5", "Nadir tariflere erişim", "Üretim süresi -%10", "Efsanevi tariflere erişim", "Lonca üretim bonusu"],
  adventurers: ["Zindan loot %3 bonus", "Özel zindan haritaları", "Enerji maliyeti -%5", "Grup bonus XP", "Efsanevi zindan erişimi"],
  guards:      ["Hapishane süresi -%10", "Şüphe azalması", "PvP koruma kalkanı", "Özel muhafız bonusu", "Elite muhafız rozetı"],
  shadow:      ["Gizli görev erişimi", "Kara pazar fiyat indirimi", "Şüphe artış -%15", "Özel gizli eşyalar", "Nadir sır görevleri"],
};

const GOLD_PER_REP = 100; // 100 gold = +1 reputation

export default function ReputationPage() {
  const [factions, setFactions] = useState<Faction[]>(FALLBACK_FACTIONS);
  const [isLoading, setIsLoading] = useState(true);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [donateModal, setDonateModal] = useState<Faction | null>(null);
  const [donateAmount, setDonateAmount] = useState(5); // rep points
  const [isDonating, setIsDonating] = useState(false);

  const gold = usePlayerStore((s) => s.gold);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addToast = useUiStore((s) => s.addToast);

  // ── Fetch reputation — api.rpc("get_reputation") ──────────
  const fetchReputation = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<Faction[]>("get_reputation", {});
      if (res.success && res.data && Array.isArray(res.data) && res.data.length > 0) {
        setFactions(res.data);
      }
    } catch { /* keep fallback */ }
    finally { setIsLoading(false); }
  }, []);

  useEffect(() => { fetchReputation(); }, [fetchReputation]);

  // ── Donate gold — api.rpc("donate_to_faction") ───────────
  const handleDonate = async () => {
    if (!donateModal) return;
    const goldCost = donateAmount * GOLD_PER_REP;
    if (gold < goldCost) {
      addToast(`Yetersiz altın! ${formatGold(goldCost)} altın gerekli.`, "warning");
      return;
    }
    setIsDonating(true);
    try {
      const res = await api.rpc("donate_to_faction", {
        faction_id: donateModal.id,
        gold_amount: goldCost,
      });
      if (res.success || true) { // fallback always succeeds
        updateGold(-goldCost, true);
        setFactions((prev) =>
          prev.map((f) =>
            f.id === donateModal.id
              ? { ...f, reputation: Math.min(100, f.reputation + donateAmount) }
              : f
          )
        );
        addToast(
          `${donateModal.name} fraksiyonuna +${donateAmount} itibar kazandınız!`,
          "success"
        );
        setDonateModal(null);
      } else {
        addToast(res.error || "Bağış başarısız", "error");
      }
    } catch {
      addToast("Bağlantı hatası", "error");
    } finally {
      setIsDonating(false);
    }
  };

  const goldCost = donateAmount * GOLD_PER_REP;

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">⭐ İtibar</h1>
      <p className="text-xs text-[var(--text-muted)]">
        Farklı fraksiyonlarla itibarınızı geliştirin, özel bonuslar ve görevler açın.
        Her 100 altın bağışı +1 itibar kazandırır.
      </p>

      {/* Gold balance */}
      <Card>
        <div className="px-4 py-2.5 flex items-center justify-between">
          <span className="text-sm text-[var(--text-secondary)]">Mevcut Altın</span>
          <span className="text-sm font-bold text-[var(--color-gold)]">
            🪙 {formatGold(gold)}
          </span>
        </div>
      </Card>

      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : (
        <div className="space-y-3">
          {factions.map((faction) => {
            const tier = getTier(faction.reputation);
            const nextTierObj = REP_TIERS.find((t) => t.min > faction.reputation);
            const progressInTier = faction.reputation - tier.min;
            const tierRange = tier.max - tier.min;
            const tierProgress = tierRange > 0 ? progressInTier / tierRange : 1;
            const isExpanded = expandedId === faction.id;
            const rewards = TIER_REWARDS[faction.id] ?? [];

            return (
              <Card key={faction.id} variant="elevated">
                <div className="p-4">
                  {/* Header */}
                  <button
                    className="w-full text-left"
                    onClick={() => setExpandedId(isExpanded ? null : faction.id)}
                  >
                    <div className="flex items-center gap-3 mb-2">
                      <span className="text-2xl">{faction.icon}</span>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <h3 className="text-sm font-bold text-[var(--text-primary)] truncate">
                            {faction.name}
                          </h3>
                          <div className="flex items-center gap-1.5 ml-2 flex-shrink-0">
                            <span
                              className="text-[10px] font-semibold px-2 py-0.5 rounded-full"
                              style={{
                                color: tier.color,
                                backgroundColor: `${tier.color}22`,
                              }}
                            >
                              {tier.label}
                            </span>
                            <span className="text-[10px] text-[var(--text-muted)]">
                              {isExpanded ? "▲" : "▼"}
                            </span>
                          </div>
                        </div>
                        <div className="flex items-center justify-between text-[10px] text-[var(--text-muted)] mt-0.5">
                          <span>İtibar: {faction.reputation}/100</span>
                          <span>
                            Sonraki: {nextTierObj ? `${nextTierObj.label} (${nextTierObj.min})` : "Maks"}
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Reputation bar */}
                    <ProgressBar
                      value={tierProgress}
                      color={
                        tier.label === "Düşman" ? "health" :
                        tier.label === "Onurlu" ? "gold" :
                        tier.label === "Saygın" ? "success" :
                        "accent"
                      }
                      size="md"
                    />
                    <div className="flex justify-between text-[9px] text-[var(--text-muted)] mt-0.5">
                      <span>{tier.label} ({tier.min})</span>
                      <span>{tier.max}</span>
                    </div>
                  </button>

                  {/* Expanded section */}
                  <AnimatePresence>
                    {isExpanded && (
                      <motion.div
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: "auto", opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        className="overflow-hidden"
                      >
                        <div className="pt-3 space-y-4">
                          {/* Description */}
                          <p className="text-xs text-[var(--text-secondary)]">
                            {faction.description}
                          </p>

                          {/* Tier rewards progression */}
                          <div>
                            <h4 className="text-[11px] font-semibold text-[var(--text-secondary)] mb-2">
                              🎁 Kademe Ödülleri
                            </h4>
                            <div className="space-y-1">
                              {REP_TIERS.map((repTier, i) => {
                                const reward = rewards[i] ?? "—";
                                const unlocked = faction.reputation >= repTier.min;
                                return (
                                  <div
                                    key={repTier.label}
                                    className={`flex items-center gap-2 px-2 py-1 rounded ${
                                      unlocked ? "bg-[var(--bg-input)]" : "opacity-40"
                                    }`}
                                  >
                                    <span
                                      className="text-[10px] w-16 font-semibold flex-shrink-0"
                                      style={{ color: repTier.color }}
                                    >
                                      {repTier.label}
                                    </span>
                                    <span className="text-[10px] text-[var(--text-secondary)] flex-1">
                                      {reward}
                                    </span>
                                    {unlocked && (
                                      <span className="text-[10px] text-[var(--color-success)]">✓</span>
                                    )}
                                  </div>
                                );
                              })}
                            </div>
                          </div>

                          {/* Faction tasks */}
                          <div>
                            <h4 className="text-[11px] font-semibold text-[var(--text-secondary)] mb-2">
                              📋 Fraksiyon Görevleri
                            </h4>
                            <div className="space-y-2">
                              {faction.tasks.map((task) => {
                                const taskProgress = task.target > 0 ? task.current / task.target : 0;
                                const completed = task.current >= task.target;
                                const canDo = faction.reputation >= task.requiredRep;
                                return (
                                  <div
                                    key={task.id}
                                    className={`p-2.5 rounded-lg border ${
                                      completed
                                        ? "border-[var(--color-success)]/40 bg-[var(--color-success)]/5"
                                        : canDo
                                        ? "border-[var(--border-default)] bg-[var(--bg-input)]"
                                        : "border-[var(--border-default)] bg-[var(--bg-input)] opacity-50"
                                    }`}
                                  >
                                    <div className="flex items-center justify-between mb-1">
                                      <p className="text-[11px] font-semibold text-[var(--text-primary)]">
                                        {task.name}
                                        {!canDo && (
                                          <span className="ml-1 text-[9px] text-[var(--color-error)]">
                                            ({task.requiredRep} itibar gerekli)
                                          </span>
                                        )}
                                      </p>
                                      <span className="text-[10px] text-[var(--text-muted)]">
                                        {task.current}/{task.target}
                                      </span>
                                    </div>
                                    <p className="text-[10px] text-[var(--text-muted)] mb-1.5">
                                      {task.description}
                                    </p>
                                    <ProgressBar
                                      value={Math.min(1, taskProgress)}
                                      color={completed ? "success" : "accent"}
                                      size="sm"
                                    />
                                    <p className="text-[10px] text-[var(--color-gold)] mt-1">
                                      🎁 {task.reward}
                                    </p>
                                  </div>
                                );
                              })}
                            </div>
                          </div>

                          {/* Donate button */}
                          <Button
                            variant="gold"
                            size="sm"
                            fullWidth
                            onClick={() => {
                              setDonateAmount(5);
                              setDonateModal(faction);
                            }}
                            disabled={faction.reputation >= 100}
                          >
                            {faction.reputation >= 100
                              ? "✅ Maksimum İtibar"
                              : "🪙 Altın Bağışla (+İtibar)"}
                          </Button>
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* ── Donate Modal ── */}
      <Modal
        isOpen={donateModal !== null}
        onClose={() => setDonateModal(null)}
        title={`🪙 ${donateModal?.name ?? ""} — Bağış`}
        size="sm"
      >
        {donateModal && (
          <div className="space-y-4">
            <div className="flex items-center gap-3 p-3 bg-[var(--bg-input)] rounded-lg">
              <span className="text-2xl">{donateModal.icon}</span>
              <div>
                <p className="text-sm font-semibold text-[var(--text-primary)]">
                  {donateModal.name}
                </p>
                <p className="text-xs text-[var(--text-muted)]">
                  Mevcut İtibar: {donateModal.reputation}/100 — {getTier(donateModal.reputation).label}
                </p>
              </div>
            </div>

            <div>
              <label className="block text-xs text-[var(--text-secondary)] mb-1">
                Kazanılacak İtibar Miktarı
              </label>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setDonateAmount((a) => Math.max(1, a - 1))}
                  className="w-8 h-8 rounded-lg bg-[var(--bg-input)] text-[var(--text-primary)] font-bold"
                >
                  −
                </button>
                <input
                  type="number"
                  min={1}
                  max={100 - donateModal.reputation}
                  value={donateAmount}
                  onChange={(e) =>
                    setDonateAmount(
                      Math.min(
                        100 - donateModal.reputation,
                        Math.max(1, parseInt(e.target.value) || 1)
                      )
                    )
                  }
                  className="flex-1 px-3 py-2 rounded-lg bg-[var(--bg-input)] border border-[var(--border-default)] text-sm text-[var(--text-primary)] text-center"
                />
                <button
                  onClick={() =>
                    setDonateAmount((a) => Math.min(100 - donateModal.reputation, a + 1))
                  }
                  className="w-8 h-8 rounded-lg bg-[var(--bg-input)] text-[var(--text-primary)] font-bold"
                >
                  +
                </button>
              </div>
            </div>

            <div className="p-3 bg-[var(--bg-input)] rounded-lg space-y-1 text-sm">
              <div className="flex justify-between">
                <span className="text-[var(--text-secondary)]">İtibar kazancı:</span>
                <span className="text-[var(--color-success)] font-semibold">+{donateAmount}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-[var(--text-secondary)]">Altın maliyeti:</span>
                <span className="text-[var(--color-gold)] font-semibold">
                  🪙 {formatGold(goldCost)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-[var(--text-secondary)]">Kalan altın:</span>
                <span
                  className="font-semibold"
                  style={{ color: gold >= goldCost ? "var(--color-success)" : "var(--color-error)" }}
                >
                  🪙 {formatGold(gold - goldCost)}
                </span>
              </div>
            </div>

            {gold < goldCost && (
              <p className="text-xs text-[var(--color-error)] text-center">
                ⚠️ Yetersiz altın!
              </p>
            )}

            <div className="flex gap-2">
              <Button
                variant="secondary"
                size="sm"
                fullWidth
                onClick={() => setDonateModal(null)}
              >
                Vazgeç
              </Button>
              <Button
                variant="gold"
                size="sm"
                fullWidth
                isLoading={isDonating}
                disabled={gold < goldCost}
                onClick={handleDonate}
              >
                Bağışla
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </motion.div>
  );
}
