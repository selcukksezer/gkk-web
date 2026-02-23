# 🎮 Inventory Drag-Drop UX Fix & RPC Deployment Guide

**Date:** February 23, 2026  
**Status:** ✅ Ready to Deploy

---

## 🔍 Issues Fixed

### 1. **RPC 400 Bad Request Error**
- **Problem:** The `equip_item` RPC was receiving incorrect parameters  
- **Root Cause:** Code was passing `item_id` but should pass `row_id` (specific inventory instance)
- **Solution:** Updated all RPC calls to use `row_id` for targeting specific items

### 2. **Inventory "Refresh" / "Flicker" Effect During Drag**
- **Problem:** Items appeared to flicker/reload during drag-drop  
- **Root Causes:**  
  - Missing DragOverlay causing visual confusion
  - Unnecessary full inventory re-fetches after every drag
  - Browser default drag behaviors interfering
  - No Framer Motion layout animations

### 3. **Performance Issues**
- **Problem:** All inventory items re-rendered on every state change
- **Solution:** Wrapped `SortableSlot` with `React.memo()` to prevent unnecessary renders

---

## ✅ Changes Made

### Frontend (TypeScript)

#### [inventoryStore.ts](src/stores/inventoryStore.ts#L200)
- **equipItem():** Now uses `p_row_id` instead of `p_item_id`
- **Optimistic Updates:** State updates immediately without waiting for server (reverts on error)
- **No Auto-Refetch:** Removed `fetchInventory()` calls after operations (server state is source of truth)

#### [InventoryClient.tsx](src/components/game/InventoryClient.tsx)
- **equipItem calls:** Changed from `dragged.item_id` to `dragged.row_id`
- **RPC parameter fix:** All calls now use correct parameter names

#### [InventoryGrid.tsx](src/components/game/InventoryGrid.tsx)
- **React.memo:** Wrapped `SortableSlot` to prevent unnecessary re-renders
- **Framer Motion improvements:**
  - Set `initial={false}` to skip initial animation (smooth during drag)
  - Spring physics: `type: "spring", stiffness: 300, damping: 30`
  - Layout animations for smooth item transitions
- **CSS Classes:** Added `select-none` and `inventory-slot` classes

#### [globals.css](src/app/globals.css#L183)
- **Drag-Drop Optimization:**
  - `-webkit-user-drag: none` — Prevents browser image drag
  - `user-select: none` — No text selection during drag
  - `touch-action: none` — Prevents mobile scroll interference
  - `-webkit-touch-callout: none` — iOS callout prevention
  - `will-change: transform` — GPU acceleration hint

### Backend (SQL Migrations)

#### Corrected RPC Signatures

**Before (❌ BROKEN):**
```sql
CREATE FUNCTION equip_item(p_item_id UUID, p_slot TEXT)
```

**After (✅ FIXED):**
```sql
CREATE FUNCTION equip_item(p_row_id UUID, p_slot TEXT)
```

---

## 🚀 Deployment Steps

### Step 1: Drop Old Functions (If They Exist)

Copy the SQL below into Supabase SQL Editor:  
https://app.supabase.com/projects/znvsyzstmxhqvdkkmgdt/sql/new

```sql
DROP FUNCTION IF EXISTS public.equip_item(UUID, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.equip_item(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.unequip_item(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.unequip_item(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.remove_inventory_item_by_row(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.remove_inventory_item_by_row(UUID, INT) CASCADE;
```

**Click "Run"** and wait for success.

### Step 2: Deploy New RPC Functions

Copy the entire contents of [deploy-manual.sql](../deploy-manual.sql) into the same SQL Editor and click **"Run"**.

This will create:
- ✅ `equip_item(p_row_id UUID, p_slot TEXT)` — Equip an item by its instance
- ✅ `unequip_item(p_slot TEXT)` — Unequip from a slot
- ✅ `get_equipped_items()` — Fetch all equipped items
- ✅ `remove_inventory_item_by_row(p_row_id UUID, p_quantity INT)` — Delete by row instance
- ✅ `swap_slots(p_from_slot INT, p_to_slot INT)` — Swap two positions

### Step 3: Verify in App

```bash
cd gkk-web
npm run dev
```

**Expected Behavior:**
- ✅ Drag item to equipment slot: Should equip smoothly with no flicker
- ✅ Drag item to trash: Should delete with no page reload
- ✅ Console shows: `[dnd] end active=... over=equip-chest` (no 400 error)
- ✅ Items move smoothly using Spring animations (not teleporting)

---

## 🧪 Testing Checklist

| Feature | Expected | Status |
|---------|----------|--------|
| Equip item via drag | Spring animation, no flicker | ⭕ Test |
| Delete item via drag to trash | Smooth fade, no reload | ⭕ Test |
| Swap inventory slots | Smooth slide transition | ⭕ Test |
| Drag multiple times | No "refresh" feeling | ⭕ Test |
| Mobile drag (touch) | Smooth, no page scroll | ⭕ Test |
| Console errors | None (no 400/404s) | ⭕ Test |

---

## 📝 Technical Details

### Row ID vs Item ID

**Why `row_id` is critical:**
```
inventory table:
- row_id: UUID (unique instance: "b236cfce-114d-4802...")
- item_id: UUID (shared by identical items: "sword-001")
- user_id: UUID
- quantity: 3
- is_equipped: true

Problem: If you have 3 swords, equip_item(item_id) doesn't know WHICH one!
Solution: equip_item(row_id) targets the specific inventory slot.
```

### Optimistic Updates

**Old Flow (Slow):**
1. User drags item → UI waits 500ms
2. Server updates DB → response comes back  
3. UI re-renders → "flicker" effect

**New Flow (Smooth):**
1. User drags item → UI updates INSTANTLY
2. Server updates DB in background
3. If error: UI reverts
4. No flicker, feels responsive

---

## 🔗 Related Files

- Migration (gkk): [`supabase/migrations/20260223124000_add_equip_rpcs.sql`](../../gkk/supabase/migrations/20260223124000_add_equip_rpcs.sql)
- Migration (gkk-web): [`supabase/migrations/20260223124000_add_equip_rpcs.sql`](supabase/migrations/20260223124000_add_equip_rpcs.sql)
- Store: [`src/stores/inventoryStore.ts`](src/stores/inventoryStore.ts)
- Component: [`src/components/game/InventoryClient.tsx`](src/components/game/InventoryClient.tsx)
- Grid: [`src/components/game/InventoryGrid.tsx`](src/components/game/InventoryGrid.tsx)
- Styles: [`src/app/globals.css`](src/app/globals.css)

---

## 🎯 Testing After Deploy

### Console Test (Should see no errors):
```javascript
// Open DevTools (F12) → Console
// Equip an item via drag-drop
// Should see: [dnd] end active=xxx over=equip-chest
// Should NOT see: 400 Bad Request or 404 Not Found
```

### Performance Test:
```javascript
// Performance tab → Record
// Drag item 5 times
// Should see smooth Spring animations
// Should NOT see sudden "layout shift" or flickering
```

---

## 🆘 Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| 400 Bad Request | Old RPC signature still deployed | Redeploy from deploy-manual.sql |
| Equip fails silently | `row_id` not found | Check item exists in inventory table |
| Still seeing flicker | Browser cache | Hard refresh (Ctrl+Shift+R) |
| Drag not working | Touch-action CSS conflict | Check globals.css is loaded |

---

**Ready to ship!** 🚀

After deployment, the inventory will feel smooth and responsive—no more "refresh" effect during drag-drop operations.
