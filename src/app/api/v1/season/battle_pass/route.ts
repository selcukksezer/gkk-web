import { NextResponse } from "next/server";
import type { BattlePassInfo } from "@/hooks/useSeason";

// Static API route — compatible with output: export (Capacitor builds)
export const dynamic = "force-static";

export async function GET() {
  const info: BattlePassInfo = {
    currentTier: 1,
    currentXp: 0,
    xpPerTier: 1000,
    maxTiers: 100,
    isPremium: false,
    claimedRewards: [],
  };
  return NextResponse.json(info);
}