// ============================================================
// RecipeTabsBar Component — Tarif Kategorileri (7 Tab)
// Tümü + 6 tip: Silah, Zırh, İksir, Rün, Scroll, Aksesuar
// ============================================================

"use client";

import { motion } from "framer-motion";

interface RecipeTabsBarProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  counts: Record<string, number>;
}

const TABS = [
  { key: "tumu", label: "Tümü" },
  { key: "weapon", label: "⚔ Silah" },
  { key: "armor", label: "🛡 Zırh" },
  { key: "potion", label: "🧪 İksir" },
  { key: "rune", label: "🔮 Rün" },
  { key: "scroll", label: "📜 Scroll" },
  { key: "accessory", label: "💍 Aksesuar" },
];

export function RecipeTabsBar({ activeTab, onTabChange, counts }: RecipeTabsBarProps) {
  return (
    <div
      className="flex gap-2 overflow-x-auto overflow-y-hidden no-scrollbar pb-2 -mx-4 px-4 snap-x snap-mandatory scroll-smooth md:overflow-visible md:flex-wrap md:pb-0 md:-mx-0 md:px-0"
      style={{ touchAction: "pan-x" }}
    >
      {TABS.map((tab) => (
        <motion.button
          key={tab.key}
          onClick={() => onTabChange(tab.key)}
          whileTap={{ scale: 0.95 }}
          className={`flex-shrink-0 px-4 py-2 rounded-lg font-medium text-sm transition-all duration-200 whitespace-nowrap snap-center ${
            activeTab === tab.key
              ? "bg-gradient-to-r from-blue-600 to-purple-600 text-white shadow-lg shadow-blue-500/50"
              : "bg-white/10 text-white/70 hover:bg-white/20 hover:text-white border border-white/20"
          }`}
        >
          {tab.label}
          {counts[tab.key] && (
            <span className={`ml-2 text-xs font-bold ${activeTab === tab.key ? "text-blue-100" : "text-white/50"}`}>
              ({counts[tab.key]})
            </span>
          )}
        </motion.button>
      ))}
    </div>
  );
}
