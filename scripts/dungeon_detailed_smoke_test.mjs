#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

const ROOT = process.cwd();

// ========================================================================
// ENV & SETUP
// ========================================================================

function loadEnvFiles() {
  const localPath = path.join(ROOT, '.env.local');
  const envPath = path.join(ROOT, '.env');

  if (fs.existsSync(localPath)) {
    dotenv.config({ path: localPath, override: false });
  }
  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath, override: false });
  }
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing env var: ${name}`);
  }
  return value.trim();
}

function optionalInt(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.trunc(parsed);
}

function nowIso() {
  return new Date().toISOString();
}

function isFuture(raw) {
  if (!raw) return false;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return false;
  return d > new Date();
}

function printSection(title) {
  console.log('\n' + '='.repeat(72));
  console.log(title);
  console.log('='.repeat(72));
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ========================================================================
// SUPABASE CLIENT
// ========================================================================

loadEnvFiles();

const SUPABASE_URL = requiredEnv('NEXT_PUBLIC_SUPABASE_URL');
const SUPABASE_KEY = requiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY');
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const RUNS_PER_PLAYER = optionalInt('DUNGEON_SMOKE_RUNS_PER_PLAYER', 10);
const TOTAL_RUNS = optionalInt('DUNGEON_SMOKE_TOTAL_RUNS', 0);
const COOLDOWN_MS = optionalInt('DUNGEON_SMOKE_COOLDOWN_MS', 200);

// ========================================================================
// PLAYER SETUP
// ========================================================================

const PLAYERS = [
  { name: 'ALCHEMIST_A', class: 'alchemist', emailKey: 'DUNGEON_SMOKE_ALCHEMIST_A_EMAIL', passKey: 'DUNGEON_SMOKE_ALCHEMIST_A_PASSWORD' },
  { name: 'ALCHEMIST_B', class: 'alchemist', emailKey: 'DUNGEON_SMOKE_ALCHEMIST_B_EMAIL', passKey: 'DUNGEON_SMOKE_ALCHEMIST_B_PASSWORD' },
  { name: 'ALCHEMIST_C', class: 'alchemist', emailKey: 'DUNGEON_SMOKE_ALCHEMIST_C_EMAIL', passKey: 'DUNGEON_SMOKE_ALCHEMIST_C_PASSWORD' },
  { name: 'SHADOW_A', class: 'shadow', emailKey: 'DUNGEON_SMOKE_SHADOW_A_EMAIL', passKey: 'DUNGEON_SMOKE_SHADOW_A_PASSWORD' },
  { name: 'SHADOW_B', class: 'shadow', emailKey: 'DUNGEON_SMOKE_SHADOW_B_EMAIL', passKey: 'DUNGEON_SMOKE_SHADOW_B_PASSWORD' },
  { name: 'WARRIOR_A', class: 'warrior', emailKey: 'DUNGEON_SMOKE_WARRIOR_A_EMAIL', passKey: 'DUNGEON_SMOKE_WARRIOR_A_PASSWORD' },
];

async function buildPlayerEnv(pConfig) {
  const email = requiredEnv(pConfig.emailKey);
  const password = requiredEnv(pConfig.passKey);
  return { email, password, uuid: null, name: pConfig.name };
}

async function createOrLoginPlayer(email, password, uuid) {
  const client = createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  let player;
  let session;

  if (!uuid) {
    const signUpRes = await client.auth.signUp({ email, password });
    if (signUpRes.error) {
      console.log(`  ✓ Account exists: ${email}`);
      const loginRes = await client.auth.signInWithPassword({ email, password });
      player = loginRes.data.user;
      session = loginRes.data.session;
    } else {
      player = signUpRes.data.user;
      session = signUpRes.data.session;
      console.log(`  ✓ Signed up: ${email}`);

      if (!session) {
        const loginRes = await client.auth.signInWithPassword({ email, password });
        player = loginRes.data.user;
        session = loginRes.data.session;
      }
    }
  } else {
    const loginRes = await client.auth.signInWithPassword({ email, password });
    player = loginRes.data.user;
    session = loginRes.data.session;
  }

  if (!player || !session) {
    throw new Error(`Authentication failed for ${email}`);
  }

  const { data: profile } = await client
    .from('users')
    .select('*')
    .eq('auth_id', player.id)
    .maybeSingle();

  const safeProfile = profile || {
    level: 1,
    power: 0,
    xp: 0,
    gold: 1000,
    energy: 100,
    gems: 100,
    character_class: 'alchemist',
    in_hospital: false,
  };

  return {
    authId: player.id,
    email: player.email,
    client,
    ...safeProfile,
  };
}

async function updateUserLimits(player) {
  await player.client.rpc('update_user_limits', {
    p_user_id: player.authId,
    p_energy: 10000,
    p_gems: 10000,
  });
}

async function healHospitalWithGems(player) {
  try {
    const { data, error } = await player.client.rpc('heal_with_gems');
    if (error) {
      return { ok: false, error: error.message };
    }
    return { ok: true, data };
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

function extractRowsFromInventoryPayload(payload) {
  if (Array.isArray(payload)) return payload;
  if (payload && typeof payload === 'object') {
    if (Array.isArray(payload.items)) return payload.items;
    if (payload.data && Array.isArray(payload.data.items)) return payload.data.items;
    if (Array.isArray(payload.data)) return payload.data;
  }
  return [];
}

async function getInventoryRows(player) {
  const payload = await player.client.rpc('get_inventory');
  const rows = extractRowsFromInventoryPayload(payload?.data ?? payload).filter((row) => {
    if (!row || typeof row !== 'object') return false;
    return row.is_equipped !== true;
  });
  return rows;
}

async function maintainInventoryCapacity(player, maxSlots = 20) {
  const rows = await getInventoryRows(player);
  if (rows.length < maxSlots) {
    return { cleaned: 0, soldGold: 0, before: rows.length, after: rows.length };
  }

  const sorted = [...rows].sort((a, b) => {
    const av = Number(a.vendor_sell_price ?? a.base_price ?? 0);
    const bv = Number(b.vendor_sell_price ?? b.base_price ?? 0);
    return av - bv;
  });

  const toClean = (rows.length - maxSlots) + 1;
  let cleaned = 0;
  let soldGold = 0;

  for (let i = 0; i < toClean && i < sorted.length; i++) {
    const row = sorted[i];
    if (!row?.row_id) continue;

    const quantity = Number(row.quantity ?? 1);
    const sellResp = await player.client.rpc('sell_inventory_item_by_row', {
      p_row_id: row.row_id,
      p_quantity: Number.isFinite(quantity) && quantity > 0 ? quantity : 1,
    });

    const sellPayload = sellResp?.data;
    const sellError = sellResp?.error;
    const soldOk = !sellError && (sellPayload?.success !== false);

    if (soldOk) {
      cleaned++;
      soldGold += Number(sellPayload?.gold_earned ?? 0);
      continue;
    }

    const trashResp = await player.client.rpc('trash_item', { p_row_id: row.row_id });
    if (!trashResp?.error) {
      cleaned++;
    }
  }

  const afterRows = await getInventoryRows(player);
  return { cleaned, soldGold, before: rows.length, after: afterRows.length };
}

async function loadItemValueMap() {
  const { data, error } = await supabase
    .from('items')
    .select('id,vendor_sell_price,base_price,rarity,type');

  if (error) {
    throw new Error(`Failed to load items map: ${error.message}`);
  }

  const map = {};
  for (const row of data || []) {
    map[row.id] = {
      vendorSellPrice: Number(row.vendor_sell_price ?? 0),
      basePrice: Number(row.base_price ?? 0),
      rarity: row.rarity || 'unknown',
      type: row.type || 'unknown',
    };
  }
  return map;
}

// ========================================================================
// DUNGEON CATALOG & SELECTION
// ========================================================================

function dungeonNumericId(rawId) {
  const match = String(rawId || '').match(/(\d+)/);
  return match ? Number(match[1]) : Number.MAX_SAFE_INTEGER;
}

async function loadDungeonCatalog() {
  const { data, error } = await supabase
    .from('dungeons')
    .select('id,name,power_requirement,energy_cost,is_boss')
    .order('power_requirement', { ascending: true });

  if (error) {
    throw new Error(`Failed to load dungeons: ${error.message}`);
  }

  const normalized = (data || [])
    .filter((d) => typeof d.id === 'string' && d.id.startsWith('dng_'))
    .sort((a, b) => {
      const pa = Number(a.power_requirement || 0);
      const pb = Number(b.power_requirement || 0);
      if (pa !== pb) return pa - pb;
      return dungeonNumericId(a.id) - dungeonNumericId(b.id);
    })
    .map((d) => ({
      id: d.id,
      name: d.name || d.id,
      powerReq: Number(d.power_requirement || 0),
      energyCost: Number(d.energy_cost || 0),
      isBoss: d.is_boss === true,
    }));

  if (normalized.length === 0) {
    throw new Error('No dungeon rows found in public.dungeons');
  }

  return normalized;
}

// ========================================================================
// ITEM TRACKING
// ========================================================================

class ItemTracker {
  constructor() {
    this.items = [];
    this.rarityStats = {};
    this.slotStats = {};
    this.typeStats = {};
    this.totalValue = 0;
    this.runsWithDrop = 0;
    this.totalDroppedItems = 0;
  }

  addItem(item, itemValueMap) {
    if (!item || !item.rarity) return;

    this.items.push(item);
    this.totalDroppedItems++;

    if (!this.rarityStats[item.rarity]) {
      this.rarityStats[item.rarity] = 0;
    }
    this.rarityStats[item.rarity]++;

    const slot = item.slot || item.type || 'unknown';
    if (!this.slotStats[slot]) {
      this.slotStats[slot] = 0;
    }
    this.slotStats[slot]++;

    const type = item.type || 'unknown';
    if (!this.typeStats[type]) {
      this.typeStats[type] = 0;
    }
    this.typeStats[type]++;

    const itemMeta = itemValueMap[item.item_id] || null;
    const itemValue = Number(itemMeta?.vendorSellPrice ?? itemMeta?.basePrice ?? 0);
    this.totalValue += itemValue;
  }

  parseItems(lootArray, itemValueMap) {
    if (!Array.isArray(lootArray)) return;
    if (lootArray.length > 0) {
      this.runsWithDrop++;
    }
    lootArray.forEach((item) => this.addItem(item, itemValueMap));
  }

  summary(totalRuns) {
    const rarityStr = Object.entries(this.rarityStats)
      .map(([r, c]) => `${r}×${c}`)
      .join(', ');
    const slotStr = Object.entries(this.slotStats)
      .map(([s, c]) => `${s}×${c}`)
      .join(', ');
    const typeStr = Object.entries(this.typeStats)
      .map(([t, c]) => `${t}×${c}`)
      .join(', ');

    const dropRateByRun = totalRuns > 0
      ? ((this.runsWithDrop / totalRuns) * 100).toFixed(1)
      : '0.0';

    return {
      totalItems: this.items.length,
      raritySummary: rarityStr || 'none',
      slotSummary: slotStr || 'none',
      typeSummary: typeStr || 'none',
      totalValue: this.totalValue,
      dropRateByRun,
    };
  }
}

// ========================================================================
// DUNGEON RUN
// ========================================================================

async function runEnterDungeon(player, dungeonId, tracker, itemValueMap) {
  try {
    const { data, error } = await player.client.rpc('enter_dungeon', {
      p_player_id: player.authId,
      p_dungeon_id: dungeonId,
    });

    if (error) {
      throw error;
    }

    if (!data || typeof data !== 'object') {
      return {
        success: false,
        error: 'Invalid dungeon response payload',
        gold: 0,
        xp: 0,
        won: false,
        hospitalized: false,
        itemCount: 0,
      };
    }

    if (data.error) {
      return {
        success: false,
        error: String(data.error),
        gold: 0,
        xp: 0,
        won: false,
        hospitalized: Boolean(data.hospitalized),
        itemCount: 0,
      };
    }

    const droppedItems = Array.isArray(data.items)
      ? data.items
      : (Array.isArray(data.items_dropped) ? data.items_dropped : []);

    if (droppedItems.length > 0) {
      tracker.parseItems(droppedItems, itemValueMap);
    }

    return {
      success: true,
      gold: Number(data.gold_earned || 0),
      xp: Number(data.xp_earned || 0),
      won: Boolean(data.success),
      hospitalized: Boolean(data.hospitalized),
      itemCount: droppedItems.length,
    };
  } catch (err) {
    return {
      success: false,
      error: err.message,
      gold: 0,
      xp: 0,
      won: false,
      hospitalized: false,
      itemCount: 0,
    };
  }
}

// ========================================================================
// MAIN TEST
// ========================================================================

async function main() {
  printSection('PLAN_04 Detayli Dungeon Smoke Test (Adaptive Full Catalog)');

  const dungeonCatalog = await loadDungeonCatalog();
  const itemValueMap = await loadItemValueMap();
  const dungeonById = Object.fromEntries(dungeonCatalog.map((d) => [d.id, d]));
  const targetTotalRuns = TOTAL_RUNS > 0 ? TOTAL_RUNS : (RUNS_PER_PLAYER * PLAYERS.length);

  console.log(`time=${nowIso()}`);
  console.log(`totalRunsTarget=${targetTotalRuns}`);
  console.log(`runsPerPlayerFallback=${RUNS_PER_PLAYER}`);
  console.log(`cooldownMs=${COOLDOWN_MS}`);
  console.log(`dungeonCount=${dungeonCatalog.length}`);
  console.log('mode=level-up -> next dungeon, fail/hospital -> previous dungeon');

  // ========================================================================
  // LOGIN
  // ========================================================================

  printSection('Account Login');

  const playerMap = {};
  for (const pConfig of PLAYERS) {
    const env = await buildPlayerEnv(pConfig);
    const player = await createOrLoginPlayer(env.email, env.password, env.uuid);
    playerMap[pConfig.name] = { ...player, ...pConfig, _email: env.email, _password: env.password };
    console.log(
      `${pConfig.name} | uuid=${player.authId} | level=${player.level} power=${player.power} class=${pConfig.class}`,
    );
  }

  // ========================================================================
  // PREFLIGHT
  // ========================================================================

  printSection('Preflight Checks');

  const preflight = [];
  for (const [name, player] of Object.entries(playerMap)) {
    // Update limits
    await updateUserLimits(player);

    // Refresh player state
    const { data: fresh } = await player.client.from('users').select('*').eq('auth_id', player.authId).maybeSingle();
    const updated = fresh ? { ...player, ...fresh, authId: player.authId } : player;
    playerMap[name] = { ...player, ...updated };

    preflight.push(
      `${name} | xp=${updated.xp} gold=${updated.gold} energy=${updated.energy} gems=${updated.gems} in_hospital=${updated.in_hospital}`,
    );
  }
  console.log(preflight.join('\n'));

  // ========================================================================
  // RUNTIME: DUNGEON PROGRESSION
  // ========================================================================

  printSection('Runtime Checks (adaptive progression across full dungeon list)');

  const stats = {};
  const dungeonStats = {};
  for (const dungeon of dungeonCatalog) {
    dungeonStats[dungeon.id] = {
      attempts: 0,
      successes: 0,
      failures: 0,
      hospitalizations: 0,
      zeroRewardSuccesses: 0,
    };
  }

  for (const [name, player] of Object.entries(playerMap)) {
    stats[name] = {
      runs: 0,
      successes: 0,
      failures: 0,
      hospitalizations: 0,
      goldEarned: 0,
      xpEarned: 0,
      itemsGathered: new ItemTracker(),
      currentDungeonIndex: 0,
      maxDungeonIndex: 0,
      levelUpCount: 0,
      downgradeCount: 0,
      consecutiveSuccess: 0,
      healCount: 0,
      healFailures: 0,
      inventoryCleanups: 0,
      inventoryItemsCleaned: 0,
      inventoryGoldRecovered: 0,
      gemSpentOnHeals: 0,
      zeroRewardSuccesses: 0,
      levelStart: player.level,
      levelEnd: player.level,
      powerStart: player.power,
      powerEnd: player.power,
    };
  }

  let totalExecutedRuns = 0;
  while (totalExecutedRuns < targetTotalRuns) {
    for (const [name, player] of Object.entries(playerMap)) {
      if (totalExecutedRuns >= targetTotalRuns) break;

      try {
        // Refresh player to get latest power/level
        const { data: fresh } = await player.client.from('users').select('*').eq('auth_id', player.authId).maybeSingle();
        const updated = fresh ? { ...player, ...fresh, authId: player.authId } : player;
        playerMap[name] = updated;

        const s = stats[name];
        const previousLevel = s.levelEnd || updated.level || 1;
        s.powerEnd = updated.power || 0;
        s.levelEnd = updated.level || 1;
        const leveledUp = s.levelEnd > previousLevel;

        if (leveledUp) {
          s.levelUpCount += (s.levelEnd - previousLevel);
        }

        const currentDungeon = dungeonCatalog[s.currentDungeonIndex];
        const nextDungeonId = currentDungeon.id;

        const timestamp = nowIso();

        // Keep collecting even with 20-slot inventory by cleaning low-value items first.
        const cleanup = await maintainInventoryCapacity(updated, 20);
        if (cleanup.cleaned > 0) {
          s.inventoryCleanups++;
          s.inventoryItemsCleaned += cleanup.cleaned;
          s.inventoryGoldRecovered += cleanup.soldGold;
        }

        // Run dungeon
        const result = await runEnterDungeon(updated, nextDungeonId, s.itemsGathered, itemValueMap);

        s.runs++;
        totalExecutedRuns++;
        dungeonStats[nextDungeonId].attempts++;

        const isRunFailure = !result.success || !result.won || result.hospitalized;
        const isZeroRewardSuccess = result.success
          && result.won
          && !result.hospitalized
          && result.gold === 0
          && result.xp === 0
          && result.itemCount === 0;

        if (result.success) {
          s.goldEarned += result.gold;
          s.xpEarned += result.xp;
          if (result.hospitalized) {
            s.hospitalizations++;
            dungeonStats[nextDungeonId].hospitalizations++;
          }

          if (result.won && !result.hospitalized) {
            s.successes++;
            s.consecutiveSuccess++;
            dungeonStats[nextDungeonId].successes++;

            if (isZeroRewardSuccess) {
              s.zeroRewardSuccesses++;
              dungeonStats[nextDungeonId].zeroRewardSuccesses++;
            }
          } else {
            s.failures++;
            s.consecutiveSuccess = 0;
            dungeonStats[nextDungeonId].failures++;
          }

          console.log(
            `${timestamp} | run=${totalExecutedRuns}/${targetTotalRuns} | ${name} -> ${nextDungeonId} | ok=${result.won} gold=${result.gold} xp=${result.xp} items=${result.itemCount} hospital=${result.hospitalized} invClean=${cleanup.cleaned}`,
          );
        } else {
          s.failures++;
          s.consecutiveSuccess = 0;
          dungeonStats[nextDungeonId].failures++;
          console.log(`${timestamp} | run=${totalExecutedRuns}/${targetTotalRuns} | ${name} -> ${nextDungeonId} | FAIL | ${result.error}`);
        }

        // Auto-heal if hospitalized and keep the test flowing.
        if (result.hospitalized || (result.error && String(result.error).includes('in_hospital'))) {
          const beforeHealGems = Number(updated.gems ?? 0);
          const heal = await healHospitalWithGems(updated);
          if (heal.ok) {
            s.healCount++;
            const { data: healedProfile } = await updated.client
              .from('users')
              .select('gems')
              .eq('auth_id', updated.authId)
              .maybeSingle();
            const afterHealGems = Number(healedProfile?.gems ?? beforeHealGems);
            const gemSpent = Math.max(0, beforeHealGems - afterHealGems);
            s.gemSpentOnHeals += gemSpent;
            console.log(`  -> ${name} auto-heal with gems OK`);
          } else {
            s.healFailures++;
            console.log(`  -> ${name} auto-heal FAILED: ${heal.error}`);
          }
        }

        // Adaptive movement:
        // - Level up OR stable success streak => go one dungeon up
        // - Any failure/hospital => go one dungeon down
        if (isRunFailure) {
          if (s.currentDungeonIndex > 0) {
            s.currentDungeonIndex -= 1;
            s.downgradeCount++;
          }
        } else {
          const canPromote = s.currentDungeonIndex < dungeonCatalog.length - 1;
          const shouldPromote = leveledUp || s.consecutiveSuccess >= 3;
          if (canPromote && shouldPromote) {
            s.currentDungeonIndex += 1;
            s.maxDungeonIndex = Math.max(s.maxDungeonIndex, s.currentDungeonIndex);
            s.consecutiveSuccess = 0;
          }
        }
      } catch (err) {
        console.error(`ERROR [${name}]:`, err.message);
      }

      await sleep(COOLDOWN_MS);
    }
  }

  // ========================================================================
  // STATISTICS
  // ========================================================================

  printSection('Final Statistics');

  let totalRuns = 0;
  let totalSuccesses = 0;
  let totalHospitalizations = 0;
  let totalGoldEarned = 0;
  let totalXpEarned = 0;
  let totalItems = 0;
  let totalItemValue = 0;
  let totalAutoHeals = 0;
  let totalAutoHealFailures = 0;
  let totalInventoryCleanups = 0;
  let totalInventoryCleanedItems = 0;
  let totalInventoryRecoveredGold = 0;
  let totalZeroRewardSuccesses = 0;
  let totalGemSpentOnHeals = 0;

  for (const s of Object.values(stats)) {
    totalRuns += s.runs;
    totalSuccesses += s.successes;
    totalHospitalizations += s.hospitalizations;
    totalGoldEarned += s.goldEarned;
    totalXpEarned += s.xpEarned;
    totalItems += s.itemsGathered.items.length;
    totalItemValue += s.itemsGathered.totalValue;
    totalAutoHeals += s.healCount;
    totalAutoHealFailures += s.healFailures;
    totalInventoryCleanups += s.inventoryCleanups;
    totalInventoryCleanedItems += s.inventoryItemsCleaned;
    totalInventoryRecoveredGold += s.inventoryGoldRecovered;
    totalZeroRewardSuccesses += s.zeroRewardSuccesses;
    totalGemSpentOnHeals += s.gemSpentOnHeals;
  }

  console.log(`Total attempts: ${totalRuns}`);
  console.log(`Successes: ${totalSuccesses} (${((totalSuccesses / totalRuns) * 100).toFixed(1)}%)`);
  console.log(`Hospitalizations: ${totalHospitalizations} (${((totalHospitalizations / totalRuns) * 100).toFixed(1)}%)`);
  console.log(`Failures: ${totalRuns - totalSuccesses} (${(((totalRuns - totalSuccesses) / totalRuns) * 100).toFixed(1)}%)`);
  console.log(`Total gold earned: ${totalGoldEarned.toLocaleString()}`);
  console.log(`Total XP earned: ${totalXpEarned.toLocaleString()}`);
  console.log(`Total items gathered: ${totalItems}`);
  console.log(`Total item value (vendor): ${Math.round(totalItemValue).toLocaleString()}`);
  console.log(`Auto heals with gems: ${totalAutoHeals} (failed: ${totalAutoHealFailures})`);
  console.log(`Estimated gems spent on heals: ${Math.round(totalGemSpentOnHeals).toLocaleString()}`);
  console.log(`Inventory cleanups: ${totalInventoryCleanups} | items cleaned: ${totalInventoryCleanedItems} | gold recovered: ${Math.round(totalInventoryRecoveredGold).toLocaleString()}`);
  console.log(`Zero-reward successes (anomaly): ${totalZeroRewardSuccesses}`);

  const coveredDungeonCount = Object.values(dungeonStats).filter((row) => row.attempts > 0).length;
  console.log(`Dungeon coverage: ${coveredDungeonCount}/${dungeonCatalog.length} (${((coveredDungeonCount / dungeonCatalog.length) * 100).toFixed(1)}%)`);

  printSection('Dungeon Coverage Summary');
  for (const dungeon of dungeonCatalog) {
    const row = dungeonStats[dungeon.id];
    if (row.attempts === 0) continue;
    const winRate = ((row.successes / row.attempts) * 100).toFixed(1);
    const hospRate = ((row.hospitalizations / row.attempts) * 100).toFixed(1);
    console.log(`${dungeon.id} (${dungeon.name}) | req=${dungeon.powerReq} | runs=${row.attempts} win=${winRate}% hosp=${hospRate}% zeroReward=${row.zeroRewardSuccesses}`);
  }

  // ========================================================================
  // PER-PLAYER SUMMARY
  // ========================================================================

  printSection('Per-Player Summary');

  for (const [name, s] of Object.entries(stats)) {
    const player = playerMap[name];
    const itemSummary = s.itemsGathered.summary(s.runs);

    console.log(`\n${name}:`);
    console.log(`  Class: ${player.character_class}`);
    console.log(`  Level: ${s.levelStart} → ${s.levelEnd} (${s.levelEnd - s.levelStart >= 0 ? '+' : ''}${s.levelEnd - s.levelStart})`);
    console.log(`  Power: ${s.powerStart.toLocaleString()} → ${s.powerEnd.toLocaleString()} (${s.powerEnd - s.powerStart >= 0 ? '+' : ''}${(s.powerEnd - s.powerStart).toLocaleString()})`);
    console.log(`  XP: ${s.xpEarned.toLocaleString()}`);
    console.log(`  Gold: ${s.goldEarned.toLocaleString()}`);
    console.log(`  Dungeon runs: ${s.runs}`);
    console.log(`  Success rate: ${((s.successes / s.runs) * 100).toFixed(1)}%`);
    console.log(`  Hospital rate: ${((s.hospitalizations / s.runs) * 100).toFixed(1)}%`);
    console.log(`  Fail count: ${s.failures}`);
    console.log(`  Level-up promotions: ${s.levelUpCount}`);
    console.log(`  Downgrades: ${s.downgradeCount}`);
    console.log(`  Auto heals: ${s.healCount} (fail: ${s.healFailures})`);
    console.log(`  Gems spent on heals: ${Math.round(s.gemSpentOnHeals).toLocaleString()}`);
    console.log(`  Zero-reward successes: ${s.zeroRewardSuccesses}`);
    console.log(`  Inventory cleanups: ${s.inventoryCleanups} | cleaned items: ${s.inventoryItemsCleaned} | recovered gold: ${Math.round(s.inventoryGoldRecovered).toLocaleString()}`);
    console.log(`  Max dungeon reached: ${dungeonCatalog[s.maxDungeonIndex]?.id || 'n/a'}`);
    console.log(`  Final dungeon: ${dungeonCatalog[s.currentDungeonIndex]?.id || 'n/a'}`);
    console.log(`  Items gathered: ${itemSummary.totalItems}`);
    console.log(`  Item value total: ${Math.round(itemSummary.totalValue).toLocaleString()}`);
    console.log(`  Drop rate by run: ${itemSummary.dropRateByRun}%`);
    if (itemSummary.totalItems > 0) {
      console.log(`    - By rarity: ${itemSummary.raritySummary}`);
      console.log(`    - By slot: ${itemSummary.slotSummary}`);
      console.log(`    - By type: ${itemSummary.typeSummary}`);
    }
  }

  // ========================================================================
  // ASSERTIONS
  // ========================================================================

  printSection('Assertions');

  const assertions = [];

  // 1. XP Progression
  assertions.push({
    name: 'XP Progression',
    passed: totalXpEarned > 0,
    detail: `${totalXpEarned.toLocaleString()} total XP earned`,
  });

  // 2. Gold Earning
  assertions.push({
    name: 'Gold Earning',
    passed: totalGoldEarned > 0,
    detail: `${totalGoldEarned.toLocaleString()} total gold earned`,
  });

  // 3. Item Gathering
  assertions.push({
    name: 'Item Collection',
    passed: totalItems > 0,
    detail: `${totalItems} items gathered across all players`,
  });

  assertions.push({
    name: 'Hospital Auto-Heal Flow',
    passed: totalAutoHealFailures === 0,
    detail: `auto_heal_ok=${totalAutoHeals}, auto_heal_fail=${totalAutoHealFailures}`,
  });

  assertions.push({
    name: 'Reward Integrity',
    passed: totalZeroRewardSuccesses <= Math.floor(totalRuns * 0.05),
    detail: `zero_reward_success=${totalZeroRewardSuccesses}, threshold=${Math.floor(totalRuns * 0.05)}`,
  });

  assertions.push({
    name: 'All Dungeon Coverage',
    passed: coveredDungeonCount === dungeonCatalog.length,
    detail: `${coveredDungeonCount}/${dungeonCatalog.length} dungeons attempted at least once`,
  });

  // 4. Hospital Avoidance
  const hospitalRate = (totalHospitalizations / totalRuns) * 100;
  assertions.push({
    name: 'Hospital Rate (Avoidance)',
    passed: hospitalRate <= 20,
    detail: `${hospitalRate.toFixed(1)}% (target ≤20% with power×1.5 strategy)`,
  });

  // 5. Class Performance (Warrior should have highest success)
  const warriorStats = Object.entries(stats).find(
    ([k, s]) => playerMap[k].character_class === 'warrior',
  );
  if (warriorStats) {
    const [, s] = warriorStats;
    const warriorSuccessRate = (s.successes / s.runs) * 100;
    assertions.push({
      name: 'Warrior Class Bonus',
      passed: warriorSuccessRate >= 85,
      detail: `${warriorSuccessRate.toFixed(1)}% success (expected ≥85% with +5% passive)`,
    });
  }

  // 6. Consistent Gold Rewards
  const avgGoldPerRun = totalGoldEarned / totalRuns;
  assertions.push({
    name: 'Gold Reward Consistency',
    passed: avgGoldPerRun >= 1000,
    detail: `${avgGoldPerRun.toFixed(0)} avg gold per run (expected ≥1000)`,
  });

  assertions.push({
    name: 'Inventory Overflow Handling',
    passed: totalInventoryCleanups > 0 || totalItems < (targetTotalRuns * 0.2),
    detail: `cleanups=${totalInventoryCleanups}, cleaned_items=${totalInventoryCleanedItems}`,
  });

  let passCount = 0;
  for (const a of assertions) {
    const status = a.passed ? 'PASS' : 'FAIL';
    const mark = a.passed ? '✓' : '✗';
    console.log(`${status} | ${a.name} | ${a.detail} ${mark}`);
    if (a.passed) passCount++;
  }

  // ========================================================================
  // RESULT
  // ========================================================================

  printSection('Result');

  console.log(`assertions_pass=${passCount}/${assertions.length}`);
  console.log(`total_runs=${totalRuns}`);
  console.log(`hospital_avoidance_success=${((totalRuns - totalHospitalizations) / totalRuns) * 100}%`);
  console.log('note=Adaptive progression test complete (level-up upshift, failure downshift).');
}

main().catch((err) => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
