import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://znvsyzstmxhqvdkkmgdt.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudnN5enN0bXhocXZka2ttZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MzIyODUsImV4cCI6MjA4MzAwODI4NX0.uXjfsk_VnhQ8Ri9Fwg_tY_pUf1xuF5G-dgRSRRAJV5I";

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testRPCs() {
  console.log("Testing RPC function signatures...\n");

  try {
    console.log("1. Testing equip_item with p_item_id, p_slot...");
    const result = await supabase.rpc("equip_item", {
      p_item_id: "00000000-0000-0000-0000-000000000000",
      p_slot: "test",
    });
    console.log("   Result:", result);
  } catch (err) {
    console.error("   Error:", err.message);
  }

  try {
    console.log("\n2. Testing remove_inventory_item_by_row with p_row_id, p_quantity...");
    const result = await supabase.rpc("remove_inventory_item_by_row", {
      p_row_id: "00000000-0000-0000-0000-000000000000",
      p_quantity: 1,
    });
    console.log("   Result:", result);
  } catch (err) {
    console.error("   Error:", err.message);
  }

  console.log("\n✅ RPC testing complete. Check errors above.");
}

testRPCs();
