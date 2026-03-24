// ============================================================
// BottomNav — Floating Glassmorphism MMORPG Navigation Bar
// React + Framer Motion + Lucide React
// ============================================================

"use client";

import { usePathname, useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { Home, Package, Swords, Zap, User } from "lucide-react";
import type { LucideIcon } from "lucide-react";

// ─── Types ────────────────────────────────────────────────
type NavItem = {
  path: string;
  label: string;
  icon: LucideIcon;
};

// ─── Navigation Items ─────────────────────────────────────
const NAV_ITEMS: NavItem[] = [
  { path: "/home",      label: "Home",      icon: Home    },
  { path: "/inventory", label: "Inventory", icon: Package },
  { path: "/dungeon",   label: "Dungeon",   icon: Swords  },
  { path: "/character", label: "Skills",    icon: Zap     },
  { path: "/profile",   label: "Profile",   icon: User    },
];

// ─── Shared spring config ─────────────────────────────────
const ACTIVE_SPRING = { type: "spring" as const, stiffness: 300, damping: 30 };
const HOVER_SPRING  = { type: "spring" as const, stiffness: 420, damping: 22 };

// ─── Component ────────────────────────────────────────────
export function BottomNav() {
  const pathname = usePathname();
  const router   = useRouter();

  return (
    <nav
      aria-label="Main navigation"
      className="fixed z-50 left-1/2 -translate-x-1/2 pointer-events-none"
      style={{ bottom: "calc(env(safe-area-inset-bottom, 0px) + 20px)" }}
    >
      {/* ── Floating Bar ─────────────────────────────────── */}
      <motion.div
        role="list"
        className="pointer-events-auto relative flex items-center gap-0.5 px-2 py-2 rounded-3xl"
        initial={{ y: 80, opacity: 0 }}
        animate={{ y: 0,  opacity: 1 }}
        transition={{ type: "spring", stiffness: 240, damping: 26, delay: 0.12 }}
        style={{
          background:          "rgba(7, 9, 20, 0.74)",
          backdropFilter:      "blur(12px)",
          WebkitBackdropFilter:"blur(12px)",
          border:              "0.5px solid rgba(82, 150, 255, 0.36)",
          boxShadow: [
            "0 8px 32px rgba(0, 0, 0, 0.55)",
            "0 1px 0   rgba(100, 170, 255, 0.10) inset",
            "0 -1px 0  rgba(0, 0, 0, 0.30) inset",
            "0 0 60px  rgba(60, 110, 255, 0.06)",
          ].join(", "),
        }}
      >
        {NAV_ITEMS.map((item) => {
          const isActive =
            pathname === item.path ||
            (item.path !== "/home" && pathname?.startsWith(item.path));

          return (
            <NavButton
              key={item.path}
              item={item}
              isActive={isActive}
              onPress={() => router.push(item.path)}
            />
          );
        })}
      </motion.div>
    </nav>
  );
}

// ─── NavButton sub-component ──────────────────────────────
function NavButton({
  item,
  isActive,
  onPress,
}: {
  item: NavItem;
  isActive: boolean;
  onPress: () => void;
}) {
  const Icon = item.icon;

  return (
    <motion.button
      role="listitem"
      aria-label={item.label}
      aria-current={isActive ? "page" : undefined}
      onClick={onPress}
      className="relative flex flex-col items-center justify-center gap-[3px] w-[62px] h-[60px] rounded-2xl select-none outline-none focus-visible:ring-2 focus-visible:ring-blue-400/60"
      whileHover="hover"
      whileTap={{ scale: 0.88, transition: { duration: 0.1 } }}
    >
      {/* ── Active glow background ───────────────────────── */}
      <AnimatePresence>
        {isActive && (
          <motion.div
            layoutId="nav-glow-bg"
            aria-hidden="true"
            className="absolute inset-0 rounded-2xl"
            initial={{ opacity: 0, scale: 0.75 }}
            animate={{ opacity: 1, scale: 1 }}
            exit  ={{ opacity: 0, scale: 0.75 }}
            transition={ACTIVE_SPRING}
            style={{
              background: "radial-gradient(ellipse 85% 75% at 50% 65%, rgba(72, 148, 255, 0.20) 0%, transparent 78%)",
              boxShadow:  "inset 0 0 14px rgba(60, 128, 255, 0.09)",
            }}
          />
        )}
      </AnimatePresence>

      {/* ── Floating indicator dot ───────────────────────── */}
      <AnimatePresence>
        {isActive && (
          <motion.span
            layoutId="nav-indicator-dot"
            aria-hidden="true"
            className="absolute rounded-full"
            style={{
              top:        6,
              width:      5,
              height:     5,
              background: "rgb(152, 208, 255)",
              boxShadow:  "0 0 7px 1px rgba(110, 180, 255, 0.95), 0 0 16px rgba(80, 148, 255, 0.55)",
            }}
            initial={{ scale: 0, opacity: 0, y: -3 }}
            animate={{ scale: 1, opacity: 1, y: 0  }}
            exit  ={{ scale: 0, opacity: 0, y: -3  }}
            transition={ACTIVE_SPRING}
          />
        )}
      </AnimatePresence>

      {/* ── Icon ─────────────────────────────────────────── */}
      <motion.div
        aria-hidden="true"
        className="relative z-10 mt-0.5"
        variants={{
          hover: {
            y:      -5,
            filter: "brightness(1.55) drop-shadow(0 0 7px rgba(110,185,255,0.75))",
          },
        }}
        transition={HOVER_SPRING}
      >
        <Icon
          size={22}
          strokeWidth={isActive ? 2.2 : 1.65}
          style={{
            color: isActive
              ? "rgba(168, 214, 255, 1)"
              : "rgba(85, 112, 162, 0.88)",
            filter: isActive
              ? "drop-shadow(0 0 5px rgba(100, 175, 255, 0.72)) drop-shadow(0 0 11px rgba(70, 135, 255, 0.38))"
              : undefined,
            transition: "color 0.22s ease, filter 0.22s ease",
          }}
        />
      </motion.div>

      {/* ── Label ────────────────────────────────────────── */}
      <span
        className="relative z-10 text-[8.5px] font-bold uppercase"
        style={{
          color: isActive
            ? "rgba(168, 214, 255, 0.82)"
            : "rgba(75, 100, 150, 0.72)",
          letterSpacing: "0.09em",
          transition: "color 0.22s ease",
        }}
      >
        {item.label}
      </span>
    </motion.button>
  );
}
