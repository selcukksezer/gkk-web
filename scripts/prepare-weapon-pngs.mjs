import fs from "fs";
import path from "path";
import sharp from "sharp";

const ROOT = process.cwd();
const WEAPONS_DIR = path.join(ROOT, "gkk_flutter", "assets", "items", "weapons");
const SEED_PATH = path.join(ROOT, "supabase", "seeds", "plan1_items.generated.sql");

function slugifyName(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function parseWeaponRows(sql) {
  const rows = [];
  const rowRegex = /\('([^']+)'\s*,\s*'([^']*)'\s*,\s*'([^']*)'\s*,\s*'([^']*)'\s*,\s*'([^']*)'/g;
  let match;
  while ((match = rowRegex.exec(sql)) !== null) {
    const id = match[1];
    const name = match[2];
    const icon = match[4];
    const type = match[5];
    if (type === "weapon") {
      rows.push({ id, name, icon });
    }
  }
  return rows;
}

function estimateBackgroundColor(raw, width, height) {
  const samples = [];
  const sampleRadius = 14;

  function pushSample(x, y) {
    const idx = (y * width + x) * 4;
    samples.push([raw[idx], raw[idx + 1], raw[idx + 2]]);
  }

  for (let y = 0; y < sampleRadius; y += 1) {
    for (let x = 0; x < sampleRadius; x += 1) {
      pushSample(x, y);
      pushSample(width - 1 - x, y);
      pushSample(x, height - 1 - y);
      pushSample(width - 1 - x, height - 1 - y);
    }
  }

  const r = Math.round(samples.reduce((s, c) => s + c[0], 0) / samples.length);
  const g = Math.round(samples.reduce((s, c) => s + c[1], 0) / samples.length);
  const b = Math.round(samples.reduce((s, c) => s + c[2], 0) / samples.length);
  return { r, g, b };
}

function colorDistanceSq(r1, g1, b1, r2, g2, b2) {
  const dr = r1 - r2;
  const dg = g1 - g2;
  const db = b1 - b2;
  return dr * dr + dg * dg + db * db;
}

function createBackgroundMask(raw, width, height, bg) {
  const total = width * height;
  const visited = new Uint8Array(total);
  const queue = new Int32Array(total);
  let head = 0;
  let tail = 0;

  const thresholdSq = 34 * 34;

  function maybeEnqueue(x, y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const idx = y * width + x;
    if (visited[idx] === 1) return;
    const p = idx * 4;
    const distSq = colorDistanceSq(raw[p], raw[p + 1], raw[p + 2], bg.r, bg.g, bg.b);
    if (distSq <= thresholdSq) {
      visited[idx] = 1;
      queue[tail++] = idx;
    }
  }

  for (let x = 0; x < width; x += 1) {
    maybeEnqueue(x, 0);
    maybeEnqueue(x, height - 1);
  }
  for (let y = 1; y < height - 1; y += 1) {
    maybeEnqueue(0, y);
    maybeEnqueue(width - 1, y);
  }

  while (head < tail) {
    const idx = queue[head++];
    const x = idx % width;
    const y = (idx - x) / width;
    maybeEnqueue(x + 1, y);
    maybeEnqueue(x - 1, y);
    maybeEnqueue(x, y + 1);
    maybeEnqueue(x, y - 1);
  }

  return visited;
}

async function removeBackgroundAndSave(sourcePath, outPath) {
  const { data, info } = await sharp(sourcePath)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const bg = estimateBackgroundColor(data, info.width, info.height);
  const mask = createBackgroundMask(data, info.width, info.height, bg);

  for (let i = 0; i < mask.length; i += 1) {
    if (mask[i] === 1) {
      data[i * 4 + 3] = 0;
    }
  }

  await sharp(data, {
    raw: {
      width: info.width,
      height: info.height,
      channels: 4,
    },
  })
    .png({ quality: 100, compressionLevel: 8 })
    .toFile(outPath);
}

async function main() {
  if (!fs.existsSync(SEED_PATH)) {
    throw new Error(`Seed file not found: ${SEED_PATH}`);
  }
  if (!fs.existsSync(WEAPONS_DIR)) {
    throw new Error(`Weapons directory not found: ${WEAPONS_DIR}`);
  }

  const sql = fs.readFileSync(SEED_PATH, "utf8");
  const weaponRows = parseWeaponRows(sql);
  if (weaponRows.length === 0) {
    throw new Error("No weapon rows found in seed SQL.");
  }

  const mapping = [];
  for (const row of weaponRows) {
    const sourceBase = `${slugifyName(row.name)}.jpeg`;
    const sourcePath = path.join(WEAPONS_DIR, sourceBase);
    if (!fs.existsSync(sourcePath)) {
      console.warn(`[SKIP] Missing source image for ${row.id} (${row.name}): ${sourceBase}`);
      continue;
    }

    const targetFile = `${row.icon || row.id}.png`;
    const targetPath = path.join(WEAPONS_DIR, targetFile);

    await removeBackgroundAndSave(sourcePath, targetPath);
    mapping.push({ itemId: row.id, source: sourceBase, output: targetFile });
    console.log(`[OK] ${sourceBase} -> ${targetFile}`);
  }

  const mapPath = path.join(WEAPONS_DIR, "_weapon_image_map.json");
  fs.writeFileSync(mapPath, `${JSON.stringify(mapping, null, 2)}\n`, "utf8");
  console.log(`\nDone. Processed ${mapping.length}/${weaponRows.length} weapon images.`);
  console.log(`Mapping file: ${path.relative(ROOT, mapPath)}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
