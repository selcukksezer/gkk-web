import { NextResponse } from "next/server";
import type { ShopOffer } from "@/hooks/useShop";
import { supabase } from "@/lib/supabase";
import { getAllItems } from "@/data/ItemDatabase";

export async function GET() {
  // Try to read shop items from Supabase table `shop_items`.
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
    const queryPromise = supabase.from("shop_items").select("*");
    const timeoutPromise = new Promise((_, rej) => setTimeout(() => rej(new Error("supabase query timeout")), 3000));

    const { data, error } = (await Promise.race([queryPromise, timeoutPromise])) as any;

    if (error) {
      console.warn("Supabase shop_items error:", error.message || error);
    }

    if (data && Array.isArray(data) && data.length > 0) {
      const offers: ShopOffer[] = data.map((row: any) => ({
        id: String(row.id ?? row.item_id ?? row.name),
        name: row.name ?? row.title ?? "Unnamed",
        description: row.description ?? "",
        price: Number(row.price ?? 0),
        currency: (row.currency as any) ?? "gems",
        rewards:
          row.rewards ?? (row.reward ? [{ type: row.reward.type ?? "item", amount: row.reward.amount ?? 1, item_id: row.reward.item_id }] : []),
        expires_at: row.expires_at ?? null,
        is_featured: !!row.is_featured,
      }));

      return NextResponse.json(offers);
    }
  } catch (err) {
    console.warn("Error querying Supabase shop_items (timed out or failed):", err);
  }

  // If Supabase returned nothing or errored, fallback to local ItemDatabase (same source Godot uses)
  try {
    const items = getAllItems();
    const offersFromItems: ShopOffer[] = items.map((it) => ({
      id: it.item_id,
      name: it.name,
      description: it.description || "",
      price: Number(it.base_price ?? it.vendor_sell_price ?? 0),
      currency: "gold",
      rewards: [],
      expires_at: null,
      is_featured: false,
    }));
    return NextResponse.json(offersFromItems);
  } catch (err) {
    console.warn("Error building shop items from local ItemDatabase:", err);
  }

  // Final minimal fallback mock
  const offers: ShopOffer[] = [
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

  return NextResponse.json(offers);
}