import fs from "fs";
import path from "path";

// Seeds directories
const SEEDS_DIR = path.resolve("./supabase/seeds");
const OUTPUT_DIR = path.resolve("./prompts/midjourney-items");

const FILES_TO_PARSE = [
  "plan1_items.generated.sql",
  "plan2_resources.generated.sql",
  "plan1_consumables.generated.sql",
];

// Helper to extract values from INSERT INTO ... VALUES (...)
// We'll use a simple regex to capture rows: ('id', 'Name', ...)
function parseItemsFromSql(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, "utf8");
  
  const items = [];
  // Regex to match value groups like ('wpn_dagger_common', 'Rookie Piercer', 'weapon', ...)
  // This is a naive regex but works since strings are nicely formatted.
  const regex = /\('([^']+)',\s*'((?:[^']|'')*)',(?:[^,]+,)*?\s*'([^']+)'/g;
  
  // Actually regex on SQL isn't bulletproof. Let's do it better.
  // VALUES\n('id', 'Name', 'Desc/Icon/Type/Rarity' ...)
  // We just need name, item_id, type.
  const rowRegex = /\('([^']+)',\s*'([^']+)'/g;
  
  let match;
  while ((match = rowRegex.exec(content)) !== null) {
      // First is ID, Second is name
      // Example: ('wpn_dagger_common', 'Rookie Piercer'
      const id = match[1];
      const name = match[2];
      
      // Let's guess item category based on ID prefixes
      let category = "";
      if (id.startsWith("wpn")) category = "Weapon";
      else if (id.startsWith("amulet") || id.startsWith("neck")) category = "Necklace";
      else if (id.startsWith("ring")) category = "Ring";
      else if (id.startsWith("arm") || id.startsWith("chest") || id.startsWith("head") || id.startsWith("legs") || id.startsWith("boots") || id.startsWith("gloves")) category = "Armor";
      else if (id.startsWith("res_")) category = "Resource";
      else if (id.startsWith("potion")) category = "Potion";
      else if (id.startsWith("scroll")) category = "Scroll";
      else if (id.startsWith("catalyst")) category = "Catalyst";
      else category = "Misc";
      
      let rarity = "common";
      if (id.includes("_uncommon")) rarity = "Uncommon";
      else if (id.includes("_rare")) rarity = "Rare";
      else if (id.includes("_epic")) rarity = "Epic";
      else if (id.includes("_legendary")) rarity = "Legendary";
      else if (id.includes("_mythic")) rarity = "Mythic";

      items.push({ id, name, category, rarity });
  }
  return items;
}

function generatePrompts(items) {
  let md = `# GKK Item Prompts\n\n`;
  md += `Bu dosyadaki tum promptlar oyun icindeki tum esyalarin (weapons, armors, resources, consumables) guncel isimlerine gore uretilmistir.\n\n`;
  
  // Group by category
  const grouped = {};
  for (const item of items) {
    if (!grouped[item.category]) grouped[item.category] = [];
    grouped[item.category].push(item);
  }

  const basePrompt = `stylized 3D MMORPG-like game item icon look, battle-worn, dark metal and weathered surface details, hand-painted PBR feel, non-photorealistic, over-saturated, bright aura and particle effects (especially crimson red or deep blue), cinematic, high contrast, single item, no characters, no scene, three-quarter isometric view, 35-degree angle, facing left, transparent background, game item icon, centered composition, isolated object, no background scene, no text, no watermark, no logo --v 6.0`;

  for (const cat in grouped) {
    md += `## ${cat}\n\n`;
    for (const item of grouped[cat]) {
        let modifier = "";
        if (item.category === "Weapon") modifier = `${item.rarity} rarity ${item.name}, fantasy weapon`;
        if (item.category === "Armor") modifier = `${item.rarity} rarity ${item.name}, fantasy armor piece`;
        if (item.category === "Resource") modifier = `${item.rarity} rarity ${item.name}, raw fantasy crafting material resource`;
        if (item.category === "Potion") modifier = `${item.rarity} rarity ${item.name}, glowing magical potion vial`;
        if (item.category === "Scroll") modifier = `${item.rarity} rarity ${item.name}, ancient magical parchment scroll`;
        if (item.category === "Catalyst") modifier = `${item.rarity} rarity ${item.name}, intense magical glowing crystal catalyst`;
        
        const finalPrompt = `**${item.id}** (${item.name})\n\`\`\`\n${modifier}, ${basePrompt}\n\`\`\`\n`;
        md += finalPrompt + "\n";
    }
  }

  return md;
}

function main() {
  const allItems = [];
  for (const file of FILES_TO_PARSE) {
    const p = path.join(SEEDS_DIR, file);
    const parsed = parseItemsFromSql(p);
    allItems.push(...parsed);
  }

  const outputMd = generatePrompts(allItems);
  
  // Clean old files (optional) but let's just make ALL_PROMPTS.md first
  const outPath = path.join(OUTPUT_DIR, "00_ALL_ITEM_PROMPTS.md");
  fs.writeFileSync(outPath, outputMd, "utf8");
  console.log(`Generated ${allItems.length} prompts to ${outPath}`);
}

main();

