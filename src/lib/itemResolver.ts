// ============================================================
// Item Resolver — Supabase'den item metadata çeken util
// ============================================================

import { supabase } from '@/lib/supabase';

export interface ItemMeta {
  id: string;
  name: string;
  type: string;
  description?: string;
  rarity?: string;
  icon?: string;
  is_stackable?: boolean;
  max_stack?: number;
  base_price?: number;
  vendor_sell_price?: number;
  attack?: number;
  defense?: number;
  health?: number;
  power?: number;
  energy_restore?: number;
  [key: string]: any;
}

let itemCache: Map<string, ItemMeta> = new Map();
let cacheTime = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 dakika

/**
 * Supabase'den item metadata çeker ve cache'ler
 */
export async function getItemFromSupabase(itemId: string): Promise<ItemMeta | null> {
  try {
    const { data, error } = await supabase
      .from('items')
      .select('*')
      .eq('id', itemId)
      .single();

    if (error) {
      console.warn(`[itemResolver] Item not found in Supabase: ${itemId}`, error);
      return null;
    }

    if (data) {
      itemCache.set(itemId, data);
    }
    return data || null;
  } catch (err) {
    console.error(`[itemResolver] Error fetching item ${itemId}:`, err);
    return null;
  }
}

/**
 * Cache'den item al veya ek bir hızlı lookup
 */
export function getItemFromCache(itemId: string): ItemMeta | null {
  return itemCache.get(itemId) || null;
}

/**
 * Batch items çek (performance için)
 */
export async function getItemsFromSupabase(itemIds: string[]): Promise<Map<string, ItemMeta>> {
  const result = new Map<string, ItemMeta>();
  const missingIds: string[] = [];

  // Önce cache'den al
  for (const id of itemIds) {
    const cached = itemCache.get(id);
    if (cached) {
      result.set(id, cached);
    } else {
      missingIds.push(id);
    }
  }

  // Cache'de olmayan'ları DB'den çek
  if (missingIds.length > 0) {
    try {
      const { data, error } = await supabase
        .from('items')
        .select('*')
        .in('id', missingIds);

      if (error) {
        console.warn('[itemResolver] Batch fetch error:', error);
      } else if (data && Array.isArray(data)) {
        for (const item of data) {
          itemCache.set(item.id, item);
          result.set(item.id, item);
        }
      }
    } catch (err) {
      console.error('[itemResolver] Error in batch fetch:', err);
    }
  }

  return result;
}

/**
 * Cache'i temizle (logout vs.)
 */
export function clearItemCache(): void {
  itemCache.clear();
  cacheTime = 0;
}
