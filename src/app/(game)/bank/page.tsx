'use client';

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ItemIcon } from '@/components/game/ItemIcon';
import { api } from '@/lib/api';
import { usePlayerStore } from '@/stores/playerStore';
import { getItemFromSupabase } from '@/lib/itemResolver';

interface AccountData {
  id: string;
  total_slots: number;
  used_slots: number;
  free_slots_remaining: number;
  paid_slots_purchased: number;
}

interface BankItem {
  id: string;
  item_id: string;
  position: number;
  quantity: number;
  name?: string;
  rarity?: string;
  icon?: string | null;
  upgradeLevel?: number | null;
}

interface InventoryItem {
  row_id: string;
  item_id: string;
  quantity: number;
  name: string;
  rarity?: string;
  slot_position?: number;
  is_stackable?: boolean;
  max_stack?: number;
  icon?: string | null;
  upgradeLevel?: number | null;
}

type BankAccountRpcData = AccountData | AccountData[];
type BankItemsRpcData = BankItem[] | { items: BankItem[] } | { items: any; categories: any } | Array<{ items: BankItem[] }> | Array<{ items: any; categories: any }>;
type InventoryRpcData = InventoryItem[] | { items: InventoryItem[] };

const ITEMS_PER_PAGE = 20;
const SLOTS_PER_PAGE = 20;
const BASE_BANK_SLOTS = 100;
const MAX_BANK_SLOTS = 200;

function toAccountData(data: BankAccountRpcData | undefined): AccountData | null {
  if (!data) return null;
  if (Array.isArray(data)) return data[0] ?? null;
  return data;
}

function toBankItems(data: BankItemsRpcData | undefined): BankItem[] {
  if (!data) return [];
  
  // Supabase RETURNS TABLE döndürüyor: [{ items: [...], categories: {...} }]
  let itemsData: any = data;
  if (Array.isArray(data) && data.length > 0) {
    itemsData = data[0]; // Extract first element from TABLE return
  }
  
  // items array'ini özle
  const raw = Array.isArray(itemsData?.items) ? itemsData.items : (Array.isArray(itemsData) ? itemsData : []);
  
  return raw.map((it: any) => ({
    id: String(it.id ?? it.row_id ?? ''),
    item_id: String(it.item_id ?? it.itemId ?? ''),
    position: Number(it.slot_position ?? it.position ?? -1),
    quantity: Number(it.quantity ?? 1),
    name: String(it.name ?? it.display_name ?? ''),
    rarity: it.rarity,
    icon: it.icon ?? null,
    upgradeLevel: it.upgrade_level ?? it.upgrade ?? it.enhancement_level ?? null,
  } as BankItem));
}

function toInventoryItems(data: InventoryRpcData | undefined): InventoryItem[] {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  const raw = Array.isArray(data.items) ? data.items : [];
  return raw.map((it: any) => ({
    row_id: String(it.row_id ?? it.rowId ?? ''),
    item_id: String(it.item_id ?? it.itemId ?? ''),
    quantity: Number(it.quantity ?? 1),
    name: String(it.name ?? it.display_name ?? ''),
    rarity: it.rarity,
    slot_position: typeof it.slot_position === 'number' ? it.slot_position : (typeof it.slotPosition === 'number' ? it.slotPosition : undefined),
    is_stackable: !!it.is_stackable,
    max_stack: typeof it.max_stack === 'number' ? it.max_stack : (typeof it.maxStack === 'number' ? it.maxStack : undefined),
    icon: it.icon ?? null,
    upgradeLevel: it.upgrade_level ?? it.upgrade ?? it.enhancement_level ?? null,
  } as InventoryItem));
}

function getExpansionCost(totalSlots: number): number {
  if (totalSlots >= 175) return 500;
  if (totalSlots >= 150) return 200;
  if (totalSlots >= 125) return 100;
  return 50;
}

export default function BankPage() {
  const player = usePlayerStore((state) => state.player);
  const gems = player?.gems || 0;

  const initialLoadRef = useRef(true);
  const lastSnapshotRef = useRef<string | null>(null);
  const idleCountRef = useRef(0);
  const pollTimerRef = useRef<number | null>(null);

  const [accountData, setAccountData] = useState<AccountData | null>(null);
  const [bankItems, setBankItems] = useState<BankItem[]>([]);
  const [inventoryItems, setInventoryItems] = useState<InventoryItem[]>([]);

  const [inventoryPage, setInventoryPage] = useState(1);
  const [bankPage, setBankPage] = useState(1);

  const [selectedInventoryRows, setSelectedInventoryRows] = useState<string[]>([]);
  const [selectedBankRows, setSelectedBankRows] = useState<string[]>([]);

  const [draggedInventoryItem, setDraggedInventoryItem] = useState<InventoryItem | null>(null);
  const [draggedBankItem, setDraggedBankItem] = useState<BankItem | null>(null);

  const [loading, setLoading] = useState(true);
  const [depositing, setDepositing] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);
  const [expanding, setExpanding] = useState(false);
  const [showExpandDetails, setShowExpandDetails] = useState(false);
  const [showStats, setShowStats] = useState(false);

  const [showDepositModal, setShowDepositModal] = useState(false);
  const [depositModalItem, setDepositModalItem] = useState<InventoryItem | null>(null);
  const [depositQuantity, setDepositQuantity] = useState(1);
  const [pendingDepositRowIds, setPendingDepositRowIds] = useState<string[]>([]);

  // Drag-drop quantity selection modal
  const [swapQuantityModal, setSwapQuantityModal] = useState<{
    sourceType: 'inventory' | 'bank';
    targetType: 'inventory' | 'bank';
    sourceId: string;
    sourceItem: InventoryItem | BankItem;
    targetSlotIndex: number;
  } | null>(null);
  const [swapQuantity, setSwapQuantity] = useState(1);

  const unlockedSlots = Math.min(accountData?.total_slots ?? BASE_BANK_SLOTS, MAX_BANK_SLOTS);
  const usedSlots = accountData?.used_slots ?? 0;
  const freeSlots = Math.max(unlockedSlots - usedSlots, 0);
  const fillPercent = Math.min((usedSlots / Math.max(unlockedSlots, 1)) * 100, 100);

  const inventoryTotalPages = Math.max(1, Math.ceil(inventoryItems.length / ITEMS_PER_PAGE));

  const inventorySlots = useMemo(() => {
    // Build fixed ITEMS_PER_PAGE slots for current page, index 0..ITEMS_PER_PAGE-1
    const slots: (InventoryItem | null)[] = Array.from({ length: ITEMS_PER_PAGE }, () => null);

    // First try to place items by their slot_position if present
    for (const it of inventoryItems) {
      const pos = typeof it.slot_position === 'number' ? it.slot_position : undefined;
      if (typeof pos === 'number') {
        const pageIndex = pos - (inventoryPage - 1) * ITEMS_PER_PAGE;
        if (pageIndex >= 0 && pageIndex < ITEMS_PER_PAGE) {
          slots[pageIndex] = it;
        }
      }
    }

    // Fill remaining empty slots with items lacking slot_position or not yet placed, preserving RPC order
    let fillIndex = 0;
    for (const it of inventoryItems) {
      const pos = typeof it.slot_position === 'number' ? it.slot_position : undefined;
      if (typeof pos === 'number') continue; // already handled
      // find next empty slot
      while (fillIndex < ITEMS_PER_PAGE && slots[fillIndex] !== null) fillIndex++;
      if (fillIndex < ITEMS_PER_PAGE) {
        slots[fillIndex] = it;
        fillIndex++;
      }
    }

    return slots;
  }, [inventoryItems, inventoryPage]);

  const bankTotalPages = Math.ceil(MAX_BANK_SLOTS / SLOTS_PER_PAGE);
  const bankStartIndex = (bankPage - 1) * SLOTS_PER_PAGE;
  const bankVisibleSlots = useMemo(
    () => Array.from({ length: SLOTS_PER_PAGE }, (_, idx) => bankStartIndex + idx),
    [bankStartIndex]
  );

  // Fetch once and return raw RPC results (do not update state here)
  const fetchOnce = useCallback(async () => {
    try {
      const [accountRes, bankRes, invRes] = await Promise.all([
        api.rpc<BankAccountRpcData>('get_bank_account'),
        api.rpc<BankItemsRpcData>('get_bank_items', { p_category: null }),
        api.rpc<InventoryRpcData>('get_inventory'),
      ]);
      return { accountRes, bankRes, invRes };
    } catch (error) {
      console.error('Bank data fetch failed:', error);
      return { accountRes: { success: false, data: null } as any, bankRes: { success: false, data: null } as any, invRes: { success: false, data: null } as any };
    }
  }, []);

  useEffect(() => {
    let mounted = true;

    const scheduleNext = () => {
      if (!mounted) return;
      // don't poll when tab is hidden; check again later
      if (typeof document !== 'undefined' && document.hidden) {
        pollTimerRef.current = window.setTimeout(scheduleNext, 10000);
        return;
      }

      const base = 10000; // 10s
      const delay = Math.min(base * Math.pow(2, Math.max(0, idleCountRef.current)), 60000); // backoff up to 60s

      pollTimerRef.current = window.setTimeout(async () => {
        const { accountRes, bankRes, invRes } = await fetchOnce();

        const snapshot = JSON.stringify({
          a: accountRes.success ? accountRes.data : null,
          b: bankRes.success ? bankRes.data : null,
          i: invRes.success ? invRes.data : null,
        });

        if (lastSnapshotRef.current === null) {
          // first poll - apply state
          if (accountRes.success) setAccountData(toAccountData(accountRes.data));
          if (bankRes.success) setBankItems(toBankItems(bankRes.data));
          if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
          lastSnapshotRef.current = snapshot;
          idleCountRef.current = 0;
        } else if (snapshot !== lastSnapshotRef.current) {
          // data changed - update state and reset backoff
          if (accountRes.success) setAccountData(toAccountData(accountRes.data));
          if (bankRes.success) setBankItems(toBankItems(bankRes.data));
          if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
          lastSnapshotRef.current = snapshot;
          idleCountRef.current = 0;
        } else {
          // no change
          idleCountRef.current = Math.min(idleCountRef.current + 1, 6);
        }

        scheduleNext();
      }, delay) as unknown as number;
    };

    const start = async () => {
      setLoading(true);
      const { accountRes, bankRes, invRes } = await fetchOnce();
      if (!mounted) return;
      if (accountRes.success) setAccountData(toAccountData(accountRes.data));
      if (bankRes.success) setBankItems(toBankItems(bankRes.data));
      if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
      lastSnapshotRef.current = JSON.stringify({ a: accountRes.data, b: bankRes.data, i: invRes.data });
      setLoading(false);
      scheduleNext();
    };

    start();

    const onVisibility = () => {
      // reset backoff when tab becomes visible
      if (!document.hidden) {
        idleCountRef.current = 0;
      }
    };
    document.addEventListener('visibilitychange', onVisibility);

    return () => {
      mounted = false;
      if (pollTimerRef.current) window.clearTimeout(pollTimerRef.current);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [fetchOnce]);

  const handleDeposit = useCallback(
    async (rowIds: string[]) => {
      if (rowIds.length === 0) return;
      
      // Find first stackable item that needs quantity confirmation
      const firstStackable = rowIds
        .map(rid => inventoryItems.find(x => x.row_id === rid))
        .filter(item => item && item.is_stackable && item.quantity > 1)[0];
      
      if (firstStackable) {
        // Show modal for quantity selection
        setDepositModalItem(firstStackable);
        setDepositQuantity(firstStackable.quantity);
        setPendingDepositRowIds(rowIds);
        setShowDepositModal(true);
        return;
      }
      
      // No stackable items, proceed directly
      setDepositing(true);
      try {
        const result = await api.rpc('deposit_to_bank', { p_item_row_ids: rowIds });
        if (result.success) {
          setSelectedInventoryRows([]);
          const { accountRes, bankRes, invRes } = await fetchOnce();
          if (accountRes.success) setAccountData(toAccountData(accountRes.data));
          if (bankRes.success) setBankItems(toBankItems(bankRes.data));
          if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
        }
      } catch (error) {
        console.error('Deposit failed:', error);
      } finally {
        setDepositing(false);
      }
    },
    [inventoryItems, fetchOnce]
  );

  const handleDepositConfirm = useCallback(async () => {
    if (pendingDepositRowIds.length === 0 || !depositModalItem) return;
    setShowDepositModal(false);
    setDepositing(true);
    try {
      // Build quantities array: use depositQuantity for first stackable, full quantity for others
      const quantities = pendingDepositRowIds.map((rid) => {
        if (depositModalItem && rid === depositModalItem.row_id) {
          return depositQuantity;
        }
        // Get full quantity for non-stackable or non-modal items
        const item = inventoryItems.find(x => x.row_id === rid);
        return item?.quantity || 1;
      });

      const result = await api.rpc('deposit_to_bank', { 
        p_item_row_ids: pendingDepositRowIds,
        p_quantities: quantities
      });
      if (result.success) {
        setSelectedInventoryRows([]);
        const { accountRes, bankRes, invRes } = await fetchOnce();
        if (accountRes.success) setAccountData(toAccountData(accountRes.data));
        if (bankRes.success) setBankItems(toBankItems(bankRes.data));
        if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
      }
    } catch (error) {
      console.error('Deposit failed:', error);
    } finally {
      setDepositing(false);
      setDepositModalItem(null);
      setPendingDepositRowIds([]);
      setDepositQuantity(1);
    }
  }, [pendingDepositRowIds, depositModalItem, inventoryItems, depositQuantity, fetchOnce]);

  const handleWithdraw = useCallback(async (bankItemIds?: string[]) => {
    const idsToWithdraw = bankItemIds || selectedBankRows;
    if (idsToWithdraw.length === 0) return;
    setWithdrawing(true);
    try {
      const result = await api.rpc('withdraw_from_bank', { p_bank_item_ids: idsToWithdraw });
      if (result.success) {
        setSelectedBankRows([]);
        const { accountRes, bankRes, invRes } = await fetchOnce();
        if (accountRes.success) setAccountData(toAccountData(accountRes.data));
        if (bankRes.success) setBankItems(toBankItems(bankRes.data));
        if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
      }
    } catch (error) {
      console.error('Withdraw failed:', error);
    } finally {
      setWithdrawing(false);
    }
  }, [fetchOnce, selectedBankRows]);

  const handleExpand = useCallback(async () => {
    setExpanding(true);
    try {
      const result = await api.rpc('expand_bank_slots', { p_num_expansions: 1 });
      if (result.success) {
        const { accountRes, bankRes, invRes } = await fetchOnce();
        if (accountRes.success) setAccountData(toAccountData(accountRes.data));
        if (bankRes.success) setBankItems(toBankItems(bankRes.data));
        if (invRes.success) setInventoryItems(toInventoryItems(invRes.data));
      }
    } catch (error) {
      console.error('Expand failed:', error);
    } finally {
      setExpanding(false);
    }
  }, [fetchOnce]);

  const handleInventoryDropToBank = useCallback(
    async (slotIndex: number) => {
      if (!draggedInventoryItem) return;
      if (slotIndex >= unlockedSlots) return;

      try {
        // Get item metadata from Supabase to check if stackable
        const itemMeta = await getItemFromSupabase(draggedInventoryItem.item_id);
        const isStackable = itemMeta?.max_stack && itemMeta.max_stack > 1;

        if (isStackable) {
          // Open quantity selection modal for stackable items
          setSwapQuantityModal({
            sourceType: 'inventory',
            targetType: 'bank',
            sourceId: draggedInventoryItem.row_id,
            sourceItem: draggedInventoryItem,
            targetSlotIndex: slotIndex,
          });
          setSwapQuantity(draggedInventoryItem.quantity);
          setDraggedInventoryItem(null);
        } else {
          // Non-stackable: transfer immediately without quantity modal
          await performInventoryToSwap(draggedInventoryItem.row_id, 'bank', slotIndex, draggedInventoryItem.quantity);
          setDraggedInventoryItem(null);
        }
      } catch (error) {
        console.error('Error checking item stackability:', error);
        // Fallback: try to transfer anyway
        await performInventoryToSwap(draggedInventoryItem.row_id, 'bank', slotIndex, draggedInventoryItem.quantity);
        setDraggedInventoryItem(null);
      }
    },
    [draggedInventoryItem, unlockedSlots]
  );

  const performInventoryToSwap = useCallback(
    async (rowId: string, targetType: 'inventory' | 'bank', slotIndex: number, quantity: number) => {
      setDepositing(true);
      try {
        const targetItemId = targetType === 'bank'
          ? (bankItems.find((item) => item.position === slotIndex)?.id ?? null)
          : (inventoryItems.find((item) => item.slot_position === slotIndex)?.row_id ?? null);

        console.log('🔄 Swap request:', {
          source: 'inventory',
          target: targetType,
          sourceId: rowId,
          targetId: targetItemId,
          targetSlot: slotIndex,
          quantity: quantity,
        });

        // Merge same items or swap different items
        const result = await api.rpc('swap_inventory_bank', {
          p_source_type: 'inventory',
          p_source_id: rowId,
          p_target_type: targetType,
          p_target_id: targetItemId,
          p_quantity: quantity,
          p_target_slot: slotIndex,
        });

        console.log('📦 Swap result:', result);

        if (result?.success) {
          console.log('✅ Swap successful, fetching updated data...');
          // Refresh data
          const { accountRes, bankRes, invRes } = await fetchOnce();
          console.log('🔄 Fetched account:', accountRes);
          console.log('🔄 Fetched bank:', bankRes);
          console.log('🔄 Fetched inventory:', invRes);
          
          if (accountRes.success) {
            const accountData = toAccountData(accountRes.data);
            console.log('📝 Setting account data:', accountData);
            setAccountData(accountData);
          }
          if (bankRes.success) {
            const bankItems = toBankItems(bankRes.data);
            console.log('📝 Setting bank items:', bankItems);
            setBankItems(bankItems);
          }
          if (invRes.success) {
            const inventoryItems = toInventoryItems(invRes.data);
            console.log('📝 Setting inventory items:', inventoryItems);
            setInventoryItems(inventoryItems);
          }
        } else {
          console.warn('⚠️ Swap not successful:', JSON.stringify(result) || 'Unknown error');
        }
      } catch (error) {
        console.error('❌ Inventory swap failed:', error);
      } finally {
        setDepositing(false);
      }
    },
    [bankItems, inventoryItems, fetchOnce]
  );

  const handleSwapQuantityConfirm = useCallback(async () => {
    if (!swapQuantityModal) return;

    setSwapQuantityModal(null);
    if (swapQuantityModal.sourceType === 'inventory') {
      await performInventoryToSwap(
        swapQuantityModal.sourceId,
        swapQuantityModal.targetType,
        swapQuantityModal.targetSlotIndex,
        swapQuantity
      );
      return;
    }

    await performBankToSwap(
      swapQuantityModal.sourceId,
      swapQuantityModal.targetType,
      swapQuantityModal.targetSlotIndex,
      swapQuantity
    );
  }, [swapQuantityModal, swapQuantity, performInventoryToSwap]);

  const handleBankDropToInventory = useCallback(
    async (slotIndex: number) => {
      if (!draggedBankItem) return;

      try {
        // Get item metadata from Supabase to check if stackable
        const itemMeta = await getItemFromSupabase(draggedBankItem.item_id);
        const isStackable = itemMeta?.max_stack && itemMeta.max_stack > 1;

        if (isStackable) {
          // Open quantity selection modal for stackable items
          setSwapQuantityModal({
            sourceType: 'bank',
            targetType: 'inventory',
            sourceId: draggedBankItem.id,
            sourceItem: draggedBankItem,
            targetSlotIndex: slotIndex,
          });
          setSwapQuantity(draggedBankItem.quantity);
          setDraggedBankItem(null);
        } else {
          // Non-stackable: transfer immediately without quantity modal
          await performBankToSwap(draggedBankItem.id, 'inventory', slotIndex, draggedBankItem.quantity);
          setDraggedBankItem(null);
        }
      } catch (error) {
        console.error('Error checking item stackability:', error);
        // Fallback: try to transfer anyway
        await performBankToSwap(draggedBankItem.id, 'inventory', slotIndex, draggedBankItem.quantity);
        setDraggedBankItem(null);
      }
    },
    [draggedBankItem]
  );

  const handleBankDropToBank = useCallback(
    async (slotIndex: number) => {
      if (!draggedBankItem) return;

      try {
        const itemMeta = await getItemFromSupabase(draggedBankItem.item_id);
        const isStackable = itemMeta?.max_stack && itemMeta.max_stack > 1;

        if (isStackable) {
          setSwapQuantityModal({
            sourceType: 'bank',
            targetType: 'bank',
            sourceId: draggedBankItem.id,
            sourceItem: draggedBankItem,
            targetSlotIndex: slotIndex,
          });
          setSwapQuantity(draggedBankItem.quantity);
          setDraggedBankItem(null);
        } else {
          await performBankToSwap(draggedBankItem.id, 'bank', slotIndex, draggedBankItem.quantity);
          setDraggedBankItem(null);
        }
      } catch (error) {
        console.error('Error checking item stackability:', error);
        await performBankToSwap(draggedBankItem.id, 'bank', slotIndex, draggedBankItem.quantity);
        setDraggedBankItem(null);
      }
    },
    [draggedBankItem]
  );

  const handleInventoryDropToInventory = useCallback(
    async (slotIndex: number) => {
      if (!draggedInventoryItem) return;

      try {
        const itemMeta = await getItemFromSupabase(draggedInventoryItem.item_id);
        const isStackable = itemMeta?.max_stack && itemMeta.max_stack > 1;

        if (isStackable) {
          setSwapQuantityModal({
            sourceType: 'inventory',
            targetType: 'inventory',
            sourceId: draggedInventoryItem.row_id,
            sourceItem: draggedInventoryItem,
            targetSlotIndex: slotIndex,
          });
          setSwapQuantity(draggedInventoryItem.quantity);
          setDraggedInventoryItem(null);
        } else {
          await performInventoryToSwap(draggedInventoryItem.row_id, 'inventory', slotIndex, draggedInventoryItem.quantity);
          setDraggedInventoryItem(null);
        }
      } catch (error) {
        console.error('Error checking item stackability:', error);
        await performInventoryToSwap(draggedInventoryItem.row_id, 'inventory', slotIndex, draggedInventoryItem.quantity);
        setDraggedInventoryItem(null);
      }
    },
    [draggedInventoryItem]
  );

  const performBankToSwap = useCallback(
    async (bankItemId: string, targetType: 'inventory' | 'bank', slotIndex: number, quantity: number) => {
      setWithdrawing(true);
      try {
        const targetItemId = targetType === 'inventory'
          ? (inventoryItems.find((item) => item.slot_position === slotIndex)?.row_id ?? null)
          : (bankItems.find((item) => item.position === slotIndex)?.id ?? null);

        console.log('🔄 Swap request:', {
          source: 'bank',
          target: targetType,
          sourceId: bankItemId,
          targetId: targetItemId,
          targetSlot: slotIndex,
          quantity: quantity,
        });

        // Merge same items or swap different items
        const result = await api.rpc('swap_inventory_bank', {
          p_source_type: 'bank',
          p_source_id: bankItemId,
          p_target_type: targetType,
          p_target_id: targetItemId,
          p_quantity: quantity,
          p_target_slot: slotIndex,
        });

        console.log('📦 Swap result:', result);

        if (result?.success) {
          console.log('✅ Swap successful, fetching updated data...');
          // Refresh data
          const { accountRes, bankRes, invRes } = await fetchOnce();
          console.log('🔄 Fetched account:', accountRes);
          console.log('🔄 Fetched bank:', bankRes);
          console.log('🔄 Fetched inventory:', invRes);
          
          if (accountRes.success) {
            const accountData = toAccountData(accountRes.data);
            console.log('📝 Setting account data:', accountData);
            setAccountData(accountData);
          }
          if (bankRes.success) {
            const bankItems = toBankItems(bankRes.data);
            console.log('📝 Setting bank items:', bankItems);
            setBankItems(bankItems);
          }
          if (invRes.success) {
            const inventoryItems = toInventoryItems(invRes.data);
            console.log('📝 Setting inventory items:', inventoryItems);
            setInventoryItems(inventoryItems);
          }
        } else {
          console.warn('⚠️ Swap not successful:', JSON.stringify(result) || 'Unknown error');
        }
      } catch (error) {
        console.error('❌ Bank swap failed:', error);
      } finally {
        setWithdrawing(false);
      }
    },
    [inventoryItems, bankItems, fetchOnce]
  );

  const nextExpansionCost = getExpansionCost(unlockedSlots);

  return (
    <div style={styles.page}>
      {/* Deposit Quantity Modal */}
      {showDepositModal && depositModalItem ? (
        <div style={styles.modalOverlay} onClick={() => setShowDepositModal(false)}>
          <div 
            style={styles.modalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={styles.modalHeader}>🏦 Depo'ya Aktar</div>
            
            <div style={styles.modalItemDisplay}>
              <div style={styles.modalItemIcon}>
                <ItemIcon icon={depositModalItem.icon} itemId={depositModalItem.item_id} />
              </div>
              <div style={styles.modalItemInfo}>
                <div style={styles.modalItemName}>{depositModalItem.name}</div>
                <div style={styles.modalItemQty}>Envanterde: {depositModalItem.quantity} adet</div>
              </div>
            </div>

            <div style={styles.quantityControl}>
              <span style={styles.quantityLabel}>Miktar:</span>
              <input
                type="number"
                style={styles.quantityInput}
                value={depositQuantity}
                onChange={(e) => {
                  const val = parseInt(e.target.value || '1', 10);
                  setDepositQuantity(Math.max(1, Math.min(val, depositModalItem.quantity)));
                }}
                min="1"
                max={depositModalItem.quantity}
              />
              <div style={{ display: 'flex', gap: '4px' }}>
                <button
                  style={styles.quantityButton}
                  onClick={() => setDepositQuantity(Math.max(1, depositQuantity - 1))}
                >
                  −
                </button>
                <button
                  style={styles.quantityButton}
                  onClick={() => setDepositQuantity(Math.min(depositModalItem.quantity, depositQuantity + 1))}
                >
                  +
                </button>
              </div>
            </div>

            <div style={styles.modalFooter}>
              <button
                style={styles.modalButtonConfirm}
                onClick={() => handleDepositConfirm()}
                disabled={depositing}
              >
                {depositing ? '⏳' : '✓ Onayla'}
              </button>
              <button
                style={styles.modalButtonCancel}
                onClick={() => {
                  setShowDepositModal(false);
                  setDepositModalItem(null);
                  setPendingDepositRowIds([]);
                }}
                disabled={depositing}
              >
                ✕ İptal
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {/* Swap Quantity Modal */}
      {swapQuantityModal ? (
        <div style={styles.modalOverlay} onClick={() => setSwapQuantityModal(null)}>
          <div 
            style={styles.modalContent}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={styles.modalHeader}>
              {swapQuantityModal.sourceType === 'inventory' ? '🎒 Envanterden' : '🏦 Banka\'dan'} Taşı
            </div>
            
            <div style={styles.modalItemDisplay}>
              <div style={styles.modalItemIcon}>
                <ItemIcon 
                  icon={swapQuantityModal.sourceItem.icon} 
                  itemId={swapQuantityModal.sourceItem.item_id} 
                />
              </div>
              <div style={styles.modalItemInfo}>
                <div style={styles.modalItemName}>{swapQuantityModal.sourceItem.name}</div>
                <div style={styles.modalItemQty}>
                  Mevcut: {swapQuantityModal.sourceItem.quantity} adet
                </div>
              </div>
            </div>

            <div style={styles.quantityControl}>
              <span style={styles.quantityLabel}>Taşınacak Miktar:</span>
              <input
                type="number"
                style={styles.quantityInput}
                value={swapQuantity}
                onChange={(e) => {
                  const val = parseInt(e.target.value || '1', 10);
                  setSwapQuantity(Math.max(1, Math.min(val, swapQuantityModal.sourceItem.quantity)));
                }}
                min="1"
                max={swapQuantityModal.sourceItem.quantity}
              />
              <div style={{ display: 'flex', gap: '4px' }}>
                <button
                  style={styles.quantityButton}
                  onClick={() => setSwapQuantity(Math.max(1, swapQuantity - 1))}
                >
                  −
                </button>
                <button
                  style={styles.quantityButton}
                  onClick={() => setSwapQuantity(Math.min(swapQuantityModal.sourceItem.quantity, swapQuantity + 1))}
                >
                  +
                </button>
              </div>
            </div>

            <div style={styles.modalFooter}>
              <button
                style={styles.modalButtonConfirm}
                onClick={() => handleSwapQuantityConfirm()}
                disabled={depositing || withdrawing}
              >
                {depositing || withdrawing ? '⏳' : '✓ Taşı'}
              </button>
              <button
                style={styles.modalButtonCancel}
                onClick={() => setSwapQuantityModal(null)}
                disabled={depositing || withdrawing}
              >
                ✕ İptal
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <div style={styles.topLayer}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <h1 style={styles.title}>🏦 BANKA</h1>
        </div>
      </div>

      <div style={styles.expandRow}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={() => setShowStats((s) => !s)}
            aria-expanded={showStats}
            style={styles.caretButton}
            title={showStats ? 'İstatistikleri gizle' : 'İstatistikleri göster ve depolama genişletme'}
          >
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1 }}>
              <span style={{ fontSize: 12, color: '#FFD700', fontWeight: 700 }}>İstatistikler</span>
              <span style={{ fontSize: 11, color: '#a9a9a9' }}>{`Depolama Genişletme ${showStats ? '▾' : '▸'}`}</span>
            </div>
          </button>
        </div>
      </div>

      {showStats ? (
        <div style={styles.statsLayer}>
        <div style={styles.statsLeft}>
          <div style={styles.statCard}>
            <span style={styles.statLabel}>Açık Slot</span>
            <strong style={styles.statValue}>{unlockedSlots}</strong>
          </div>
          <div style={styles.statCard}>
            <span style={styles.statLabel}>Dolu</span>
            <strong style={styles.statValue}>{usedSlots}</strong>
          </div>
          <div style={styles.statCard}>
            <span style={styles.statLabel}>Boş</span>
            <strong style={styles.statValue}>{freeSlots}</strong>
          </div>
          <div style={styles.statCard}>
            <span style={styles.statLabel}>Gem</span>
            <strong style={styles.statValue}>💎 {gems}</strong>
          </div>
        </div>
        <div style={styles.statsRight}>
          <div style={styles.progressTrack}>
            <div style={{ ...styles.progressFill, width: `${fillPercent}%` }} />
          </div>
          <div style={{ marginTop: 8 }}>
            <button
              style={{
                ...styles.expandButton,
                opacity: gems >= nextExpansionCost ? 1 : 0.55,
                cursor: gems >= nextExpansionCost ? 'pointer' : 'not-allowed',
                padding: '4px 8px',
                fontSize: '12px',
              }}
              onClick={handleExpand}
              disabled={expanding || gems < nextExpansionCost || unlockedSlots >= MAX_BANK_SLOTS}
              title={`+25 Slot — 💎 ${nextExpansionCost}`}
            >
              {expanding ? '⏳' : `+25 (💎${nextExpansionCost})`}
            </button>
          </div>
        </div>
        </div>
      ) : null}

      <section style={styles.inventoryLayer}>
        <div style={styles.sectionHeader}>
          <h2 style={styles.sectionTitle}>Envanter</h2>
          <button
            style={{
              ...styles.primaryButton,
              opacity: selectedInventoryRows.length > 0 ? 1 : 0.5,
              cursor: selectedInventoryRows.length > 0 ? 'pointer' : 'not-allowed',
            }}
            onClick={() => handleDeposit(selectedInventoryRows)}
            disabled={depositing || selectedInventoryRows.length === 0}
          >
            {depositing ? 'Aktarılıyor...' : `Seçilenleri Aktar (${selectedInventoryRows.length})`}
          </button>
        </div>

        {loading ? (
          <div style={styles.loading}>Yükleniyor...</div>
        ) : (
          <>
            <div 
              style={styles.inventoryGrid}
              onDragOver={(event) => {
                if (draggedBankItem) event.preventDefault();
              }}
            >
              {inventorySlots.map((item, idx) => {
                const key = item ? item.row_id : `empty-${idx}`;
                const selected = item ? selectedInventoryRows.includes(item.row_id) : false;
                return (
                  <div
                    key={key}
                    style={{
                      ...styles.inventoryItem,
                      borderColor: selected ? '#4ECDC4' : '#3a3a3a',
                      background: selected ? '#1f3530' : '#191919',
                    }}
                    onClick={() => {
                      if (!item) return;
                      setSelectedInventoryRows((prev) =>
                        prev.includes(item.row_id)
                          ? prev.filter((id) => id !== item.row_id)
                          : [...prev, item.row_id]
                      );
                    }}
                    draggable={!!item}
                    onDragStart={() => item && setDraggedInventoryItem(item)}
                    onDragEnd={() => setDraggedInventoryItem(null)}
                    onDragOver={(event) => {
                      if (draggedBankItem || draggedInventoryItem) event.preventDefault();
                    }}
                    onDrop={(event) => {
                      event.preventDefault();
                      const globalSlotIndex = (inventoryPage - 1) * ITEMS_PER_PAGE + idx;
                      if (draggedBankItem) {
                        void handleBankDropToInventory(globalSlotIndex);
                      } else if (draggedInventoryItem) {
                        void handleInventoryDropToInventory(globalSlotIndex);
                      }
                    }}
                  >
                    {item ? (
                      <div style={{ width: 88, height: 88, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <ItemIcon icon={item.icon} itemId={item.item_id} />
                      </div>
                    ) : null}
                    {item && item.quantity > 1 ? <span style={styles.qtyBottomLeft}>{item.quantity}</span> : null}
                    {item && Number(item.upgradeLevel ?? 0) > 0 ? (
                      <span style={styles.upgradeBadge}>{`+${item.upgradeLevel}`}</span>
                    ) : null}
                    {item ? <span style={styles.itemCaption}>{item.name}</span> : null}
                  </div>
                );
              })}
            </div>
            
          </>
        )}
      </section>

      <section style={styles.bankLayer}>
        <div style={styles.sectionHeader}>
          <h2 style={styles.sectionTitle}>Banka</h2>
          <button
            style={{
              ...styles.dangerButton,
              opacity: selectedBankRows.length > 0 ? 1 : 0.5,
              cursor: selectedBankRows.length > 0 ? 'pointer' : 'not-allowed',
            }}
            onClick={() => handleWithdraw()}
            disabled={withdrawing || selectedBankRows.length === 0}
          >
            {withdrawing ? 'Çıkarılıyor...' : `Seçilenleri Çıkar (${selectedBankRows.length})`}
          </button>
        </div>

        <div style={styles.bankGrid}>
          {bankVisibleSlots.map((slotIndex) => {
            const bankItem = bankItems.find((item) => item.position === slotIndex);
            const isLocked = slotIndex >= unlockedSlots;
            const selected = bankItem ? selectedBankRows.includes(bankItem.id) : false;

            return (
              <div
                key={slotIndex}
                style={{
                  ...styles.bankSlot,
                  opacity: isLocked ? 0.4 : 1,
                  borderColor: selected ? '#4ECDC4' : bankItem ? '#FFD700' : '#333',
                  background: selected ? '#1f3530' : bankItem ? '#151515' : 'transparent',
                  cursor: isLocked ? 'not-allowed' : 'pointer',
                }}
                onClick={() => {
                  if (!bankItem || isLocked) return;
                  setSelectedBankRows((prev) =>
                    prev.includes(bankItem.id)
                      ? prev.filter((id) => id !== bankItem.id)
                      : [...prev, bankItem.id]
                  );
                }}
                draggable={!!bankItem && !isLocked}
                onDragStart={() => bankItem && !isLocked && setDraggedBankItem(bankItem)}
                onDragEnd={() => setDraggedBankItem(null)}
                onDragOver={(event) => {
                  if (!isLocked && (draggedInventoryItem || draggedBankItem)) event.preventDefault();
                }}
                onDrop={(event) => {
                  event.preventDefault();
                  if (draggedInventoryItem) {
                    void handleInventoryDropToBank(slotIndex);
                  } else if (draggedBankItem) {
                    void handleBankDropToBank(slotIndex);
                  }
                }}
              >
                {isLocked ? (
                  <span style={styles.lockedIcon}>🔒</span>
                ) : bankItem ? (
                  <>
                    <div style={{ width: 88, height: 88, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <ItemIcon icon={bankItem.icon} itemId={bankItem.item_id} />
                    </div>
                    {bankItem.quantity > 1 ? <span style={styles.qtyBottomLeft}>{bankItem.quantity}</span> : null}
                    {Number(bankItem.upgradeLevel ?? 0) > 0 ? (
                      <span style={styles.upgradeBadge}>{`+${bankItem.upgradeLevel}`}</span>
                    ) : null}
                    {bankItem.name ? <span style={styles.itemCaption}>{bankItem.name}</span> : null}
                  </>
                ) : null}
                <span style={styles.slotNo}>#{slotIndex + 1}</span>
              </div>
            );
          })}
        </div>

        <div style={styles.paginationRow}>
          <button
            style={styles.pageButton}
            onClick={() => setBankPage((p) => Math.max(1, p - 1))}
            disabled={bankPage === 1}
          >
            Önceki
          </button>
          <span style={styles.pageText}>{bankPage} / {bankTotalPages}</span>
          <button
            style={styles.pageButton}
            onClick={() => setBankPage((p) => Math.min(bankTotalPages, p + 1))}
            disabled={bankPage === bankTotalPages}
          >
            Sonraki
          </button>
        </div>
      </section>
    </div>
  );
}

const styles = {
  page: {
    width: '100%',
    minHeight: '100vh',
    margin: 0,
    padding: 0,
    background: 'linear-gradient(180deg, #0d0d0d 0%, #141414 100%)',
    color: '#fff',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '10px',
    overflowX: 'hidden' as const,
  },
  topLayer: {
    width: '100%',
    padding: '14px 20px 10px',
    borderBottom: '1px solid #2a2a2a',
    background: 'linear-gradient(90deg, #FFD70022 0%, transparent 45%)',
    boxSizing: 'border-box' as const,
  },
  title: {
    margin: 0,
    fontSize: '24px',
    letterSpacing: '1px',
    color: '#FFD700',
  },
  subtitle: {
    margin: '6px 0 0 0',
    color: '#9f9f9f',
    fontSize: '12px',
  },
  statsLayer: {
    width: '100%',
    display: 'grid',
    gridTemplateColumns: '1fr minmax(260px, 340px)',
    gap: '10px',
    padding: '0 20px',
    boxSizing: 'border-box' as const,
  },
  statsLeft: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(110px, 1fr))',
    gap: '8px',
  },
  statCard: {
    background: '#1a1a1a',
    border: '1px solid #2f2f2f',
    borderRadius: '6px',
    padding: '8px 10px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '3px',
    minWidth: '110px',
    boxSizing: 'border-box' as const,
  },
  statLabel: {
    color: '#8a8a8a',
    fontSize: '11px',
  },
  statValue: {
    color: '#FFD700',
    fontSize: '16px',
  },
  statsRight: {
    background: '#1a1a1a',
    border: '1px solid #2f2f2f',
    borderRadius: '6px',
    padding: '6px 8px',
    display: 'flex',
    flexDirection: 'column' as const,
    gap: '8px',
  },
  progressTrack: {
    height: '6px',
    background: '#2b2b2b',
    borderRadius: '4px',
    overflow: 'hidden' as const,
  },
  progressFill: {
    height: '100%',
    background: 'linear-gradient(90deg, #FFD700 0%, #FF9F1A 100%)',
  },
  expandRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: '8px',
  },
  expandText: {
    fontSize: '11px',
    color: '#a9a9a9',
  },
  expandButton: {
    background: '#FFD700',
    color: '#000',
    border: '1px solid #b78f00',
    borderRadius: '6px',
    padding: '6px 10px',
    fontWeight: '700' as const,
    fontSize: '12px',
  },
  caretButton: {
    background: '#1a1a1a',
    border: '1px solid #2f2f2f',
    color: '#a9a9a9',
    fontSize: '12px',
    cursor: 'pointer',
    padding: '4px 6px',
    borderRadius: '4px',
  },
  statsToggle: {
    background: 'transparent',
    border: 'none',
    color: '#FFD700',
    fontSize: '16px',
    cursor: 'pointer',
    padding: '2px 6px',
    marginLeft: '4px',
  },
  inventoryLayer: {
    width: '100%',
    padding: '0 20px',
    boxSizing: 'border-box' as const,
  },
  bankLayer: {
    width: '100%',
    padding: '0 0 14px 0',
    boxSizing: 'border-box' as const,
  },
  sectionHeader: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: '8px',
    margin: '10px 0',
  },
  sectionTitle: {
    margin: 0,
    color: '#FFD700',
    fontSize: '15px',
  },
  primaryButton: {
    background: '#4ECDC4',
    color: '#000',
    border: 'none',
    borderRadius: '5px',
    padding: '7px 12px',
    fontWeight: 'bold' as const,
    fontSize: '12px',
  },
  dangerButton: {
    background: '#FF6B6B',
    color: '#fff',
    border: 'none',
    borderRadius: '5px',
    padding: '7px 12px',
    fontWeight: 'bold' as const,
    fontSize: '12px',
    marginRight: '20px',
  },
  loading: {
    padding: '20px',
    textAlign: 'center' as const,
    color: '#9a9a9a',
  },
  inventoryGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(5, 88px)',
    gridAutoRows: '88px',
    gap: '8px',
    justifyContent: 'start',
  },
  inventoryItem: {
    width: '88px',
    height: '88px',
    border: '1px solid #3a3a3a',
    borderRadius: '6px',
    background: '#191919',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative' as const,
    cursor: 'grab',
  },
  itemQty: {
    position: 'absolute' as const,
    right: '6px',
    top: '6px',
    fontSize: '10px',
    color: '#f0f0f0',
    background: '#00000088',
    padding: '1px 4px',
    borderRadius: '4px',
  },
  itemCaption: {
    position: 'absolute' as const,
    left: '6px',
    right: '6px',
    bottom: '5px',
    textAlign: 'center' as const,
    fontSize: '10px',
    color: '#8f8f8f',
    overflow: 'hidden' as const,
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap' as const,
  },
  bankGrid: {
    width: '100%',
    display: 'grid',
    gridTemplateColumns: 'repeat(5, 88px)',
    justifyContent: 'space-between',
    rowGap: '14px',
    padding: '0 20px',
    boxSizing: 'border-box' as const,
  },
  bankSlot: {
    width: '88px',
    height: '88px',
    border: '1px solid #333',
    borderRadius: '7px',
    background: 'transparent',
    position: 'relative' as const,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyIcon: {
    fontSize: '22px',
    color: '#4a4a4a',
  },
  lockedIcon: {
    fontSize: '20px',
    color: '#8a8a8a',
  },
  slotNo: {
    position: 'absolute' as const,
    top: '5px',
    left: '6px',
    fontSize: '10px',
    color: '#6f6f6f',
  },
  slotQty: {
    position: 'absolute' as const,
    right: '6px',
    top: '6px',
    fontSize: '10px',
    color: '#fff',
    background: '#00000088',
    padding: '1px 4px',
    borderRadius: '4px',
  },
  qtyBottomLeft: {
    position: 'absolute' as const,
    left: '6px',
    bottom: '6px',
    fontSize: '11px',
    color: '#fff',
    background: '#00000088',
    padding: '2px 6px',
    borderRadius: '5px',
    fontWeight: '600' as const,
  },
  plusBadge: {
    position: 'absolute' as const,
    right: '6px',
    bottom: '6px',
    fontSize: '10px',
    color: '#000',
    background: '#FFD700',
    padding: '2px 5px',
    borderRadius: '8px',
    fontWeight: 'bold' as const,
  },
  upgradeBadge: {
    position: 'absolute' as const,
    right: '6px',
    top: '6px',
    fontSize: '11px',
    color: '#000',
    background: '#FFD700',
    padding: '2px 6px',
    borderRadius: '6px',
    fontWeight: '700' as const,
  },
  slotPlaceholder: {
    position: 'absolute' as const,
    left: '6px',
    right: '6px',
    bottom: '5px',
    textAlign: 'center' as const,
    color: '#5a5a5a',
    opacity: 0.5,
    fontSize: '9px',
    letterSpacing: '0.4px',
  },
  paginationRow: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '10px',
    margin: '12px 0',
  },
  pageButton: {
    background: '#242424',
    color: '#FFD700',
    border: '1px solid #3a3a3a',
    borderRadius: '5px',
    padding: '6px 12px',
    fontSize: '12px',
  },
  pageText: {
    color: '#9a9a9a',
    fontSize: '12px',
  },
  // Deposit modal styles
  modalOverlay: {
    position: 'fixed' as const,
    inset: 0,
    background: 'rgba(0, 0, 0, 0.75)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 9999,
  },
  modalContent: {
    background: 'linear-gradient(135deg, #1a1a1a 0%, #242424 100%)',
    border: '2px solid #FFD700',
    borderRadius: '8px',
    padding: '20px',
    maxWidth: '420px',
    width: 'calc(100% - 40px)',
    boxShadow: '0 0 30px rgba(255, 215, 0, 0.3)',
  },
  modalHeader: {
    fontSize: '18px',
    fontWeight: '700' as const,
    color: '#FFD700',
    marginBottom: '16px',
    textAlign: 'center' as const,
    letterSpacing: '0.5px',
  },
  modalItemDisplay: {
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    marginBottom: '16px',
    padding: '12px',
    background: '#0f0f0f',
    borderRadius: '6px',
    border: '1px solid #2f2f2f',
  },
  modalItemIcon: {
    width: '64px',
    height: '64px',
    background: '#1a1a1a',
    borderRadius: '4px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: '1px solid #3a3a3a',
    flexShrink: 0,
  },
  modalItemInfo: {
    flex: 1,
  },
  modalItemName: {
    fontSize: '14px',
    fontWeight: '700' as const,
    color: '#FFD700',
    marginBottom: '4px',
  },
  modalItemQty: {
    fontSize: '12px',
    color: '#9a9a9a',
  },
  quantityControl: {
    display: 'grid',
    gridTemplateColumns: 'auto 1fr auto',
    gap: '8px',
    alignItems: 'center',
    marginBottom: '16px',
  },
  quantityLabel: {
    fontSize: '12px',
    color: '#9a9a9a',
  },
  quantityInput: {
    background: '#0f0f0f',
    border: '1px solid #3a3a3a',
    borderRadius: '4px',
    padding: '8px',
    color: '#FFD700',
    textAlign: 'center' as const,
    fontWeight: '700' as const,
    fontSize: '14px',
  },
  quantityButton: {
    background: '#2a2a2a',
    border: '1px solid #3a3a3a',
    borderRadius: '4px',
    color: '#FFD700',
    padding: '6px 12px',
    cursor: 'pointer',
    fontWeight: '700' as const,
    fontSize: '12px',
  },
  modalFooter: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '8px',
  },
  modalButtonConfirm: {
    background: '#FFD700',
    border: 'none',
    color: '#000',
    padding: '10px 16px',
    borderRadius: '4px',
    fontWeight: '700' as const,
    cursor: 'pointer',
    fontSize: '12px',
  },
  modalButtonCancel: {
    background: '#2a2a2a',
    border: '1px solid #3a3a3a',
    color: '#9a9a9a',
    padding: '10px 16px',
    borderRadius: '4px',
    fontWeight: '700' as const,
    cursor: 'pointer',
    fontSize: '12px',
  },
} as const;
