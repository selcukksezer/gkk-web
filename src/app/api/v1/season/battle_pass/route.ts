import { NextResponse } from "next/server";
import type { BattlePassInfo } from "@/hooks/useSeason";

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