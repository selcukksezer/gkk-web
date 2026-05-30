#!/usr/bin/env node

/**
 * CLASS BONUSES - 1000-RUN SMOKE TEST
 * ===================================
 * Warrior, Alchemist, Shadow için success rate, gold, hospital, loot testleri
 */

import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

const ROOT = process.cwd();
dotenv.config({ path: path.join(ROOT, '.env.local') });

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ Missing Supabase config');
  process.exit(1);
}

const TEST_CONFIGS = [
  { 
    email: process.env.DUNGEON_SMOKE_WARRIOR_A_EMAIL,
    password: process.env.DUNGEON_SMOKE_WARRIOR_A_PASSWORD,
    class: 'warrior',
    description: 'Warrior'
  },
  { 
    email: process.env.DUNGEON_SMOKE_ALCHEMIST_A_EMAIL,
    password: process.env.DUNGEON_SMOKE_ALCHEMIST_A_PASSWORD,
    class: 'alchemist',
    description: 'Alchemist'
  },
  { 
    email: process.env.DUNGEON_SMOKE_SHADOW_A_EMAIL,
    password: process.env.DUNGEON_SMOKE_SHADOW_A_PASSWORD,
    class: 'shadow',
    description: 'Shadow'
  },
];

const DUNGEON_NAME = 'Luporum Cubile'; // Non-boss dungeon (power: 0 = unlimited success)
const RUNS_PER_CLASS = 1000;
const DELAY_MS = 30;
const BATCH_REPORT = 100;

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

function now() { return new Date().toISOString(); }

async function login(supabase, email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data?.session) throw new Error(`Login failed: ${error?.message}`);
  return data.user.id;
}

async function getProfile(supabase, authId) {
  const { data } = await supabase.from('users').select('*').eq('auth_id', authId).single();
  return data;
}

async function getDungeonId(supabase, dungeonName) {
  const { data } = await supabase.from('dungeons').select('id').eq('name', dungeonName).single();
  return data?.id;
}

async function ensureEnergy(supabase, authId, dungeonId) {
  // Get dungeon energy cost
  const { data: dungeon } = await supabase.from('dungeons').select('energy_cost').eq('id', dungeonId).single();
  const needed = (dungeon?.energy_cost || 10) * 1200; // 1200 run için +%20 buffer
  
  const { data: user } = await supabase.from('users').select('energy').eq('auth_id', authId).single();
  if ((user?.energy || 0) < needed) {
    await supabase.from('users').update({ energy: 50000 }).eq('auth_id', authId);
  }
}

async function runDungeon(supabase, authId, dungeonId) {
  try {
    const { data, error } = await supabase.rpc('enter_dungeon', {
      p_player_id: authId,
      p_dungeon_id: dungeonId,
    });

    if (error) {
      // Skip is_visible errors in old migration - try attack_dungeon instead
      if (error.message.includes('is_visible')) {
        return { error: 'SCHEMA_ERROR', data: null };
      }
      return { error: error.message, data: null };
    }
    
    if (data?.error) {
      return { error: data.error, data: null };
    }
    
    return { error: null, data };
  } catch (err) {
    return { error: err.message, data: null };
  }
}

async function testClass(config) {
  console.log(`\n${'='.repeat(70)}`);
  console.log(`🧪 ${config.description.toUpperCase()} CLASS SMOKE TEST`);
  console.log(`${'='.repeat(70)}\n`);

  const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false },
  });

  try {
    // Login
    console.log(`📝 Logging in: ${config.email}...`);
    const authId = await login(supabase, config.email, config.password);
    console.log(`✅ Auth ID: ${authId}\n`);

    // Get profile
    const profile = await getProfile(supabase, authId);
    console.log(`📊 Profile:`);
    console.log(`   Class: ${profile.character_class}`);
    console.log(`   Level: ${profile.level}`);
    console.log(`   Power: ${profile.power}`);
    console.log(`   Luck: ${profile.luck}`);
    console.log(`   Defense: ${profile.defense}\n`);

    // Verify class matches config
    if (profile.character_class !== config.class) {
      console.error(`⚠️  WARNING: Profile class is ${profile.character_class}, expected ${config.class}`);
      console.log(`   → Will continue with ${profile.character_class}\n`);
    }

    // Get dungeon
    console.log(`🗺️  Looking for dungeon: ${DUNGEON_NAME}...`);
    const dungeonId = await getDungeonId(supabase, DUNGEON_NAME);
    if (!dungeonId) {
      console.error(`❌ Dungeon not found: ${DUNGEON_NAME}`);
      return null;
    }
    console.log(`✅ Dungeon ID: ${dungeonId}\n`);

    // Ensure energy
    console.log(`⚡ Ensuring energy...`);
    await ensureEnergy(supabase, authId, dungeonId);
    console.log(`✅ Energy ready\n`);

    // Run dungeon 1000 times
    console.log(`🎮 Starting ${RUNS_PER_CLASS} runs...\n`);

    const results = {
      total_runs: 0,
      successes: 0,
      failures: 0,
      hospitalizations: 0,
      total_gold: 0,
      total_xp: 0,
      total_items: 0,
      critical_hits: 0,
      errors: 0,
      avg_gold_per_success: 0,
      avg_xp_per_success: 0,
      avg_items_per_success: 0,
      success_rate: 0,
      hospitalization_rate: 0,
      critical_rate: 0,
    };

    const startTime = Date.now();

    for (let i = 0; i < RUNS_PER_CLASS; i++) {
      const { error, data } = await runDungeon(supabase, authId, dungeonId);

      if (error) {
        results.errors++;
        if (i % BATCH_REPORT === 0) {
          console.log(`  [${i}/${RUNS_PER_CLASS}] ⚠️  Error: ${error}`);
        }
        continue;
      }

      results.total_runs++;

      if (data.success) {
        results.successes++;
        results.total_gold += data.gold_earned || 0;
        results.total_xp += data.xp_earned || 0;
        results.total_items += data.items_dropped?.length || 0;
        if (data.is_critical) results.critical_hits++;
      } else {
        results.failures++;
      }

      if (data.hospitalized) {
        results.hospitalizations++;
      }

      if ((i + 1) % BATCH_REPORT === 0) {
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        const successRate = ((results.successes / results.total_runs) * 100).toFixed(1);
        console.log(`  [${i + 1}/${RUNS_PER_CLASS}] Success: ${results.successes}/${results.total_runs} (${successRate}%) | Gold: ${results.total_gold} | Items: ${results.total_items} | Hospital: ${results.hospitalizations} | Time: ${elapsed}s`);
      }

      await sleep(DELAY_MS);
    }

    // Calculate averages
    results.success_rate = (results.successes / results.total_runs) * 100;
    results.hospitalization_rate = (results.hospitalizations / results.total_runs) * 100;
    results.avg_gold_per_success = results.successes > 0 ? results.total_gold / results.successes : 0;
    results.avg_xp_per_success = results.successes > 0 ? results.total_xp / results.successes : 0;
    results.avg_items_per_success = results.successes > 0 ? results.total_items / results.successes : 0;
    results.critical_rate = results.successes > 0 ? (results.critical_hits / results.successes) * 100 : 0;

    console.log(`\n${'─'.repeat(70)}`);
    console.log(`📈 RESULTS FOR ${config.description.toUpperCase()}`);
    console.log(`${'─'.repeat(70)}`);
    console.log(`Total Runs:             ${results.total_runs}`);
    console.log(`Successes:              ${results.successes}`);
    console.log(`Success Rate:           ${results.success_rate.toFixed(2)}%`);
    console.log(`Critical Hits:          ${results.critical_hits}`);
    console.log(`Critical Rate:          ${results.critical_rate.toFixed(2)}%`);
    console.log(`Avg Gold (per success): ${results.avg_gold_per_success.toFixed(0)}`);
    console.log(`Total Gold:             ${results.total_gold}`);
    console.log(`Avg XP (per success):   ${results.avg_xp_per_success.toFixed(0)}`);
    console.log(`Total XP:               ${results.total_xp}`);
    console.log(`Hospitalizations:       ${results.hospitalizations}`);
    console.log(`Hospital Rate:          ${results.hospitalization_rate.toFixed(2)}%`);
    console.log(`Total Items Dropped:    ${results.total_items}`);
    console.log(`Avg Items (per success):${results.avg_items_per_success.toFixed(2)}`);
    console.log(`Errors:                 ${results.errors}`);

    return results;
  } catch (err) {
    console.error(`❌ Test failed: ${err.message}`);
    return null;
  }
}

async function main() {
  console.log(`\n${'█'.repeat(70)}`);
  console.log(`   CLASS BONUSES - 1000-RUN COMPREHENSIVE SMOKE TEST`);
  console.log(`${'█'.repeat(70)}\n`);
  console.log(`📍 Dungeon: ${DUNGEON_NAME} (Boss)`);
  console.log(`📊 Runs per class: ${RUNS_PER_CLASS}`);
  console.log(`⏱️  Delay between runs: ${DELAY_MS}ms\n`);

  const allResults = {};

  for (const config of TEST_CONFIGS) {
    const result = await testClass(config);
    if (result) {
      allResults[config.class] = result;
    }
  }

  // Summary table
  console.log(`\n${'█'.repeat(70)}`);
  console.log(`   COMPARISON TABLE`);
  console.log(`${'█'.repeat(70)}\n`);

  if (Object.keys(allResults).length > 0) {
    console.log(`${'Metric'.padEnd(25)} | ${'Warrior'.padEnd(15)} | ${'Alchemist'.padEnd(15)} | ${'Shadow'.padEnd(15)}`);
    console.log(`${'-'.repeat(25)}-+-${'-'.repeat(15)}-+-${'-'.repeat(15)}-+-${'-'.repeat(15)}`);

    const metrics = [
      { name: 'Success Rate (%)', key: 'success_rate', format: (v) => v.toFixed(2) },
      { name: 'Avg Gold', key: 'avg_gold_per_success', format: (v) => v.toFixed(0) },
      { name: 'Hospital Rate (%)', key: 'hospitalization_rate', format: (v) => v.toFixed(2) },
      { name: 'Avg Items', key: 'avg_items_per_success', format: (v) => v.toFixed(2) },
      { name: 'Critical Rate (%)', key: 'critical_rate', format: (v) => v.toFixed(2) },
    ];

    for (const metric of metrics) {
      const warrior = allResults.warrior ? allResults.warrior[metric.key] : 'N/A';
      const alchemist = allResults.alchemist ? allResults.alchemist[metric.key] : 'N/A';
      const shadow = allResults.shadow ? allResults.shadow[metric.key] : 'N/A';

      const w = typeof warrior === 'number' ? metric.format(warrior) : warrior;
      const a = typeof alchemist === 'number' ? metric.format(alchemist) : alchemist;
      const s = typeof shadow === 'number' ? metric.format(shadow) : shadow;

      console.log(`${metric.name.padEnd(25)} | ${w.padEnd(15)} | ${a.padEnd(15)} | ${s.padEnd(15)}`);
    }
  }

  // Save results
  const outputDir = path.join(ROOT, 'scripts', 'output');
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  const outputFile = path.join(outputDir, `class_bonuses_1000run_${timestamp}.json`);
  
  fs.writeFileSync(outputFile, JSON.stringify({
    timestamp: now(),
    dungeon: DUNGEON_NAME,
    runs_per_class: RUNS_PER_CLASS,
    results: allResults,
    expected_order: {
      success_rate: 'Alchemist > Warrior > Shadow',
      avg_gold: 'Warrior ≥ Alchemist (warrior +15% boss bonus)',
      hospital_rate: 'Warrior < Alchemist = Shadow',
      avg_items: 'Shadow > Alchemist = Warrior (shadow x1.40 luck)',
    }
  }, null, 2));

  console.log(`\n✅ Results saved: ${outputFile}\n`);
}

main().catch(console.error);
