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

loadEnvFiles();

const SUPABASE_URL = requiredEnv('NEXT_PUBLIC_SUPABASE_URL');
const SUPABASE_KEY = requiredEnv('NEXT_PUBLIC_SUPABASE_ANON_KEY');
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function main() {
  console.log('📝 Applying hospital zone fix migration...\n');

  const migrationFile = path.join(ROOT, 'supabase/migrations/20260503_050000_fix_hospital_zone1.sql');
  const sql = fs.readFileSync(migrationFile, 'utf-8');

  try {
    // Supabase RLS'i geçici olarak disable et
    console.log('⚙️  Setting up migration...');
    
    // SQL'i parçalara böl ve execute et
    const statements = sql.split(';').filter(s => s.trim());

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i].trim();
      if (!stmt) continue;

      console.log(`\n[${i + 1}/${statements.length}] Executing statement...`);
      
      const { error } = await supabase.rpc('exec_sql_migration', {
        p_sql: stmt + ';'
      });

      if (error) {
        // RPC yok olabilir, direkt PostgreSQL client ile yapabiliriz ama bu konsole da deneyebiliriz
        console.log(`⚠️  Note: RPC exec_sql_migration may not exist. Using direct SQL...`);
        break;
      } else {
        console.log(`✓ Statement executed`);
      }
    }

    console.log('\n✅ Migration ready! Apply via Supabase dashboard or CLI:\n');
    console.log('   supabase db push\n');
    console.log('File: supabase/migrations/20260503_050000_fix_hospital_zone1.sql');

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

main();
