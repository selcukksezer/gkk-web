// ============================================================
// Ocean Sunset Color Palette — Central Source of Truth
// All game colors derived from this palette
// ============================================================

export const OCEAN_SUNSET_PALETTE = {
  // ========== Foundational Tones ==========
  inkBlack: "#001219",
  darkTeal: "#005f73",
  darkCyan: "#0a9396",
  pearlAqua: "#94d2bd",
  wheat: "#e9d8a6",
  goldenOrange: "#ee9b00",
  burntCaramel: "#ca6702",
  rustySpice: "#bb3e03",
  oxidizedIron: "#ae2012",
  brownRed: "#9b2226",
} as const;

// ========== Color Aliases ==========
export const COLOR_ROLES = {
  // Primary Brand Color
  primary: OCEAN_SUNSET_PALETTE.goldenOrange,
  primaryLight: "#f4b942",
  primaryDark: OCEAN_SUNSET_PALETTE.burntCaramel,

  // Secondary Brand Color
  secondary: OCEAN_SUNSET_PALETTE.pearlAqua,
  secondaryLight: "#b8e0d5",
  secondaryDark: OCEAN_SUNSET_PALETTE.darkCyan,

  // Status Colors
  success: OCEAN_SUNSET_PALETTE.pearlAqua,
  error: OCEAN_SUNSET_PALETTE.brownRed,
  warning: OCEAN_SUNSET_PALETTE.goldenOrange,
  info: OCEAN_SUNSET_PALETTE.darkCyan,
  danger: OCEAN_SUNSET_PALETTE.oxidizedIron,

  // Game Resources
  gold: OCEAN_SUNSET_PALETTE.goldenOrange,
  gems: OCEAN_SUNSET_PALETTE.rustySpice,
  energy: OCEAN_SUNSET_PALETTE.pearlAqua,
  health: OCEAN_SUNSET_PALETTE.brownRed,
  xp: OCEAN_SUNSET_PALETTE.wheat,

  // Backgrounds
  bgDark: OCEAN_SUNSET_PALETTE.inkBlack,
  bgDarker: "#000c0f",
  bgCard: OCEAN_SUNSET_PALETTE.darkTeal,
  bgElevated: OCEAN_SUNSET_PALETTE.darkCyan,
  bgInput: "#003d47",
  bgSurface: OCEAN_SUNSET_PALETTE.darkTeal,

  // Text
  textPrimary: OCEAN_SUNSET_PALETTE.wheat,
  textSecondary: OCEAN_SUNSET_PALETTE.pearlAqua,
  textMuted: OCEAN_SUNSET_PALETTE.darkTeal,
  textAccent: OCEAN_SUNSET_PALETTE.goldenOrange,

  // Borders
  borderDefault: OCEAN_SUNSET_PALETTE.darkTeal,
  borderLight: OCEAN_SUNSET_PALETTE.darkCyan,
  borderAccent: OCEAN_SUNSET_PALETTE.goldenOrange,

  // Rarity
  rarity: {
    common: OCEAN_SUNSET_PALETTE.wheat,
    uncommon: OCEAN_SUNSET_PALETTE.pearlAqua,
    rare: OCEAN_SUNSET_PALETTE.darkCyan,
    epic: OCEAN_SUNSET_PALETTE.goldenOrange,
    legendary: OCEAN_SUNSET_PALETTE.rustySpice,
    mythic: OCEAN_SUNSET_PALETTE.brownRed,
  },
} as const;

export const getRarityColor = (rarity: string): string => {
  const rarityKey = rarity.toLowerCase() as keyof typeof COLOR_ROLES.rarity;
  return COLOR_ROLES.rarity[rarityKey] || COLOR_ROLES.rarity.common;
};

export const getRarityLabel = (rarity: string): string => {
  const labels: Record<string, string> = {
    common: "Sıradan",
    uncommon: "Nadir",
    rare: "Ender",
    epic: "Efsanevi",
    legendary: "Lejyoner",
    mythic: "Mitolojik",
  };
  return labels[rarity.toLowerCase()] || "Bilinmeyen";
};
