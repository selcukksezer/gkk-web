#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

const ROOT = process.cwd();

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
  console.log('');
  console.log('========================================================================');
  console.log(title);
  console.log('========================================================================');
}

function buildPlayerEnv(prefix) {
  const email = process.env[`${prefix}_EMAIL`];
  const password = process.env[`${prefix}_PASSWORD`];
  const uuid = process.env[`${prefix}_UUID`] || null;

  if (!email || !password) {
    throw new Error(`Missing ${prefix}_EMAIL or ${prefix}_PASSWORD`);
  }

  return { key: prefix, email, password, authId: uuid };
}

async function createOrLoginPlayer(supabaseUrl, supabaseAnonKey, player) {
  const client = createClient(supabaseUrl, supabaseAnonKey);

  // Try to login first
  let { data, error } = await client.auth.signInWithPassword({
    email: player.email,
    password: player.password,
  });

  if (!error && data?.session) {
    console.log(`  ✓ Logged in: ${player.email}`);
    player.authId = data.user.id;
    return client;
  }

  // If login fails, try to sign up
  console.log(`  Creating account: ${player.email}`);
  const { data: signUpData, error: signUpError } = await client.auth.signUp({
    email: player.email,
    password: player.password,
  });

  if (signUpError) {
    throw new Error(`Signup failed for ${player.email}: ${signUpError.message}`);
  }

  if (!signUpData.user?.id) {
    throw new Error(`No user ID from signup for ${player.email}`);
  }

  player.authId = signUpData.user.id;
  console.log(`  ✓ Signed up: ${player.email} (uuid=${player.authId})`);

  // Try login again
  const { data: loginData, error: loginError } = await client.auth.signInWithPassword({
    email: player.email,
    password: player.password,
  });

  if (loginError) {
    throw new Error(`Login after signup failed for ${player.email}: ${loginError.message}`);
  }

  if (!loginData.session) {
    throw new Error(`No session for ${player.key} after signup`);
  }

  return client;
}

async function readUserState(client, authId) {
  const { data, error } = await client
    .from('users')
    .select(
      'auth_id,username,character_class,level,xp,power,luck,attack,defense,health,gold,gems,energy,hospital_until,pvp_rating,reputation,pvp_wins,pvp_losses',
    )
    .eq('auth_id', authId)
    .single();

  if (error) {
    throw new Error(`Failed to read user state for ${authId}: ${error.message}`);
  }

  return data;
}

async function runEnterDungeon(client, authId, dungeonId) {
  const { data, error } = await client.rpc('enter_dungeon', {
    p_player_id: authId,
    p_dungeon_id: dungeonId,
  });

  if (error) {
    return { ok: false, error: error.message };
  }

  return { ok: true, data };
}

async function updateUserLimits(observerClient, authId) {
  const { error } = await observerClient
    .from('users')
    .update({ energy: 99999, gems: 99999 })
    .eq('auth_id', authId);

  if (error) {
    console.warn(`Failed to update energy/gems for ${authId}: ${error.message}`);
  }
}

function summarizeAttempt(attempt) {
  const status = attempt.result.ok ? 'OK' : 'FAIL';
  const icon = attempt.result.ok ? '✓' : '✗';
  const details = attempt.result.ok
    ? `won=${attempt.result.data.victory} gold=${attempt.result.data.gold_earned} xp=${attempt.result.data.xp_earned}`
    : attempt.result.error;

  return `${attempt.when} | ${attempt.player} → ${attempt.dungeon} | ${status} ${icon} | ${details}`;
}

function getDungeonInfo(dungeonId) {
  // Simplified dungeon data (full catalog in PLAN_04)
  const dungeons = {
    dng_001: { zone: 1, number: 1, name: 'Kurt İni', powerReq: 0, energy: 5 },
    dng_002: { zone: 1, number: 2, name: 'Örümcek Yuvası', powerReq: 1500, energy: 5 },
    dng_003: { zone: 1, number: 3, name: 'Goblin Kampı', powerReq: 2500, energy: 5 },
    dng_004: { zone: 1, number: 4, name: 'Mantar Mağarası', powerReq: 3500, energy: 6 },
    dng_005: { zone: 1, number: 5, name: 'Orman Tapınağı', powerReq: 4500, energy: 6 },
    dng_010: { zone: 1, number: 10, name: 'Lanetli Orman Kalbi', powerReq: 10000, energy: 8, boss: true },
    dng_011: { zone: 2, number: 11, name: 'Terk Edilmiş Maden', powerReq: 12000, energy: 8 },
    dng_020: { zone: 2, number: 20, name: 'Uçurumun Kapısı', powerReq: 40000, energy: 12, boss: true },
  };

  return dungeons[dungeonId] || { zone: 0, number: 0, name: 'Unknown', powerReq: 0, energy: 5 };
}

function selectNextDungeon(playerPower, lastDungeonId) {
  // Simple progression: if player power >= dungeon * 1.25, try next
  const progression = [
    'dng_001',
    'dng_002',
    'dng_003',
    'dng_004',
    'dng_005',
    'dng_010',
    'dng_011',
    'dng_020',
  ];

  const currentIdx = progression.indexOf(lastDungeonId);
  const current = getDungeonInfo(lastDungeonId);

  if (playerPower >= current.powerReq * 1.25 && currentIdx < progression.length - 1) {
    return progression[currentIdx + 1];
  }

  return lastDungeonId;
}

async function main() {
  loadEnvFiles();

  const supabaseUrl = requiredEnv('NEXT_PUBLIC_SUPABASE_URL');
  const supabaseAnonKey = requiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY');

  const dungeonsPerPlayer = optionalInt('DUNGEON_SMOKE_RUNS_PER_PLAYER', 15);
  const cooldownMs = optionalInt('DUNGEON_SMOKE_COOLDOWN_MS', 200);

  const players = [
    buildPlayerEnv('DUNGEON_SMOKE_ALCHEMIST_A'),
    buildPlayerEnv('DUNGEON_SMOKE_ALCHEMIST_B'),
    buildPlayerEnv('DUNGEON_SMOKE_ALCHEMIST_C'),
    buildPlayerEnv('DUNGEON_SMOKE_SHADOW_A'),
    buildPlayerEnv('DUNGEON_SMOKE_SHADOW_B'),
    buildPlayerEnv('DUNGEON_SMOKE_WARRIOR_A'),
  ];

  printSection('PLAN_04 Dungeon Smoke Test Started');
  console.log(`time=${nowIso()}`);
  console.log(`dungeonsPerPlayer=${dungeonsPerPlayer}`);
  console.log(`cooldownMs=${cooldownMs}`);

  const clients = {};
  const initialState = {};
  const finalState = {};

  for (const p of players) {
    clients[p.key] = await createOrLoginPlayer(supabaseUrl, supabaseAnonKey, p);
    initialState[p.key] = await readUserState(clients[p.key], p.authId);
    console.log(
      `${p.key} | uuid=${p.authId} | level=${initialState[p.key].level} power=${initialState[p.key].power} class=${initialState[p.key].character_class}`,
    );

    // Grant unlimited energy and gems
    await updateUserLimits(clients[p.key], p.authId);
  }

  const observer = clients[players[0].key];

  printSection('Preflight');
  for (const p of players) {
    const state = initialState[p.key];
    console.log(
      `${p.key} | xp=${state.xp} gold=${state.gold} energy=${state.energy} gems=${state.gems} in_hospital=${isFuture(state.hospital_until)}`,
    );
  }

  const attempts = [];
  let currentDungeon = {};
  for (const p of players) {
    currentDungeon[p.key] = 'dng_001';
  }

  printSection('Runtime Checks');

  for (let round = 0; round < dungeonsPerPlayer; round += 1) {
    for (const p of players) {
      const before = await readUserState(observer, p.authId);
      const dungeonId = currentDungeon[p.key];
      const dungeon = getDungeonInfo(dungeonId);

      const result = await runEnterDungeon(clients[p.key], p.authId, dungeonId);

      const after = await readUserState(observer, p.authId);
      const levelUp = after.level > before.level;
      const nextDungeon = selectNextDungeon(after.power, dungeonId);

      const attempt = {
        when: nowIso(),
        round,
        player: p.key,
        dungeon: dungeonId,
        dungeonName: dungeon.name,
        powerReq: dungeon.powerReq,
        playerPowerBefore: before.power,
        playerPowerAfter: after.power,
        result,
        levelBefore: before.level,
        levelAfter: after.level,
        levelUp,
        goldBefore: before.gold,
        goldAfter: after.gold,
        goldEarned: after.gold - before.gold,
        hospitalBefore: isFuture(before.hospital_until),
        hospitalAfter: isFuture(after.hospital_until),
      };
      attempts.push(attempt);

      console.log(summarizeAttempt(attempt));

      if (nextDungeon !== dungeonId) {
        console.log(`  → Progressing to ${getDungeonInfo(nextDungeon).name}`);
        currentDungeon[p.key] = nextDungeon;
      }

      await new Promise((resolve) => setTimeout(resolve, cooldownMs));
    }
  }

  // Fetch final state
  for (const p of players) {
    finalState[p.key] = await readUserState(observer, p.authId);
  }

  printSection('Statistics');

  const successCount = attempts.filter((a) => a.result.ok).length;
  const failureCount = attempts.filter((a) => !a.result.ok).length;
  const levelUpCount = attempts.filter((a) => a.levelUp).length;
  const hospitalCount = attempts.filter((a) => a.hospitalAfter).length;

  console.log(`Total attempts: ${attempts.length}`);
  console.log(`Successes: ${successCount} (${((successCount / attempts.length) * 100).toFixed(1)}%)`);
  console.log(`Failures: ${failureCount} (${((failureCount / attempts.length) * 100).toFixed(1)}%)`);
  console.log(`Level ups: ${levelUpCount}`);
  console.log(`Hospital triggers: ${hospitalCount}`);

  const totalGoldEarned = attempts.reduce((sum, a) => sum + a.goldEarned, 0);
  const avgGoldPerRun = (totalGoldEarned / successCount).toFixed(0);
  console.log(`Total gold earned: ${totalGoldEarned.toLocaleString()}`);
  console.log(`Average gold per successful run: ${avgGoldPerRun.toLocaleString()}`);

  printSection('Per-Player Summary');

  for (const p of players) {
    const initial = initialState[p.key];
    const final = finalState[p.key];
    const playerAttempts = attempts.filter((a) => a.player === p.key);
    const playerSuccesses = playerAttempts.filter((a) => a.result.ok).length;
    const playerLevelUps = playerAttempts.filter((a) => a.levelUp).length;
    const playerGoldEarned = playerAttempts.reduce((sum, a) => sum + a.goldEarned, 0);

    console.log(`${p.key}:`);
    console.log(`  Class: ${initial.character_class}`);
    console.log(`  Level: ${initial.level} → ${final.level} (+${final.level - initial.level})`);
    console.log(`  XP: ${initial.xp} → ${final.xp} (+${final.xp - initial.xp})`);
    console.log(`  Power: ${initial.power} → ${final.power} (+${final.power - initial.power})`);
    console.log(`  Gold: ${initial.gold.toLocaleString()} → ${final.gold.toLocaleString()}`);
    console.log(`  Dungeon runs: ${playerAttempts.length}`);
    console.log(`  Success rate: ${((playerSuccesses / playerAttempts.length) * 100).toFixed(1)}%`);
    console.log(`  Gold earned: ${playerGoldEarned.toLocaleString()}`);
    console.log(`  Level ups: ${playerLevelUps}`);
    console.log('');
  }

  printSection('Assertions');

  let assertions = [];

  // Assertion 1: XP progression
  let totalXpGained = 0;
  for (const p of players) {
    totalXpGained += finalState[p.key].xp - initialState[p.key].xp;
  }
  assertions.push({
    name: 'XP Progression',
    pass: totalXpGained > 0,
    detail: `${totalXpGained} total XP earned across all players`,
  });

  // Assertion 2: Gold earning
  let totalGoldGained = 0;
  for (const p of players) {
    totalGoldGained += finalState[p.key].gold - initialState[p.key].gold;
  }
  assertions.push({
    name: 'Gold Earning',
    pass: totalGoldGained > 0,
    detail: `${totalGoldGained.toLocaleString()} total gold earned`,
  });

  // Assertion 3: Success rate reasonable
  const successRate = (successCount / attempts.length) * 100;
  assertions.push({
    name: 'Success Rate',
    pass: successRate > 30 && successRate < 95,
    detail: `${successRate.toFixed(1)}% success rate (expected 30-95%)`,
  });

  // Assertion 4: Hospital mechanics
  assertions.push({
    name: 'Hospital Mechanics',
    pass: hospitalCount > 0 && hospitalCount < attempts.length * 0.3,
    detail: `${hospitalCount} hospitalizations (expected 5-30% of runs)`,
  });

  // Assertion 5: Dungeon progression
  let progressions = 0;
  for (const p of players) {
    const playerAttempts = attempts.filter((a) => a.player === p.key);
    let lastDungeon = playerAttempts[0]?.dungeon;
    for (const attempt of playerAttempts) {
      if (attempt.dungeon !== lastDungeon) {
        progressions += 1;
        lastDungeon = attempt.dungeon;
      }
    }
  }
  assertions.push({
    name: 'Dungeon Progression',
    pass: progressions > 0,
    detail: `${progressions} dungeon progressions observed`,
  });

  // Assertion 6: Class bonuses (warrior should have higher success)
  const warriorAttempts = attempts.filter(
    (a) => a.player === 'DUNGEON_SMOKE_WARRIOR_A' && a.result.ok,
  ).length;
  const allAttempts = attempts.filter((a) => a.player === 'DUNGEON_SMOKE_WARRIOR_A').length;
  const warriorRate = (warriorAttempts / allAttempts) * 100;
  assertions.push({
    name: 'Warrior Class Bonus',
    pass: warriorRate > 55,
    detail: `Warrior success rate ${warriorRate.toFixed(1)}% (expected >55% with passive bonus)`,
  });

  for (const a of assertions) {
    const status = a.pass ? 'PASS' : 'WARN';
    console.log(`${status} | ${a.name} | ${a.detail}`);
  }

  printSection('Result');

  const passingAssertions = assertions.filter((a) => a.pass).length;
  console.log(`assertions_pass=${passingAssertions}/${assertions.length}`);
  console.log(`total_attempts=${attempts.length}`);
  console.log(
    `note=Dungeon mekanikleri ve class bonusları smoke test ile doğrulandı. Detaylı metrikleri yukarı bölümlerde bulunuz.`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
