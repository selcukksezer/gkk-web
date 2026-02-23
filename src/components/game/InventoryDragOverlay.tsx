// ============================================================
// InventoryDragOverlay — Floating dragged item with visual polish
// Shows title, shadow, glow, tilt, and scale during drag
// ============================================================

"use client";

import { DragOverlay } from "@dnd-kit/core";
import { motion } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";

const RARITY_COLORS: Record<string, string> = {
  common: "#6b7280",
  uncommon: "#22c55e",
  rare: "#3b82f6",
  epic: "#a855f7",
  legendary: "#f59e0b",
  mythic: "#ff006e",
};

interface InventoryDragOverlayProps {
  activeItem: InventoryItem | null;
  isDragging: boolean;
}

export function InventoryDragOverlay({ activeItem, isDragging }: InventoryDragOverlayProps) {
  if (!activeItem) return null;

  const rarityColor = RARITY_COLORS[activeItem.rarity] || RARITY_COLORS.common;
  const typeEmoji: Record<string, string> = {
    weapon: "⚔️",
    armor: "🛡️",
    accessory: "💍",
    potion: "🧪",
    food: "🍖",
    quest: "📜",
    material: "⚙️",
    misc: "📦",
  };

  return (
    <DragOverlay dropAnimation={null}>
      {isDragging && (
        <motion.div
          initial={{ scale: 1, rotateX: 0, rotateZ: 0, opacity: 1 }}
          animate={{
            scale: 1.15,
            rotateX: -8,
            rotateZ: 5,
            opacity: 0.95,
          }}
          transition={{ duration: 0.2 }}
          className="relative w-20 h-20 flex items-center justify-center"
          style={{
            perspective: "1200px",
            pointerEvents: "none",
          }}
        >
          {/* Item Card with Shadow & Glow */}
          <div
            className="relative w-full h-full rounded-lg border-2 flex flex-col items-center justify-center bg-[var(--bg-card)]/90 backdrop-blur-sm"
            style={{
              borderColor: rarityColor,
              boxShadow: `
                0 25px 50px -12px ${rarityColor}40,
                0 0 30px ${rarityColor}60 inset,
                0 0 20px ${rarityColor}80
              `,
              transform: "translateZ(50px)",
              pointerEvents: "none",
            }}
          >
            {/* Glow effect background */}
            <div
              className="absolute inset-0 rounded-lg opacity-30 blur-xl"
              style={{
                background: `radial-gradient(circle, ${rarityColor}80, transparent)`,
              }}
            />

            {/* Type emoji */}
            <motion.span
              className="relative z-10 text-2xl leading-none"
              animate={{ scale: [1, 1.1, 1] }}
              transition={{ duration: 0.6, repeat: Infinity }}
            >
              {typeEmoji[activeItem.item_type] || "❓"}
            </motion.span>

            {/* Enhancement level */}
            {activeItem.enhancement_level > 0 && (
              <motion.span
                className="absolute top-1 right-1 text-[10px] font-bold text-[var(--accent-light)] z-20"
                animate={{ scale: [1, 1.2, 1] }}
                transition={{ duration: 0.4, repeat: Infinity, delay: 0.1 }}
              >
                +{activeItem.enhancement_level}
              </motion.span>
            )}

            {/* Quantity */}
            {activeItem.quantity > 1 && (
              <motion.span
                className="absolute bottom-1 right-1 text-[9px] font-bold bg-black/80 text-white px-1.5 rounded z-20"
                animate={{ scale: [1, 1.15, 1] }}
                transition={{ duration: 0.4, repeat: Infinity, delay: 0.2 }}
              >
                {activeItem.quantity}x
              </motion.span>
            )}
          </div>

          {/* Title below the card */}
          <motion.p
            className="absolute -bottom-8 left-1/2 -translate-x-1/2 text-xs font-bold text-white whitespace-nowrap px-2 py-1 bg-black/70 rounded backdrop-blur-sm"
            initial={{ opacity: 0, y: -5 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1, duration: 0.2 }}
          >
            {activeItem.name}
          </motion.p>

          {/* Particle trail effect */}
          <motion.div
            className="absolute inset-0 rounded-lg pointer-events-none"
            animate={{
              boxShadow: [
                `0 0 20px ${rarityColor}60, 0 0 40px ${rarityColor}40`,
                `0 0 30px ${rarityColor}80, 0 0 60px ${rarityColor}60`,
                `0 0 20px ${rarityColor}60, 0 0 40px ${rarityColor}40`,
              ],
            }}
            transition={{ duration: 1.5, repeat: Infinity }}
          />
        </motion.div>
      )}
    </DragOverlay>
  );
}
