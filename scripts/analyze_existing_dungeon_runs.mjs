#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import path from 'node:path';
import fs from 'node:fs';

const ROOT = process.cwd();
dotenv.config({ path: path.join(ROOT, '.env.local') });

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function getDungeonRunStats() {
  console.log('\n📊 Analyzing existing dungeon_runs data...\n');

  const testAccounts = [
    { email: 'zindan3@gmail.com', class: 'warrior', auth_id: '6c0605fc-300e-4c52-9908-4a2a0706f25c' },
    { email: 'zindan1@gmail.com', class: 'alchemist', auth_id: 'fef07751-33ff-4752-b94e-41df18b51874' },
    { email: 'zindan2@gmail.com', class: 'shadow', auth_id: 'ccfabb01-efa3-4cec-a305-27247764eaf6' },
  ];

  const results = {};

  for (const account of testAccounts) {
    try {
      // Get last 1000 runs for this player
      const { data: runs, error } = await supabase
        .from('dungeon_runs')
        .select('*')
        .eq('player_id', account.auth_id)
        .order('created_at', { ascending: false })
        .limit(1000);

      if (error || !runs || runs.length === 0) {
        console.log(`❌ ${account.class.toUpperCase()}: No runs found`);
        continue;
      }

      // Calculate stats
      const stats = {
        total_runs: runs.length,
        successes: runs.filter(r => r.success).length,
        failures: runs.filter(r => !r.success).length,
        hospitalizations: runs.filter(r => r.hospitalized).length,
        criticals: runs.filter(r => r.is_critical).length,
        total_gold: runs.reduce((sum, r) => sum + (r.gold_earned || 0), 0),
        total_xp: runs.reduce((sum, r) => sum + (r.xp_earned || 0), 0),
        total_items: runs.reduce((sum, r) => sum + (r.items_dropped?.length || 0), 0),
      };

      stats.success_rate = ((stats.successes / stats.total_runs) * 100).toFixed(2);
      stats.hospital_rate = ((stats.hospitalizations / stats.total_runs) * 100).toFixed(2);
      stats.critical_rate = stats.successes > 0 
        ? ((stats.criticals / stats.successes) * 100).toFixed(2)
        : '0.00';
      stats.avg_gold = stats.successes > 0 
        ? Math.round(stats.total_gold / stats.successes)
        : 0;
      stats.avg_xp = stats.successes > 0 
        ? Math.round(stats.total_xp / stats.successes)
        : 0;
      stats.avg_items = stats.successes > 0 
        ? (stats.total_items / stats.successes).toFixed(2)
        : '0.00';

      results[account.class] = { ...stats, auth_id: account.auth_id };

      console.log(`\n✅ ${account.class.toUpperCase()}`);
      console.log(`   Runs: ${stats.total_runs}`);
      console.log(`   Success: ${stats.successes}/${stats.total_runs} (${stats.success_rate}%)`);
      console.log(`   Critical: ${stats.criticals} (${stats.critical_rate}% of successes)`);
      console.log(`   Avg Gold: ${stats.avg_gold}`);
      console.log(`   Avg XP: ${stats.avg_xp}`);
      console.log(`   Hospitalizations: ${stats.hospitalizations} (${stats.hospital_rate}%)`);
      console.log(`   Total Items: ${stats.total_items} (avg ${stats.avg_items}/success)`);

    } catch (err) {
      console.error(`❌ ${account.class}: ${err.message}`);
    }
  }

  // Summary table
  console.log(`\n${'═'.repeat(80)}`);
  console.log('COMPARISON TABLE\n');
  
  if (Object.keys(results).length > 0) {
    console.log(`${'Metric'.padEnd(25)} | ${'Warrior'.padEnd(18)} | ${'Alchemist'.padEnd(18)} | ${'Shadow'.padEnd(18)}`);
    console.log(`${'-'.repeat(25)}-+-${'-'.repeat(18)}-+-${'-'.repeat(18)}-+-${'-'.repeat(18)}`);

    const metrics = [
      { name: 'Total Runs', format: (r) => r.total_runs.toString() },
      { name: 'Success Rate (%)', format: (r) => r.success_rate },
      { name: 'Avg Gold', format: (r) => r.avg_gold.toString() },
      { name: 'Hospital Rate (%)', format: (r) => r.hospital_rate },
      { name: 'Avg Items', format: (r) => r.avg_items },
      { name: 'Critical Rate (%)', format: (r) => r.critical_rate },
    ];

    for (const m of metrics) {
      const warrior = results.warrior ? m.format(results.warrior) : 'N/A';
      const alchemist = results.alchemist ? m.format(results.alchemist) : 'N/A';
      const shadow = results.shadow ? m.format(results.shadow) : 'N/A';

      console.log(`${m.name.padEnd(25)} | ${warrior.padEnd(18)} | ${alchemist.padEnd(18)} | ${shadow.padEnd(18)}`);
    }
  }

  // Save to file
  const outputDir = path.join(ROOT, 'scripts', 'output');
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  const file = path.join(outputDir, `class_bonuses_analysis_${timestamp}.json`);

  fs.writeFileSync(file, JSON.stringify({
    timestamp: new Date().toISOString(),
    results,
    analysis: {
      expected_order_success_rate: 'Alchemist > Warrior > Shadow',
      expected_avg_gold: 'Warrior ≥ Alchemist (boss bonus)',
      expected_hospital_rate: 'Warrior < Alchemist = Shadow',
      expected_items: 'Shadow > Alchemist = Warrior',
    }
  }, null, 2));

  console.log(`\n✅ Results saved: ${file}\n`);
}

getDungeonRunStats().catch(console.error);
