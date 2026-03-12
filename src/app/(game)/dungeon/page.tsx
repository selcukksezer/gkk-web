// ============================================================
// Dungeon Page — Kaynak: scenes/ui/screens/DungeonScreen.gd (303 satır)
// Solo/Grup toggle, zorluk renkleri, enerji/seviye kontrolü,
// tahmini ödül aralığı (multiplier), başarı oranı breakdown,
// bilgi dialogu (loot table + season mods), hastane kontrolü
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { api } from "@/lib/api";
import { isInHospital } from "@/lib/utils/validation";
import { formatGold } from "@/lib/utils/string";
import type { DungeonData } from "@/types/dungeon";

type DungeonMode = "solo" | "group";

const difficultyColors: Record<string, string> = {
  EASY: "var(--color-success)",
  easy: "var(--color-success)",
  MEDIUM: "var(--color-warning)",
  medium: "var(--color-warning)",
  HARD: "var(--color-error)",
  hard: "var(--color-error)",
  DUNGEON: "var(--rarity-epic)",
  dungeon: "var(--rarity-epic)",
};

const difficultyEmoji: Record<string, string> = {
  EASY: "✓", easy: "✓",
  MEDIUM: "⚔️", medium: "⚔️",
  HARD: "⚠️", hard: "⚠️",
  DUNGEON: "☠️", dungeon: "☠️",
};

const difficultyLabels: Record<string, string> = {
  EASY: "Kolay", easy: "Kolay",
  MEDIUM: "Orta", medium: "Orta",
  HARD: "Zor", hard: "Zor",
  DUNGEON: "Zindan", dungeon: "Zindan",
};

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function estimateEquipmentPower(equippedItems: Record<string, { attack?: number; defense?: number; health?: number; enhancement_level?: number } | null>): number {
  return Math.floor(
    Object.values(equippedItems).reduce((sum, item) => {
      if (!item) return sum;
      const enh = 1 + ((item.enhancement_level ?? 0) * 0.15);
      const part = ((item.attack ?? 0) + (item.defense ?? 0) + ((item.health ?? 0) / 10)) * enh;
      return sum + part;
    }, 0)
  );
}

// PLAN_04 parity: power_ratio tabanli zindan basari preview'i
function previewSuccessRate(
  dungeon: DungeonData,
  player: { power?: number; luck?: number; reputation?: number; character_class?: string | null } | null,
  fallbackLevel: number,
  equippedItems: Record<string, { attack?: number; defense?: number; health?: number; enhancement_level?: number } | null>
) {
  const gearPowerEstimate = estimateEquipmentPower(equippedItems);

  const playerPower = (player?.power ?? 0) > 0
    ? Number(player?.power ?? 0)
    : Math.floor(
        fallbackLevel * 500 +
        Math.floor((player?.reputation ?? 0) * 0.1) +
        Math.floor((player?.luck ?? 0) * 50)
      );

  // Prefer server-provided power requirement when available.
  const inferredPowerReq = dungeon.dungeon_order === 1 ? 0 : Math.max(1, dungeon.required_level * 500);
  const powerRequirement = typeof dungeon.power_requirement === "number"
    ? dungeon.power_requirement
    : inferredPowerReq;

  const ratio = powerRequirement > 0 ? playerPower / powerRequirement : 999;

  let baseFromPower = 0;
  if (powerRequirement === 0) {
    baseFromPower = 1.0;
  } else if (ratio >= 1.5) {
    baseFromPower = 0.95;
  } else if (ratio >= 1.0) {
    baseFromPower = 0.70 + (ratio - 1.0) * 0.50;
  } else if (ratio >= 0.5) {
    baseFromPower = 0.25 + (ratio - 0.5) * 0.90;
  } else if (ratio >= 0.25) {
    baseFromPower = 0.10 + (ratio - 0.25) * 0.60;
  } else {
    baseFromPower = Math.max(0.05, ratio * 0.40);
  }

  const luckBonus = clamp((player?.luck ?? 0) * 0.001, 0, 0.05);
  const warriorBonus = (player?.character_class ?? null) === "warrior" ? 0.05 : 0;
  const reputationBonus = clamp((player?.reputation ?? 0) * 0.0005, 0, 0.025);
  const guildBonus = 0;
  const seasonBonus = 0;

  const calculated = clamp(
    baseFromPower + luckBonus + warriorBonus + reputationBonus + guildBonus + seasonBonus,
    0.05,
    0.95
  );

  return {
    calculated,
    baseFromPower,
    luckBonus,
    warriorBonus,
    reputationBonus,
    guildBonus,
    seasonBonus,
    ratio,
    playerPower,
    powerRequirement,
    gearPowerEstimate,
  };
}

const EMPTY_DUNGEONS: DungeonData[] = [];

export default function DungeonPage() {
  const energy = usePlayerStore((s) => s.energy);
  const level = usePlayerStore((s) => s.level);
  const player = usePlayerStore((s) => s.player);
  const hospitalUntil = usePlayerStore((s) => s.hospitalUntil);
  const consumeEnergy = usePlayerStore((s) => s.consumeEnergy);
  const equippedItems = useInventoryStore((s) => s.equippedItems);
  const addToast = useUiStore((s) => s.addToast);

  const [mode, setMode] = useState<DungeonMode>("solo");
  const [allDungeons, setAllDungeons] = useState<DungeonData[]>(EMPTY_DUNGEONS);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedDungeon, setSelectedDungeon] = useState<DungeonData | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [infoOpen, setInfoOpen] = useState(false);
  const [infoDungeon, setInfoDungeon] = useState<DungeonData | null>(null);
  const [isEntering, setIsEntering] = useState(false);
  const [entryPhase, setEntryPhase] = useState<string | null>(null);
  const [battleResult, setBattleResult] = useState<{
    success: boolean;
    rewards?: { gold: number; xp: number; items: string[] };
    hospitalDuration?: number;
  } | null>(null);

  const inHospital = isInHospital(hospitalUntil);

  // Mode change — boss ağırlıklı filtre ve genel solo akışı
  const handleModeChange = (newMode: DungeonMode) => {
    setMode(newMode);
  };

  // Load dungeon catalog from RPC
  useEffect(() => {
    (async () => {
      setIsLoading(true);
      try {
        const res = await api.rpc<DungeonData[]>("get_dungeons", {});
        if (res.success && res.data && res.data.length > 0) {
          setAllDungeons(res.data);
        } else {
          setAllDungeons([]);
        }
      } catch {
        setAllDungeons([]);
      }
      setIsLoading(false);
    })();
  }, []);

  const dungeons = useMemo(() => {
    if (mode === "group") {
      return allDungeons.filter((d) => d.difficulty === "dungeon" || d.max_players > 1);
    }
    return allDungeons;
  }, [allDungeons, mode]);

  const handleEnterDungeon = async () => {
    if (!selectedDungeon) return;
    setIsEntering(true);
    setConfirmOpen(false);
    setEntryPhase("Zindana giriliyor...");
    
    try {
      await new Promise(r => setTimeout(r, 1000));
      setEntryPhase("Düşmanla karşılaşıldı...");
      
      await new Promise(r => setTimeout(r, 1000));
      setEntryPhase("Savaşılıyor...");
      
      const resPromise = api.rpc<{
        success: boolean;
        gold_earned: number;
        xp_earned: number;
        items: string[];
        hospital_duration?: number;
      }>("enter_dungeon", { p_dungeon_id: selectedDungeon.dungeon_id });
      
      await new Promise(r => setTimeout(r, 1500));
      const res = await resPromise;

      const result = res.data;
      consumeEnergy(selectedDungeon.energy_cost);
      setEntryPhase(null);
      setBattleResult({
        success: result?.success ?? false,
        rewards: result?.success
          ? { gold: result.gold_earned, xp: result.xp_earned, items: result.items || [] }
          : undefined,
        hospitalDuration: result?.hospital_duration,
      });
    } catch {
      setEntryPhase(null);
      addToast("Zindana girilemedi", "error");
    } finally {
      setIsEntering(false);
    }
  };

  return (
    <div className="p-4 space-y-4 pb-24">
      <h2 className="text-lg font-bold text-[var(--text-primary)]">🏰 Zindanlar</h2>

      {/* Solo/Group Toggle — Godot: solo_button / group_button */}
      <div className="flex gap-2">
        <button
          onClick={() => handleModeChange("solo")}
          className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
            mode === "solo" ? "bg-[var(--accent)] text-white" : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
          }`}
        >
          ⚔️ Solo
        </button>
        <button
          onClick={() => handleModeChange("group")}
          className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${
            mode === "group" ? "bg-[var(--accent)] text-white" : "bg-[var(--bg-card)] text-[var(--text-secondary)]"
          }`}
        >
          👥 Grup
        </button>
      </div>

      {/* Hospital warning — Godot: "⚠️ Hastanelisiniz! Zindana giremezsiniz." */}
      {inHospital && (
        <Card>
          <div className="p-3 text-center text-sm text-[var(--color-error)]">
            ⚠️ Hastanelisiniz! Zindana giremezsiniz. Hastane sekmesine gidin.
          </div>
        </Card>
      )}

      {isLoading ? (
        <div className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</div>
      ) : (
        <div className="space-y-3">
          {dungeons.map((d) => {
            const canEnter = d.required_level <= level && d.energy_cost <= energy && !inHospital;
            const preview = previewSuccessRate(d, player, level, equippedItems as Record<string, { attack?: number; defense?: number; health?: number; enhancement_level?: number } | null>);
            const multiplier = 1.0; // Would come from season events

            // Breakdown parts — PLAN_04 format (power_ratio + modifierler)
            const breakdownParts: string[] = [];
            breakdownParts.push(`Power ${Math.round(preview.playerPower).toLocaleString()}/${Math.round(preview.powerRequirement).toLocaleString()}`);
            breakdownParts.push(`Ratio x${preview.ratio.toFixed(2)}`);
            breakdownParts.push(`Base ${Math.round(preview.baseFromPower * 100)}%`);
            if (preview.luckBonus > 0) breakdownParts.push(`Luck +${Math.round(preview.luckBonus * 100)}%`);
            if (preview.warriorBonus > 0) breakdownParts.push(`Savaşçı +${Math.round(preview.warriorBonus * 100)}%`);
            if (preview.reputationBonus > 0) breakdownParts.push(`Rep +${Math.round(preview.reputationBonus * 100)}%`);
            if (preview.gearPowerEstimate > 0) breakdownParts.push(`Ekipman Gücü~${preview.gearPowerEstimate.toLocaleString()}`);

            return (
              <Card key={d.dungeon_id} variant="elevated">
                <div className="p-4">
                  <div className="flex items-start justify-between mb-2">
                    <div>
                      <h3 className="text-sm font-bold text-[var(--text-primary)]">
                        {d.name}
                        {d.is_group && (
                          <span className="ml-1.5 text-[10px] bg-[var(--accent)]/20 text-[var(--accent-light)] px-1.5 py-0.5 rounded">GRUP</span>
                        )}
                      </h3>
                      <p className="text-xs text-[var(--text-muted)] mt-0.5">{d.description}</p>
                    </div>
                    <span className="text-xs font-semibold px-2 py-0.5 rounded" style={{
                      color: difficultyColors[d.difficulty],
                      backgroundColor: `${difficultyColors[d.difficulty]}20`,
                    }}>
                      {difficultyEmoji[d.difficulty]} {difficultyLabels[d.difficulty]}
                    </span>
                  </div>

                  {/* Stats row — Godot: Sev, ⚡, 💰, Başarı, breakdown */}
                  <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-[var(--text-secondary)] mb-2">
                    <span style={{ color: d.required_level <= level ? "var(--color-success)" : "var(--color-error)" }}>
                      📊 Sev: {d.required_level}
                    </span>
                    <span style={{ color: d.energy_cost <= energy ? "var(--color-warning)" : "var(--color-error)" }}>
                      ⚡ {d.energy_cost}
                    </span>
                    <span className="text-[var(--color-gold)]">
                      💰 {formatGold(d.min_gold)}-{formatGold(d.max_gold)} altın (x{multiplier})
                    </span>
                    <span className="text-[var(--color-success)]">
                      🎯 Başarı: %{Math.round(preview.calculated * 100)}
                    </span>
                  </div>

                  {/* Breakdown — Godot: "(Base X%, Gear +Y%, ...)" */}
                  <p className="text-[10px] text-[var(--text-muted)] mb-3">
                    ({breakdownParts.join(", ")})
                  </p>

                  <div className="flex gap-2">
                    {/* Info button — Godot: "Bilgi" */}
                    <Button variant="secondary" size="sm" onClick={() => { setInfoDungeon(d); setInfoOpen(true); }}>
                      Bilgi
                    </Button>
                    <Button
                      variant={canEnter ? "primary" : "secondary"}
                      size="sm"
                      className="flex-1"
                      disabled={!canEnter}
                      onClick={() => {
                        if (inHospital) {
                          addToast("Hastanedeyken zindana giremezsiniz!", "error");
                          return;
                        }
                        setSelectedDungeon(d);
                        setConfirmOpen(true);
                      }}
                    >
                      {d.required_level > level ? `Seviye ${d.required_level} gerekli`
                        : d.energy_cost > energy ? "ENERJİ YETERSİZ"
                        : "GİR"}
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* Confirm Entry Modal */}
      <Modal isOpen={confirmOpen} onClose={() => setConfirmOpen(false)} title={`${selectedDungeon?.name} — Giriş Onayı`} size="sm">
        <div className="space-y-3">
          <p className="text-sm text-[var(--text-secondary)]">
            Bu zindana girmek <strong>{selectedDungeon?.energy_cost}</strong> enerji harcayacak. Başarısız olursan hastaneye düşebilirsin.
          </p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setConfirmOpen(false)}>Vazgeç</Button>
            <Button variant="primary" size="sm" fullWidth isLoading={isEntering} onClick={handleEnterDungeon}>Giriş Yap</Button>
          </div>
        </div>
      </Modal>

      {/* Info Dialog — Godot: _on_show_dungeon_info (loot table + season mods + estimated gold) */}
      <Modal isOpen={infoOpen} onClose={() => setInfoOpen(false)} title={`${infoDungeon?.name} - Bilgi`} size="sm">
        {infoDungeon && (
          <div className="space-y-3">
            <div>
              <h4 className="text-xs font-semibold text-[var(--text-secondary)] mb-1">Muhtemel Loot (üst 3):</h4>
              {infoDungeon.loot_table.length > 0 ? (
                <ul className="text-xs text-[var(--text-primary)] space-y-0.5">
                  {infoDungeon.loot_table.slice(0, 3).map((item, i) => (
                    <li key={i}>• {item.replace(/_/g, " ")}</li>
                  ))}
                </ul>
              ) : (
                <p className="text-xs text-[var(--text-muted)]">Muhtemel loot bilgisi bulunamadı</p>
              )}
            </div>
            <div>
              <p className="text-xs text-[var(--color-gold)]">
                Tahmini Altın: {formatGold(infoDungeon.min_gold)} - {formatGold(infoDungeon.max_gold)} (x1.0)
              </p>
            </div>
            {infoDungeon.boss_name && (
              <p className="text-xs text-[var(--rarity-epic)]">
                Boss: {infoDungeon.boss_name}
              </p>
            )}
            <Button variant="secondary" size="sm" fullWidth onClick={() => setInfoOpen(false)}>Kapat</Button>
          </div>
        )}
      </Modal>

      {/* Entry Animation Modal */}
      <Modal isOpen={entryPhase !== null} onClose={() => {}} title="Savaş" size="sm">
        <div className="flex flex-col items-center justify-center p-8 space-y-6">
          <motion.div
            animate={{ rotate: 360, scale: [1, 1.2, 1] }}
            transition={{ duration: 1, repeat: Infinity }}
            className="text-5xl"
          >
            ⚔️
          </motion.div>
          <p className="text-lg font-semibold text-[var(--text-primary)] text-center animate-pulse">
            {entryPhase}
          </p>
        </div>
      </Modal>

      {/* Battle Result Modal */}
      <Modal isOpen={battleResult !== null} onClose={() => setBattleResult(null)} title={battleResult?.success ? "🎉 Başarılı!" : "💀 Başarısız"} size="sm">
        {battleResult && (
          <div className="space-y-3 text-center">
            {battleResult.success ? (
              <>
                <p className="text-sm text-[var(--color-success)]">Zindanı başarıyla tamamladın!</p>
                {battleResult.rewards && (
                  <div className="space-y-1 text-sm">
                    <p>🪙 {formatGold(battleResult.rewards.gold)} altın</p>
                    <p>✨ {battleResult.rewards.xp} XP</p>
                    {battleResult.rewards.items.length > 0 && <p>🎒 {battleResult.rewards.items.join(", ")}</p>}
                  </div>
                )}
              </>
            ) : (
              <>
                <p className="text-sm text-[var(--color-error)]">Yenildin!</p>
                {battleResult.hospitalDuration && (
                  <p className="text-xs text-[var(--text-muted)]">🏥 Hastanede {Math.round(battleResult.hospitalDuration / 3600)} saat kalacaksın</p>
                )}
              </>
            )}
            <Button variant="secondary" size="sm" fullWidth onClick={() => setBattleResult(null)}>Tamam</Button>
          </div>
        )}
      </Modal>
    </div>
  );
}
