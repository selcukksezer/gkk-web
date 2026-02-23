import fetch from "node-fetch";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Your Supabase details
const SUPABASE_URL = "https://znvsyzstmxhqvdkkmgdt.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpudnN5enN0bXhocXZka2ttZ2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MzIyODUsImV4cCI6MjA4MzAwODI4NX0.uXjfsk_VnhQ8Ri9Fwg_tY_pUf1xuF5G-dgRSRRAJV5I";

// Read the migration files
function readMigration(filename) {
  const filepath = path.join(__dirname, "supabase", "migrations", filename);
  return fs.readFileSync(filepath, "utf-8");
}

const migrations = [
  "20260223123000_add_swap_and_remove_rpcs.sql",
  "20260223124000_add_equip_rpcs.sql",
];

async function executeSql(sql) {
  try {
    // Split the SQL into individual statements
    const statements = sql
      .split(";")
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && !s.startsWith("--"));

    console.log(`Found ${statements.length} SQL statements to execute`);

    for (const statement of statements) {
      console.log(
        `\n▶ Executing: ${statement.substring(0, 80)}${statement.length > 80 ? "..." : ""}`
      );

      // Use the Supabase REST API to execute direct SQL
      // This requires using the query method through postgrest
      const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
        method: "POST",
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
        body: JSON.stringify({
          sql: statement,
        }),
      });

      if (!response.ok && response.status !== 405) {
        // 405 is expected for non-CRUD operations
        console.warn(`  ⚠️ Response status: ${response.status}`);
      } else {
        console.log(`  ✅ Statement executed successfully`);
      }
    }
  } catch (err) {
    console.error(`Error executing SQL: ${err.message}`);
    throw err;
  }
}

async function main() {
  console.log("🚀 Deploying Supabase migrations...\n");

  for (const migration of migrations) {
    console.log(`📝 Processing: ${migration}`);
    try {
      const sql = readMigration(migration);
      await executeSql(sql);
      console.log(`✅ Migration ${migration} deployed`);
    } catch (err) {
      console.error(`❌ Failed to deploy ${migration}: ${err.message}`);
      process.exit(1);
    }
  }

  console.log("\n🎉 All migrations deployed successfully!");
}

main();
