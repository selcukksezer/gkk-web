"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { api } from "@/lib/api";
import { isInHospital } from "@/lib/utils/validation";
import { formatGold } from "@/lib/utils/string";
import { parseDate } from "@/lib/utils/datetime";
import type { DungeonData } from "@/types/dungeon";

type DungeonMode = "solo" | "group";

type DungeonResult = {
  success: boolean;
  is_critical?: boolean;
  error?: string;
  gold_earned?: number;
  xp_earned?: number;
  items?: string[];
  hospitalized?: boolean;
  hospital_until?: string;
  hospital_duration?: number;
};

type BattleResult = {
  success: boolean;
  critical: boolean;
  rewards?: { gold: number; xp: number; items: string[] };
  hospitalized: boolean;
  hospitalUntil?: string;
  hospitalDurationSeconds?: number;
  error?: string;
};

const EMPTY_DUNGEONS: DungeonData[] = [];

const difficultyLabels: Record<string, string> = {
  EASY: "Kolay",
  easy: "Kolay",
  MEDIUM: "Orta",
  medium: "Orta",
  HARD: "Zor",
  hard: "Zor",
  DUNGEON: "Boss",
  dungeon: "Boss",
};

const difficultyTheme: Record<string, { glow: string; text: string; ring: string }> = {
  EASY: { glow: "rgba(74, 222, 128, 0.24)", text: "#166534", ring: "rgba(34,197,94,0.35)" },
  easy: { glow: "rgba(74, 222, 128, 0.24)", text: "#166534", ring: "rgba(34,197,94,0.35)" },
  MEDIUM: { glow: "rgba(251, 191, 36, 0.24)", text: "#854d0e", ring: "rgba(245,158,11,0.35)" },
  medium: { glow: "rgba(251, 191, 36, 0.24)", text: "#854d0e", ring: "rgba(245,158,11,0.35)" },
  HARD: { glow: "rgba(248, 113, 113, 0.24)", text: "#991b1b", ring: "rgba(239,68,68,0.35)" },
  hard: { glow: "rgba(248, 113, 113, 0.24)", text: "#991b1b", ring: "rgba(239,68,68,0.35)" },
  DUNGEON: { glow: "rgba(129, 140, 248, 0.24)", text: "#3730a3", ring: "rgba(99,102,241,0.35)" },
  dungeon: { glow: "rgba(129, 140, 248, 0.24)", text: "#3730a3", ring: "rgba(99,102,241,0.35)" },
};

const rarityTheme: Record<string, { label: string; bg: string; text: string; ring: string }> = {
  common: { label: "Common", bg: "rgba(148,163,184,.16)", text: "#cbd5e1", ring: "rgba(148,163,184,.35)" },
  uncommon: { label: "Uncommon", bg: "rgba(34,197,94,.16)", text: "#86efac", ring: "rgba(34,197,94,.35)" },
  rare: { label: "Rare", bg: "rgba(56,189,248,.16)", text: "#7dd3fc", ring: "rgba(56,189,248,.35)" },
  epic: { label: "Epic", bg: "rgba(244,114,182,.16)", text: "#f9a8d4", ring: "rgba(244,114,182,.35)" },
  legendary: { label: "Legendary", bg: "rgba(251,191,36,.18)", text: "#fcd34d", ring: "rgba(251,191,36,.38)" },
  mythic: { label: "Mythic", bg: "rgba(248,113,113,.2)", text: "#fda4af", ring: "rgba(248,113,113,.42)" },
};

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function estimateEquipmentPower(
  equippedItems: Record<string, { attack?: number; defense?: number; health?: number; enhancement_level?: number } | null>
): number {
  return Math.floor(
    Object.values(equippedItems).reduce((sum, item) => {
      if (!item) return sum;
      const enh = 1 + (item.enhancement_level ?? 0) * 0.15;
      const part = ((item.attack ?? 0) + (item.defense ?? 0) + (item.health ?? 0) / 10) * enh;
      return sum + part;
    }, 0)
  );
}

function previewSuccessRate(
  dungeon: DungeonData,
  player: { power?: number; luck?: number; reputation?: number; character_class?: string | null } | null,
  fallbackLevel: number,
  equippedItems: Record<string, { attack?: number; defense?: number; health?: number; enhancement_level?: number } | null>
) {
  const gearPowerEstimate = estimateEquipmentPower(equippedItems);
  const playerPower =
    (player?.power ?? 0) > 0
      ? Number(player?.power ?? 0)
      : Math.floor(fallbackLevel * 500 + Math.floor((player?.reputation ?? 0) * 0.1) + Math.floor((player?.luck ?? 0) * 50));

  const inferredPowerReq = dungeon.dungeon_order === 1 ? 0 : Math.max(1, dungeon.required_level * 500);
  const powerRequirement = typeof dungeon.power_requirement === "number" ? dungeon.power_requirement : inferredPowerReq;
  const ratio = powerRequirement > 0 ? playerPower / powerRequirement : 999;

  let baseFromPower = 0;
  if (powerRequirement === 0) {
    baseFromPower = 1.0;
  } else if (ratio >= 1.5) {
    baseFromPower = 0.95;
  } else if (ratio >= 1.0) {
    baseFromPower = 0.7 + (ratio - 1.0) * 0.5;
  } else if (ratio >= 0.5) {
    baseFromPower = 0.25 + (ratio - 0.5) * 0.9;
  } else if (ratio >= 0.25) {
    baseFromPower = 0.1 + (ratio - 0.25) * 0.6;
  } else {
    baseFromPower = Math.max(0.05, ratio * 0.4);
  }

  const luckBonus = clamp((player?.luck ?? 0) * 0.001, 0, 0.05);
  const warriorBonus = (player?.character_class ?? null) === "warrior" ? 0.05 : 0;
  const reputationBonus = clamp((player?.reputation ?? 0) * 0.0005, 0, 0.025);

  const calculated = clamp(baseFromPower + luckBonus + warriorBonus + reputationBonus, 0.05, 0.95);
  return { calculated, ratio, playerPower, powerRequirement, gearPowerEstimate };
}

function getHospitalRemainingSeconds(hospitalUntil: string | null | undefined): number {
  if (!hospitalUntil) return 0;
  const parsed = parseDate(hospitalUntil);
  if (!parsed) return 0;
  return Math.max(0, Math.floor((parsed.getTime() - Date.now()) / 1000));
}

function formatDuration(seconds: number): string {
  if (seconds <= 0) return "0 dk";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h <= 0) return `${m} dk`;
  return `${h} sa ${m} dk`;
}

function getReadableDungeonError(error: string | undefined): string {
  const normalized = String(error || "").trim().toLowerCase();

  if (!normalized || normalized === "rpc error") {
    return "Operasyon şu anda tamamlanamadı. Kısa süre sonra tekrar dene.";
  }

  if (normalized.includes("failed to fetch") || normalized.includes("network") || normalized.includes("bağlantı")) {
    return "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.";
  }

  if (normalized.includes("timeout") || normalized.includes("zaman aşım")) {
    return "İstek zaman aşımına uğradı. Birkaç saniye sonra tekrar dene.";
  }

  return error || "Operasyon şu anda tamamlanamadı. Kısa süre sonra tekrar dene.";
}

function inferRarityFromItemToken(itemId: string): keyof typeof rarityTheme {
  const normalized = String(itemId || "").toLowerCase();
  if (normalized.endsWith("_mythic")) return "mythic";
  if (normalized.endsWith("_legendary")) return "legendary";
  if (normalized.endsWith("_epic")) return "epic";
  if (normalized.endsWith("_rare")) return "rare";
  if (normalized.endsWith("_uncommon")) return "uncommon";
  return "common";
}

function formatLootToken(itemId: string): string {
  return itemId
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function HospitalResultOverlay({
  isOpen,
  durationSeconds,
  onGoHospital,
  onClose,
}: {
  isOpen: boolean;
  durationSeconds: number;
  onGoHospital: () => void;
  onClose: () => void;
}) {
  if (!isOpen) return null;
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-[120]"
      style={{
        background:
          "radial-gradient(120% 100% at 50% 0%, rgba(239,68,68,.38) 0%, rgba(15,23,42,.94) 54%, rgba(2,6,23,.98) 100%)",
      }}
    >
      <div className="absolute inset-0 opacity-30" style={{ backgroundImage: "linear-gradient(to right, rgba(248,113,113,.22) 1px, transparent 1px), linear-gradient(to bottom, rgba(248,113,113,.18) 1px, transparent 1px)", backgroundSize: "30px 30px" }} />
      <div className="relative z-10 flex min-h-screen items-center justify-center p-4">
        <motion.div
          initial={{ y: 28, opacity: 0, scale: 0.96 }}
          animate={{ y: 0, opacity: 1, scale: 1 }}
          transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
          className="w-full max-w-xl rounded-3xl border border-red-300/20 bg-slate-950/78 p-6 text-center shadow-[0_30px_80px_rgba(0,0,0,.55)]"
        >
          <p className="text-[11px] uppercase tracking-[0.28em] text-red-200/80">Critical Status</p>
          <h2 className="mt-2 text-3xl font-black tracking-tight text-red-100 sm:text-4xl">Hastaneye Sevk Edildin</h2>
          <p className="mt-3 text-sm text-red-100/85">
            Operasyon başarısız oldu. Karakterin ağır yaralı ve savaş dışı bırakıldı.
          </p>
          <div className="mt-4 rounded-2xl border border-red-300/20 bg-red-950/35 px-4 py-3">
            <p className="text-xs uppercase tracking-widest text-red-200/70">Tahmini Tedavi Süresi</p>
            <p className="mt-1 text-2xl font-black text-red-100">{formatDuration(durationSeconds)}</p>
          </div>
          <div className="mt-6 flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={onClose}>Kapat</Button>
            <Button variant="primary" size="sm" fullWidth onClick={onGoHospital}>Hastaneye Git</Button>
          </div>
        </motion.div>
      </div>
    </motion.div>
  );
}

export default function DungeonPage() {
  const router = useRouter();
  const energy = usePlayerStore((s) => s.energy);
  const level = usePlayerStore((s) => s.level);
  const player = usePlayerStore((s) => s.player);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);
  const updateGold = usePlayerStore((s) => s.updateGold);
  const addXp = usePlayerStore((s) => s.addXp);

  const equippedItems = useInventoryStore((s) => s.equippedItems);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);

  const [mode, setMode] = useState<DungeonMode>("solo");
  const [query, setQuery] = useState("");
  const [allDungeons, setAllDungeons] = useState<DungeonData[]>(EMPTY_DUNGEONS);
  const [isLoading, setIsLoading] = useState(false);
  const [isEntering, setIsEntering] = useState(false);
  const [entryPhase, setEntryPhase] = useState<string | null>(null);

  const [selectedDungeon, setSelectedDungeon] = useState<DungeonData | null>(null);
  const [lootDungeon, setLootDungeon] = useState<DungeonData | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [lootOpen, setLootOpen] = useState(false);
  const [battleResult, setBattleResult] = useState<BattleResult | null>(null);

  const inHospital = isInHospital(hospitalUntil);
  const hospitalRemaining = getHospitalRemainingSeconds(hospitalUntil);

  useEffect(() => {
    void fetchProfile();
  }, [fetchProfile]);

  useEffect(() => {
    (async () => {
      setIsLoading(true);
      try {
        const res = await api.rpc<DungeonData[]>("get_dungeons", {});
        if (res.success && res.data) {
          setAllDungeons(Array.isArray(res.data) ? res.data : []);
        } else {
          setAllDungeons([]);
        }
      } catch {
        setAllDungeons([]);
      } finally {
        setIsLoading(false);
      }
    })();
  }, []);

  const filteredDungeons = useMemo(() => {
    const modeFiltered = mode === "group" ? allDungeons.filter((d) => d.difficulty === "dungeon" || d.max_players > 1) : allDungeons;
    const q = query.trim().toLowerCase();
    if (!q) return modeFiltered;
    return modeFiltered.filter((d) => d.name.toLowerCase().includes(q) || d.description.toLowerCase().includes(q));
  }, [allDungeons, mode, query]);

  const handleEnterDungeon = async () => {
    if (!selectedDungeon || isEntering) return;

    setIsEntering(true);
    setConfirmOpen(false);

    try {
      setEntryPhase("Giriş tüneli açılıyor...");
      await new Promise((r) => setTimeout(r, 420));
      setEntryPhase("Savaş simülasyonu başlatılıyor...");
      await new Promise((r) => setTimeout(r, 500));

      const rpcResult = await api.rpc<DungeonResult>("enter_dungeon", {
        p_dungeon_id: selectedDungeon.dungeon_id,
      });

      if (!rpcResult.success) {
        await fetchProfile();
        const latestState = usePlayerStore.getState();
        const latestHospitalUntil = latestState.hospitalUntil;
        const normalizedRpcError = String(rpcResult.error || "").toLowerCase();

        if (normalizedRpcError.includes("in_hospital") || latestState.inHospital || isInHospital(latestHospitalUntil)) {
          const remaining = getHospitalRemainingSeconds(latestHospitalUntil);
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: true,
            hospitalUntil: latestHospitalUntil ?? undefined,
            hospitalDurationSeconds: remaining > 0 ? remaining : undefined,
            error: "🏥 Hastanedeyken zindana giriş yapılamaz.",
          });
          setEntryPhase(null);
          return;
        }

        if (normalizedRpcError.includes("in_prison")) {
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: false,
            error: "👮 Hapisteyken zindana giriş yapılamaz.",
          });
          setEntryPhase(null);
          return;
        }

        if (normalizedRpcError.includes("insufficient_energy")) {
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: false,
            error: "⚡ Enerjin yetersiz.",
          });
          setEntryPhase(null);
          return;
        }

        throw new Error(rpcResult.error || "Zindan işlemi başarısız");
      }

      const result = rpcResult.data;
      if (!result) {
        throw new Error("Zindan cevabı alınamadı");
      }

      if (result.error) {
        if (result.error === "in_hospital") {
          await fetchProfile();
          const currentHospitalUntil = usePlayerStore.getState().hospitalUntil;
          const remaining = getHospitalRemainingSeconds(currentHospitalUntil);
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: true,
            hospitalUntil: currentHospitalUntil ?? undefined,
            hospitalDurationSeconds: remaining > 0 ? remaining : undefined,
            error: "🏥 Hastanedeyken zindana giriş yapılamaz.",
          });
        } else if (result.error === "in_prison") {
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: false,
            error: "👮 Hapisteyken zindana giriş yapılamaz.",
          });
        } else if (result.error === "insufficient_energy") {
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: false,
            error: "⚡ Enerjin yetersiz.",
          });
        } else {
          setBattleResult({
            success: false,
            critical: false,
            hospitalized: false,
            error: result.error,
          });
        }
        setEntryPhase(null);
        return;
      }

      const goldEarned = Number(result.gold_earned ?? 0);
      const xpEarned = Number(result.xp_earned ?? 0);
      const droppedItems = Array.isArray(result.items)
        ? result.items.map((it) => (typeof it === "string" ? it : JSON.stringify(it)))
        : [];

      if (result.success && goldEarned !== 0) updateGold(goldEarned, true);
      if (result.success && xpEarned !== 0) addXp(xpEarned);

      if (result.hospitalized && result.hospital_until) {
        usePlayerStore.setState((s) => ({
          inHospital: true,
          hospitalUntil: result.hospital_until as string,
          hospitalReason: s.hospitalReason || "Zindan başarısızlığı",
          player: s.player
            ? ({ ...s.player, hospital_until: result.hospital_until, in_hospital: true } as typeof s.player)
            : s.player,
          profile: s.profile
            ? ({ ...s.profile, hospital_until: result.hospital_until, in_hospital: true } as typeof s.profile)
            : s.profile,
        }));
      }

      await Promise.all([fetchProfile(), fetchInventory(true)]);

      const computedHospitalSeconds = result.hospital_duration ?? getHospitalRemainingSeconds(result.hospital_until);
      setBattleResult({
        success: !!result.success,
        critical: !!result.is_critical,
        rewards: result.success ? { gold: goldEarned, xp: xpEarned, items: droppedItems } : undefined,
        hospitalized: !!result.hospitalized,
        hospitalUntil: result.hospital_until,
        hospitalDurationSeconds: computedHospitalSeconds > 0 ? computedHospitalSeconds : undefined,
      });

      setEntryPhase(null);
    } catch (error) {
      setEntryPhase(null);
      await fetchProfile();
      const latestState = usePlayerStore.getState();
      const latestHospitalUntil = latestState.hospitalUntil;
      const latestHospitalized = latestState.inHospital || isInHospital(latestHospitalUntil);
      setBattleResult({
        success: false,
        critical: false,
        hospitalized: latestHospitalized,
        hospitalUntil: latestHospitalUntil ?? undefined,
        hospitalDurationSeconds: latestHospitalized ? getHospitalRemainingSeconds(latestHospitalUntil) : undefined,
        error: getReadableDungeonError(error instanceof Error ? error.message : undefined),
      });
    } finally {
      setIsEntering(false);
    }
  };

  return (
    <div
      className="min-h-full p-4 pb-24"
      style={{
        background:
          "radial-gradient(130% 90% at 50% -10%, rgba(251,146,60,.24) 0%, rgba(255,255,255,0) 42%), radial-gradient(120% 110% at 90% 10%, rgba(20,184,166,.16) 0%, rgba(255,255,255,0) 48%), linear-gradient(160deg, #070b14 0%, #0f172a 38%, #111827 70%, #0b1220 100%)",
      }}
    >
      <motion.section
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
        className="relative overflow-hidden rounded-3xl border border-white/10 p-5 shadow-[0_25px_70px_rgba(2,6,23,.55)]"
        style={{
          background:
            "linear-gradient(120deg, rgba(2,6,23,.74) 0%, rgba(15,23,42,.72) 55%, rgba(17,24,39,.78) 100%)",
          backdropFilter: "blur(8px)",
        }}
      >
        <div className="absolute -top-20 -right-8 h-44 w-44 rounded-full bg-orange-400/35 blur-3xl" />
        <div className="absolute -bottom-16 -left-12 h-40 w-40 rounded-full bg-teal-400/22 blur-3xl" />
        <div className="absolute inset-0 opacity-[0.1]" style={{ backgroundImage: "linear-gradient(to right, rgba(248,250,252,.16) 1px, transparent 1px), linear-gradient(to bottom, rgba(248,250,252,.1) 1px, transparent 1px)", backgroundSize: "24px 24px" }} />

        <div className="relative z-10">
          <p className="text-[11px] uppercase tracking-[0.24em] text-slate-300/80">TACTICAL DUNGEON NET</p>
          <div className="mt-1 flex flex-wrap items-end justify-between gap-3">
            <h1 className="text-2xl font-black leading-tight text-white sm:text-3xl">Zindan Operasyon Merkezi</h1>
            <div className="rounded-2xl border border-white/15 bg-white/5 px-3 py-2 text-right">
              <p className="text-[10px] uppercase tracking-widest text-slate-300">Toplam Bölge</p>
              <p className="text-lg font-black text-white">{filteredDungeons.length}</p>
            </div>
          </div>

          <div className="mt-4 grid gap-2 sm:grid-cols-3">
            <div className="rounded-2xl border border-white/12 bg-white/5 px-3 py-2">
              <p className="text-[10px] uppercase tracking-wide text-slate-300">Enerji</p>
              <p className="text-sm font-semibold text-slate-100">⚡ {energy.toLocaleString("tr-TR")}</p>
            </div>
            <div className="rounded-2xl border border-white/12 bg-white/5 px-3 py-2">
              <p className="text-[10px] uppercase tracking-wide text-slate-300">Seviye</p>
              <p className="text-sm font-semibold text-slate-100">📈 {level}</p>
            </div>
            <div className="rounded-2xl border border-white/12 bg-white/5 px-3 py-2">
              <p className="text-[10px] uppercase tracking-wide text-slate-300">Durum</p>
              <p className={`text-sm font-semibold ${inHospital ? "text-red-700" : "text-emerald-700"}`}>
                {inHospital ? `🏥 Hastanede • ${formatDuration(hospitalRemaining)}` : "✅ Operasyona Hazır"}
              </p>
            </div>
          </div>
        </div>
      </motion.section>

      <motion.section
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.45, delay: 0.06, ease: [0.22, 1, 0.36, 1] }}
        className="mt-4 rounded-3xl border border-white/12 bg-slate-950/55 p-3 shadow-[0_16px_35px_rgba(0,0,0,.35)]"
      >
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => setMode("solo")}
            className={`rounded-xl px-3 py-2 text-xs font-semibold transition-all ${
              mode === "solo"
                ? "bg-orange-500 text-slate-950 shadow-[0_8px_20px_rgba(249,115,22,.35)]"
                : "bg-white/6 text-slate-200 hover:bg-white/12"
            }`}
          >
            Solo Operasyon
          </button>
          <button
            type="button"
            onClick={() => setMode("group")}
            className={`rounded-xl px-3 py-2 text-xs font-semibold transition-all ${
              mode === "group"
                ? "bg-teal-400 text-slate-950 shadow-[0_8px_20px_rgba(45,212,191,.35)]"
                : "bg-white/6 text-slate-200 hover:bg-white/12"
            }`}
          >
            Grup Baskını
          </button>

          <div className="ml-auto w-full sm:w-60">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Zindan ara..."
              className="w-full rounded-xl border border-white/12 bg-slate-900/80 px-3 py-2 text-sm text-slate-100 outline-none transition focus:border-orange-300"
            />
          </div>
        </div>
      </motion.section>

      {inHospital && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4 rounded-2xl border border-red-200 bg-gradient-to-r from-red-50 to-orange-50 p-3"
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-semibold text-red-700">
              🏥 Hastanedesin, zindana giriş kilitli. Kalan süre: {formatDuration(hospitalRemaining)}
            </p>
            <Button variant="secondary" size="sm" onClick={() => router.push("/hospital")}>Hastaneye Git</Button>
          </div>
        </motion.div>
      )}

      <div className="mt-4 space-y-3">
        {isLoading && <p className="py-8 text-center text-sm text-slate-500">Zindan verileri yükleniyor...</p>}

        {!isLoading && filteredDungeons.length === 0 && (
          <Card>
            <div className="p-6 text-center text-sm text-slate-500">Aramana uygun zindan bulunamadı.</div>
          </Card>
        )}

        {!isLoading &&
          filteredDungeons.map((d, idx) => {
            const canEnter = d.required_level <= level && d.energy_cost <= energy && !inHospital;
            const preview = previewSuccessRate(
              d,
              player,
              level,
              equippedItems as Record<string, { attack?: number; defense?: number; health?: number; enhancement_level?: number } | null>
            );
            const successPct = Math.round(preview.calculated * 100);
            const theme = difficultyTheme[d.difficulty] || difficultyTheme.medium;

            return (
              <motion.article
                key={d.dungeon_id}
                initial={{ opacity: 0, y: 14 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.35, delay: idx * 0.04, ease: [0.22, 1, 0.36, 1] }}
                className="overflow-hidden rounded-3xl border border-white/12 bg-slate-900/72 shadow-[0_14px_34px_rgba(0,0,0,.35)]"
              >
                <div className="p-4 sm:p-5">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="truncate text-base font-black text-slate-100">{d.name}</h3>
                      <p className="mt-1 line-clamp-2 text-xs text-slate-300/80">{d.description}</p>
                    </div>
                    <span
                      className="rounded-xl px-2 py-1 text-[11px] font-semibold"
                      style={{ background: theme.glow, color: theme.text, boxShadow: `inset 0 0 0 1px ${theme.ring}` }}
                    >
                      {difficultyLabels[d.difficulty] || "Zindan"}
                    </span>
                  </div>

                  <div className="mt-3 grid grid-cols-2 gap-2 text-xs text-slate-100 sm:grid-cols-4">
                    <div className="rounded-xl bg-white/8 px-2 py-1.5">📊 Seviye: {d.required_level}</div>
                    <div className="rounded-xl bg-white/8 px-2 py-1.5">⚡ Enerji: {d.energy_cost}</div>
                    <div className="rounded-xl bg-white/8 px-2 py-1.5">💰 {formatGold(d.min_gold)}-{formatGold(d.max_gold)}</div>
                    <div className="rounded-xl bg-white/8 px-2 py-1.5">🎯 %{successPct}</div>
                  </div>

                  <div className="mt-3">
                    <div className="mb-1 flex items-center justify-between text-[11px] text-slate-300/80">
                      <span>Başarı Oranı</span>
                      <span>Power {Math.round(preview.playerPower).toLocaleString("tr-TR")}/{Math.round(preview.powerRequirement).toLocaleString("tr-TR")}</span>
                    </div>
                    <div className="h-2 rounded-full bg-slate-800">
                      <div
                        className="h-2 rounded-full transition-all"
                        style={{
                          width: `${successPct}%`,
                          background: "linear-gradient(90deg, #10b981 0%, #14b8a6 65%, #06b6d4 100%)",
                        }}
                      />
                    </div>
                  </div>

                  <div className="mt-4 flex gap-2">
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => {
                        setLootDungeon(d);
                        setLootOpen(true);
                      }}
                    >
                      Loot
                    </Button>
                    <Button
                      variant={canEnter ? "primary" : "secondary"}
                      size="sm"
                      className="flex-1"
                      disabled={!canEnter}
                      onClick={() => {
                        setSelectedDungeon(d);
                        setConfirmOpen(true);
                      }}
                    >
                      {!canEnter && inHospital
                        ? "Hastane Kilidi"
                        : !canEnter && d.required_level > level
                          ? `Seviye ${d.required_level}`
                          : !canEnter && d.energy_cost > energy
                            ? "Enerji Yetersiz"
                            : "Operasyonu Başlat"}
                    </Button>
                  </div>
                </div>
              </motion.article>
            );
          })}
      </div>

      <Modal
        isOpen={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        title={`${selectedDungeon?.name || "Zindan"} • Operasyon Onayı`}
        size="sm"
      >
        <div className="space-y-3">
          <p className="text-sm text-slate-600">
            Bu operasyon {selectedDungeon?.energy_cost || 0} enerji harcar. Başarısızlık durumunda hastaneye düşebilirsin.
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setConfirmOpen(false)}>
              İptal
            </Button>
            <Button variant="primary" size="sm" fullWidth isLoading={isEntering} onClick={handleEnterDungeon}>
              Başlat
            </Button>
          </div>
        </div>
      </Modal>

      <Modal isOpen={entryPhase !== null} onClose={() => {}} title="Savaş Akışı" size="sm">
        <div className="flex flex-col items-center justify-center gap-4 p-6">
          <motion.div
            animate={{ rotate: 360, scale: [1, 1.1, 1] }}
            transition={{ duration: 1.2, repeat: Infinity, ease: "linear" }}
            className="text-5xl"
          >
            ⚔️
          </motion.div>
          <p className="text-center text-sm font-semibold text-slate-700">{entryPhase}</p>
        </div>
      </Modal>

      <Modal
        isOpen={lootOpen}
        onClose={() => setLootOpen(false)}
        title={`${lootDungeon?.name || "Zindan"} • Loot Tablosu`}
        size="sm"
      >
        <div className="space-y-3">
          <div className="rounded-xl border border-slate-700 bg-slate-900 p-3">
            <p className="text-xs text-slate-300">Muhtemel Ödüller</p>
            {lootDungeon && lootDungeon.loot_table.length > 0 ? (
              <ul className="mt-2 space-y-2 text-sm text-slate-100">
                {lootDungeon.loot_table.slice(0, 8).map((item, i) => (
                  <li key={`${item}-${i}`} className="flex items-center justify-between gap-2 rounded-lg border border-white/8 bg-white/5 px-2 py-1.5">
                    <span className="truncate text-xs text-slate-100">{formatLootToken(item)}</span>
                    <span
                      className="rounded-md px-1.5 py-0.5 text-[10px] font-semibold"
                      style={{
                        background: rarityTheme[inferRarityFromItemToken(item)].bg,
                        color: rarityTheme[inferRarityFromItemToken(item)].text,
                        boxShadow: `inset 0 0 0 1px ${rarityTheme[inferRarityFromItemToken(item)].ring}`,
                      }}
                    >
                      {rarityTheme[inferRarityFromItemToken(item)].label}
                    </span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-2 text-sm text-slate-400">Bu zindan için loot bilgisi bulunamadı.</p>
            )}
          </div>
          {lootDungeon && (
            <div className="grid grid-cols-2 gap-2 text-xs text-slate-100">
              <div className="rounded-lg bg-white/8 px-2 py-1.5">💰 {formatGold(lootDungeon.min_gold)}-{formatGold(lootDungeon.max_gold)}</div>
              <div className="rounded-lg bg-white/8 px-2 py-1.5">⚡ {lootDungeon.energy_cost} enerji</div>
            </div>
          )}
          <Button variant="secondary" size="sm" fullWidth onClick={() => setLootOpen(false)}>
            Kapat
          </Button>
        </div>
      </Modal>

      <Modal
        isOpen={battleResult !== null && !battleResult?.hospitalized}
        onClose={() => setBattleResult(null)}
        title={battleResult?.success ? "Operasyon Başarılı" : "Operasyon Sonucu"}
        size="sm"
      >
        {battleResult && (
          <div className="space-y-3 text-center">
            {battleResult.error && (
              <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-semibold text-red-700">
                {battleResult.error}
              </div>
            )}
            {battleResult.success ? (
              <>
                <p className="text-sm font-semibold text-emerald-700">
                  {battleResult.critical ? "KRİTİK ZAFER!" : "Zindan temizlendi."}
                </p>
                {battleResult.rewards && (
                  <div className="space-y-1 text-sm text-slate-700">
                    <p>🪙 +{formatGold(battleResult.rewards.gold)} altın</p>
                    <p>✨ +{battleResult.rewards.xp.toLocaleString("tr-TR")} XP</p>
                    {battleResult.rewards.items.length > 0 && (
                      <p className="text-xs text-slate-500">🎒 {battleResult.rewards.items.join(", ")}</p>
                    )}
                  </div>
                )}
              </>
            ) : battleResult.error ? null : (
              <p className="text-sm font-semibold text-orange-700">Yenildin, fakat hastaneye düşmedin.</p>
            )}
            <Button variant="secondary" size="sm" fullWidth onClick={() => setBattleResult(null)}>
              Tamam
            </Button>
          </div>
        )}
      </Modal>

      <AnimatePresence>
        <HospitalResultOverlay
          isOpen={Boolean(battleResult?.hospitalized)}
          durationSeconds={battleResult?.hospitalDurationSeconds ?? 0}
          onGoHospital={() => router.push("/hospital")}
          onClose={() => setBattleResult(null)}
        />
      </AnimatePresence>
    </div>
  );
}
