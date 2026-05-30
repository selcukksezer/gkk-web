#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";

const ROOT = process.cwd();
dotenv.config({ path: path.join(ROOT, ".env") });
dotenv.config({ path: path.join(ROOT, ".env.local") });

const SUPABASE_URL =
  process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error("Missing Supabase env vars");
  process.exit(1);
}

const CLASS_CONFIGS = [
  {
    key: "warrior",
    label: "Warrior",
    email: process.env.DUNGEON_SMOKE_WARRIOR_A_EMAIL,
    password: process.env.DUNGEON_SMOKE_WARRIOR_A_PASSWORD,
  },
  {
    key: "alchemist",
    label: "Alchemist",
    email: process.env.DUNGEON_SMOKE_ALCHEMIST_A_EMAIL,
    password: process.env.DUNGEON_SMOKE_ALCHEMIST_A_PASSWORD,
  },
  {
    key: "shadow",
    label: "Shadow",
    email: process.env.DUNGEON_SMOKE_SHADOW_A_EMAIL,
    password: process.env.DUNGEON_SMOKE_SHADOW_A_PASSWORD,
  },
];

const DEFAULT_SCENARIOS = [
  {
    id: "normal",
    dungeonId: process.env.SMOKE_DUNGEON_NORMAL_ID || "dng_036",
    dungeonName: process.env.SMOKE_DUNGEON_NORMAL_NAME || "Nanorum Fodina",
    runs: Number(process.env.SMOKE_RUNS_NORMAL || 700),
    delayMs: Number(process.env.SMOKE_DELAY_NORMAL_MS || 10),
    expectHospitalPressure: false,
  },
  {
    id: "hard",
    dungeonId: process.env.SMOKE_DUNGEON_HARD_ID || "dng_059",
    dungeonName: process.env.SMOKE_DUNGEON_HARD_NAME || "Fati Thronus",
    runs: Number(process.env.SMOKE_RUNS_HARD || 300),
    delayMs: Number(process.env.SMOKE_DELAY_HARD_MS || 20),
    expectHospitalPressure: true,
  },
];

const REPORT_EVERY = Number(process.env.SMOKE_REPORT_EVERY || 100);
const CLEANUP_EVERY = Number(process.env.SMOKE_CLEANUP_EVERY || 50);
const OUTPUT_DIR = path.join(ROOT, "scripts", "output");

const NORMALIZE_PLAYERS = String(process.env.SMOKE_NORMALIZE_PLAYERS || "true") === "true";
const BASELINE_LEVEL = Number(process.env.SMOKE_BASELINE_LEVEL || 50);
const BASELINE_POWER = Number(process.env.SMOKE_BASELINE_POWER || 25000);
const BASELINE_LUCK = Number(process.env.SMOKE_BASELINE_LUCK || 60);
const BASELINE_DEFENSE = Number(process.env.SMOKE_BASELINE_DEFENSE || 60);
const BASELINE_REPUTATION = Number(process.env.SMOKE_BASELINE_REPUTATION || 100);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function pct(part, whole) {
  if (!whole) return 0;
  return (part / whole) * 100;
}

function mean(values) {
  if (!values.length) return 0;
  return values.reduce((sum, x) => sum + x, 0) / values.length;
}

function percentile(values, p) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

function ci95(rate, n) {
  if (!n) return { low: 0, high: 0 };
  const p = rate / 100;
  const z = 1.96;
  const se = Math.sqrt((p * (1 - p)) / n);
  return {
    low: Math.max(0, (p - z * se) * 100),
    high: Math.min(100, (p + z * se) * 100),
  };
}

function ensureClassEnv() {
  const missing = CLASS_CONFIGS.filter((c) => !c.email || !c.password).map((c) => c.label);
  if (missing.length) {
    console.error(`Missing class credentials for: ${missing.join(", ")}`);
    console.error("Required: DUNGEON_SMOKE_<CLASS>_A_EMAIL / DUNGEON_SMOKE_<CLASS>_A_PASSWORD");
    process.exit(1);
  }
}

async function login(client, email, password) {
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error || !data?.session) {
    throw new Error(`Login failed (${email}): ${error?.message || "unknown"}`);
  }
  return data.user;
}

async function getUserProfile(client, authId) {
  const { data, error } = await client
    .from("users")
    .select("auth_id, character_class, level, power, luck, defense, energy")
    .eq("auth_id", authId)
    .single();
  if (error) throw new Error(`users read failed: ${error.message}`);
  return data;
}

async function getDungeonEnergyCost(adminClient, dungeonId) {
  const { data, error } = await adminClient
    .from("dungeons")
    .select("id, name, energy_cost")
    .eq("id", dungeonId)
    .single();
  if (error) throw new Error(`dungeon read failed (${dungeonId}): ${error.message}`);
  return data;
}

async function ensureEnergy(client, authId, requiredEnergy) {
  const { data, error } = await client
    .from("users")
    .select("energy")
    .eq("auth_id", authId)
    .single();
  if (error) throw new Error(`energy read failed: ${error.message}`);

  if ((data?.energy || 0) >= requiredEnergy) return;

  const { error: updateError } = await client
    .from("users")
    .update({ energy: requiredEnergy + 5000 })
    .eq("auth_id", authId);
  if (updateError) {
    throw new Error(`energy update failed: ${updateError.message}`);
  }
}

async function recoverFromHospital(client, authId) {
  const { error } = await client
    .from("users")
    .update({ hospital_until: null })
    .eq("auth_id", authId);
  if (error) {
    return { ok: false, error: error.message };
  }
  return { ok: true };
}

async function clearDungeonStatsForScenarios(client, authId, scenarios) {
  const dungeonIds = scenarios.map((s) => s.dungeonId);
  const { error } = await client
    .from("player_dungeon_stats")
    .delete()
    .eq("player_id", authId)
    .in("dungeon_id", dungeonIds);

  if (error) {
    return { ok: false, error: error.message };
  }

  return { ok: true };
}

async function clearInventoryNonEquipped(client, authId) {
  const { data, error } = await client
    .from("inventory")
    .delete()
    .eq("user_id", authId)
    .eq("is_equipped", false)
    .select("row_id");

  if (error) {
    return { ok: false, deletedCount: 0, error: error.message };
  }

  return {
    ok: true,
    deletedCount: Array.isArray(data) ? data.length : 0,
  };
}

async function clearAllInventory(client, authId) {
  const { data, error } = await client
    .from("inventory")
    .delete()
    .eq("user_id", authId)
    .select("row_id");

  if (error) {
    return { ok: false, deletedCount: 0, error: error.message };
  }

  return {
    ok: true,
    deletedCount: Array.isArray(data) ? data.length : 0,
  };
}

async function normalizePlayerState(client, authId, scenarios) {
  const updatePayload = {
    level: BASELINE_LEVEL,
    power: BASELINE_POWER,
    luck: BASELINE_LUCK,
    defense: BASELINE_DEFENSE,
    reputation: BASELINE_REPUTATION,
    hospital_until: null,
    prison_until: null,
    energy: 200000,
  };

  const { error: userUpdateError } = await client
    .from("users")
    .update(updatePayload)
    .eq("auth_id", authId);
  if (userUpdateError) {
    return { ok: false, error: `user normalize failed: ${userUpdateError.message}` };
  }

  const inventoryResult = await clearAllInventory(client, authId);
  if (!inventoryResult.ok) {
    return { ok: false, error: `inventory normalize failed: ${inventoryResult.error}` };
  }

  const statsResult = await clearDungeonStatsForScenarios(client, authId, scenarios);
  if (!statsResult.ok) {
    return { ok: false, error: `dungeon stats normalize failed: ${statsResult.error}` };
  }

  return {
    ok: true,
    normalized: {
      ...updatePayload,
      inventoryDeleted: inventoryResult.deletedCount,
    },
  };
}

function createScenarioStats() {
  return {
    requestedRuns: 0,
    completedRuns: 0,
    successes: 0,
    failures: 0,
    criticalHits: 0,
    totalGold: 0,
    totalXp: 0,
    totalItems: 0,
    runsWithLoot: 0,
    multiDropRuns: 0,
    hospitalizations: 0,
    hospitalDurationsSec: [],
    inventoryFullHits: 0,
    inventoryCleanupCount: 0,
    inventoryRowsDeleted: 0,
    inventoryCleanupFailures: 0,
    errors: {},
    rawErrors: 0,
    itemIds: {},
    itemRarities: {},
    itemTypes: {},
  };
}

function addError(stats, errorCode) {
  const key = errorCode || "unknown_error";
  stats.errors[key] = (stats.errors[key] || 0) + 1;
  stats.rawErrors += 1;
}

async function fetchItemMeta(adminClient, cache, itemId) {
  if (!itemId) return null;
  if (cache[itemId]) return cache[itemId];

  const { data } = await adminClient
    .from("items")
    .select("id, rarity, type")
    .eq("id", itemId)
    .single();

  const meta = {
    id: itemId,
    rarity: data?.rarity || "unknown",
    type: data?.type || "unknown",
  };
  cache[itemId] = meta;
  return meta;
}

async function runScenario(client, adminClient, authId, classLabel, scenario, itemMetaCache) {
  const stats = createScenarioStats();
  stats.requestedRuns = scenario.runs;

  console.log(`\n  Scenario: ${scenario.id} (${scenario.dungeonName} / ${scenario.dungeonId})`);
  console.log(`  Planned runs: ${scenario.runs}`);

  const initialCleanup = await clearInventoryNonEquipped(client, authId);
  if (initialCleanup.ok) {
    stats.inventoryCleanupCount += 1;
    stats.inventoryRowsDeleted += initialCleanup.deletedCount;
    console.log(`  Initial inventory cleanup deleted=${initialCleanup.deletedCount}`);
  } else {
    stats.inventoryCleanupFailures += 1;
    addError(stats, `inventory_cleanup_failed:${initialCleanup.error}`);
  }

  for (let i = 0; i < scenario.runs; i++) {
    const runNo = i + 1;

    if (runNo % CLEANUP_EVERY === 0) {
      const periodicCleanup = await clearInventoryNonEquipped(client, authId);
      if (periodicCleanup.ok) {
        stats.inventoryCleanupCount += 1;
        stats.inventoryRowsDeleted += periodicCleanup.deletedCount;
      } else {
        stats.inventoryCleanupFailures += 1;
        addError(stats, `inventory_cleanup_failed:${periodicCleanup.error}`);
      }
    }

    const { data, error } = await client.rpc("attack_dungeon", {
      p_dungeon_id: scenario.dungeonId,
    });

    if (error) {
      addError(stats, error.message || "rpc_error");
      if (scenario.expectHospitalPressure && String(error.message || "").includes("in_hospital")) {
        const recovery = await recoverFromHospital(client, authId);
        if (!recovery.ok) {
          addError(stats, `hospital_recovery_failed:${recovery.error}`);
        }
      }
      if (runNo % REPORT_EVERY === 0) {
        console.log(`    ${runNo}/${scenario.runs} rpc errors: ${stats.rawErrors}`);
      }
      await sleep(scenario.delayMs);
      continue;
    }

    if (data?.error) {
      addError(stats, data.error);
      if (data.error === "in_hospital") {
        const recovery = await recoverFromHospital(client, authId);
        if (!recovery.ok) {
          addError(stats, `hospital_recovery_failed:${recovery.error}`);
        }
      }
      if (runNo % REPORT_EVERY === 0) {
        console.log(`    ${runNo}/${scenario.runs} app errors: ${stats.rawErrors}`);
      }
      await sleep(scenario.delayMs);
      continue;
    }

    stats.completedRuns += 1;
    const success = Boolean(data.success);
    const itemIds = Array.isArray(data.items) ? data.items : [];

    if (success) {
      stats.successes += 1;
      stats.totalGold += Number(data.gold || 0);
      stats.totalXp += Number(data.xp || 0);
      if (data.is_critical) stats.criticalHits += 1;
    } else {
      stats.failures += 1;
    }

    if (data.inventory_full) {
      stats.inventoryFullHits += 1;
      const emergencyCleanup = await clearInventoryNonEquipped(client, authId);
      if (emergencyCleanup.ok) {
        stats.inventoryCleanupCount += 1;
        stats.inventoryRowsDeleted += emergencyCleanup.deletedCount;
      } else {
        stats.inventoryCleanupFailures += 1;
        addError(stats, `inventory_cleanup_failed:${emergencyCleanup.error}`);
      }
    }
    if (data.hospitalized) {
      stats.hospitalizations += 1;
      if (Number.isFinite(data.hospital_duration)) {
        stats.hospitalDurationsSec.push(Math.max(0, Number(data.hospital_duration || 0)));
      }
    }

    const dropCount = itemIds.length;
    stats.totalItems += dropCount;
    if (dropCount > 0) stats.runsWithLoot += 1;
    if (dropCount > 1) stats.multiDropRuns += 1;

    for (const itemId of itemIds) {
      stats.itemIds[itemId] = (stats.itemIds[itemId] || 0) + 1;
      const meta = await fetchItemMeta(adminClient, itemMetaCache, itemId);
      const rarity = meta?.rarity || "unknown";
      const type = meta?.type || "unknown";
      stats.itemRarities[rarity] = (stats.itemRarities[rarity] || 0) + 1;
      stats.itemTypes[type] = (stats.itemTypes[type] || 0) + 1;
    }

    if (runNo % REPORT_EVERY === 0) {
      const successRate = pct(stats.successes, stats.completedRuns || 1).toFixed(2);
      const hospRate = pct(stats.hospitalizations, stats.completedRuns || 1).toFixed(2);
      const lootRate = pct(stats.runsWithLoot, stats.completedRuns || 1).toFixed(2);
      console.log(
        `    ${runNo}/${scenario.runs} success=${successRate}% hospital=${hospRate}% loot=${lootRate}% cleanup=${stats.inventoryCleanupCount}`
      );
    }

    if (data.hospitalized) {
      await recoverFromHospital(client, authId);
    }

    await sleep(scenario.delayMs);
  }

  return stats;
}

function summarizeScenario(stats) {
  const successRate = pct(stats.successes, stats.completedRuns);
  const hospitalRate = pct(stats.hospitalizations, stats.completedRuns);
  const hospitalByFailure = pct(stats.hospitalizations, stats.failures);
  const lootRate = pct(stats.runsWithLoot, stats.completedRuns);
  const multiDropRate = pct(stats.multiDropRuns, stats.completedRuns);
  const critRate = pct(stats.criticalHits, stats.successes);
  const avgGoldPerSuccess = stats.successes ? stats.totalGold / stats.successes : 0;
  const avgXpPerSuccess = stats.successes ? stats.totalXp / stats.successes : 0;
  const avgItemsPerRun = stats.completedRuns ? stats.totalItems / stats.completedRuns : 0;
  const avgItemsPerSuccess = stats.successes ? stats.totalItems / stats.successes : 0;
  const avgHospitalSec = mean(stats.hospitalDurationsSec);
  const ci = ci95(successRate, stats.completedRuns);

  return {
    ...stats,
    summary: {
      successRate,
      successRateCI95: ci,
      hospitalRate,
      hospitalByFailure,
      lootRate,
      multiDropRate,
      critRate,
      avgGoldPerSuccess,
      avgXpPerSuccess,
      avgItemsPerRun,
      avgItemsPerSuccess,
      avgHospitalSec,
      p50HospitalSec: percentile(stats.hospitalDurationsSec, 50),
      p90HospitalSec: percentile(stats.hospitalDurationsSec, 90),
      maxHospitalSec: stats.hospitalDurationsSec.length
        ? Math.max(...stats.hospitalDurationsSec)
        : 0,
      inventoryCleanupCount: stats.inventoryCleanupCount,
      inventoryRowsDeleted: stats.inventoryRowsDeleted,
      inventoryCleanupFailures: stats.inventoryCleanupFailures,
    },
  };
}

function topN(obj, n = 8) {
  return Object.entries(obj)
    .sort((a, b) => b[1] - a[1])
    .slice(0, n)
    .map(([k, v]) => ({ key: k, count: v }));
}

function printClassSummary(classLabel, scenarios) {
  console.log(`\n==== ${classLabel} Summary ====`);
  for (const [scenarioId, data] of Object.entries(scenarios)) {
    const s = data.summary;
    console.log(`  [${scenarioId}] completed=${data.completedRuns}/${data.requestedRuns} errors=${data.rawErrors}`);
    console.log(
      `    success=${s.successRate.toFixed(2)}% (CI95 ${s.successRateCI95.low.toFixed(2)}-${s.successRateCI95.high.toFixed(2)})`
    );
    console.log(
      `    hospital=${s.hospitalRate.toFixed(2)}% fail->hospital=${s.hospitalByFailure.toFixed(2)}% avgHospital=${Math.round(s.avgHospitalSec)}s`
    );
    console.log(
      `    lootRate=${s.lootRate.toFixed(2)}% items/run=${s.avgItemsPerRun.toFixed(3)} items/success=${s.avgItemsPerSuccess.toFixed(3)}`
    );
    console.log(
      `    avgGold/success=${s.avgGoldPerSuccess.toFixed(1)} avgXp/success=${s.avgXpPerSuccess.toFixed(1)} crit=${s.critRate.toFixed(2)}%`
    );
    console.log(
      `    inventoryFull=${data.inventoryFullHits} cleanups=${s.inventoryCleanupCount} deletedRows=${s.inventoryRowsDeleted} cleanupFailures=${s.inventoryCleanupFailures}`
    );
  }
}

function compareClasses(resultByClass) {
  const normal = {
    warrior: resultByClass.warrior.scenarios.normal?.summary,
    alchemist: resultByClass.alchemist.scenarios.normal?.summary,
    shadow: resultByClass.shadow.scenarios.normal?.summary,
  };
  const hard = {
    warrior: resultByClass.warrior.scenarios.hard?.summary,
    alchemist: resultByClass.alchemist.scenarios.hard?.summary,
    shadow: resultByClass.shadow.scenarios.hard?.summary,
  };

  const safePctDiff = (a, b) => {
    if (!b) return 0;
    return ((a - b) / b) * 100;
  };

  return {
    normalScenario: {
      successDiffAlchemistVsWarrior: (normal.alchemist?.successRate || 0) - (normal.warrior?.successRate || 0),
      successDiffAlchemistVsShadow: (normal.alchemist?.successRate || 0) - (normal.shadow?.successRate || 0),
      lootItemsPerRunDiffShadowVsWarriorPct: safePctDiff(
        normal.shadow?.avgItemsPerRun || 0,
        normal.warrior?.avgItemsPerRun || 0
      ),
      lootItemsPerRunDiffShadowVsAlchemistPct: safePctDiff(
        normal.shadow?.avgItemsPerRun || 0,
        normal.alchemist?.avgItemsPerRun || 0
      ),
    },
    hardScenario: {
      hospitalRateWarrior: hard.warrior?.hospitalRate || 0,
      hospitalRateAlchemist: hard.alchemist?.hospitalRate || 0,
      hospitalRateShadow: hard.shadow?.hospitalRate || 0,
      avgHospitalSecWarrior: hard.warrior?.avgHospitalSec || 0,
      avgHospitalSecAlchemist: hard.alchemist?.avgHospitalSec || 0,
      avgHospitalSecShadow: hard.shadow?.avgHospitalSec || 0,
      warriorHospitalDurationReductionVsAlchemistPct: safePctDiff(
        hard.alchemist?.avgHospitalSec || 0,
        hard.warrior?.avgHospitalSec || 1
      ),
      warriorHospitalDurationReductionVsShadowPct: safePctDiff(
        hard.shadow?.avgHospitalSec || 0,
        hard.warrior?.avgHospitalSec || 1
      ),
    },
  };
}

async function runClassTest(config, scenarios, adminClient, itemMetaCache) {
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
  });

  console.log(`\n${"=".repeat(80)}`);
  console.log(`Testing class: ${config.label}`);
  console.log(`${"=".repeat(80)}`);

  const user = await login(client, config.email, config.password);

  if (NORMALIZE_PLAYERS) {
    const normalized = await normalizePlayerState(client, user.id, scenarios);
    if (!normalized.ok) {
      throw new Error(`Normalization failed for ${config.label}: ${normalized.error}`);
    }
    console.log(
      `Normalized baseline level=${BASELINE_LEVEL} power=${BASELINE_POWER} luck=${BASELINE_LUCK} defense=${BASELINE_DEFENSE} deletedInventory=${normalized.normalized.inventoryDeleted}`
    );
  }

  const profile = await getUserProfile(client, user.id);
  console.log(
    `Profile class=${profile.character_class} level=${profile.level} power=${profile.power} luck=${profile.luck} defense=${profile.defense}`
  );

  const scenarioResults = {};

  for (const scenario of scenarios) {
    const dungeon = await getDungeonEnergyCost(adminClient, scenario.dungeonId);
    const requiredEnergy = Math.ceil((dungeon.energy_cost || 1) * scenario.runs * 1.2);
    await ensureEnergy(client, user.id, requiredEnergy);
    await recoverFromHospital(client, user.id);

    const raw = await runScenario(client, adminClient, user.id, config.label, scenario, itemMetaCache);
    scenarioResults[scenario.id] = summarizeScenario(raw);
  }

  await client.auth.signOut();

  return {
    class: config.key,
    classLabel: config.label,
    profile,
    scenarios: scenarioResults,
    topLoot: {
      normalTopRarity: topN(scenarioResults.normal?.itemRarities || {}, 5),
      normalTopTypes: topN(scenarioResults.normal?.itemTypes || {}, 8),
      hardTopRarity: topN(scenarioResults.hard?.itemRarities || {}, 5),
      hardTopTypes: topN(scenarioResults.hard?.itemTypes || {}, 8),
    },
  };
}

async function main() {
  ensureClassEnv();
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const adminClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
  });

  const itemMetaCache = {};

  const totalRuns = DEFAULT_SCENARIOS.reduce((sum, s) => sum + s.runs, 0);
  console.log("Comprehensive class smoke test started");
  console.log(`Scenarios: ${DEFAULT_SCENARIOS.map((s) => `${s.id}:${s.runs}`).join(" | ")}`);
  console.log(`Per class planned runs: ${totalRuns}`);
  console.log(`Total planned runs: ${totalRuns * CLASS_CONFIGS.length}`);

  const resultByClass = {};

  for (const cfg of CLASS_CONFIGS) {
    const classResult = await runClassTest(cfg, DEFAULT_SCENARIOS, adminClient, itemMetaCache);
    resultByClass[cfg.key] = classResult;
    printClassSummary(cfg.label, classResult.scenarios);
  }

  const crossClassAnalysis = compareClasses(resultByClass);

  console.log(`\n${"=".repeat(80)}`);
  console.log("Cross-class analysis");
  console.log(`${"=".repeat(80)}`);
  console.log(
    `Normal success diff A-W: ${crossClassAnalysis.normalScenario.successDiffAlchemistVsWarrior.toFixed(2)}%`
  );
  console.log(
    `Normal success diff A-S: ${crossClassAnalysis.normalScenario.successDiffAlchemistVsShadow.toFixed(2)}%`
  );
  console.log(
    `Normal loot Shadow vs Warrior: ${crossClassAnalysis.normalScenario.lootItemsPerRunDiffShadowVsWarriorPct.toFixed(2)}%`
  );
  console.log(
    `Normal loot Shadow vs Alchemist: ${crossClassAnalysis.normalScenario.lootItemsPerRunDiffShadowVsAlchemistPct.toFixed(2)}%`
  );
  console.log(
    `Hard avg hospital sec Warrior/Alchemist/Shadow: ${crossClassAnalysis.hardScenario.avgHospitalSecWarrior.toFixed(1)} / ${crossClassAnalysis.hardScenario.avgHospitalSecAlchemist.toFixed(1)} / ${crossClassAnalysis.hardScenario.avgHospitalSecShadow.toFixed(1)}`
  );

  const output = {
    timestamp: new Date().toISOString(),
    scenarios: DEFAULT_SCENARIOS,
    expectedSignals: {
      successRate: "alchemist > warrior > shadow",
      hospitalizationRate: "hard dungeon should show measurable hospitalization rate",
      hospitalDuration: "warrior expected shorter average duration",
      lootPerRun: "shadow expected higher items/run via luck multiplier",
    },
    resultByClass,
    crossClassAnalysis,
  };

  const outputFile = path.join(
    OUTPUT_DIR,
    `class_bonuses_smoke_test_${new Date().toISOString().replace(/[:.]/g, "-")}.json`
  );
  fs.writeFileSync(outputFile, JSON.stringify(output, null, 2));

  const latestFile = path.join(OUTPUT_DIR, "class_bonuses_smoke_test_latest.json");
  fs.writeFileSync(latestFile, JSON.stringify(output, null, 2));

  console.log(`\nSaved detailed report: ${outputFile}`);
  console.log(`Saved latest report: ${latestFile}`);
}

main().catch((err) => {
  console.error("Smoke test failed", err);
  process.exit(1);
});
