import { NextResponse } from "next/server";
import type { ShopOffer } from "@/hooks/useShop";
import { supabase } from "@/lib/supabase";
import { getAllItems } from "@/data/ItemDatabase";

export async function GET() {
  // Read shop items from Supabase `items` table.
  // Visibility and currency are controlled by items.shop_available / items.shop_currency.
  // If Supabase env vars aren't set, immediately return a small mock.
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey) {
    // Quick fallback when running in environments without Supabase configured
    const fallback: ShopOffer[] = [
      {
        id: "offer1",
        name: "Başlangıç Paketi",
        description: "Ücretsiz örnek teklif",
        price: 0,
        currency: "gems",
        rewards: [{ type: "gem", amount: 100 }],
        expires_at: null,
        is_featured: false,
      },
    ];
    return NextResponse.json(fallback);
  }

  try {
    // Apply a short timeout when querying Supabase so server routes don't hang.
    const queryPromise = supabase
      .from("items")
      .select("id,name,description,icon,rarity,type,is_stackable,max_stack,base_price,vendor_sell_price,shop_available,shop_currency")
      .eq("shop_available", true)
      .order("id", { ascending: true });
    const timeoutPromise = new Promise((_, rej) => setTimeout(() => rej(new Error("supabase query timeout")), 3000));

    const { data, error } = (await Promise.race([queryPromise, timeoutPromise])) as any;

    console.log("🔍 [SHOP API] Filtered query (shop_available=true):");
    console.log("   Error:", error ? error.message : "none");
    console.log("   Data count:", data?.length ?? 0);

    if (error) {
      console.warn("Supabase items query error:", error.message || error);
    }

    if (data && Array.isArray(data) && data.length > 0) {
      console.log(`✅ [SHOP API] Returning ${data.length} items from filtered query`);
      const offers: ShopOffer[] = data.map((row: any) => ({
        id: String(row.id ?? row.name),
        item_id: String(row.id ?? "unknown"),
        name: row.name ?? "Unnamed",
        description: row.description ?? "",
        price: Number(row.base_price ?? row.vendor_sell_price ?? 0),
        currency: row.shop_currency === "gems" ? "gems" : "gold",
        icon: row.icon ?? "📦",
        rarity: row.rarity ?? "common",
        item_type: row.type ?? null,
        is_stackable: row.is_stackable ?? false,
        max_stack: Number(row.max_stack ?? 1),
        rewards: [],
        expires_at: row.expires_at ?? null,
        is_featured: !!row.is_featured,
      })) as ShopOffer[];

      return NextResponse.json(offers);
    }

    // shop_available filtreli sorgu boş dönerse, migration/policy farklarına karşı
    // items tablosunu filtresiz bir kez daha deneyelim.
    console.log("⚠️  [SHOP API] Filtered query returned empty, trying legacy query (no filter)...");
    
    const { data: legacyData, error: legacyError } = await supabase
      .from("items")
      .select("id,name,description,icon,rarity,type,is_stackable,max_stack,base_price,vendor_sell_price")
      .order("id", { ascending: true });

    console.log("🔍 [SHOP API] Legacy query (no filter):");
    console.log("   Error:", legacyError ? legacyError.message : "none");
    console.log("   Data count:", legacyData?.length ?? 0);

    if (legacyError) {
      console.warn("Supabase legacy items query error:", legacyError.message || legacyError);
    } else if (legacyData && Array.isArray(legacyData) && legacyData.length > 0) {
      console.log(`✅ [SHOP API] Returning ${legacyData.length} items from legacy query`);
      const offers: ShopOffer[] = legacyData.map((row: any) => ({
        id: String(row.id ?? row.name),
        item_id: String(row.id ?? "unknown"),
        name: row.name ?? "Unnamed",
        description: row.description ?? "",
        price: Number(row.base_price ?? row.vendor_sell_price ?? 0),
        currency: "gold",
        icon: row.icon ?? "📦",
        rarity: row.rarity ?? "common",
        item_type: row.type ?? null,
        is_stackable: row.is_stackable ?? false,
        max_stack: Number(row.max_stack ?? 1),
        rewards: [],
        expires_at: null,
        is_featured: false,
      })) as ShopOffer[];

      return NextResponse.json(offers);
    }
  } catch (err) {
    console.warn("Error querying Supabase items (timed out or failed):", err);
  }

  // If Supabase returned nothing or errored, fallback to local ItemDatabase (same source Godot uses)
  console.log("📦 [SHOP API] Supabase queries failed/empty, using local ItemDatabase fallback...");
  try {
    const items = getAllItems();
    const offersFromItems: ShopOffer[] = items.map((it) => ({
      id: it.item_id,
      item_id: it.item_id,  // NEW: explicit item_id
      name: it.name,
      description: it.description || "",
      price: Number(it.base_price ?? it.vendor_sell_price ?? 0),
      currency: "gold",
      icon: it.icon,
      rarity: it.rarity,
      item_type: it.item_type,
      is_stackable: it.is_stackable,
      max_stack: it.max_stack,
      rewards: [],
      expires_at: null,
      is_featured: false,
    })) as ShopOffer[];
    return NextResponse.json(offersFromItems);
  } catch (err) {
    console.warn("Error building shop items from local ItemDatabase:", err);
  }

  // Final minimal fallback mock
  const offers: ShopOffer[] = [
    {
      id: "offer1",
      item_id: "offer1",
      name: "Başlangıç Paketi",
      description: "Ücretsiz örnek teklif",
      price: 0,
      currency: "gems",
      rewards: [{ type: "gem", amount: 100 }],
      expires_at: null,
      is_featured: false,
    },
  ];

  return NextResponse.json(offers);
}