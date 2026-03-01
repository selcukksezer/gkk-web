#!/usr/bin/env node
import { createClient } from "@supabase/supabase-js";

const projectId = "znvsyzstmxhqvdkkmgdt";
const supabaseUrl = `https://${projectId}.supabase.co`;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseKey) {
  console.error("❌ SUPABASE_ANON_KEY environment variable not set");
  console.error("   Set it in .env.local or export it before running this script");
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const rpcsToVerify = {
  "CRAFTING SYSTEM": [
    {
      name: "get_craft_queue",
      params: {},
      description: "Get user's crafting queue",
    },
    {
      name: "get_craft_recipes",
      params: { p_user_level: 1 },
      description: "Get available craft recipes",
    },
    {
      name: "craft_item_async",
      params: { p_user_id: "test", p_recipe_id: "test-recipe", p_batch_count: 1 },
      description: "Start crafting item (will fail without valid user, but RPC should exist)",
      shouldFail: true, // Expected to fail due to invalid params, but RPC exists
    },
    {
      name: "claim_crafted_item",
      params: { p_user_id: "test", p_queue_item_id: "test-queue-id" },
      description: "Claim crafted item",
      shouldFail: true,
    },
  ],
  "BANKING SYSTEM": [
    {
      name: "get_bank_items",
      params: {},
      description: "Get user's bank items",
    },
    {
      name: "expand_bank",
      params: { p_slots: 25 },
      description: "Expand bank capacity",
      shouldFail: true, // May fail due to insufficient gems, but RPC should exist
    },
    {
      name: "deposit_to_bank",
      params: { p_item_row_ids: [] },
      description: "Deposit items to bank",
    },
    {
      name: "withdraw_from_bank",
      params: { p_item_ids: [] },
      description: "Withdraw items from bank",
    },
  ],
};

async function verifyRPC(rpcName, params, description, shouldFail = false) {
  try {
    const { data, error } = await supabase.rpc(rpcName, params);

    if (error) {
      // Check if it's an auth error (expected if not logged in) vs RPC not found
      if (error.message?.includes("does not exist") || error.code === "42883") {
        console.error(`  ❌ ${rpcName}: RPC NOT FOUND`);
        return false;
      } else if (shouldFail) {
        // Expected to fail with functional error (not "not found")
        console.log(`  ✅ ${rpcName}: Exists (failed as expected: ${error.message})`);
        return true;
      } else {
        // Unexpected error, but RPC exists
        console.log(`  ⚠️  ${rpcName}: Exists but returned error: ${error.message}`);
        return true;
      }
    } else {
      console.log(`  ✅ ${rpcName}: Working (${description})`);
      return true;
    }
  } catch (err) {
    console.error(`  ❌ ${rpcName}: ${err.message}`);
    return false;
  }
}

async function main() {
  console.log("\n🔍 Verifying RPC Deployments\n");
  console.log(`📍 Project: ${projectId}`);
  console.log(`🌐 URL: ${supabaseUrl}\n`);

  let allPassed = true;

  for (const [systemName, rpcs] of Object.entries(rpcsToVerify)) {
    console.log(`\n${systemName}`);
    console.log("─".repeat(50));

    for (const rpc of rpcs) {
      const passed = await verifyRPC(
        rpc.name,
        rpc.params,
        rpc.description,
        rpc.shouldFail
      );
      if (!passed && !rpc.shouldFail) {
        allPassed = false;
      }
    }
  }

  console.log("\n" + "═".repeat(50));
  if (allPassed) {
    console.log("✅ All RPCs deployed successfully!");
    console.log("\n📋 Next steps:");
    console.log("  1. npm run dev");
    console.log("  2. Reload browser and test crafting feature");
    console.log("  3. Test bank feature");
  } else {
    console.log("❌ Some RPCs are still missing. Deploy migration and try again.");
  }
  console.log("─".repeat(50) + "\n");
}

main().catch(console.error);
