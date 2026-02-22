// ============================================================
// Character Page — Kaynak: scenes/ui/screens/CharacterScreen.gd
// Karakter bilgileri, stats, skills, equipment özet
// ============================================================

"use client";

import { motion } from "framer-motion";
import { useRouter } from "next/navigation";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { Card } from "@/components/ui/Card";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Button } from "@/components/ui/Button";
import { formatGold, formatCompact } from "@/lib/utils/string";

const EQUIP_SLOTS = [
  { key: "weapon", label: "Silah", icon: "⚔️" },
  { key: "armor", label: "Zırh", icon: "🛡️" },
  { key: "helmet", label: "Kask", icon: "⛑️" },
  { key: "gloves", label: "Eldiven", icon: "🧤" },
  { key: "boots", label: "Ayakkabı", icon: "👢" },
  { key: "accessory", label: "Aksesuar", icon: "💍" },
];

export default function CharacterPage() {
  const router = useRouter();
  const player = usePlayerStore((s) => s.player);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const tolerance = usePlayerStore((s) => s.tolerance);
  const items = useInventoryStore((s) => s.items);

  const xpForNext = Math.floor(1000 * Math.pow(level, 1.5));

  // Basic stat calculation from equipped items
  const equippedItems = items.filter((i) => i.is_equipped);
  const totalAtk = equippedItems.reduce((sum, i) => sum + (i.attack ?? 0), 0);
  const totalDef = equippedItems.reduce((sum, i) => sum + (i.defense ?? 0), 0);
  const totalHp = equippedItems.reduce((sum, i) => sum + (i.health ?? 0), 0);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🧙 Karakter</h1>

      {/* Name + Level + XP */}
      <Card variant="elevated">
        <div className="p-4">
          <h2 className="text-lg font-bold text-[var(--text-primary)]">
            {player?.display_name || player?.username || "Oyuncu"}
          </h2>
          <p className="text-xs text-[var(--text-muted)] mb-3">Seviye {level}</p>
          <ProgressBar value={xp} max={xpForNext} color="accent" size="sm"
            label={`XP: ${formatCompact(xp)} / ${formatCompact(xpForNext)}`} />
        </div>
      </Card>

      {/* Stats */}
      <Card>
        <div className="p-4">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-3">📊 İstatistikler</h3>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Sağlık", value: 100 + totalHp + level * 10, icon: "❤️" },
              { label: "Saldırı", value: totalAtk + level * 2, icon: "⚔️" },
              { label: "Savunma", value: totalDef + level, icon: "🛡️" },
              { label: "Şans", value: Math.floor(level * 0.5 + 5), icon: "🍀" },
            ].map((stat) => (
              <div key={stat.label} className="flex items-center gap-2 bg-[var(--bg-input)] rounded-lg p-2">
                <span className="text-lg">{stat.icon}</span>
                <div>
                  <p className="text-[10px] text-[var(--text-muted)]">{stat.label}</p>
                  <p className="text-sm font-bold text-[var(--text-primary)]">{stat.value}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </Card>

      {/* Resources */}
      <Card>
        <div className="p-4">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-3">💰 Kaynaklar</h3>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between"><span className="text-[var(--text-muted)]">Altın</span><span className="text-[var(--color-gold)]">🪙 {formatGold(gold)}</span></div>
            <div className="flex justify-between"><span className="text-[var(--text-muted)]">Gem</span><span className="text-[var(--color-gem)]">💎 {formatCompact(gems)}</span></div>
            <div className="flex justify-between"><span className="text-[var(--text-muted)]">Enerji</span><span className="text-energy">⚡ {energy}/{maxEnergy}</span></div>
            <div className="flex justify-between"><span className="text-[var(--text-muted)]">Tolerans</span><span>{tolerance}/100</span></div>
          </div>
        </div>
      </Card>

      {/* Equipment Summary */}
      <Card>
        <div className="p-4">
          <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-3">🛡️ Ekipman</h3>
          <div className="space-y-2">
            {EQUIP_SLOTS.map((slot) => {
              const equipped = equippedItems.find((i) => i.equipped_slot === slot.key || i.equip_slot === slot.key || i.item_type === slot.key);
              return (
                <div key={slot.key} className="flex items-center justify-between bg-[var(--bg-input)] rounded-lg px-3 py-2">
                  <span className="text-xs text-[var(--text-muted)]">{slot.icon} {slot.label}</span>
                  <span className="text-xs font-medium text-[var(--text-primary)]">
                    {equipped ? equipped.name : "—Boş—"}
                  </span>
                </div>
              );
            })}
          </div>
          <Button variant="secondary" size="sm" fullWidth className="mt-3"
            onClick={() => router.push("/equipment")}>
            Teçhizat Yönetimi →
          </Button>
        </div>
      </Card>
    </motion.div>
  );
}
