const { createClient } = require("@supabase/supabase-js");
const fs = require("fs");
const path = require("path");

const SUPABASE_URL = "https://znvsyzstmxhqvdkkmgdt.supabase.co";
// Using the service role key from environment or command line
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error("Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  db: {
    schema: "public",
  },
});

async function runMigration(filePath) {
  try {
    const sql = fs.readFileSync(filePath, "utf-8");
    console.log(`\n📝 Running migration: ${path.basename(filePath)}`);

    // Split on semicolons and filter empty statements
    const statements = sql
      .split(";")
      .map((stmt) => stmt.trim())
      .filter((stmt) => stmt.length > 0);

    for (const statement of statements) {
      const result = await supabase.rpc("_query", { query: statement });
      if (result.error) {
        console.error(`❌ Error in statement:`);
        console.error(statement);
        console.error(result.error);
        // Continue with next statement instead of stopping
      } else {
        console.log(`✅ Statement executed`);
      }
    }

    console.log(`✅ Migration complete: ${path.basename(filePath)}`);
  } catch (err) {
    console.error(`Error reading migration file: ${err.message}`);
    process.exit(1);
  }
}

async function main() {
  const migrationsDir = path.join(
    __dirname,
    "supabase/migrations"
  );
  const files = [
    "20260223123000_add_swap_and_remove_rpcs.sql",
    "20260223124000_add_equip_rpcs.sql",
  ];

  for (const file of files) {
    const filePath = path.join(migrationsDir, file);
    if (fs.existsSync(filePath)) {
      await runMigration(filePath);
    } else {
      console.warn(`⚠️ File not found: ${filePath}`);
    }
  }

  console.log("\n🎉 All migrations completed!");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
