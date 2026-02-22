import { NextResponse } from "next/server";
import type { ShopOffer } from "@/hooks/useShop";

// ensure API route runs dynamically (not exported as static HTML)
export const dynamic = "force-dynamic";

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