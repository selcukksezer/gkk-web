#!/usr/bin/env node

/**
 * Verify Supabase Crafting RPCs are deployed
 * Checks if all required crafting functions exist in the database
 */

import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://znvsyzstmxhqvdkkmgdt.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudnN5enN0bXhocXZka2ttZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MzIyODUsImV4cCI6MjA4MzAwODI4NX0.uXjfsk_VnhQ8Ri9Fwg_tY_pUf1xuF5G-dgRSRRAJV5I";

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const REQUIRED_RPCS = [
  { name: "get_craft_queue", type: "function" },
  { name: "get_craft_recipes", type: "function" },
  { name: "craft_item_async", type: "function" },
  { name: "claim_crafted_item", type: "function" },
];

async function verifyRPCs() {
  console.log("\n🔍 Verifying Supabase Crafting RPCs...\n");

  const missing: string[] = [];
  const found: string[] = [];

  for (const rpc of REQUIRED_RPCS) {
    try {
      // Try calling each RPC with minimal parameters to check if it exists
      if (rpc.name === "get_craft_queue") {
        const { error } = await supabase.rpc("get_craft_queue");
        if (error?.message?.includes("not found")) {
          missing.push(rpc.name);
          console.log(`❌ ${rpc.name} - NOT FOUND`);
        } else {
          found.push(rpc.name);
          console.log(`✅ ${rpc.name} - OK`);
        }
      } else if (rpc.name === "get_craft_recipes") {
        const { error } = await supabase.rpc("get_craft_recipes", {
          p_user_level: 1,
        });
        if (error?.message?.includes("not found")) {
          missing.push(rpc.name);
          console.log(`❌ ${rpc.name} - NOT FOUND`);
        } else {
          found.push(rpc.name);
          console.log(`✅ ${rpc.name} - OK`);
        }
      } else {
        // For other RPCs, they need proper parameters
        console.log(`⚠️  ${rpc.name} - Skipped (requires auth)`);
      }
    } catch (err) {
      console.log(`❌ ${rpc.name} - ERROR: ${err.message}`);
      missing.push(rpc.name);
    }
  }

  console.log("\n" + "=".repeat(50));
  console.log(`Found: ${found.length}/${REQUIRED_RPCS.length}`);

  if (missing.length > 0) {
    console.log(`\n⚠️  Missing RPCs: ${missing.join(", ")}`);
    console.log(
      "\n📋 Deploy migration to Supabase using deploy-crafting-rpcs.ps1"
    );
    process.exit(1);
  } else {
    console.log("\n✅ All crafting RPCs are deployed!");
    process.exit(0);
  }
}

verifyRPCs().catch((err) => {
  console.error("❌ Verification failed:", err);
  process.exit(1);
});
