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
  if (fs.existsSync(localPath)) dotenv.config({ path: localPath, override: false });
  if (fs.existsSync(envPath)) dotenv.config({ path: envPath, override: false });
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value || !value.trim()) throw new Error(`Missing env var: ${name}`);
  return value.trim();
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

loadEnvFiles();

const SUPABASE_URL = requiredEnv('NEXT_PUBLIC_SUPABASE_URL');
const SUPABASE_KEY = requiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY');
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function createOrLoginPlayer(email, password) {
  let player, session;

  const signUpRes = await supabase.auth.signUp({ email, password });
  if (signUpRes.error) {
    const loginRes = await supabase.auth.signInWithPassword({ email, password });
    player = loginRes.data.user;
    session = loginRes.data.session;
  } else {
    player = signUpRes.data.user;
    session = signUpRes.data.session;
  }

  if (session) {
    await supabase.auth.setSession(session);
  }

  const { data: profile } = await supabase.from('users').select('*').eq('id', player.id).maybeSingle();
  return { 
    id: player.id, 
    email: player.email,
    ...(profile || { level: 1, power: 0, xp: 0, gold: 1000, energy: 100, gems: 100, character_class: 'alchemist', in_hospital: false })
  };
}

async function updateUserLimits(userId) {
  await supabase.rpc('update_user_limits', {
    p_user_id: userId,
    p_energy: 10000,
    p_gems: 10000,
  });
}

async function runDungeon(player, dungeonId) {
  try {
    if (player._email && player._password) {
      const { data: { session } } = await supabase.auth.signInWithPassword({
        email: player._email,
        password: player._password,
      });
      if (session) {
        await supabase.auth.setSession(session);
      }
    }

    const { data, error } = await supabase.rpc('enter_dungeon', {
      p_player_id: player.id,
      p_dungeon_id: dungeonId,
    });

    if (error) throw error;

    return {
      success: data?.success ?? true,
      gold: data?.gold_earned || 0,
      xp: data?.xp_earned || 0,
      hospitalized: data?.hospitalized ?? false,
      hospital_until: data?.hospital_until,
    };
  } catch (err) {
    return {
      success: false,
      error: err.message,
      gold: 0,
      xp: 0,
      hospitalized: false,
    };
  }
}

async function main() {
  console.log('═'.repeat(72));
  console.log('Hospital Zone Fix Verification Test');
  console.log('Testing: Zone 1 (dng_001) should have 0% hospitalization');
  console.log('Testing: Zone 2 (dng_010) should have variable hospitalization');
  console.log('═'.repeat(72));

  // Create test player
  const email = `hospital-test-${Date.now()}@test.com`;
  const password = 'test123456';

  console.log(`\n📝 Creating test player: ${email}`);
  const player = await createOrLoginPlayer(email, password);
  player._email = email;
  player._password = password;

  console.log(`✓ Player created: ${player.id}`);

  // Grant unlimited energy
  await updateUserLimits(player.id);
  console.log('✓ Limits updated (unlimited energy/gems)');

  // ========================================================================
  // Test 1: dng_001 (Zone 1 - should be 0% hospitalization)
  // ========================================================================
  console.log('\n' + '─'.repeat(72));
  console.log('TEST 1: dng_001 (Zone 1 - Expected: 0% hospitalization)');
  console.log('─'.repeat(72));

  const zone1Results = [];
  for (let i = 0; i < 10; i++) {
    const result = await runDungeon(player, 'dng_001');
    zone1Results.push(result);
    
    const status = result.hospitalized ? '🏥 HOSPITALIZED' : '✓ OK';
    console.log(`Run ${i+1}: ${status} | success=${result.success} | gold=${result.gold} | xp=${result.xp}`);
    
    await sleep(200);
  }

  const zone1HospitalizationRate = (zone1Results.filter(r => r.hospitalized).length / zone1Results.length) * 100;
  console.log(`\n📊 Zone 1 Results: ${zone1HospitalizationRate.toFixed(1)}% hospitalization rate`);
  console.log(`   Expected: 0% (since Zone 1 should have NO hospitalization risk)`);

  // ========================================================================
  // Test 2: dng_010 (Zone 2 - should have high hospitalization for low power)
  // ========================================================================
  console.log('\n' + '─'.repeat(72));
  console.log('TEST 2: dng_010 (Zone 2 - Expected: High hospitalization for power 0 player)');
  console.log('─'.repeat(72));

  // Refresh player (should still be power 0)
  const { data: freshPlayer } = await supabase.from('users').select('*').eq('id', player.id).maybeSingle();
  const zone2Results = [];
  for (let i = 0; i < 10; i++) {
    const result = await runDungeon(freshPlayer, 'dng_010');
    zone2Results.push(result);
    
    const status = result.hospitalized ? '🏥 HOSPITALIZED' : '✓ OK';
    console.log(`Run ${i+1}: ${status} | success=${result.success} | gold=${result.gold} | xp=${result.xp}`);
    
    await sleep(200);
  }

  const zone2HospitalizationRate = (zone2Results.filter(r => r.hospitalized).length / zone2Results.length) * 100;
  console.log(`\n📊 Zone 2 Results: ${zone2HospitalizationRate.toFixed(1)}% hospitalization rate`);
  console.log(`   Expected: >50% (since power 0 vs power_req 10000 = very low success chance)`);

  // ========================================================================
  // VERDICT
  // ========================================================================
  console.log('\n' + '═'.repeat(72));
  console.log('VERDICT');
  console.log('═'.repeat(72));

  if (zone1HospitalizationRate === 0 && zone2HospitalizationRate > 30) {
    console.log('✅ PASS: Hospital zone fix is working correctly!');
    console.log(`   Zone 1 (dng_001): ${zone1HospitalizationRate.toFixed(1)}% hospitalization ✓`);
    console.log(`   Zone 2 (dng_010): ${zone2HospitalizationRate.toFixed(1)}% hospitalization ✓`);
  } else {
    console.log('❌ FAIL: Hospital zone fix not applied or RPC update needed');
    console.log(`   Zone 1 (dng_001): ${zone1HospitalizationRate.toFixed(1)}% (expected 0%)`);
    console.log(`   Zone 2 (dng_010): ${zone2HospitalizationRate.toFixed(1)}% (expected >30%)`);
    console.log('\n💡 Fix: Migration file created at supabase/migrations/20260503_050000_fix_hospital_zone1.sql');
    console.log('   Run: supabase db push');
  }

  process.exit(zone1HospitalizationRate === 0 && zone2HospitalizationRate > 30 ? 0 : 1);
}

main().catch(err => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
