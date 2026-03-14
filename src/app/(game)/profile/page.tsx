// ============================================================
// Profile Page — Kaynak: scenes/ui/screens/ProfileScreen.gd
// Temel bilgiler, istatistikler, PvP, itibar, aktivite
// ============================================================

"use client";

import { useMemo, useEffect } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { calculateEquipmentStats, calculateCharacterPowerBreakdown } from "@/lib/utils/calculateEquipmentStats";
import { getReputationTier, getReputationPowerContribution, getNextReputationMilestone } from "@/lib/utils/reputation";
import { Card } from "@/components/ui/Card";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { formatGold, formatCompact } from "@/lib/utils/string";
import { timeAgo } from "@/lib/utils/datetime";

const stagger = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.06 } },
};
const fadeUp = {
  hidden: { opacity: 0, y: 12 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } },
};

export default function ProfilePage() {
  const player = usePlayerStore((s) => s.player);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const tolerance = usePlayerStore((s) => s.tolerance);
  const pvpWins = usePlayerStore((s) => s.pvpWins);
  const pvpLosses = usePlayerStore((s) => s.pvpLosses);
  const pvpRating = usePlayerStore((s) => s.pvpRating);
  const characterClass = usePlayerStore((s) => s.characterClass);

  // Subscribe to equipped items to update stats immediately when equipment changes
  const equippedMap = useInventoryStore((s) => s.equippedItems);
  const computedStats = useMemo(() => {
    const eq = calculateEquipmentStats(equippedMap || {});
    const breakdown = calculateCharacterPowerBreakdown(eq, level, player?.reputation ?? 0);

    return {
      totalPower: breakdown.totalPower,
      attack: eq.totalAttack,
      defense: eq.totalDefense,
      hp: eq.totalHP,
      luck: eq.totalLuck,
      equipmentPower: breakdown.equipmentPower,
      levelPower: breakdown.levelPower,
      reputationPower: breakdown.reputationPower,
    };
  }, [equippedMap, level, player?.reputation]);

  // Ensure inventory (and equipped items) are fetched when profile mounts
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  useEffect(() => {
    fetchInventory(true).catch(() => {});
  }, [fetchInventory]);

  const xpForNext = Math.floor(1000 * Math.pow(level, 1.5));
  const winRate =
    pvpWins + pvpLosses > 0
      ? Math.round((pvpWins / (pvpWins + pvpLosses)) * 100)
      : 0;

  const reputation = Math.max(0, player?.reputation ?? 0);
  const reputationTier = useMemo(() => getReputationTier(reputation), [reputation]);
  const nextReputation = useMemo(() => getNextReputationMilestone(reputation), [reputation]);

  return (
    <motion.div
      variants={stagger}
      initial="hidden"
      animate="show"
      className="p-4 space-y-3"
    >
      {/* Temel Bilgiler */}
      <motion.div variants={fadeUp}>
        <Card variant="elevated">
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
              📋 Temel Bilgiler
            </h3>
            <div className="space-y-2">
              <InfoRow label="İsim" value={player?.display_name || player?.username || "—"} />
              <InfoRow label="Seviye" value={String(level)} />
              <InfoRow 
                label="Sınıf" 
                value={
                  characterClass
                    ? characterClass === 'warrior' ? '🗡️ Savaşçı' : 
                      characterClass === 'alchemist' ? '⚗️ Simyacı' : '🌑 Gölge'
                    : '❓ Seçilmedi'
                } 
              />
              <div>
                <div className="flex justify-between text-xs mb-1">
                  <span className="text-[var(--text-muted)]">Deneyim</span>
                  <span className="text-[var(--text-primary)]">
                    {formatCompact(xp)} / {formatCompact(xpForNext)}
                  </span>
                </div>
                <ProgressBar value={xp} max={xpForNext} color="accent" size="sm" />
              </div>
              <InfoRow label="Lonca" value={player?.guild_name || "Yok"} />
              <InfoRow label="Unvan" value={reputationTier.title} />
            </div>
          </div>
        </Card>
      </motion.div>

      {/* İstatistikler */}
      <motion.div variants={fadeUp}>
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
              📊 İstatistikler
            </h3>
            <div className="grid grid-cols-2 gap-x-4 gap-y-1">
              <InfoRow label="Güç" value={String(Math.round(computedStats.totalPower))} />
              <InfoRow label="Dayanıklılık" value={String(computedStats.defense)} />
              <InfoRow label="Çeviklik" value={String(computedStats.attack)} />
              <InfoRow label="Zeka" value={String(player?.intelligence || 0)} />
              <InfoRow label="Şans" value={String(computedStats.luck)} />
              <InfoRow label="HP" value={String(computedStats.hp)} />
              <InfoRow label="Enerji" value={`${energy}/${maxEnergy}`} />
              <InfoRow label="Güç (Ekipman)" value={formatCompact(computedStats.equipmentPower)} />
              <InfoRow label="Güç (Seviye)" value={formatCompact(computedStats.levelPower)} />
              <InfoRow label="Güç (Saygınlık)" value={formatCompact(computedStats.reputationPower)} />
            </div>
          </div>
        </Card>
      </motion.div>

      {/* Servet */}
      <motion.div variants={fadeUp}>
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
              💰 Servet
            </h3>
            <div className="grid grid-cols-2 gap-x-4 gap-y-1">
              <InfoRow label="Altın" value={formatGold(gold)} highlight />
              <InfoRow label="Gem" value={formatCompact(gems)} />
            </div>
          </div>
        </Card>
      </motion.div>

      {/* PvP */}
      <motion.div variants={fadeUp}>
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
              ⚔️ PvP İstatistikleri
            </h3>
            <div className="grid grid-cols-2 gap-x-4 gap-y-1">
              <InfoRow label="Rating" value={String(pvpRating)} />
              <InfoRow label="Galibiyet" value={String(pvpWins)} />
              <InfoRow label="Mağlubiyet" value={String(pvpLosses)} />
              <InfoRow label="Kazanma Oranı" value={`%${winRate}`} />
            </div>
          </div>
        </Card>
      </motion.div>

      {/* İtibar */}
      <motion.div variants={fadeUp}>
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
              ⭐ İtibar
            </h3>
            <p
              className="text-sm font-bold"
              style={{ color: reputationTier.color }}
            >
              {reputationTier.title}
            </p>
            <p className="text-xs text-[var(--text-muted)]">
              Puan: {formatCompact(reputation)}
            </p>
            <p className="text-xs text-[var(--text-muted)]">
              Power katkısı: +{formatCompact(getReputationPowerContribution(reputation))}
            </p>
            <p className="text-xs text-[var(--text-muted)]">
              Görsel: {reputationTier.visual}
            </p>
            <p className="text-xs text-[var(--text-muted)]">
              {nextReputation.target
                ? `Sonraki unvan: ${formatCompact(nextReputation.target)} (kalan ${formatCompact(nextReputation.remaining)})`
                : "Maksimum unvandasın"}
            </p>
          </div>
        </Card>
      </motion.div>

      {/* Aktivite */}
      <motion.div variants={fadeUp}>
        <Card>
          <div className="p-4">
            <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-2">
              📅 Aktivite
            </h3>
            <div className="space-y-1">
              {player?.created_at && (
                <InfoRow label="Kayıt" value={timeAgo(player.created_at)} />
              )}
              {player?.last_login && (
                <InfoRow label="Son Giriş" value={timeAgo(player.last_login)} />
              )}
              <InfoRow label="Tolerans" value={`%${tolerance}`} />
            </div>
          </div>
        </Card>
      </motion.div>
    </motion.div>
  );
}

function InfoRow({
  label,
  value,
  highlight,
}: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div className="flex justify-between text-xs">
      <span className="text-[var(--text-muted)]">{label}</span>
      <span
        className={
          highlight
            ? "text-[var(--color-gold)] font-medium"
            : "text-[var(--text-primary)]"
        }
      >
        {value}
      </span>
    </div>
  );
}
