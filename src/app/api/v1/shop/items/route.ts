import { NextResponse } from "next/server";
import type { ShopOffer } from "@/hooks/useShop";

// Static API route — compatible with output: export (Capacitor builds)
export const dynamic = "force-static";

export async function GET() {
  // simple mock response, adjust as needed
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