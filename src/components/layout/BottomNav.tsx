// ============================================================
// BottomNav — Godot aynısı: Home, Map, Inventory, Market, Guild
// Kaynak: scenes/ui/components/BottomNav.gd
// ============================================================

"use client";

import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { cn } from "@/lib/utils/cn";

const NAV_ITEMS = [
  { path: "/home", label: "Ana Sayfa", icon: "🏠" },
  { path: "/map", label: "Harita", icon: "🗺️" },
  { path: "/inventory", label: "Envanter", icon: "🎒" },
  { path: "/market", label: "Pazar", icon: "🏪" },
  { path: "/guild", label: "Lonca", icon: "⚔️" },
];

export function BottomNav() {
  const pathname = usePathname();
  const router = useRouter();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t border-[var(--border-default)] bg-[var(--bg-darker)]/95 backdrop-blur-md"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
    >
      <div className="flex items-center justify-around h-16 max-w-lg mx-auto">
        {NAV_ITEMS.map((item) => {
          const isActive =
            pathname === item.path ||
            (item.path !== "/home" && pathname?.startsWith(item.path));

          return (
            <button
              key={item.path}
              onClick={() => router.push(item.path)}
              className={cn(
                "relative flex flex-col items-center justify-center gap-0.5 w-full h-full transition-colors",
                isActive ? "text-[var(--accent-light)]" : "text-[var(--text-muted)]"
              )}
            >
              {isActive && (
                <motion.div
                  layoutId="nav-indicator"
                  className="absolute -top-[1px] left-3 right-3 h-[2px] bg-[var(--accent)] rounded-full"
                  transition={{ type: "spring", duration: 0.35, bounce: 0.2 }}
                />
              )}
              <span className="text-xl">{item.icon}</span>
              <span className="text-[10px] font-medium">{item.label}</span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}
