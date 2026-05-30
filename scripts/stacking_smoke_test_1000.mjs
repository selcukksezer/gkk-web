#!/usr/bin/env node
/**
 * STACKING SMOKE TEST — 1000 Run
 * ================================
 * Kullanıcı  : testet@gmail.com / 123selcuk
 * Zindan     : dng_001 (Luporum Cubile — power_req=0)
 * RPC        : attack_dungeon (Flutter-compat wrapper)
 * Odak       : stacking doğruluğu, envanter slot kullanımı,
 *              drop oranları, hospital/enerji yönetimi
 *
 * Çalıştır:
 *   node scripts/stacking_smoke_test_1000.mjs
 *
 * Çıktı:
 *   scripts/output/stacking_smoke_1000_<timestamp>.json
 */

import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// ─── ENV ──────────────────────────────────────────────────────────────────────

const ROOT = process.cwd();
dotenv.config({ path: path.join(ROOT, '.env.local'), override: false });
dotenv.config({ path: path.join(ROOT, '.env'), override: false });

const SUPABASE_URL = env('NEXT_PUBLIC_SUPABASE_URL');
const SUPABASE_KEY = env('NEXT_PUBLIC_SUPABASE_ANON_KEY');

function env(name) {
  const v = process.env[name];
  if (!v?.trim()) throw new Error(`Eksik env: ${name}`);
  return v.trim();
}

// ─── SABITLER ─────────────────────────────────────────────────────────────────

const EMAIL    = 'testet@gmail.com';
const PASSWORD = '123selcuk';
const DUNGEON  = 'dng_001';
const TOTAL    = 1000;
const BATCH    = 10;          // her kaç runda bir durum raporu yazılır
const DELAY_MS = 150;         // run arası bekleme (rate-limit önlemi)
const MAX_CONSECUTIVE_HOSPITAL = 5; // bu kadar hastane sonrası gem ile iyileştir

// ─── YARDIMCı ─────────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function now() { return new Date().toISOString(); }

function bar(label, value, max, width = 30) {
  const pct = max > 0 ? value / max : 0;
  const filled = Math.round(pct * width);
  const empty  = width - filled;
  const bar    = '█'.repeat(filled) + '░'.repeat(empty);
  return `${label.padEnd(18)} [${bar}] ${(pct * 100).toFixed(1)}% (${value}/${max})`;
}

function pct(n, d) {
  return d > 0 ? ((n / d) * 100).toFixed(1) + '%' : 'N/A';
}

function sep(char = '─', len = 72) { return char.repeat(len); }

// ─── SUPABASE İSTEMCİ ─────────────────────────────────────────────────────────

function makeClient() {
  return createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

// ─── GİRİŞ ────────────────────────────────────────────────────────────────────

async function login(client) {
  const { data, error } = await client.auth.signInWithPassword({ email: EMAIL, password: PASSWORD });
  if (error || !data?.session) throw new Error(`Giriş hatası: ${error?.message ?? 'session yok'}`);
  console.log(`✓ Giriş başarılı → auth_id=${data.user.id}`);
  return data.user.id;
}

// ─── KULLANICI PROFİLİ ────────────────────────────────────────────────────────

async function getProfile(client, authId) {
  const { data } = await client.from('users').select('*').eq('auth_id', authId).maybeSingle();
  return data;
}

// ─── ENERJİ DOLUMU ────────────────────────────────────────────────────────────
// Enerjisi 5'ten düşerse gem ile doldurur (veya admins aracılığıyla direkt günceller)

async function ensureEnergy(client, authId) {
  // Direkt update – test hesabı, gerçek oyun değil
  await client.from('users').update({ energy: 10000 }).eq('auth_id', authId);
}

// ─── HASTANE İYİLEŞTİRME ─────────────────────────────────────────────────────

async function healIfNeeded(client) {
  const { data } = await client.rpc('heal_with_gems');
  return data?.success === true;
}

// ─── ENVANTER SNAPSHOT ────────────────────────────────────────────────────────

async function getInventory(client) {
  const { data, error } = await client.from('inventory')
    .select('row_id, item_id, quantity, slot_position, is_equipped, obtained_at')
    .eq('is_equipped', false)
    .order('slot_position', { ascending: true });
  if (error) return [];
  return data ?? [];
}

// ─── İTEM KATALOĞU ────────────────────────────────────────────────────────────

async function loadItems(client) {
  const { data } = await client
    .from('items')
    .select('id, name, rarity, type, is_stackable, max_stack');
  const map = {};
  for (const item of data ?? []) map[item.id] = item;
  return map;
}

// ─── STACKING ANALİZİ ─────────────────────────────────────────────────────────

function analyzeInventory(rows, itemMap) {
  const byItem = {};
  for (const row of rows) {
    if (!byItem[row.item_id]) byItem[row.item_id] = [];
    byItem[row.item_id].push(row);
  }

  const stackingViolations = []; // aynı item_id'li birden fazla slot (stackable olmalı)
  const stackStats = {
    stackableItems: 0,
    nonStackableItems: 0,
    properlyStacked: 0,
    improperlyMultiSlot: 0,
    totalQuantity: 0,
    totalSlots: rows.length,
    usedSlots: new Set(rows.map((r) => r.slot_position)).size,
  };

  for (const [itemId, slots] of Object.entries(byItem)) {
    const meta   = itemMap[itemId] ?? {};
    const isStack = meta.is_stackable ?? false;
    const total   = slots.reduce((s, r) => s + (r.quantity ?? 1), 0);
    stackStats.totalQuantity += total;

    if (isStack) {
      stackStats.stackableItems++;
      if (slots.length > 1) {
        stackStats.improperlyMultiSlot++;
        stackingViolations.push({
          item_id: itemId,
          name: meta.name ?? itemId,
          rarity: meta.rarity ?? '?',
          slotCount: slots.length,
          totalQty: total,
          maxStack: meta.max_stack ?? 999,
          slots: slots.map((s) => ({ slot: s.slot_position, qty: s.quantity })),
        });
      } else {
        stackStats.properlyStacked++;
      }
    } else {
      stackStats.nonStackableItems++;
    }
  }

  return { stackStats, stackingViolations };
}

// ─── SONUÇ TOPLAYICI ──────────────────────────────────────────────────────────

class ResultCollector {
  constructor() {
    this.runs         = [];        // {run, success, gold, xp, items, hospitalized, inventory_full, is_critical, durationMs}
    this.errors       = [];        // {run, error}
    this.hospitalRuns = 0;
    this.healCount    = 0;
    this.energyRefills = 0;
    this.itemDrops    = {};        // item_id → toplam adet
    this.inventorySnapshots = [];  // belirli runlarda envanter anlık görüntüsü
    this.stackViolationsPerRun = []; // {run, violations[]}
  }

  addRun(run, data) {
    this.runs.push({ run, ...data });
    if (data.hospitalized) this.hospitalRuns++;
    for (const itemId of data.items ?? []) {
      this.itemDrops[itemId] = (this.itemDrops[itemId] ?? 0) + 1;
    }
  }

  addError(run, error) {
    this.errors.push({ run, error });
  }

  summary() {
    const total    = this.runs.length;
    const successes = this.runs.filter((r) => r.success).length;
    const wins      = this.runs.filter((r) => r.won).length;
    const crits     = this.runs.filter((r) => r.is_critical).length;
    const invFull   = this.runs.filter((r) => r.inventory_full).length;
    const goldTotal = this.runs.reduce((s, r) => s + (r.gold ?? 0), 0);
    const xpTotal   = this.runs.reduce((s, r) => s + (r.xp ?? 0), 0);
    const itemTotal = this.runs.reduce((s, r) => s + (r.items?.length ?? 0), 0);
    const avgMs     = total > 0
      ? (this.runs.reduce((s, r) => s + (r.durationMs ?? 0), 0) / total).toFixed(0)
      : 0;

    return {
      total,
      errors: this.errors.length,
      successes,
      wins,
      crits,
      hospitalizations: this.hospitalRuns,
      inventoryFull: invFull,
      successRate: pct(successes, total),
      winRate:     pct(wins, total),
      critRate:    pct(crits, successes > 0 ? successes : 1),
      hospitalRate: pct(this.hospitalRuns, total),
      invFullRate: pct(invFull, total),
      goldTotal,
      xpTotal,
      itemTotal,
      avgDropPerRun: total > 0 ? (itemTotal / total).toFixed(2) : '0',
      avgGoldPerRun: total > 0 ? (goldTotal / total).toFixed(0) : '0',
      avgXpPerRun:   total > 0 ? (xpTotal / total).toFixed(0) : '0',
      avgRpcMs:      avgMs,
      healCount:  this.healCount,
      energyRefills: this.energyRefills,
      topItems: Object.entries(this.itemDrops)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 20)
        .map(([id, cnt]) => ({ item_id: id, count: cnt })),
      totalStackViolationsDetected: this.stackViolationsPerRun
        .reduce((s, v) => s + v.violations.length, 0),
    };
  }
}

// ─── DURUM RAPORU ─────────────────────────────────────────────────────────────

function printBatch(collector, batchNum, run) {
  const s = collector.summary();
  console.log(`\n${sep()}`);
  console.log(`BATCH ${batchNum} — Run ${run}/${TOTAL}  (${now()})`);
  console.log(sep());
  console.log(bar('Başarı (RPC)', s.successes, s.total));
  console.log(bar('Zafer',        s.wins,      s.total));
  console.log(bar('Hastane',      s.hospitalizations, s.total));
  console.log(bar('Envanter Dolu',s.inventoryFull,   s.total));
  console.log(`  Kritik İsabet : ${s.crits}  (${s.critRate})`);
  console.log(`  Toplam Altın  : ${s.goldTotal.toLocaleString()}`);
  console.log(`  Toplam XP     : ${s.xpTotal.toLocaleString()}`);
  console.log(`  Toplam Item   : ${s.itemTotal}`);
  console.log(`  Ortalama ms   : ${s.avgRpcMs}ms`);
  console.log(`  Stacking İhlal: ${s.totalStackViolationsDetected}`);
  if (collector.errors.length > 0) {
    console.log(`  ⚠ Hatalar     : ${collector.errors.length}`);
  }
}

// ─── ANA FONKSİYON ────────────────────────────────────────────────────────────

async function main() {
  console.log(sep('═'));
  console.log('STACKING SMOKE TEST — 1000 Run');
  console.log(`Kullanıcı : ${EMAIL}`);
  console.log(`Zindan    : ${DUNGEON} (Luporum Cubile)`);
  console.log(`Başlangıç : ${now()}`);
  console.log(sep('═'));

  const client  = makeClient();
  const authId  = await login(client);
  const itemMap = await loadItems(client);

  // Enerjiyi doldur
  await ensureEnergy(client, authId);
  console.log('✓ Enerji 10000 olarak ayarlandı');

  const profile = await getProfile(client, authId);
  console.log(`  Level=${profile?.level} Power=${profile?.power} Gold=${profile?.gold} Energy=${profile?.energy}`);

  const collector    = new ResultCollector();
  let consecutiveHospital = 0;

  for (let run = 1; run <= TOTAL; run++) {
    // ── Enerji kontrolü: her 50 runda bir topla ──────────────────────────
    if (run % 50 === 0) {
      await ensureEnergy(client, authId);
      collector.energyRefills++;
    }

    // ── Hastaneden çık ───────────────────────────────────────────────────
    if (consecutiveHospital >= MAX_CONSECUTIVE_HOSPITAL) {
      const healed = await healIfNeeded(client);
      if (healed) {
        collector.healCount++;
        consecutiveHospital = 0;
        console.log(`  [run ${run}] Gem ile iyileştirildi.`);
      } else {
        // gem yoksa doğrudan hospital_until sıfırla (test ortamı)
        await client.from('users').update({ hospital_until: null }).eq('auth_id', authId);
        consecutiveHospital = 0;
        console.log(`  [run ${run}] hospital_until sıfırlandı (test).`);
      }
    }

    // ── Zindan koşusu ─────────────────────────────────────────────────────
    const t0 = Date.now();
    let raw, rpcError;
    try {
      const resp = await client.rpc('attack_dungeon', { p_dungeon_id: DUNGEON });
      raw      = resp.data;
      rpcError = resp.error;
    } catch (err) {
      rpcError = err;
    }
    const durationMs = Date.now() - t0;

    // ── Hata işleme ───────────────────────────────────────────────────────
    if (rpcError || !raw || typeof raw !== 'object') {
      const msg = rpcError?.message ?? rpcError ?? 'Bilinmeyen hata';
      collector.addError(run, msg);

      // Hastane hatası?
      if (typeof msg === 'string' && msg.includes('in_hospital')) {
        consecutiveHospital++;
        await sleep(DELAY_MS);
        continue;
      }
      if (typeof msg === 'string' && msg.includes('insufficient_energy')) {
        await ensureEnergy(client, authId);
        collector.energyRefills++;
        run--; // bu runu tekrar say
        await sleep(DELAY_MS);
        continue;
      }

      console.log(`  [run ${run}] HATA: ${msg}`);
      await sleep(DELAY_MS);
      continue;
    }

    if (raw.error) {
      const errStr = String(raw.error);
      collector.addError(run, errStr);

      if (errStr === 'in_hospital') {
        consecutiveHospital++;
        await sleep(DELAY_MS);
        continue;
      }
      if (errStr === 'insufficient_energy') {
        await ensureEnergy(client, authId);
        collector.energyRefills++;
        run--;
        await sleep(DELAY_MS);
        continue;
      }

      console.log(`  [run ${run}] DB HATASI: ${errStr}`);
      await sleep(DELAY_MS);
      continue;
    }

    // ── Run başarılı ──────────────────────────────────────────────────────
    const won         = raw.success === true;
    const hospitalized = raw.hospitalized === true;
    if (hospitalized) {
      consecutiveHospital++;
    } else {
      consecutiveHospital = 0;
    }

    const items        = Array.isArray(raw.items) ? raw.items : [];
    const gold         = Number(raw.gold   ?? 0);
    const xp           = Number(raw.xp     ?? 0);
    const isCritical   = raw.is_critical   === true;
    const inventoryFull = raw.inventory_full === true;

    collector.addRun(run, {
      success: true,
      won,
      gold,
      xp,
      items,
      hospitalized,
      inventory_full: inventoryFull,
      is_critical: isCritical,
      durationMs,
    });

    // ── Stacking kontrolü: her 100 runda bir envanter çek ────────────────
    if (run % 100 === 0) {
      const invRows  = await getInventory(client);
      const analysis = analyzeInventory(invRows, itemMap);
      collector.inventorySnapshots.push({
        run,
        slotCount: analysis.stackStats.usedSlots,
        totalSlots: 20,
        uniqueItems: Object.keys(
          invRows.reduce((m, r) => { m[r.item_id] = true; return m; }, {})
        ).length,
        stackableSlots: analysis.stackStats.stackableItems,
        stackViolations: analysis.stackingViolations.length,
        stats: analysis.stackStats,
      });
      collector.stackViolationsPerRun.push({
        run,
        violations: analysis.stackingViolations,
      });

      if (analysis.stackingViolations.length > 0) {
        console.log(`  [run ${run}] ⚠ Stacking ihlali: ${analysis.stackingViolations.length} item`);
        for (const v of analysis.stackingViolations.slice(0, 3)) {
          console.log(`    • ${v.name} (${v.rarity}): ${v.slotCount} slot × qty${v.slots.map((s) => s.qty).join('+')} = ${v.totalQty}`);
        }
      } else {
        console.log(`  [run ${run}] ✓ Stacking OK — envanter ${analysis.stackStats.usedSlots}/20 slot dolu`);
      }
    }

    // ── Batch raporu ──────────────────────────────────────────────────────
    if (run % BATCH === 0) {
      const batchNum = run / BATCH;
      // Sadece büyük sıçramalarda ekrana yaz (her 100 run)
      if (run % 100 === 0) {
        printBatch(collector, batchNum, run);
      } else {
        // Kısa satır
        process.stdout.write(
          `\r  run=${run}/${TOTAL}  wins=${collector.runs.filter((r) => r.won).length}  hospital=${collector.hospitalRuns}  items=${Object.values(collector.itemDrops).reduce((s, c) => s + c, 0)}  ms=${durationMs}   `
        );
      }
    }

    await sleep(DELAY_MS);
  }

  // ─── ÖZET ─────────────────────────────────────────────────────────────────

  console.log(`\n\n${sep('═')}`);
  console.log('SMOKE TEST TAMAMLANDI');
  console.log(sep('═'));

  const s = collector.summary();

  console.log(`\nGenel İstatistikler`);
  console.log(sep());
  console.log(bar('RPC Başarısı',  s.successes,         TOTAL));
  console.log(bar('Zafer',          s.wins,              TOTAL));
  console.log(bar('Hastane',        s.hospitalizations,  TOTAL));
  console.log(bar('Envanter Dolu',  s.inventoryFull,     TOTAL));
  console.log(bar('Kritik İsabet',  s.crits,             TOTAL));
  console.log(`\nHatalar         : ${s.errors}`);
  console.log(`Enerji Dolumu   : ${s.energyRefills}x`);
  console.log(`Gem Heal        : ${s.healCount}x`);

  console.log(`\nEkonomik Özet`);
  console.log(sep());
  console.log(`  Toplam Altın  : ${s.goldTotal.toLocaleString()}`);
  console.log(`  Ort. Altın/run: ${s.avgGoldPerRun}`);
  console.log(`  Toplam XP     : ${s.xpTotal.toLocaleString()}`);
  console.log(`  Ort. XP/run   : ${s.avgXpPerRun}`);

  console.log(`\nLoot Özeti`);
  console.log(sep());
  console.log(`  Toplam Item   : ${s.itemTotal}  (ort. ${s.avgDropPerRun}/run)`);
  console.log(`  Top 10 Drop:`);
  for (const t of s.topItems.slice(0, 10)) {
    const meta = itemMap[t.item_id] ?? {};
    console.log(`    ${t.item_id.padEnd(30)} ×${t.count.toString().padStart(4)}  ${meta.rarity ?? ''}  ${meta.name ?? ''}`);
  }

  console.log(`\nStacking Analizi`);
  console.log(sep());
  const lastSnap = collector.inventorySnapshots.at(-1);
  if (lastSnap) {
    console.log(`  Son envanter  : ${lastSnap.slotCount}/20 slot`);
    console.log(`  Stacking ihlal: ${s.totalStackViolationsDetected}`);
    if (s.totalStackViolationsDetected === 0) {
      console.log('  ✅ Tüm stacking kontrolleri BAŞARILI — item\'lar doğru şekilde stackleniyor');
    } else {
      console.log('  ❌ Stacking ihlalleri tespit edildi — dungeon_add_item mantığını kontrol et');
    }
  }

  const envSnapshot = collector.inventorySnapshots;
  if (envSnapshot.length > 1) {
    console.log(`\n  Envanter büyüme tablosu:`);
    console.log(`  ${'Run'.padStart(5)}  ${'Slot'.padStart(4)}  ${'İhlal'.padStart(5)}`);
    for (const snap of envSnapshot) {
      console.log(`  ${String(snap.run).padStart(5)}  ${String(snap.slotCount).padStart(4)}  ${String(snap.stackViolations).padStart(5)}`);
    }
  }

  // ─── JSON ÇIKTI ───────────────────────────────────────────────────────────

  const outDir = path.join(ROOT, 'scripts', 'output');
  fs.mkdirSync(outDir, { recursive: true });

  const ts      = new Date().toISOString().replace(/[:.]/g, '-');
  const outFile = path.join(outDir, `stacking_smoke_1000_${ts}.json`);

  const report = {
    meta: {
      email:    EMAIL,
      dungeon:  DUNGEON,
      totalRuns: TOTAL,
      startedAt: now(),
    },
    summary: s,
    inventorySnapshots: collector.inventorySnapshots,
    stackViolationsByRun: collector.stackViolationsPerRun.filter((v) => v.violations.length > 0),
    errors: collector.errors,
    allRuns: collector.runs,
  };

  fs.writeFileSync(outFile, JSON.stringify(report, null, 2), 'utf8');
  console.log(`\n📄 Rapor kaydedildi: ${outFile}`);
  console.log(sep('═'));
}

main().catch((err) => {
  console.error('FATAL:', err);
  process.exit(1);
});
