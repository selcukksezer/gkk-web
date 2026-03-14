// ============================================================
// Reputation Utils — PLAN_06/Rep progression tablo kurallari
// ============================================================

export interface ReputationTier {
  min: number;
  max: number | null;
  title: string;
  color: string;
  visual: string;
}

export const REPUTATION_TIERS: ReputationTier[] = [
  { min: 0, max: 5000, title: "Acemi", color: "var(--text-secondary)", visual: "Gri cerceve" },
  { min: 5001, max: 20000, title: "Taninan", color: "var(--color-success)", visual: "Yesil cerceve" },
  { min: 20001, max: 80000, title: "Saygin", color: "var(--rarity-rare)", visual: "Mavi cerceve" },
  { min: 80001, max: 170000, title: "Unlu", color: "var(--rarity-epic)", visual: "Mor cerceve" },
  { min: 170001, max: 280000, title: "Efsanevi", color: "var(--rarity-legendary)", visual: "Turuncu cerceve" },
  { min: 280001, max: 356000, title: "Destansi", color: "var(--color-error)", visual: "Kirmizi cerceve + parliti" },
  { min: 356001, max: null, title: "Imparator", color: "var(--color-gold)", visual: "Altin cerceve + aura" },
];

export function getReputationTier(reputation: number): ReputationTier {
  const rep = Math.max(0, Math.floor(reputation || 0));
  for (const tier of REPUTATION_TIERS) {
    if (rep >= tier.min && (tier.max === null || rep <= tier.max)) {
      return tier;
    }
  }
  return REPUTATION_TIERS[0];
}

export function getReputationPowerContribution(reputation: number): number {
  return Math.max(0, Math.floor((reputation || 0) * 0.1));
}

export function getNextReputationMilestone(reputation: number): { target: number | null; remaining: number } {
  const rep = Math.max(0, Math.floor(reputation || 0));
  const nextTier = REPUTATION_TIERS.find((tier) => tier.min > rep);
  if (!nextTier) {
    return { target: null, remaining: 0 };
  }
  return {
    target: nextTier.min,
    remaining: Math.max(0, nextTier.min - rep),
  };
}
