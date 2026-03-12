// ============================================================
// Character Page — Kaynak: scenes/ui/screens/CharacterScreen.gd
// 3 sekme: Özellikler, Yetenekler, Başarımlar
// Tam savaş formülü, ekipman slotları, kaynaklar, şüphe seviyesi
// ============================================================

"use client";

import { useEffect, useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useRouter } from "next/navigation";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { Card } from "@/components/ui/Card";
import { ProgressBar } from "@/components/ui/ProgressBar";
import { Button } from "@/components/ui/Button";
import { formatGold, formatCompact } from "@/lib/utils/string";
import { ToleranceBar } from "@/components/game/ToleranceBar";

// Character class data (PLAN_11 — Karakter Sınıfı & Stat Sistemi)
const CLASS_DATA: Record<'warrior' | 'alchemist' | 'shadow', {
  name: string;
  icon: string;
  description: string;
  class_feature: string;
  base_stats: { attack: number; defense: number; health: number; luck: number };
  bonuses: { label: string; value: string; color: string }[];
}> = {
  warrior: {
    name: "🗡️ Savaşçı",
    icon: "🗡️",
    description: "Yeraltı dünyasının sert dövüşçüsü. Han'ın en güçlü PvP oyuncusu.",
    class_feature: "Kan Hırsı — PvP kazandıktan sonra 30 dk boyunca attack %10 artar (üst üste 3 kazanımda %20'ye çıkar).",
    base_stats: { attack: 18, defense: 12, health: 120, luck: 5 },
    bonuses: [
      { label: "PvP Hasar", value: "+20%", color: "var(--color-error)" },
      { label: "Boss Hasar", value: "+15%", color: "var(--color-gold)" },
      { label: "PvP Kritik Şansı", value: "+10%", color: "var(--color-warning)" },
      { label: "Zindan Başarısı", value: "+5%", color: "var(--color-success)" },
      { label: "Hastane Süresi", value: "-20%", color: "var(--text-muted)" },
    ],
  },
  alchemist: {
    name: "⚗️ Simyacı",
    icon: "⚗️",
    description: "İksirlerin ve formüllerin efendisi. Crafting ve üretim odaklı oyuncunun tercihi.",
    class_feature: "Formül Ustası — Her gün 1 adet ücretsiz Minor Detox Drink üretme hakkı (craft malzemesi gerekmez).",
    base_stats: { attack: 10, defense: 12, health: 140, luck: 12 },
    bonuses: [
      { label: "İksir Etkinliği", value: "+30%", color: "var(--rarity-epic)" },
      { label: "Tolerans Artışı", value: "-25%", color: "var(--color-success)" },
      { label: "Overdose Şansı", value: "-20%", color: "var(--color-success)" },
      { label: "Crafting Başarısı", value: "+15%", color: "var(--color-gold)" },
      { label: "Han Üretim Süresi", value: "-20%", color: "var(--text-muted)" },
    ],
  },
  shadow: {
    name: "🌑 Gölge",
    icon: "🌑",
    description: "Şüphe altında faaliyet gösteren, gizliliği ve kaçınmayı benimseyen karakter.",
    class_feature: "Gölgelik — Tesisler'de şüphe artış hızı %30 düşük, rüşvet maliyeti %25 az.",
    base_stats: { attack: 12, defense: 10, health: 110, luck: 18 },
    bonuses: [
      { label: "Tesis Şüphesi", value: "-30%", color: "var(--color-success)" },
      { label: "Rüşvet Maliyeti", value: "-25%", color: "var(--color-success)" },
      { label: "Hapişhaneden Kaçış", value: "+20%", color: "var(--color-warning)" },
      { label: "Zindan Loot Şansı", value: "+40%", color: "var(--color-gold)" },
      { label: "PvP Kaçınma", value: "+15%", color: "var(--text-muted)" },
    ],
  },
};

type CharTab = "stats" | "skills" | "achievements";

const CHAR_TABS: { key: CharTab; label: string }[] = [
  { key: "stats", label: "📊 Özellikler" },
  { key: "skills", label: "🔧 Yetenekler" },
  { key: "achievements", label: "🏅 Başarımlar" },
];

const EQUIP_SLOTS = [
  { key: "weapon", label: "Silah", icon: "⚔️" },
  { key: "armor", label: "Zırh", icon: "🛡️" },
  { key: "helmet", label: "Kask", icon: "⛑️" },
  { key: "gloves", label: "Eldiven", icon: "🧤" },
  { key: "boots", label: "Ayakkabı", icon: "👢" },
  { key: "accessory", label: "Aksesuar", icon: "💍" },
];

// Static skill definitions (Godot: CharacterScreen skill cards)
const SKILLS = [
  {
    key: "combat",
    label: "Savaş",
    icon: "⚔️",
    description: "Yakın dövüş saldırı gücünü, kritik şansını ve savunma kabiliyetini artırır.",
    color: "var(--color-error)",
  },
  {
    key: "stealth",
    label: "Gizlilik",
    icon: "🥷",
    description: "Kaçınma oranını ve gizli saldırı hasarını artırır. Şüphe birikimini yavaşlatır.",
    color: "var(--text-muted)",
  },
  {
    key: "magic",
    label: "Büyü",
    icon: "🔮",
    description: "Büyü gücünü ve enerji verimliliğini artırır. Özel büyülü becerileri açar.",
    color: "var(--rarity-epic)",
  },
  {
    key: "crafting",
    label: "Zanaatkarlık",
    icon: "🔨",
    description: "Daha iyi ekipman üretmeni sağlar. Başarı şansını ve kalite bonusunu artırır.",
    color: "var(--color-warning)",
  },
  {
    key: "trade",
    label: "Ticaret",
    icon: "💰",
    description: "Satış fiyatlarını artırır ve satın alım maliyetlerini düşürür.",
    color: "var(--color-gold)",
  },
  {
    key: "leadership",
    label: "Liderlik",
    icon: "👑",
    description: "Grup bonuslarını artırır. Zindan ekibiyle senkronize XP kazanımını güçlendirir.",
    color: "var(--rarity-legendary)",
  },
];

// Dummy skill levels — in a real app these would come from the player profile
const DEFAULT_SKILL_LEVELS: Record<string, number> = {
  combat: 3,
  stealth: 1,
  magic: 2,
  crafting: 0,
  trade: 1,
  leadership: 0,
};

function suspicionColor(level: number): string {
  if (level < 30) return "var(--color-success)";
  if (level < 60) return "var(--color-warning)";
  if (level < 80) return "var(--color-error)";
  return "#dc2626";
}

function toleranceColor(value: number): string {
  if (value < 40) return "var(--color-success)";
  if (value < 70) return "var(--color-warning)";
  return "var(--color-error)";
}

export default function CharacterPage() {
  const router = useRouter();

  // Player state
  const player = usePlayerStore((s) => s.player);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const nextLevelXp = usePlayerStore((s) => s.nextLevelXp);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const tolerance = usePlayerStore((s) => s.tolerance);
  const addictionLevel = usePlayerStore((s) => s.addictionLevel);
  const lastPotionUsedAt = usePlayerStore((s) => s.lastPotionUsedAt);
  const warriorBloodlustUntil = usePlayerStore((s) => s.warriorBloodlustUntil);
  const globalSuspicionLevel = usePlayerStore((s) => s.globalSuspicionLevel);
  const characterClass = usePlayerStore((s) => s.characterClass);
  const luck = usePlayerStore((s) => s.luck);
  const fetchProfile = usePlayerStore((s) => s.fetchProfile);

  // Inventory
  const items = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);

  const addToast = useUiStore((s) => s.addToast);

  const [activeTab, setActiveTab] = useState<CharTab>("stats");
  const [skillLevels] = useState<Record<string, number>>(DEFAULT_SKILL_LEVELS);

  useEffect(() => {
    fetchProfile();
    fetchInventory();
  }, [fetchProfile, fetchInventory]);

  // Equipped items
  const equippedItems = useMemo(() => items.filter((i) => i.is_equipped), [items]);

  // Equipment bonuses
  const eqAtk = useMemo(() => equippedItems.reduce((s, i) => s + (i.attack ?? 0), 0), [equippedItems]);
  const eqDef = useMemo(() => equippedItems.reduce((s, i) => s + (i.defense ?? 0), 0), [equippedItems]);
  const eqHp = useMemo(() => equippedItems.reduce((s, i) => s + (i.health ?? 0), 0), [equippedItems]);

  // Level bonuses (Godot: CharacterScreen combat formula)
  const lvlHp = level * 10;
  const lvlAtk = level * 2;
  const lvlDef = level * 1;

  // Base stats
  const baseHp = 100;
  const baseAtk = 5;
  const baseDef = 3;
  const baseSpeed = 10;
  const baseLuck = 5;

  // Final computed stats
  const finalHp = baseHp + eqHp + lvlHp;
  const finalAtk = baseAtk + eqAtk + lvlAtk;
  const finalDef = baseDef + eqDef + lvlDef;
  const finalSpeed = baseSpeed + Math.floor(level * 0.3);
  const finalLuck = (luck ?? 0) + Math.floor(level * 0.5);
  const critChance = Math.min(5 + Math.floor(level * 0.4) + Math.floor(skillLevels.combat * 1.5), 50);
  const critDamage = 150 + Math.floor(level * 0.5) + skillLevels.combat * 5;
  const evasion = Math.floor(skillLevels.stealth * 3 + level * 0.2);

  const xpPercent = nextLevelXp > 0 ? Math.round((xp / nextLevelXp) * 100) : 0;
  const energyPercent = maxEnergy > 0 ? Math.round((energy / maxEnergy) * 100) : 0;

  // Active Buffs/Debuffs calculation
  const isBloodlustActive = characterClass === 'warrior' && warriorBloodlustUntil && new Date(warriorBloodlustUntil) > new Date();
  
  // Withdrawal: Addiction >= 3 and no potion in 24 hours
  const isWithdrawal = addictionLevel >= 3 && (!lastPotionUsedAt || (new Date().getTime() - new Date(lastPotionUsedAt).getTime()) > 24 * 60 * 60 * 1000);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-[var(--gold)]">🧙 Karakter</h1>
        <span className="text-xs text-[var(--text-muted)]">Seviye {level}</span>
      </div>

      {/* Character Class Card */}
      {characterClass && (
        <Card variant="elevated" className="border-l-4" style={{ borderLeftColor: 
          characterClass === 'warrior' ? 'var(--color-error)' : 
          characterClass === 'alchemist' ? 'var(--rarity-epic)' : 
          'var(--text-muted)'
        }}>
          <div className="p-4">
            <div className="flex items-start gap-3 mb-2">
              <div className="text-4xl">{CLASS_DATA[characterClass].icon}</div>
              <div className="flex-1">
                <h3 className="text-lg font-bold text-[var(--text-primary)]">
                  {CLASS_DATA[characterClass].name}
                </h3>
                <p className="text-xs text-[var(--text-secondary)] mt-1">
                  {CLASS_DATA[characterClass].description}
                </p>
              </div>
            </div>
            <div className="bg-[var(--bg-input)] rounded-lg p-2 mt-3 border-l-2 border-[var(--accent)]">
              <p className="text-xs text-[var(--text-muted)] font-medium">⭐ Sınıf Özelliği</p>
              <p className="text-xs text-[var(--text-secondary)] mt-1">
                {CLASS_DATA[characterClass].class_feature}
              </p>
              {characterClass === 'alchemist' && (
                <div className="mt-2 text-right">
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={async () => {
                      try {
                        const { api } = await import("@/lib/api");
                        const res = await api.rpc("claim_alchemist_detox");
                        if (res.success && (res.data as any)?.success) {
                          useUiStore.getState().addToast("✅ Minor Detox başarıyla alındı!", "success");
                        } else {
                          useUiStore.getState().addToast(`❌ ${(res.data as any)?.message || "Bir hata oluştu. Belki süresi dolmamıştır."}`, "error");
                        }
                      } catch (err) {
                        useUiStore.getState().addToast("❌ İşlem başarısız", "error");
                      }
                    }}
                  >
                    🧪 Günlük Minor Detox Al
                  </Button>
                </div>
              )}
            </div>
          </div>
        </Card>
      )}

      {/* Active Buffs/Debuffs */}
      {(isBloodlustActive || isWithdrawal) && (
        <Card variant="elevated" className="border-l-4 border-[var(--color-warning)]">
          <div className="p-4 space-y-2">
            <h3 className="text-sm font-semibold text-[var(--text-primary)]">✨ Aktif Etkiler</h3>
            <div className="space-y-1.5">
              {isBloodlustActive && (
                <div className="flex items-center gap-2 text-xs">
                  <span className="text-[var(--color-error)]">🩸 Kan Hırsı:</span>
                  <span className="text-[var(--text-secondary)]">+10/20% ATK (Aktif)</span>
                </div>
              )}
              {isWithdrawal && (
                <div className="flex items-center gap-2 text-xs">
                  <span className="text-purple-400">🌀 Yoksunluk (Bağımlılık Lvl {addictionLevel}):</span>
                  <span className="text-[var(--text-secondary)]">-20% HP, -15% ATK/DEF, Titreme aktif</span>
                </div>
              )}
            </div>
          </div>
        </Card>
      )}

      {/* Player Name + XP Bar */}
      <Card variant="elevated">
        <div className="p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-12 h-12 rounded-full bg-[var(--accent)]/20 flex items-center justify-center text-2xl">
              🧙
            </div>
            <div className="flex-1">
              <h2 className="text-base font-bold text-[var(--text-primary)]">
                {player?.display_name || player?.username || "Oyuncu"}
              </h2>
              <p className="text-xs text-[var(--text-muted)]">Seviye {level} Kahraman</p>
            </div>
            <div className="text-right">
              <p className="text-xs text-[var(--text-muted)]">Sıradaki Seviye</p>
              <p className="text-sm font-bold text-[var(--accent-light)]">{xpPercent}%</p>
            </div>
          </div>
          <ProgressBar
            value={xp}
            max={nextLevelXp}
            color="accent"
            size="sm"
            label={`XP: ${formatCompact(xp)} / ${formatCompact(nextLevelXp)}`}
          />
        </div>
      </Card>

      {/* Tab Switcher */}
      <div className="flex gap-1 bg-[var(--bg-input)] rounded-xl p-1">
        {CHAR_TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-1 py-2 px-1 rounded-lg text-xs font-medium transition-all ${
              activeTab === tab.key
                ? "bg-[var(--accent)] text-white shadow"
                : "text-[var(--text-secondary)] hover:text-[var(--text-primary)]"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <AnimatePresence mode="wait">
        {activeTab === "stats" && (
          <motion.div
            key="stats"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="space-y-4"
          >
            {/* Combat Stats Table */}
            <Card>
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-3">
                  ⚔️ Savaş İstatistikleri
                </h3>
                <div className="overflow-x-auto">
                  <table className="w-full text-xs">
                    <thead>
                      <tr className="border-b border-[var(--border-subtle)]">
                        <th className="text-left py-1.5 text-[var(--text-muted)] font-medium">İstatistik</th>
                        <th className="text-right py-1.5 text-[var(--text-muted)] font-medium">Taban</th>
                        <th className="text-right py-1.5 text-[var(--text-muted)] font-medium">Ekipman</th>
                        <th className="text-right py-1.5 text-[var(--text-muted)] font-medium">Seviye</th>
                        <th className="text-right py-1.5 text-[var(--text-primary)] font-bold">Toplam</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[var(--border-subtle)]">
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">❤️ Sağlık</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">{baseHp}</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+{eqHp}</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{lvlHp}</td>
                        <td className="py-2 text-right font-bold text-[var(--text-primary)]">{finalHp}</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">⚔️ Saldırı</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">{baseAtk}</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+{eqAtk}</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{lvlAtk}</td>
                        <td className="py-2 text-right font-bold text-[var(--text-primary)]">{finalAtk}</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">🛡️ Savunma</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">{baseDef}</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+{eqDef}</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{lvlDef}</td>
                        <td className="py-2 text-right font-bold text-[var(--text-primary)]">{finalDef}</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">💨 Hız</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">{baseSpeed}</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+0</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{finalSpeed - baseSpeed}</td>
                        <td className="py-2 text-right font-bold text-[var(--text-primary)]">{finalSpeed}</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">🍀 Şans</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">{baseLuck}</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+0</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{finalLuck - baseLuck}</td>
                        <td className="py-2 text-right font-bold text-[var(--text-primary)]">{finalLuck}</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">🎯 Kritik Şans</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">5%</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+0%</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">
                          +{critChance - 5}%
                        </td>
                        <td className="py-2 text-right font-bold text-[var(--color-warning)]">{critChance}%</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">💥 Kritik Hasar</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">150%</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+0%</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">
                          +{critDamage - 150}%
                        </td>
                        <td className="py-2 text-right font-bold text-[var(--color-error)]">{critDamage}%</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">🌀 Kaçınma</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">0%</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+0%</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{evasion}%</td>
                        <td className="py-2 text-right font-bold text-[var(--text-primary)]">{evasion}%</td>
                      </tr>
                      <tr>
                        <td className="py-2 text-[var(--text-primary)]">⭐ Şans</td>
                        <td className="py-2 text-right text-[var(--text-muted)]">5</td>
                        <td className="py-2 text-right text-[var(--color-success)]">+0</td>
                        <td className="py-2 text-right text-[var(--accent-light)]">+{Math.floor(level * 0.5)}</td>
                        <td className="py-2 text-right font-bold text-[var(--color-warning)]">{finalLuck}</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </Card>
            
            {/* Class Bonuses */}
            {characterClass && (
              <Card>
                <div className="p-4">
                  <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-3">
                    🎭 Sınıf Bonusları — {CLASS_DATA[characterClass].name}
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
                    {CLASS_DATA[characterClass].bonuses.map((bonus) => (
                      <div
                        key={bonus.label}
                        className="bg-[var(--bg-input)] p-3 rounded-lg border border-[var(--border-subtle)]"
                        style={{ borderLeftColor: bonus.color, borderLeftWidth: "3px" }}
                      >
                        <div className="text-[var(--text-muted)] font-medium">{bonus.label}</div>
                        <div className="font-bold text-lg mt-1" style={{ color: bonus.color }}>
                          {bonus.value}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </Card>
            )}

            {/* Equipment Slots */}
            <Card>
              <div className="p-4">
                <div className="flex items-center justify-between mb-3">
                  <h3 className="text-sm font-semibold text-[var(--text-secondary)]">🛡️ Ekipman Slotları</h3>
                  <span className="text-xs text-[var(--text-muted)]">
                    {equippedItems.length}/{EQUIP_SLOTS.length} kuşanıldı
                  </span>
                </div>
                <div className="space-y-2">
                  {EQUIP_SLOTS.map((slot) => {
                    const eq = equippedItems.find(
                      (i) => i.equipped_slot === slot.key || i.equip_slot === slot.key
                    );
                    return (
                      <div
                        key={slot.key}
                        className="flex items-center justify-between bg-[var(--bg-input)] rounded-lg px-3 py-2"
                      >
                        <span className="text-xs text-[var(--text-muted)] w-20 flex-shrink-0">
                          {slot.icon} {slot.label}
                        </span>
                        {eq ? (
                          <div className="flex-1 ml-2 min-w-0">
                            <span className="text-xs font-medium text-[var(--text-primary)] truncate block">
                              {eq.name}
                            </span>
                            <span className="text-[10px] text-[var(--text-muted)]">
                              {eq.attack > 0 && `ATK +${eq.attack} `}
                              {eq.defense > 0 && `DEF +${eq.defense} `}
                              {eq.health > 0 && `HP +${eq.health}`}
                            </span>
                          </div>
                        ) : (
                          <span className="flex-1 ml-2 text-xs text-[var(--text-muted)] italic">— Boş —</span>
                        )}
                      </div>
                    );
                  })}
                </div>
                <Button
                  variant="secondary"
                  size="sm"
                  fullWidth
                  className="mt-3"
                  onClick={() => router.push("/inventory")}
                >
                  Envantere Git →
                </Button>
              </div>
            </Card>

            {/* Resources Card */}
            <Card>
              <div className="p-4">
                <h3 className="text-sm font-semibold text-[var(--text-secondary)] mb-3">💰 Kaynaklar</h3>
                <div className="space-y-3">
                  {/* Gold */}
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-[var(--text-muted)]">🪙 Altın</span>
                    <span className="text-sm font-bold text-[var(--color-gold)]">{formatGold(gold)}</span>
                  </div>
                  {/* Gems */}
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-[var(--text-muted)]">💎 Gem</span>
                    <span className="text-sm font-bold text-[var(--rarity-epic)]">{formatCompact(gems)}</span>
                  </div>
                  {/* Energy bar */}
                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs text-[var(--text-muted)]">⚡ Enerji</span>
                      <span
                        className="text-xs font-semibold"
                        style={{ color: energyPercent < 30 ? "var(--color-error)" : "var(--color-warning)" }}
                      >
                        {energy}/{maxEnergy}
                      </span>
                    </div>
                    <div className="w-full h-2 bg-[var(--bg-card)] rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all"
                        style={{
                          width: `${energyPercent}%`,
                          backgroundColor:
                            energyPercent < 30 ? "var(--color-error)" : "var(--color-warning)",
                        }}
                      />
                    </div>
                  </div>
                  {/* Tolerance bar */}
                  <ToleranceBar />

                  {/* Suspicion meter */}
                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs text-[var(--text-muted)]">👁️ Şüphe Seviyesi</span>
                      <span
                        className="text-xs font-semibold"
                        style={{ color: suspicionColor(globalSuspicionLevel) }}
                      >
                        {globalSuspicionLevel}/100
                        {globalSuspicionLevel >= 80 && " ⚠️"}
                      </span>
                    </div>
                    <div className="w-full h-2 bg-[var(--bg-card)] rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all"
                        style={{
                          width: `${Math.min(globalSuspicionLevel, 100)}%`,
                          backgroundColor: suspicionColor(globalSuspicionLevel),
                        }}
                      />
                    </div>
                    {globalSuspicionLevel >= 60 && (
                      <p className="text-[10px] text-[var(--color-error)] mt-1">
                        ⚠️ Yüksek şüphe seviyesi! Yasal olmayan aktiviteleri azalt.
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </Card>
          </motion.div>
        )}

        {activeTab === "skills" && (
          <motion.div
            key="skills"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="space-y-3"
          >
            <p className="text-xs text-[var(--text-muted)]">
              Yetenekler seviye atlamayla ve görev ödülleriyle yükselir. Max seviye: 10.
            </p>
            {SKILLS.map((skill) => {
              const lvl = skillLevels[skill.key] ?? 0;
              const progressPct = (lvl / 10) * 100;
              return (
                <Card key={skill.key}>
                  <div className="p-4">
                    <div className="flex items-start gap-3">
                      <div
                        className="w-10 h-10 rounded-xl flex items-center justify-center text-xl flex-shrink-0"
                        style={{ backgroundColor: `${skill.color}20` }}
                      >
                        {skill.icon}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-0.5">
                          <h4
                            className="text-sm font-bold"
                            style={{ color: skill.color }}
                          >
                            {skill.label}
                          </h4>
                          <span className="text-xs font-bold text-[var(--text-primary)]">
                            Sev {lvl}/10
                          </span>
                        </div>
                        <p className="text-xs text-[var(--text-muted)] mb-2 leading-relaxed">
                          {skill.description}
                        </p>
                        <div className="w-full h-1.5 bg-[var(--bg-card)] rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all"
                            style={{
                              width: `${progressPct}%`,
                              backgroundColor: skill.color,
                            }}
                          />
                        </div>
                        <div className="flex justify-between mt-1">
                          {Array.from({ length: 10 }).map((_, i) => (
                            <div
                              key={i}
                              className="w-1.5 h-1.5 rounded-full"
                              style={{
                                backgroundColor: i < lvl ? skill.color : "var(--border-default)",
                              }}
                            />
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>
                </Card>
              );
            })}
            <p className="text-xs text-center text-[var(--text-muted)] pb-2">
              Yetenekleri geliştirmek için görevleri tamamla ve zindan kazan.
            </p>
          </motion.div>
        )}

        {activeTab === "achievements" && (
          <motion.div
            key="achievements"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="space-y-4"
          >
            <Card>
              <div className="p-6 text-center space-y-4">
                <div className="text-4xl">🏅</div>
                <h3 className="text-base font-bold text-[var(--text-primary)]">Başarımlar</h3>
                <p className="text-sm text-[var(--text-muted)]">
                  Tamamladığın görevler, zindan zaferler ve özel etkinliklerden kazandığın başarımları görüntüle.
                </p>
                <Button
                  variant="primary"
                  size="md"
                  fullWidth
                  onClick={() => router.push("/achievements")}
                >
                  Başarımlar → 🏅
                </Button>
              </div>
            </Card>

            {/* Quick achievement preview */}
            <Card>
              <div className="p-4">
                <h4 className="text-xs font-semibold text-[var(--text-secondary)] mb-3">
                  🔥 Öne Çıkan Başarımlar
                </h4>
                <div className="space-y-2">
                  {[
                    { icon: "⚔️", label: "İlk Zafer", desc: "İlk zindanı tamamla", done: true },
                    { icon: "📜", label: "Görev Ustası", desc: "10 görev tamamla", done: false },
                    { icon: "💰", label: "Altın Biriktirici", desc: "10.000 altın biriktir", done: false },
                    { icon: "🧙", label: "Efsanevi Kahraman", desc: "Seviye 25'e ulaş", done: false },
                    { icon: "🗺️", label: "Kaşif", desc: "Tüm bölgeleri ziyaret et", done: false },
                    { icon: "🏰", label: "Zindan Fatihi", desc: "5 farklı zindan tamamla", done: false },
                  ].map((ach) => (
                    <div
                      key={ach.label}
                      className={`flex items-center gap-3 px-3 py-2 rounded-lg ${
                        ach.done
                          ? "bg-[var(--color-success)]/10 border border-[var(--color-success)]/20"
                          : "bg-[var(--bg-input)]"
                      }`}
                    >
                      <span className="text-lg">{ach.icon}</span>
                      <div className="flex-1">
                        <p
                          className={`text-xs font-semibold ${
                            ach.done ? "text-[var(--color-success)]" : "text-[var(--text-primary)]"
                          }`}
                        >
                          {ach.label}
                          {ach.done && " ✓"}
                        </p>
                        <p className="text-[10px] text-[var(--text-muted)]">{ach.desc}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Bottom CTA — "Karakteri Güçlendir" */}
      <div className="pt-2">
        <Button
          variant="primary"
          size="md"
          fullWidth
          onClick={() => {
            addToast("Güçlendirme sistemi yakında!", "info");
            router.push("/enhancement");
          }}
        >
          ⚡ Karakteri Güçlendir
        </Button>
      </div>
    </motion.div>
  );
}
