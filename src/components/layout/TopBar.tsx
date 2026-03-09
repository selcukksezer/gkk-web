// ============================================================
// TopBar — Kaynak: scenes/ui/TopBar.gd
// Player name, Level, Gold, Gems, Energy, hamburger menu
// ============================================================

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useAuthStore } from "@/stores/authStore";
import { formatCompact } from "@/lib/utils/string";
import { xpProgress } from "@/lib/utils/math";

const MENU_ITEMS = [
  { path: "/profile", label: "Profil", icon: "👤" },
  { path: "/character", label: "Karakter", icon: "🧙" },
  /* equipment removed */
  { path: "/quests", label: "Görevler", icon: "📜" },
  { path: "/dungeon", label: "Zindan", icon: "🏰" },
  { path: "/hospital", label: "Hastane", icon: "🏥" },
  { path: "/prison", label: "Cezaevi", icon: "🚓" },
  { path: "/pvp", label: "PvP Arena", icon: "⚔️" },
  { path: "/mekans", label: "Mekanlar", icon: "🏪" },
  { path: "/my-mekan", label: "Benim Mekanım", icon: "🏬" },
  { path: "/crafting", label: "Zanaat", icon: "🔨" },
  { path: "/enhancement", label: "Güçlendirme", icon: "🔥" },
  { path: "/facilities", label: "Tesisler", icon: "🏭" },
  { path: "/shop", label: "Mağaza", icon: "🛒" },
  { path: "/bank", label: "Banka", icon: "🏦" },
  /* warehouse removed */
  { path: "/leaderboard", label: "Sıralama", icon: "🏆" },
  { path: "/season", label: "Sezon", icon: "🌟" },
  { path: "/achievements", label: "Başarımlar", icon: "🏅" },
  { path: "/events", label: "Etkinlikler", icon: "🎉" },
  { path: "/reputation", label: "İtibar", icon: "📊" },
  { path: "/chat", label: "Sohbet", icon: "💬" },
  { path: "/trade", label: "Ticaret", icon: "🤝" },
  { path: "/guild-war", label: "Lonca Savaşı", icon: "🏴" },
  { path: "/settings", label: "Ayarlar", icon: "⚙️" },
];

export function TopBar() {
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const player = usePlayerStore((s) => s.player);
  const energy = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const gold = usePlayerStore((s) => s.gold);
  const gems = usePlayerStore((s) => s.gems);
  const level = usePlayerStore((s) => s.level);
  const xp = usePlayerStore((s) => s.xp);
  const logout = useAuthStore((s) => s.logout);
  const progress = xpProgress(xp, level);

  const handleNav = (path: string) => {
    setMenuOpen(false);
    router.push(path);
  };

  const handleLogout = async () => {
    setMenuOpen(false);
    await logout();
    router.replace("/login");
  };

  return (
    <>
      <header
        className="sticky top-0 z-40 border-b border-[var(--border-default)] bg-[var(--bg-darker)]/95 backdrop-blur-md"
        style={{ paddingTop: "env(safe-area-inset-top)" }}
      >
        <div className="flex items-center justify-between h-12 px-3 max-w-lg mx-auto">
          {/* Hamburger menu */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="w-8 h-8 flex items-center justify-center rounded-lg text-[var(--text-primary)] hover:bg-[var(--bg-input)]"
          >
            <span className="text-lg">{menuOpen ? "✕" : "☰"}</span>
          </button>

          {/* Player name + Level */}
          <div className="flex items-center gap-2">
            <div className="flex items-center justify-center w-7 h-7 rounded-full bg-[var(--accent)] text-white text-[10px] font-bold">
              {level}
            </div>
            <span className="text-xs font-medium text-[var(--text-primary)] max-w-[80px] truncate">
              {player?.display_name || player?.username || "Oyuncu"}
            </span>
            <div className="w-12 h-1.5 rounded-full bg-[var(--bg-input)] overflow-hidden">
              <div
                className="h-full rounded-full bg-[var(--accent-light)] transition-all duration-300"
                style={{ width: `${progress * 100}%` }}
              />
            </div>
          </div>

          {/* Resources */}
          <div className="flex items-center gap-2 text-[10px] font-medium">
            <span className="text-energy">⚡{energy}/{maxEnergy}</span>
            <span className="text-gold">🪙{formatCompact(gold)}</span>
            <span className="text-gems">💎{formatCompact(gems)}</span>
          </div>
        </div>
      </header>

      {/* Full-screen menu overlay */}
      <AnimatePresence>
        {menuOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/60"
              onClick={() => setMenuOpen(false)}
            />
            <motion.div
              initial={{ x: "-100%" }}
              animate={{ x: 0 }}
              exit={{ x: "-100%" }}
              transition={{ type: "spring", damping: 25, stiffness: 300 }}
              className="fixed left-0 top-0 bottom-0 z-50 w-64 bg-[var(--bg-darker)] border-r border-[var(--border-default)] overflow-y-auto"
              style={{ paddingTop: "env(safe-area-inset-top)" }}
            >
              {/* Menu header */}
              <div className="p-4 border-b border-[var(--border-default)]">
                <p className="font-bold text-[var(--text-primary)]">
                  {player?.display_name || player?.username || "Oyuncu"}
                </p>
                <p className="text-xs text-[var(--text-muted)]">Seviye {level}</p>
              </div>

              {/* Menu items grid */}
              <div className="p-2 space-y-0.5">
                {MENU_ITEMS.map((item) => (
                  <button
                    key={item.path}
                    onClick={() => handleNav(item.path)}
                    className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left text-sm text-[var(--text-secondary)] hover:bg-[var(--bg-input)] hover:text-[var(--text-primary)] transition-colors"
                  >
                    <span className="text-base">{item.icon}</span>
                    <span>{item.label}</span>
                  </button>
                ))}
              </div>

              {/* Logout */}
              <div className="p-3 border-t border-[var(--border-default)]">
                <button
                  onClick={handleLogout}
                  className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left text-sm text-red-400 hover:bg-red-500/10 transition-colors"
                >
                  <span className="text-base">🚪</span>
                  <span>Çıkış Yap</span>
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}
