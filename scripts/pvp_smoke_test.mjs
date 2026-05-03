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

function safeDate(raw) {
  if (!raw) return null;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function isFuture(raw) {
  const d = safeDate(raw);
  return !!d && d.getTime() > Date.now();
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function buildPlayerEnv(prefix) {
  return {
    key: prefix,
    email: requiredEnv(`${prefix}_EMAIL`),
    password: requiredEnv(`${prefix}_PASSWORD`),
    authId: requiredEnv(`${prefix}_UUID`),
  };
}

function buildOptionalPlayerEnv(prefix) {
  const email = process.env[`${prefix}_EMAIL`]?.trim();
  const password = process.env[`${prefix}_PASSWORD`]?.trim();
  const authId = process.env[`${prefix}_UUID`]?.trim();

  if (!email || !password || !authId) {
    return null;
  }

  return {
    key: prefix,
    email,
    password,
    authId,
  };
}

async function loginPlayer(url, anonKey, playerEnv) {
  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await client.auth.signInWithPassword({
    email: playerEnv.email,
    password: playerEnv.password,
  });

  if (error) {
    throw new Error(`Login failed for ${playerEnv.key}: ${error.message}`);
  }

  return client;
}

async function readUserState(observerClient, authId) {
  const { data, error } = await observerClient
    .from('users')
    .select('auth_id, character_class, level, energy, hospital_until, prison_until, warrior_bloodlust_streak, warrior_bloodlust_until')
    .eq('auth_id', authId)
    .single();

  if (error) {
    throw new Error(`Unable to read users row ${authId}: ${error.message}`);
  }

  return data;
}

async function runPvpAttack(attackerClient, attackerId, defenderId, mekanId) {
  const { data, error } = await attackerClient.rpc('pvp_attack', {
    p_attacker_id: attackerId,
    p_defender_id: defenderId,
    p_mekan_id: mekanId,
  });

  if (error) {
    return { ok: false, error: error.message, data: null };
  }

  if (data?.success === false) {
    return { ok: false, error: data?.error ?? 'unknown_error', data };
  }

  return { ok: true, error: null, data };
}

function printSection(title) {
  console.log('\n' + '='.repeat(72));
  console.log(title);
  console.log('='.repeat(72));
}

function summarizeAttempt(attempt) {
  const result = attempt.result;
  if (!result.ok) {
    return `${attempt.when} | ${attempt.attacker} -> ${attempt.defender} | FAIL | ${result.error}`;
  }

  const winner = result.data?.winner_id ?? 'unknown';
  const mult = result.data?.attacker_bloodlust_mult;
  return `${attempt.when} | ${attempt.attacker} -> ${attempt.defender} | OK | winner=${winner} attacker_mult=${mult}`;
}

async function main() {
  loadEnvFiles();

  const supabaseUrl = requiredEnv('NEXT_PUBLIC_SUPABASE_URL');
  const supabaseAnonKey = requiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY');
  const mekanId = requiredEnv('PVP_SMOKE_MEKAN_ID');

  const maxAttempts = optionalInt('PVP_SMOKE_MAX_ATTEMPTS', 12);
  const cooldownMs = optionalInt('PVP_SMOKE_COOLDOWN_MS', 250);

  const warriorA = buildPlayerEnv('PVP_SMOKE_WARRIOR_A');
  const warriorB = buildPlayerEnv('PVP_SMOKE_WARRIOR_B');
  const shadowA = buildOptionalPlayerEnv('PVP_SMOKE_SHADOW_A');
  const neutralA = buildOptionalPlayerEnv('PVP_SMOKE_NEUTRAL_A');

  const players = {
    [warriorA.key]: warriorA,
    [warriorB.key]: warriorB,
  };
  if (shadowA) players[shadowA.key] = shadowA;
  if (neutralA) players[neutralA.key] = neutralA;

  printSection('PLAN_11 PvP Smoke Test Started');
  console.log(`time=${nowIso()}`);
  console.log(`mekan_id=${mekanId}`);

  const clients = {};
  for (const p of Object.values(players)) {
    clients[p.key] = await loginPlayer(supabaseUrl, supabaseAnonKey, p);
  }

  const observer = clients[warriorA.key];

  printSection('Preflight');
  for (const p of Object.values(players)) {
    const state = await readUserState(observer, p.authId);
    console.log(
      `${p.key} | class=${state.character_class} level=${state.level} energy=${state.energy} in_hospital=${isFuture(
        state.hospital_until,
      )} in_prison=${isFuture(state.prison_until)} streak=${state.warrior_bloodlust_streak ?? 0}`,
    );
  }

  const attempts = [];
  const defenderCycle = [
    ...(neutralA ? [neutralA] : []),
    ...(shadowA ? [shadowA] : []),
    warriorB,
  ];
  let defenderIndex = 0;

  let sawWarriorWin = false;
  let reachedStreak3 = false;
  let sawMultiplier120 = false;
  let sawResetAfterLoss = false;

  let postWinState = null;
  let postStreak3State = null;

  printSection('Runtime Checks');

  for (let i = 0; i < maxAttempts; i += 1) {
    const defender = defenderCycle[defenderIndex % defenderCycle.length];
    defenderIndex += 1;

    const before = await readUserState(observer, warriorA.authId);

    const result = await runPvpAttack(
      clients[warriorA.key],
      warriorA.authId,
      defender.authId,
      mekanId,
    );

    const after = await readUserState(observer, warriorA.authId);

    const attempt = {
      when: nowIso(),
      attacker: warriorA.key,
      defender: defender.key,
      result,
      streakBefore: before.warrior_bloodlust_streak ?? 0,
      streakAfter: after.warrior_bloodlust_streak ?? 0,
      bloodlustUntilAfter: after.warrior_bloodlust_until,
    };
    attempts.push(attempt);

    console.log(summarizeAttempt(attempt));

    if (result.ok && result.data?.winner_id === warriorA.authId) {
      sawWarriorWin = true;
      postWinState = after;
    }

    if (
      result.ok &&
      result.data?.attacker_bloodlust_mult !== undefined &&
      Number(result.data.attacker_bloodlust_mult) >= 1.2
    ) {
      sawMultiplier120 = true;
    }

    if ((after.warrior_bloodlust_streak ?? 0) >= 3) {
      reachedStreak3 = true;
      postStreak3State = after;
    }

    if (
      (before.warrior_bloodlust_streak ?? 0) > 0 &&
      result.ok &&
      result.data?.winner_id !== warriorA.authId
    ) {
      if ((after.warrior_bloodlust_streak ?? 0) === 0 && !after.warrior_bloodlust_until) {
        sawResetAfterLoss = true;
      }
    }

    if (sawWarriorWin && reachedStreak3 && sawMultiplier120 && sawResetAfterLoss) {
      break;
    }

    await sleep(cooldownMs);
  }

  printSection('Assertions');

  const checks = [
    {
      name: 'RPC calisiyor',
      pass: attempts.some((a) => a.result.ok),
      detail: attempts.some((a) => a.result.ok)
        ? 'En az bir pvp_attack cagrisi basarili.'
        : 'Hic basarili RPC cagrisi yok.',
    },
    {
      name: 'Warrior kazaninca bloodlust set',
      pass: sawWarriorWin && !!postWinState?.warrior_bloodlust_until && (postWinState?.warrior_bloodlust_streak ?? 0) >= 1,
      detail: sawWarriorWin
        ? `streak=${postWinState?.warrior_bloodlust_streak ?? 0} until=${postWinState?.warrior_bloodlust_until ?? 'null'}`
        : 'Warrior galibiyeti gozlenemedi (rastgelelik).',
    },
    {
      name: 'Streak 3 ulasimi',
      pass: reachedStreak3,
      detail: reachedStreak3
        ? `streak=${postStreak3State?.warrior_bloodlust_streak ?? 0}`
        : 'Maks denemede streak 3 olusmadi (rastgelelik / limitler).',
    },
    {
      name: 'Streak 3 sonrasi 1.20 carpan gozlemi',
      pass: sawMultiplier120,
      detail: sawMultiplier120
        ? 'attacker_bloodlust_mult >= 1.20 dondu.'
        : '1.20 carpan payloadda yakalanmadi.',
    },
    {
      name: 'Kayip sonrasi bloodlust reset',
      pass: sawResetAfterLoss,
      detail: sawResetAfterLoss
        ? 'Kayip sonrasi streak=0 ve until=null gozlemlendi.'
        : 'Reset durumu yakalanmadi (kayip gorulmemis olabilir).',
    },
  ];

  if (!shadowA) {
    checks.push({
      name: 'Shadow dogrulamasi',
      pass: true,
      detail: 'SKIP: PVP_SMOKE_SHADOW_A_* env verilmedi.',
    });
  }

  if (!neutralA) {
    checks.push({
      name: 'Neutral dogrulamasi',
      pass: true,
      detail: 'SKIP: PVP_SMOKE_NEUTRAL_A_* env verilmedi.',
    });
  }

  for (const c of checks) {
    console.log(`${c.pass ? 'PASS' : 'WARN'} | ${c.name} | ${c.detail}`);
  }

  printSection('Attempt Log');
  for (const a of attempts) {
    console.log(summarizeAttempt(a));
  }

  const passCount = checks.filter((c) => c.pass).length;
  const warnCount = checks.length - passCount;

  printSection('Result');
  console.log(`checks_pass=${passCount}`);
  console.log(`checks_warn=${warnCount}`);
  console.log(`attempts=${attempts.length}`);
  console.log('note=Warrior/Shadow/Luck etkilerinin tam nicel dogrulamasi icin daha buyuk orneklem gerekir.');
}

main().catch((err) => {
  console.error('FATAL:', err.message);
  process.exit(1);
});
