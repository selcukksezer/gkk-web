// ============================================================
// InventoryDialogs — Sell, Split Stack, Delete dialogs
// ============================================================

"use client";

import { motion, AnimatePresence } from "framer-motion";
import type { InventoryItem } from "@/types/inventory";
import { cn } from "@/lib/utils/cn";
import { useEffect, useState } from "react";

// ============================================================
// Sell Dialog
// ============================================================

interface SellDialogProps {
  item: InventoryItem | null;
  onConfirm: (quantity: number) => Promise<void>;
  onCancel: () => void;
}

export function SellDialog({ item, onConfirm, onCancel }: SellDialogProps) {
  const [quantity, setQuantity] = useState(1);
  const [isLoading, setIsLoading] = useState(false);

  if (!item) return null;

  const maxQuantity = item.is_stackable ? item.quantity : 1;
  const totalPrice = item.vendor_sell_price * quantity;

  const handleConfirm = async () => {
    setIsLoading(true);
    try {
      await onConfirm(quantity);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
        onClick={onCancel}
      >
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          onClick={(e) => e.stopPropagation()}
          className="bg-[var(--bg-card)] rounded-lg p-6 w-96 border border-[var(--border-default)]"
        >
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-bold">Eşya Sat</h2>
            <button onClick={onCancel} className="p-1 hover:bg-[var(--bg-darker)] rounded text-xl">
              ✕
            </button>
          </div>

          <p className="text-sm text-[var(--text-muted)] mb-4">
            {item.name}'yi kaç adet satmak istiyorsunuz?
          </p>

          <div className="space-y-4">
            {/* Quantity Slider */}
            <div className="space-y-2">
              <label className="text-sm font-medium">Miktar: {quantity}</label>
              <input
                type="range"
                min="1"
                max={maxQuantity}
                value={quantity}
                onChange={(e) => setQuantity(parseInt(e.target.value))}
                className="w-full"
              />
            </div>

            {/* Total Price */}
            <div className="bg-[var(--bg-darker)] p-3 rounded space-y-1">
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-muted)]">Birim Fiyat:</span>
                <span className="text-yellow-400">{item.vendor_sell_price} ⚔</span>
              </div>
              <div className="flex justify-between text-lg font-bold">
                <span>Toplam:</span>
                <span className="text-green-400">{totalPrice} ⚔</span>
              </div>
            </div>

            {/* Buttons */}
            <div className="flex gap-3">
              <button
                onClick={onCancel}
                className="flex-1 px-4 py-2 bg-[var(--bg-darker)] hover:bg-[var(--bg-darker)]/80 text-white rounded font-medium transition"
              >
                İptal
              </button>
              <button
                onClick={handleConfirm}
                disabled={isLoading}
                className="flex-1 px-4 py-2 bg-green-600 hover:bg-green-700 disabled:bg-gray-500 text-white rounded font-medium transition"
              >
                {isLoading ? "Satılıyor..." : "Sat"}
              </button>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

// ============================================================
// Split Stack Dialog
// ============================================================

interface SplitStackDialogProps {
  item: InventoryItem | null;
  onConfirm: (splitQuantity: number) => Promise<void>;
  onCancel: () => void;
}

export function SplitStackDialog({ item, onConfirm, onCancel }: SplitStackDialogProps) {
  const [splitQuantity, setSplitQuantity] = useState(1);
  const [isLoading, setIsLoading] = useState(false);

  if (!item || !item.is_stackable || item.quantity <= 1) return null;

  const remainingQuantity = item.quantity - splitQuantity;

  const handleConfirm = async () => {
    if (splitQuantity <= 0 || splitQuantity >= item.quantity) {
      alert("Geçersiz bölme miktarı");
      return;
    }

    setIsLoading(true);
    try {
      await onConfirm(splitQuantity);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
        onClick={onCancel}
      >
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          onClick={(e) => e.stopPropagation()}
          className="bg-[var(--bg-card)] rounded-lg p-6 w-96 border border-[var(--border-default)]"
        >
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-bold">Stack Böl</h2>
            <button onClick={onCancel} className="p-1 hover:bg-[var(--bg-darker)] rounded text-xl">
              ✕
            </button>
          </div>

          <p className="text-sm text-[var(--text-muted)] mb-4">
            {item.name}'{item.quantity > 1 ? "ıarını" : "ını"} kaç parçaya bölemek istiyorsunuz?
          </p>

          <div className="space-y-4">
            {/* Quantity Slider */}
            <div className="space-y-2">
              <label className="text-sm font-medium">Bölücük Miktar: {splitQuantity}</label>
              <input
                type="range"
                min="1"
                max={item.quantity - 1}
                value={splitQuantity}
                onChange={(e) => setSplitQuantity(parseInt(e.target.value))}
                className="w-full"
              />
            </div>

            {/* Split preview */}
            <div className="grid grid-cols-2 gap-2 text-sm">
              <div className="bg-blue-600/20 border border-blue-500 p-2 rounded text-center">
                <div className="text-xs text-blue-300">Yeni Stack</div>
                <div className="text-lg font-bold text-blue-400">{splitQuantity}x</div>
              </div>
              <div className="bg-purple-600/20 border border-purple-500 p-2 rounded text-center">
                <div className="text-xs text-purple-300">Kalan</div>
                <div className="text-lg font-bold text-purple-400">{remainingQuantity}x</div>
              </div>
            </div>

            {/* Buttons */}
            <div className="flex gap-3">
              <button
                onClick={onCancel}
                className="flex-1 px-4 py-2 bg-[var(--bg-darker)] hover:bg-[var(--bg-darker)]/80 text-white rounded font-medium transition"
              >
                İptal
              </button>
              <button
                onClick={handleConfirm}
                disabled={isLoading}
                className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-500 text-white rounded font-medium transition"
              >
                {isLoading ? "Bölünüyor..." : "Böl"}
              </button>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

// ============================================================
// Delete Confirm Dialog
// ============================================================

interface DeleteConfirmDialogProps {
  item: InventoryItem | null;
  onConfirm: (quantity: number) => Promise<void>;
  onCancel: () => void;
}

export function DeleteConfirmDialog({ item, onConfirm, onCancel }: DeleteConfirmDialogProps) {
  const [deleteQuantity, setDeleteQuantity] = useState(1);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (item?.row_id) {
      setDeleteQuantity(1);
    }
  }, [item?.row_id]);

  if (!item) return null;

  const isMultiStackDelete = item.is_stackable && item.quantity > 1;
  const maxDeleteQuantity = isMultiStackDelete ? item.quantity : 1;

  const handleConfirm = async () => {
    if (deleteQuantity <= 0 || deleteQuantity > item.quantity) {
      alert("Geçersiz miktar");
      return;
    }

    setIsLoading(true);
    try {
      await onConfirm(isMultiStackDelete ? deleteQuantity : 1);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
        onClick={onCancel}
      >
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          onClick={(e) => e.stopPropagation()}
          className="bg-[var(--bg-card)] rounded-lg p-6 w-96 border border-red-500/30"
        >
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-bold text-red-400">Eşyayı Sil</h2>
            <button onClick={onCancel} className="p-1 hover:bg-[var(--bg-darker)] rounded text-xl">
              ✕
            </button>
          </div>

          <p className="text-sm text-[var(--text-muted)] mb-4">
            {isMultiStackDelete
              ? `${item.name} iteminden kaç adet silmek istiyorsunuz?`
              : `${item.name} silmek istediğinize emin misiniz?`}
          </p>

          <div className="space-y-4">
            {isMultiStackDelete && (
              <div className="space-y-2">
                <label className="text-sm font-medium">Miktar: {deleteQuantity}</label>
                <input
                  type="range"
                  min="1"
                  max={maxDeleteQuantity}
                  value={deleteQuantity}
                  onChange={(e) => setDeleteQuantity(parseInt(e.target.value))}
                  className="w-full"
                />
              </div>
            )}

            {/* Warning */}
            <div className="bg-red-600/20 border border-red-500/50 p-3 rounded">
              <p className="text-sm text-red-300 font-medium">
                ⚠️ {isMultiStackDelete ? `${deleteQuantity}x ${item.name}` : item.name} silinecek
              </p>
              <p className="text-xs text-red-400 mt-1">
                Bu işlem geri alınamaz!
              </p>
            </div>

            {/* Buttons */}
            <div className="flex gap-3">
              <button
                onClick={onCancel}
                className="flex-1 px-4 py-2 bg-[var(--bg-darker)] hover:bg-[var(--bg-darker)]/80 text-white rounded font-medium transition"
              >
                İptal
              </button>
              <button
                onClick={handleConfirm}
                disabled={isLoading}
                className="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 disabled:bg-gray-500 text-white rounded font-medium transition"
              >
                {isLoading ? "Siliniyor..." : "Sil"}
              </button>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}
