// ============================================================
// Game Constants — Kaynak: game_config.json (206 satır)
// Tüm oyun sabitleri
// ============================================================

export const GAME_CONFIG = {
  game: {
    version: "0.1.0",
    apiVersion: "v1",
    minClientVersion: "0.1.0",
  },

  energy: {
    maxEnergy: 100,
    regenRate: 1,
    regenInterval: 180, // seconds
    refillCostGems: 50,
    dailyRefillsLimit: 5,
  },

  potion: {
    maxTolerance: 100,
    toleranceDecayRate: 1,
    toleranceDecayInterval: 21600, // 6 hours
    overdoseThreshold: 0.8,
    overdoseBaseRisk: 0.05,
    hospitalDurationHours: { min: 2, max: 12 },
  },

  pvp: {
    energyCost: 15,
    revengeTimeWindow: 86400, // 24 hours
    revengeEnergyCost: 0,
    criticalChance: 0.1,
    hospitalDurationCritical: 28800, // 8 hours
    goldStealPercentage: 0.05,
    reputationLossPerAttack: -3,
    reputationGainDefend: 5,
    banditReputationThreshold: -50,
    heroReputationThreshold: 50,
    maxAttacksPerDay: 50,
  },

  quest: {
    energyCosts: { easy: 5, medium: 10, hard: 15, dungeon: 20 },
    successRates: { easy: 1.0, medium: 0.95, hard: 0.85, dungeon: 0.75 },
    criticalFailureRates: { easy: 0.0, medium: 0.01, hard: 0.05, dungeon: 0.1 },
    dailyQuestResetHour: 0,
    maxActiveQuests: 10,
  },

  dungeon: {
    energyCosts: {
      easy: 5,
      medium: 10,
      hard: 15,
      dungeon_solo: 25,
      dungeon_group: 35,
    },
    baseSuccessRates: {
      easy: 0.85,
      medium: 0.7,
      hard: 0.55,
      dungeon_solo: 0.45,
      dungeon_group: 0.6,
    },
    hospitalizationRates: {
      easy: 0.0,
      medium: 0.0,
      hard: 0.05,
      dungeon_solo: 0.15,
      dungeon_group: 0.1,
    },
    hospitalDurationMinutes: {
      hard: [60, 120],
      dungeon_solo: [120, 360],
      dungeon_group: [180, 480],
    },
    successRateWeights: {
      gear: 0.2,
      skill: 0.15,
      level: 0.1,
      difficulty: 0.15,
      danger: 0.1,
    },
    minSuccessRate: 0.1,
    maxSuccessRate: 0.95,
    criticalSuccessChance: 0.1,
    criticalSuccessMultiplier: 1.5,
    failureRewardPercent: 0.3,
    maxParallelDungeons: 1,
    dungeonCooldownSeconds: 0,
    lootDropChance: 0.4,
    groupBonusMultiplier: 1.25,
  },

  hospital: {
    baseDurationHours: 2,
    maxDurationHours: 12,
    gemReleaseCostPerMinute: 3,
    healerBaseCost: 1000,
    healerSuccessRateMin: 0.3,
    healerSuccessRateMax: 0.7,
    guildHelpReductionPercent: 20,
    guildHelpCooldown: 3600,
  },

  market: {
    orderFeePercent: 0.02,
    maxOrdersPerPlayer: 50,
    orderExpiryDays: 7,
    priceChangeAlertPercent: 10,
    regions: ["central", "north", "south", "east", "west"] as const,
    arbitrageEnabled: true,
  },

  guild: {
    creationCost: 10000,
    maxMembers: {
      level_1: 30,
      level_2: 40,
      level_3: 50,
      level_4: 75,
      level_5: 100,
    },
    defaultTaxRate: 0.05,
    maxTaxRate: 0.2,
    warDurationHours: 24,
    warCooldownHours: 72,
  },

  enhancement: {
    successRates: [1.0, 1.0, 1.0, 1.0, 0.8, 0.8, 0.6, 0.6, 0.4, 0.2, 0.1],
    destructionRates: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.1, 0.15],
    statBonusPerLevel: 0.1,
    scrollCostMultiplier: [1, 1, 1, 1, 2, 2, 3, 3, 5, 8, 10],
  },

  monetization: {
    energyRefillGemCost: 50,
    hospitalReleaseGemPerMinute: 3,
    starterPackCost: 9.99,
    premiumCurrencyPacks: [
      { gems: 100, price: 0.99 },
      { gems: 500, price: 4.99, bonus: 50 },
      { gems: 1200, price: 9.99, bonus: 200 },
      { gems: 2500, price: 19.99, bonus: 500 },
      { gems: 6500, price: 49.99, bonus: 1500 },
      { gems: 14000, price: 99.99, bonus: 4000 },
    ],
  },

  season: {
    durationDays: 90,
    rewardsTiers: [
      { rank: 1, gems: 5000, title: "Season Champion" },
      { rank: 10, gems: 2000, title: "Elite Warrior" },
      { rank: 50, gems: 1000, title: "Master" },
      { rank: 100, gems: 500, title: "Expert" },
    ],
    resetItems: ["gold", "items", "level", "buildings"],
    persistentItems: ["gems", "cosmetics", "titles", "achievements"],
  },

  telemetry: {
    enabled: true,
    batchSize: 10,
    flushInterval: 60,
    trackPerformance: true,
    trackErrors: true,
    trackGameplay: true,
  },

  cache: {
    playerCacheTtl: 300,
    marketCacheTtl: 10,
    guildCacheTtl: 60,
    questCacheTtl: 300,
    configCacheTtl: 3600,
  },

  rateLimits: {
    apiRequestsPerMinute: 60,
    questCompletionsPerHour: 20,
    marketOrdersPerHour: 30,
    pvpAttacksPerHour: 10,
    chatMessagesPerMinute: 10,
  },
} as const;
