// ============================================================
// Bank Page — Kaynak: scenes/ui/screens/BankScreen.gd (202 satır)
// Güvenli depo: item saklama, genişletme, yatırma/çekme
// DB: get_bank_items, expand_bank, deposit_to_bank, withdraw_from_bank
// ============================================================

"use client";

import { useState, useEffect, useCallback } from "react";
import { motion } from "framer-motion";
import { usePlayerStore } from "@/stores/playerStore";
import { useInventoryStore } from "@/stores/inventoryStore";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { Modal } from "@/components/ui/Modal";
import { ProgressBar } from "@/components/ui/ProgressBar";

type BankTab = "all" | "weapon" | "armor" | "potion";

interface BankItem {
  id: string;
  name: string;
  type: string;
  rarity: string;
  quantity: number;
}

const RARITY_COLORS: Record<string, string> = {
  common: "#9ca3af", uncommon: "#4ade80", rare: "#3b82f6", epic: "#a855f7", legendary: "#eab308",
};

export default function BankPage() {
  const [activeTab, setActiveTab] = useState<BankTab>("all");
  const [storedItems, setStoredItems] = useState<BankItem[]>([]);
  const [maxSlots, setMaxSlots] = useState(50);
  const [isLoading, setIsLoading] = useState(true);
  const [isExpanding, setIsExpanding] = useState(false);
  // Deposit/Withdraw modal state
  const [depositModal, setDepositModal] = useState(false);
  const [withdrawModal, setWithdrawModal] = useState(false);
  const [selectedItems, setSelectedItems] = useState<string[]>([]);
  const [isTransferring, setIsTransferring] = useState(false);

  const gems = usePlayerStore((s) => s.gems);
  const inventoryItems = useInventoryStore((s) => s.items);
  const fetchInventory = useInventoryStore((s) => s.fetchInventory);
  const addToast = useUiStore((s) => s.addToast);

  const usedSlots = storedItems.length;
  const expansionCost = Math.floor(50 * Math.pow(1.5, Math.floor((maxSlots - 50) / 25)));

  const fetchItems = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.rpc<{ items: BankItem[]; max_slots: number }>("get_bank_items", {});
      if (res.success && res.data) {
        setStoredItems(res.data.items || []);
        if (res.data.max_slots) setMaxSlots(res.data.max_slots);
      }
    } catch {
      // Keep empty
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchItems();
    fetchInventory();
  }, [fetchItems, fetchInventory]);

  const expandBank = async () => {
    if (maxSlots >= 200) { addToast("Maksimum kapasiteye ulaşıldı!", "warning"); return; }
    if (gems < expansionCost) { addToast("Yetersiz gem!", "error"); return; }
    setIsExpanding(true);
    try {
      const res = await api.rpc("expand_bank", { p_slots: 25 });
      if (res.success) {
        setMaxSlots((prev) => prev + 25);
        addToast("Banka 25 slot genişletildi!", "success");
        usePlayerStore.getState().fetchProfile();
      } else {
        addToast(res.error || "Genişletme başarısız", "error");
      }
    } finally {
      setIsExpanding(false);
    }
  };

  // Deposit selected inventory items to bank
  const handleDeposit = async () => {
    if (selectedItems.length === 0) { addToast("Eşya seçin", "warning"); return; }
    if (usedSlots + selectedItems.length > maxSlots) { addToast("Banka kapasitesi yetersiz!", "error"); return; }
    setIsTransferring(true);
    try {
      const res = await api.rpc("deposit_to_bank", { p_item_row_ids: selectedItems });
      if (res.success) {
        addToast(`${selectedItems.length} eşya bankaya yatırıldı!`, "success");
        setDepositModal(false);
        setSelectedItems([]);
        await fetchItems();
        await fetchInventory();
      } else {
        addToast(res.error || "Yatırma başarısız", "error");
      }
    } catch {
      addToast("İşlem başarısız", "error");
    } finally {
      setIsTransferring(false);
    }
  };

  // Withdraw selected bank items back to inventory
  const handleWithdraw = async () => {
    if (selectedItems.length === 0) { addToast("Eşya seçin", "warning"); return; }
    setIsTransferring(true);
    try {
      const res = await api.rpc("withdraw_from_bank", { p_item_ids: selectedItems });
      if (res.success) {
        addToast(`${selectedItems.length} eşya çekildi!`, "success");
        setWithdrawModal(false);
        setSelectedItems([]);
        await fetchItems();
        await fetchInventory();
      } else {
        addToast(res.error || "Çekme başarısız", "error");
      }
    } catch {
      addToast("İşlem başarısız", "error");
    } finally {
      setIsTransferring(false);
    }
  };

  const tabs: { key: BankTab; label: string; icon: string }[] = [
    { key: "all", label: "Tümü", icon: "📦" },
    { key: "weapon", label: "Silah", icon: "⚔️" },
    { key: "armor", label: "Zırh", icon: "🛡️" },
    { key: "potion", label: "İksir", icon: "🧪" },
  ];

  const filtered = activeTab === "all" ? storedItems : storedItems.filter((i) => i.type === activeTab);
  // Inventory items that are not equipped (for deposit)
  const depositableItems = inventoryItems.filter((i) => !i.is_equipped);

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="p-4 space-y-4 pb-24">
      <h1 className="text-xl font-bold text-[var(--gold)]">🏦 Banka</h1>

      {/* Capacity */}
      <Card>
        <div className="p-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-[var(--text-primary)]">Depo Kapasitesi</span>
            <span className="text-xs text-[var(--text-muted)]">{usedSlots}/{maxSlots}</span>
          </div>
          <ProgressBar value={usedSlots} max={maxSlots} color="accent" size="sm" />
          <Button variant="secondary" size="sm" fullWidth className="mt-3" onClick={expandBank}
            disabled={maxSlots >= 200 || isExpanding}>
            {isExpanding ? "Genişletiliyor..." : `Genişlet (+25 slot) — 💎 ${expansionCost} Gem`}
          </Button>
        </div>
      </Card>

      {/* Tabs */}
      <div className="flex gap-2">
        {tabs.map((tab) => (
          <button key={tab.key}
            className={`flex-1 py-2 rounded-lg text-xs font-medium transition-colors ${
              activeTab === tab.key ? "bg-[var(--primary)] text-white" : "bg-[var(--card-bg)] text-[var(--text-secondary)]"
            }`}
            onClick={() => setActiveTab(tab.key)}>
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      {/* Deposit / Withdraw Actions */}
      <div className="grid grid-cols-2 gap-2">
        <Button variant="primary" size="sm" fullWidth
          onClick={() => { setSelectedItems([]); setDepositModal(true); }}>
          📥 Yatır
        </Button>
        <Button variant="secondary" size="sm" fullWidth
          onClick={() => { setSelectedItems([]); setWithdrawModal(true); }}
          disabled={storedItems.length === 0}>
          📤 Çek
        </Button>
      </div>

      {/* Items Grid */}
      {isLoading ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Yükleniyor...</p>
      ) : filtered.length === 0 ? (
        <p className="text-center text-sm text-[var(--text-muted)] py-8">Bankada eşya bulunmuyor</p>
      ) : (
        <div className="grid grid-cols-5 gap-2">
          {filtered.map((item) => (
            <div key={item.id}
              className="aspect-square bg-[var(--card-bg)] border rounded-lg flex flex-col items-center justify-center p-1"
              style={{ borderColor: RARITY_COLORS[item.rarity] || "#444" }}>
              <span className="text-lg">📦</span>
              <span className="text-[8px] text-[var(--text-muted)] truncate w-full text-center">{item.name}</span>
              {item.quantity > 1 && <span className="text-[8px] text-[var(--text-primary)]">x{item.quantity}</span>}
            </div>
          ))}
        </div>
      )}

      {/* Deposit Modal — select from inventory */}
      <Modal isOpen={depositModal} onClose={() => setDepositModal(false)} title="📥 Bankaya Yatır" size="md">
        <div className="space-y-3">
          <p className="text-xs text-[var(--text-muted)]">Yatırmak istediğiniz eşyaları seçin:</p>
          {depositableItems.length === 0 ? (
            <p className="text-center text-sm text-[var(--text-muted)] py-4">Yatırılabilir eşya yok</p>
          ) : (
            <div className="space-y-1 max-h-60 overflow-y-auto">
              {depositableItems.map((item) => (
                <button key={item.row_id}
                  className={`w-full flex items-center gap-3 p-2 rounded-lg border text-left transition-colors ${
                    selectedItems.includes(item.row_id)
                      ? "border-[var(--accent)] bg-[var(--accent)]/10"
                      : "border-[var(--border-default)] bg-[var(--card-bg)]"
                  }`}
                  onClick={() => setSelectedItems((prev) =>
                    prev.includes(item.row_id) ? prev.filter((id) => id !== item.row_id) : [...prev, item.row_id]
                  )}>
                  <span className="text-lg">{item.icon ?? "📦"}</span>
                  <div className="flex-1">
                    <p className="text-xs font-medium text-[var(--text-primary)]">{item.name}</p>
                    <p className="text-[10px] text-[var(--text-muted)]">{item.item_type}</p>
                  </div>
                  {selectedItems.includes(item.row_id) && <span className="text-[var(--accent)]">✓</span>}
                </button>
              ))}
            </div>
          )}
          <div className="flex gap-2 pt-1">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setDepositModal(false)}>Vazgeç</Button>
            <Button variant="primary" size="sm" fullWidth
              isLoading={isTransferring}
              disabled={selectedItems.length === 0}
              onClick={handleDeposit}>
              Yatır ({selectedItems.length})
            </Button>
          </div>
        </div>
      </Modal>

      {/* Withdraw Modal — select from bank */}
      <Modal isOpen={withdrawModal} onClose={() => setWithdrawModal(false)} title="📤 Bankadan Çek" size="md">
        <div className="space-y-3">
          <p className="text-xs text-[var(--text-muted)]">Çekmek istediğiniz eşyaları seçin:</p>
          {storedItems.length === 0 ? (
            <p className="text-center text-sm text-[var(--text-muted)] py-4">Bankada eşya yok</p>
          ) : (
            <div className="space-y-1 max-h-60 overflow-y-auto">
              {storedItems.map((item) => (
                <button key={item.id}
                  className={`w-full flex items-center gap-3 p-2 rounded-lg border text-left transition-colors ${
                    selectedItems.includes(item.id)
                      ? "border-[var(--accent)] bg-[var(--accent)]/10"
                      : "border-[var(--border-default)] bg-[var(--card-bg)]"
                  }`}
                  onClick={() => setSelectedItems((prev) =>
                    prev.includes(item.id) ? prev.filter((id) => id !== item.id) : [...prev, item.id]
                  )}>
                  <span className="text-lg">📦</span>
                  <div className="flex-1">
                    <p className="text-xs font-medium text-[var(--text-primary)]">{item.name}</p>
                    <p className="text-[10px] text-[var(--text-muted)]">{item.type}</p>
                  </div>
                  {selectedItems.includes(item.id) && <span className="text-[var(--accent)]">✓</span>}
                </button>
              ))}
            </div>
          )}
          <div className="flex gap-2 pt-1">
            <Button variant="secondary" size="sm" fullWidth onClick={() => setWithdrawModal(false)}>Vazgeç</Button>
            <Button variant="primary" size="sm" fullWidth
              isLoading={isTransferring}
              disabled={selectedItems.length === 0}
              onClick={handleWithdraw}>
              Çek ({selectedItems.length})
            </Button>
          </div>
        </div>
      </Modal>
    </motion.div>
  );
}

