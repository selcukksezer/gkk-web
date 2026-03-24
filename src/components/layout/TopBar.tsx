// ============================================================
// TopBar — Floating Glassmorphism MMORPG Header
// Player info, Resources, categorised drawer navigation
// ============================================================

"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import {
  Menu, X, Zap, CircleDollarSign, Gem,
  User, Wand2, ListTodo, Castle, HeartPulse, Lock,
  Target, Store, Building2, Hammer, Flame, Factory,
  ShoppingBag, Landmark, Trophy, Star, Award,
  CalendarDays, TrendingUp, ArrowLeftRight,
  Swords, Settings2, LogOut, ChevronRight,
  Map, Shield, ShoppingCart
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { usePlayerStore } from "@/stores/playerStore";
import { useAuthStore } from "@/stores/authStore";
import { formatCompact } from "@/lib/utils/string";
import { xpProgress } from "@/lib/utils/math";
import { supabase } from "@/lib/supabase";

// ─── Types ────────────────────────────────────────────────
type MenuItem = {
  path: string;
  label: string;
  icon: LucideIcon;
};

type MenuSection = {
  title: string;
  items: MenuItem[];
};

// ─── Drawer menu sections ─────────────────────────────────
const MENU_SECTIONS: MenuSection[] = [
  {
    title: "Karakter",
    items: [
      { path: "/profile",      label: "Profil",        icon: User           },
      { path: "/character",    label: "Karakter",       icon: Wand2          },
      { path: "/quests",       label: "Görevler",       icon: ListTodo       },
      { path: "/achievements", label: "Başarımlar",     icon: Award          },
      { path: "/season",       label: "Sezon",          icon: Star           },
      { path: "/reputation",   label: "İtibar",         icon: TrendingUp     },
      { path: "/events",       label: "Etkinlikler",    icon: CalendarDays   },
    ],
  },
  {
    title: "Savaş",
    items: [
      { path: "/dungeon",      label: "Zindan",         icon: Castle         },
      { path: "/pvp",          label: "PvP Arena",      icon: Target         },
      { path: "/guild-war",    label: "Lonca Savaşı",   icon: Swords         },
    ],
  },
  {
    title: "Ekonomi",
    items: [
      { path: "/shop",         label: "Mağaza",         icon: ShoppingBag    },
      { path: "/market",       label: "Pazar",          icon: ShoppingCart   },
      { path: "/bank",         label: "Banka",          icon: Landmark       },
      { path: "/trade",        label: "Ticaret",        icon: ArrowLeftRight },
    ],
  },
  {
    title: "Zanaat",
    items: [
      { path: "/crafting",     label: "Zanaat",         icon: Hammer         },
      { path: "/enhancement",  label: "Güçlendirme",    icon: Flame          },
      { path: "/facilities",   label: "Tesisler",       icon: Factory        },
    ],
  },
  {
    title: "Dünya",
    items: [
      { path: "/map",          label: "Harita",         icon: Map            },
      { path: "/mekans",       label: "Mekanlar",       icon: Store          },
      { path: "/my-mekan",     label: "Benim Mekanım",  icon: Building2      },
      { path: "/guild",        label: "Lonca",          icon: Shield         },
      { path: "/leaderboard",  label: "Sıralama",       icon: Trophy         },
    ],
  },
  {
    title: "Diğer",
    items: [
      { path: "/hospital",     label: "Hastane",        icon: HeartPulse     },
      { path: "/prison",       label: "Cezaevi",        icon: Lock           },
      { path: "/settings",     label: "Ayarlar",        icon: Settings2      },
    ],
  },
];

// ─── Component ────────────────────────────────────────────
export function TopBar() {
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(false);
  const onlineStatusDisabledRef = useRef(false);

  const player    = usePlayerStore((s) => s.player);
  const energy    = usePlayerStore((s) => s.energy);
  const maxEnergy = usePlayerStore((s) => s.maxEnergy);
  const gold      = usePlayerStore((s) => s.gold);
  const gems      = usePlayerStore((s) => s.gems);
  const level     = usePlayerStore((s) => s.level);
  const xp        = usePlayerStore((s) => s.xp);
  const logout    = useAuthStore((s) => s.logout);
  const progress  = xpProgress(xp, level);

  const displayName = player?.display_name || player?.username || "Oyuncu";

  const updateOnlineStatus = useCallback(async (isOnline: boolean) => {
    if (!player || onlineStatusDisabledRef.current) return;

    const { error } = await supabase.rpc("set_online_status", { p_is_online: isOnline });
    if (!error) return;

    const message = String(error.message ?? "");
    if (
      message.toLowerCase().includes("set_online_status") ||
      message.toLowerCase().includes("does not exist") ||
      String(error.code ?? "").toUpperCase() === "PGRST202"
    ) {
      onlineStatusDisabledRef.current = true;
    }

    console.warn("[TopBar] set_online_status RPC çağrısı başarısız:", message);
  }, [player]);

  // Online status tracking (Godot: online_status.gd)
  useEffect(() => {
    if (!player) return;
    void updateOnlineStatus(true);

    const handleBeforeUnload = () =>
      void updateOnlineStatus(false);

    const handleVisibilityChange = () => {
      const online = document.visibilityState === "visible";
      void updateOnlineStatus(online);
    };

    window.addEventListener("beforeunload", handleBeforeUnload);
    document.addEventListener("visibilitychange", handleVisibilityChange);

    return () => {
      window.removeEventListener("beforeunload", handleBeforeUnload);
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      void updateOnlineStatus(false);
    };
  }, [player, updateOnlineStatus]);

  const handleNav = useCallback((path: string) => {
    setMenuOpen(false);
    router.push(path);
  }, [router]);

  const handleLogout = useCallback(async () => {
    setMenuOpen(false);
    await logout();
    router.replace("/login");
  }, [logout, router]);

  return (
    <>
      {/* ── Sticky Header ─────────────────────────────────── */}
      <header
        className="sticky top-0 z-40"
        style={{ paddingTop: "env(safe-area-inset-top, 0px)" }}
      >
        <div className="px-3 py-2">
          <motion.div
            className="flex items-center gap-2 h-12 px-3 rounded-2xl overflow-hidden"
            initial={{ y: -56, opacity: 0 }}
            animate={{ y: 0,   opacity: 1 }}
            transition={{ type: "spring", stiffness: 240, damping: 26, delay: 0.06 }}
            style={{
              background:           "rgba(7, 9, 20, 0.80)",
              backdropFilter:       "blur(12px)",
              WebkitBackdropFilter: "blur(12px)",
              border:               "0.5px solid rgba(82, 150, 255, 0.36)",
              boxShadow: [
                "0 8px 32px rgba(0, 0, 0, 0.55)",
                "0 1px 0 rgba(100, 170, 255, 0.10) inset",
                "0 -1px 0 rgba(0, 0, 0, 0.30) inset",
              ].join(", "),
            }}
          >
            {/* Menu button */}
            <motion.button
              aria-label="Menüyü aç"
              onClick={() => setMenuOpen(true)}
              whileTap={{ scale: 0.86 }}
              className="flex items-center justify-center w-8 h-8 rounded-xl flex-shrink-0"
              style={{ color: "rgba(100, 155, 255, 0.80)" }}
            >
              <Menu size={18} strokeWidth={2} />
            </motion.button>

            {/* Level badge */}
            <div
              className="flex items-center justify-center w-7 h-7 rounded-full flex-shrink-0 text-[11px] font-black"
              style={{
                background: "linear-gradient(135deg, rgba(90,50,220,0.90) 0%, rgba(60,90,255,0.80) 100%)",
                boxShadow:  "0 0 10px rgba(80,100,255,0.50), inset 0 1px 0 rgba(255,255,255,0.15)",
                color:      "rgba(200, 220, 255, 1)",
              }}
            >
              {level}
            </div>

            {/* Name + XP bar */}
            <div className="flex flex-col justify-center flex-1 min-w-0 gap-[4px]">
              <span
                className="text-[11px] font-semibold truncate leading-none"
                style={{ color: "rgba(185, 210, 255, 0.88)" }}
              >
                {displayName}
              </span>
              <div
                className="h-[2px] rounded-full overflow-hidden"
                style={{ background: "rgba(50, 75, 140, 0.35)" }}
              >
                <motion.div
                  className="h-full rounded-full"
                  style={{
                    background: "linear-gradient(90deg, rgba(70,130,255,0.90), rgba(140,100,255,0.80))",
                    boxShadow:  "0 0 6px rgba(100,160,255,0.55)",
                  }}
                  initial={{ width: 0 }}
                  animate={{ width: `${Math.min(progress * 100, 100)}%` }}
                  transition={{ duration: 0.8, ease: "easeOut" }}
                />
              </div>
            </div>

            {/* Resources */}
            <div className="flex items-center gap-[10px] flex-shrink-0">
              <ResourceChip
                icon={Zap}
                value={`${energy}/${maxEnergy}`}
                iconColor="rgba(0, 215, 215, 0.90)"
                glowColor="rgba(0, 190, 190, 0.40)"
              />
              <ResourceChip
                icon={CircleDollarSign}
                value={formatCompact(gold)}
                iconColor="rgba(220, 178, 0, 0.90)"
                glowColor="rgba(200, 155, 0, 0.35)"
              />
              <ResourceChip
                icon={Gem}
                value={formatCompact(gems)}
                iconColor="rgba(195, 75, 255, 0.90)"
                glowColor="rgba(175, 55, 255, 0.35)"
              />
            </div>
          </motion.div>
        </div>
      </header>

      {/* ── Drawer + overlay ──────────────────────────────── */}
      <AnimatePresence>
        {menuOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              key="backdrop"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.22 }}
              className="fixed inset-0 z-50"
              style={{ background: "rgba(2, 4, 14, 0.68)", backdropFilter: "blur(2px)" }}
              onClick={() => setMenuOpen(false)}
            />

            {/* Drawer panel */}
            <motion.aside
              key="drawer"
              aria-label="Navigasyon menüsü"
              initial={{ x: "-100%" }}
              animate={{ x: 0 }}
              exit={{ x: "-100%" }}
              transition={{ type: "spring", stiffness: 300, damping: 28 }}
              className="fixed left-0 top-0 bottom-0 z-50 w-[270px] flex flex-col overflow-hidden"
              style={{
                background:           "rgba(6, 8, 22, 0.94)",
                backdropFilter:       "blur(16px)",
                WebkitBackdropFilter: "blur(16px)",
                borderRight:          "0.5px solid rgba(70, 130, 255, 0.26)",
                boxShadow:            "10px 0 44px rgba(0, 0, 0, 0.72)",
                paddingTop:           "env(safe-area-inset-top, 0px)",
              }}
            >
              {/* Drawer header */}
              <div
                className="flex items-center justify-between px-4 py-4 flex-shrink-0"
                style={{ borderBottom: "0.5px solid rgba(50, 80, 160, 0.22)" }}
              >
                <div className="flex items-center gap-3">
                  {/* Avatar */}
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center text-[13px] font-black flex-shrink-0"
                    style={{
                      background: "linear-gradient(135deg, rgba(90,50,220,0.85) 0%, rgba(50,90,255,0.75) 100%)",
                      boxShadow:  "0 0 14px rgba(80,100,255,0.44), inset 0 1px 0 rgba(255,255,255,0.12)",
                      color:      "rgba(200, 220, 255, 1)",
                    }}
                  >
                    {level}
                  </div>
                  <div>
                    <p
                      className="text-[13px] font-bold leading-none mb-[5px]"
                      style={{ color: "rgba(185, 210, 255, 0.95)" }}
                    >
                      {displayName}
                    </p>
                    <p
                      className="text-[10px] font-medium"
                      style={{ color: "rgba(70, 108, 175, 0.75)" }}
                    >
                      Seviye {level}
                    </p>
                  </div>
                </div>

                <motion.button
                  aria-label="Menüyü kapat"
                  onClick={() => setMenuOpen(false)}
                  whileTap={{ scale: 0.86 }}
                  className="w-8 h-8 flex items-center justify-center rounded-xl flex-shrink-0"
                  style={{ color: "rgba(70, 110, 190, 0.60)" }}
                >
                  <X size={17} strokeWidth={2} />
                </motion.button>
              </div>

              {/* Scrollable menu */}
              <nav className="flex-1 overflow-y-auto px-2 py-3 space-y-3">
                {MENU_SECTIONS.map((section) => (
                  <div key={section.title}>
                    <p
                      className="px-3 mb-1 text-[9px] font-black uppercase tracking-[0.15em]"
                      style={{ color: "rgba(50, 88, 160, 0.60)" }}
                    >
                      {section.title}
                    </p>
                    <div className="space-y-[1px]">
                      {section.items.map((item) => (
                        <DrawerItem
                          key={item.path}
                          item={item}
                          onPress={() => handleNav(item.path)}
                        />
                      ))}
                    </div>
                  </div>
                ))}
              </nav>

              {/* Logout */}
              <div
                className="px-2 pb-4 pt-2 flex-shrink-0"
                style={{ borderTop: "0.5px solid rgba(50, 80, 160, 0.18)" }}
              >
                <motion.button
                  onClick={handleLogout}
                  whileHover={{ backgroundColor: "rgba(200, 40, 40, 0.08)" }}
                  whileTap={{ scale: 0.97 }}
                  className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-left"
                  style={{ color: "rgba(240, 70, 70, 0.72)" }}
                >
                  <LogOut size={15} strokeWidth={1.8} />
                  <span className="text-[12.5px] font-medium">Çıkış Yap</span>
                </motion.button>
              </div>
            </motion.aside>
          </>
        )}
      </AnimatePresence>
    </>
  );
}

// ─── ResourceChip — icon + value pair ─────────────────────
function ResourceChip({
  icon: Icon,
  value,
  iconColor,
  glowColor,
}: {
  icon: LucideIcon;
  value: string;
  iconColor: string;
  glowColor: string;
}) {
  return (
    <div className="flex items-center gap-[3px]">
      <Icon
        size={11}
        strokeWidth={2.2}
        style={{
          color:      iconColor,
          filter:     `drop-shadow(0 0 4px ${glowColor})`,
          flexShrink: 0,
        }}
      />
      <span
        className="text-[10px] font-bold tabular-nums leading-none"
        style={{ color: "rgba(155, 190, 255, 0.78)" }}
      >
        {value}
      </span>
    </div>
  );
}

// ─── DrawerItem — single nav button ───────────────────────
function DrawerItem({
  item,
  onPress,
}: {
  item: MenuItem;
  onPress: () => void;
}) {
  const Icon = item.icon;
  return (
    <motion.button
      onClick={onPress}
      whileHover={{ x: 4, backgroundColor: "rgba(55, 100, 210, 0.09)" }}
      whileTap={{ scale: 0.97 }}
      transition={{ type: "spring", stiffness: 400, damping: 24 }}
      className="w-full flex items-center gap-3 px-3 py-[9px] rounded-xl text-left"
    >
      <Icon
        size={14}
        strokeWidth={1.7}
        style={{ color: "rgba(78, 128, 220, 0.68)", flexShrink: 0 }}
      />
      <span
        className="text-[12px] font-medium flex-1"
        style={{ color: "rgba(135, 168, 235, 0.80)" }}
      >
        {item.label}
      </span>
      <ChevronRight
        size={10}
        strokeWidth={2}
        style={{ color: "rgba(55, 90, 180, 0.30)", flexShrink: 0 }}
      />
    </motion.button>
  );
}
