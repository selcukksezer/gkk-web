#!/usr/bin/env node
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const projectId = "znvsyzstmxhqvdkkmgdt";

console.log("\n📖 Reading migration files...");

const craftingMigPath = path.join(__dirname, "./supabase/migrations/20260301_020000_create_craft_queue_and_rpcs.sql");
const bankingMigPath = path.join(__dirname, "./supabase/migrations/20260301_040000_create_knight_online_bank_system.sql");

if (!fs.existsSync(craftingMigPath) || !fs.existsSync(bankingMigPath)) {
  console.error("❌ Migration files not found!");
  process.exit(1);
}

const craftingMig = fs.readFileSync(craftingMigPath, "utf-8");
const bankingMig = fs.readFileSync(bankingMigPath, "utf-8");

const allMigrations = `-- ============================================================
-- COMBINED DEPLOYMENT: Crafting + Banking Systems
-- ============================================================
-- Execute this in Supabase SQL Editor or via CLI with: supabase db push

-- SECTION 1: CRAFTING SYSTEM
-- ============================================================

${craftingMig}

-- SECTION 2: BANKING SYSTEM  
-- ============================================================

${bankingMig}

-- ============================================================
-- DEPLOYMENT COMPLETE
-- ============================================================
`;

const outputFile = path.join(__dirname, "./combined-migrations.sql");
fs.writeFileSync(outputFile, allMigrations, "utf-8");

console.log("✅ Combined migration file created: combined-migrations.sql\n");

console.log("📋 DEPLOYMENT INSTRUCTIONS:\n");
console.log("Option 1: Using Supabase CLI (Recommended)");
console.log("  1. supabase link --project-ref " + projectId);
console.log("  2. supabase db push");
console.log("  3. npm run dev\n");

console.log("Option 2: Using SQL Editor (Manual)");
console.log("  1. Open: https://app.supabase.com/projects/" + projectId + "/sql/new");
console.log("  2. Copy contents of: combined-migrations.sql");
console.log("  3. Paste into SQL Editor");
console.log("  4. Click 'Run'");
console.log("  5. npm run dev\n");

console.log("📊 File Sizes:");
console.log("  Crafting Migration: " + (craftingMig.length / 1024).toFixed(2) + " KB");
console.log("  Banking Migration: " + (bankingMig.length / 1024).toFixed(2) + " KB");
console.log("  Combined: " + (allMigrations.length / 1024).toFixed(2) + " KB\n");

console.log("✨ After deployment, verify with:");
console.log("  1. node ./verify-all-rpcs.mjs");
console.log("  2. Reload http://localhost:3000 in browser");
console.log("  3. Test crafting and bank features\n");
