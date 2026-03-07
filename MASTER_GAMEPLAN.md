# MASTER GAMEPLAN — GKK Web Oyunu

> **Amaç:** Bu dosya, yapay zekanın bütün PLAN_01–11 belgelerine bakmadan oyunu eksiksiz uygulayabilmesi için **tek referans kaynak** olarak tasarlanmıştır.  
> **Güncelleme:** 2026-03-07  
> **Kapsam:** Tutarsızlık düzeltmeleri, kanonik değerler, uygulama sırası, bağımlılık zinciri

---

## ⚠️ OKUMA TALİMATI (Yapay Zeka İçin)

1. Bir özellik uygulamadan **önce** bu belgede o özelliğin **"Bağımlılıklar"** satırını oku.  
2. Her özellik için referans verilen **PLAN_XX** dosyasını aç ve **tam implementasyonu** oradan al.  
3. Bu belgede tanımlı **"Kanonik Değerler"** ile PLAN dosyaları çelişirse — **bu belge geçerlidir**.  
4. Her adımı tamamladıktan sonra bu belgedeki **implementasyon listesini** güncelle.

---

## 1. Düzeltilmiş Tutarsızlıklar (Canonical Rules)

Aşağıdaki değerler PLAN dosyalarında tutarsız bulunmuştur; bunlar için tek geçerli kaynak bu bölümdür.

### 1.1 Veritabanı Tablo Adları

| ❌ Yanlış (bazı PLAN'larda) | ✅ Doğru |
|-----------------------------|----------|
| `players` | `public.users` |
| `inventory` (player_id ile) | `public.inventory` (player_id UUID) |
| `dungeon_runs` (player_id ile) | `public.dungeon_runs` (player_id UUID) |
| `public.items(item_id)` FK | `public.items(id)` |

**Kural:** Tüm RPC'lerde `public.users` kullan; auth bağlantısı `auth_id` sütunuyla yapılır.

### 1.2 Power (Güç) Formülü — Kanonik

```
total_power = equipment_power + (level × 500) + (reputation × 0.1) + (luck × 50)

equipment_power = Σ [tüm equipped items] of:
    (item.attack + item.defense + item.health / 10 + item.luck × 2)
    × (1 + item.enhancement_level × 0.15)

luck = player.luck   (baz stat; PLAN_11 sınıf + level büyümesi)
```

> **Kaynak:** PLAN_04 §4 (TypeScript), PLAN_06 §5.1 (formül), PLAN_11 §10 (luck katkısı)  
> **Denge notu:** `luck × 50` kasıtlı küçüktür; luck'ın asıl etkisi % bazlı bonus formüllerindedir.

### 1.3 Zindan Başarı Formülü — Kanonik

```
power_ratio = player_total_power / dungeon.power_requirement

success_rate =
  power_req == 0        → 1.00
  ratio >= 1.5          → 0.95  (cap)
  ratio >= 1.0          → 0.70 + (ratio - 1.0) × 0.50
  ratio >= 0.5          → 0.25 + (ratio - 0.5) × 0.90
  ratio >= 0.25         → 0.10 + (ratio - 0.25) × 0.60
  else                  → max(0.05, ratio × 0.40)

-- Bonus modifiyerler (sırayla ekle)
success_rate += player.luck × 0.001              -- max +5%
success_rate += reputation × 0.0005             -- max +2.5%
success_rate += guild_level × 0.01              -- max +5%
success_rate += warrior_class_bonus (0.05)      -- sadece Savaşçı sınıfı
success_rate += season_modifier                 -- 0-10%

final_rate = clamp(success_rate, 0.05, 0.95)
```

> **Kaynak:** PLAN_04 §3, PLAN_11 §9.1

### 1.4 Karakter Stat Etkileri — Zindan VE PvP

Karakter sınıfı statları artık **hem zindanda hem PvP'de** geçerlidir:

| Stat | Zindan Etkisi | PvP Etkisi |
|------|--------------|------------|
| `attack` | Boss gold ödülü modifiyeri (+Savaşçı: ×1.15) | `attacker_damage = attack × (0.8 + rand×0.4) × crit` |
| `defense` | Hastane süresi azaltma: `× (1 - defense×0.001)`, max %30 | `net_dmg -= defense × 0.3` |
| `health` | Hayatta kalma kapasitesi (kozmetik/animasyon) | HP pool |
| `luck` | Zindan başarı +`luck×0.001`, loot `× (1+luck×0.002)` | Kritik: `rand < luck×0.002`, dodge: `rand < luck×0.001` |

> **Kaynak:** PLAN_04 §4.1, PLAN_09 §3.2, PLAN_11 §3.3

### 1.5 Hastane Süresi — Kanonik

```sql
-- Zindan başarısızlığından hastane:
hospital_chance = clamp(1.0 - success_rate, 0.05, 0.90) × (1 - luck × 0.003)
hospital_minutes = dungeon.hospital_min + rand × (max - min)
hospital_minutes = floor(hospital_minutes × (1 - defense × 0.001))  -- defense mitigation
IF character_class = 'warrior': hospital_minutes = floor(hospital_minutes × 0.80)

-- Overdose'dan hastane (PLAN_08):
hospital_minutes = 30 + tolerance × 2

-- Her ikisinde de: `UPDATE public.users SET hospital_until = ...`
```

### 1.6 Crafting Başarı Formülü — Kanonik

```
final_success_rate = base_rate
                   + (luck × 0.001)          -- 100 luck = +10%
                   + (facility_lv × 0.005)   -- her tesis lv +0.5%
                   + guild_bonus             -- Anıt Lv 35: +3%
IF character_class = 'alchemist': final_success_rate += 0.15
```

> **Kaynak:** PLAN_03 §6.2, PLAN_11 §9.2

### 1.7 Detox Item ID'leri — Kanonik

| Detox Türü | Item ID | Tolerance Azalma | Addiction Azalma | Cooldown |
|-----------|---------|-----------------|-----------------|---------|
| Minor | `detox_minor` | -15 | 0 | 4 saat |
| Major | `detox_major` | -35 | -1 | 8 saat |
| Supreme | `detox_supreme` | -60 | -2 | 12 saat |
| Full Cleanse | `detox_full_cleanse` | -100 (sıfırla) | -10 (sıfırla) | 24 saat |

> **Kaynak:** PLAN_08 §5.1, §8.2

### 1.8 Han-Only Item ID'leri — Kanonik

| Item ID | Etki | Craft Gold |
|---------|------|-----------|
| `han_item_vigor_minor` | +50 enerji, tolerance +3 | 50,000 |
| `han_item_vigor_major` | +100 enerji, tolerance +8 | 200,000 |
| `han_item_elixir_purge` | tolerance -20, addiction -1 | 100,000 |
| `han_item_clarity` | tolerance -40, addiction -2 | 500,000 |
| `han_item_berserk` | ATK ×1.5 / 5dk, tolerance +20 | 1,000,000 |
| `han_item_shadow_brew` | dodge +15% / 10dk, tolerance +10 | 800,000 |
| `han_item_restoration` | HP +15,000, tolerance +5, addiction -1 | 800,000 |

> **Kaynak:** PLAN_07 §5.2, PLAN_03 §5.5

### 1.9 Lonca Anıtı — Kanonik Sınırlar

| Lonca Büyüklüğü | Beklenen Lv 100 | Maliyet Çarpanı |
|----------------|----------------|----------------|
| 1-10 üye | Lv 50-60 | ×0.35 |
| 11-20 üye | Lv 70-80 | ×0.55 |
| 21-30 üye | Lv 85-95 | ×0.75 |
| 31-40 üye | Lv 95-100 | ×0.90 |
| 41-50 üye | Lv 100 (ulaşılabilir ama zor) | ×1.00 |

> **Kaynak:** PLAN_10 §3.0

---

## 2. Sistem Bağımlılık Haritası

Bir sistemi uygulamadan önce bağımlı olduğu sistemlerin **uygulama fazı** tamamlanmış olmalıdır.

```
PLAN_01 (Items/Ekipman)
  └── PLAN_03 (Crafting)
        └── PLAN_02 (Tesisler)  ←── Kaynaklar burada üretilir
        └── PLAN_05 (Enhancement)  ←── Itemlar bu sistemle geliştirilir
        └── PLAN_07 (Han — han_item craft reçeteleri)

PLAN_01 + PLAN_11 (Karakter Sınıfı)
  └── PLAN_04 (Zindan)  ←── Hem item hem sınıf statları kullanılır
  └── PLAN_09 (PvP)  ←── Hem item hem sınıf statları kullanılır
  └── PLAN_08 (Tolerans)  ←── İksirler PLAN_01'den; simyacı bonusu PLAN_11'den

PLAN_07 (Han/Mekan)
  └── PLAN_09 (PvP arena — sadece Han'da)
  └── PLAN_08 (Tolerans — detox sadece Han'da)

PLAN_04 (Zindan) + PLAN_06 (Ekonomi)
  └── PLAN_10 (Lonca Anıtı)  ←── Blueprint boss drop'lardan gelir

PLAN_09 (PvP/Reputation)
  └── PLAN_06 (Ekonomi)  ←── Reputation power'a katkı yapar
```

---

## 3. Uygulama Sırası (Faz Bazlı)

Her fazı tamamlamadan bir sonrakine geçme. İçindeki adımlar kısmen paralel yapılabilir.

---

### 🔵 FAZ 0: Temel Altyapı (ÖNCE BU)

> Bu olmadan hiçbir şey çalışmaz.

**Adım 0.1** — DB Migration: Temel tablolar

```sql
-- Mevcut tablolar (public schema):
-- users: id, auth_id, username, level, xp, gold, energy, attack, defense, health, max_health, 
--         power, reputation, pvp_wins, pvp_losses, pvp_rating, tolerance, addiction_level,
--         hospital_until, hospital_reason, prison_until, created_at

-- YENİ EKLENECEK (PLAN_11):
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS character_class text
    CHECK (character_class IN ('warrior', 'alchemist', 'shadow')),
  ADD COLUMN IF NOT EXISTS class_selected_at timestamptz;

ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_han_only boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_market_tradeable boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_direct_tradeable boolean DEFAULT true;
```

**Adım 0.2** — DB Migration: `character_classes` tablosu + seed

> Tam SQL: PLAN_11 §5.2

**Adım 0.3** — `select_character_class` RPC

> Tam SQL: PLAN_11 §5.3

**Adım 0.4** — `get_current_user` RPC güncelleme (luck, character_class, class_passive_bonuses ekle)

> Tam SQL: PLAN_11 §8

**Adım 0.5** — `apply_level_up_stats` RPC (her level atlamada sınıf büyümesi)

> Tam SQL: PLAN_11 §5.5

**Tamamlandığında:** Oyuncu kayıt olabilir, sınıf seçebilir, level atlayabilir.

---

### 🟢 FAZ 1: Item & Ekipman (PLAN_01)

> Bağımlılık: FAZ 0 tamamlandı.

**Adım 1.1** — `items` tablosunu 192+ item ile seed et

> Stat ölçeği: Common ~500-2,000; Uncommon ~3,000-10,000; Rare ~15,000-50,000; Epic ~60,000-150,000; Legendary ~200,000-500,000; Mythic ~600,000-1,500,000 (attack/defense/health)

**Adım 1.2** — `inventory` tablosu ve temel RPC'ler

```sql
-- Tablo zaten var mı kontrol et; yoksa:
CREATE TABLE IF NOT EXISTS public.inventory (
  row_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.users(id),
  item_id text NOT NULL REFERENCES public.items(id),
  quantity integer NOT NULL DEFAULT 1,
  enhancement_level integer DEFAULT 0 CHECK (enhancement_level >= 0 AND enhancement_level <= 10),
  is_equipped boolean DEFAULT false,
  equip_slot text,
  created_at timestamptz DEFAULT now()
);
```

**Adım 1.3** — `equip_item` ve `unequip_item` RPC'leri

**Adım 1.4** — Market tablosu + `market_list_item` RPC (is_market_tradeable kontrolü ekle)

**Tamamlandığında:** Oyuncu item kazanabilir, kuşanabilir, pazar'da satabilir.

---

### 🟢 FAZ 2: Tesisler & Kaynaklar (PLAN_02)

> Bağımlılık: FAZ 0 tamamlandı.

**Adım 2.1** — `resources` tablosu (90 kaynak) seed

> Tam liste: PLAN_02 §3

**Adım 2.2** — `player_resources` tablosu

```sql
CREATE TABLE IF NOT EXISTS public.player_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES public.users(id),
  resource_id text NOT NULL REFERENCES public.resources(id),
  quantity integer NOT NULL DEFAULT 0,
  UNIQUE(player_id, resource_id)
);
```

**Adım 2.3** — Tesis üretim sistemi + `collect_resources` RPC

> Üretim hızı: `base_rate × (1 + (facility_level - 1) × 0.15)`  
> Depolama: `storage_capacity = 50 × facility_level`

**Adım 2.4** — Gölge sınıfı şüphe modifiyeri (suspicion artışında `× 0.70` uygula)

**Tamamlandığında:** Oyuncu kaynak üretebilir, toplayabilir.

---

### 🟢 FAZ 3: Crafting (PLAN_03)

> Bağımlılık: FAZ 1 + FAZ 2 tamamlandı.

**Adım 3.1** — `craft_recipes` tablosu + 212 reçete seed

> Tam reçete listesi: PLAN_03 §3.1-§5.5  
> Özellikle: Han-only reçeteler `recipe_type = 'han_only'`

**Adım 3.2** — `craft_queue` tablosu + `start_crafting` RPC

> Tam SQL: PLAN_03 §8.3  
> **Önemli:** `start_crafting` içinde Simyacı bonusu ekle:  
> `IF character_class = 'alchemist': success_rate += 0.15; time *= 0.80`

**Adım 3.3** — `claim_crafting` RPC (tamamlanmış craft'ı toplama)

**Tamamlandığında:** Oyuncu kaynak + gold harcayarak item üretebilir.

---

### 🟢 FAZ 4: Zindan Sistemi (PLAN_04)

> Bağımlılık: FAZ 0 + FAZ 1 tamamlandı (items gerekli; tesisler FAZ 2'de).

**Adım 4.1** — `dungeons` tablosu + 65 zindan seed

> Tam liste: PLAN_04 §2 (65 zindan, 7 zone)

**Adım 4.2** — `dungeon_runs` + `player_dungeon_stats` tabloları

> Tam SQL: PLAN_04 §9.2-§9.3

**Adım 4.3** — `enter_dungeon` RPC

> Tam SQL: PLAN_04 §9.4  
> **KRİTİK:** Aşağıdakileri ekle:
> - `public.users` kullan (players değil)
> - `player.power` kullan (stored); yoksa `level×500 + reputation×0.1 + luck×50`
> - Savaşçı: `success_rate += 0.05`
> - Savaşçı boss: `v_gold *= 1.15`
> - Gölge: `v_luck_for_loot = luck × 1.40; v_gold *= (1 + v_luck_for_loot × 0.002)`
> - Defense mitigation: `hospital_minutes *= (1 - defense × 0.001)`, max %30
> - Savaşçı hastane: `hospital_minutes *= 0.80`

**Adım 4.4** — Loot drop sistemi (item verme)

> Loot rarity weight: PLAN_04 §6.3

**Tamamlandığında:** Oyuncu zindana girebilir, başarı/başarısızlık, loot, hastane sistemi çalışır.

---

### 🟢 FAZ 5: Enhancement (PLAN_05)

> Bağımlılık: FAZ 1 tamamlandı; FAZ 3 (scroll crafting) için FAZ 3 gerekli.

**Adım 5.1** — `enhance_item` RPC (server-authoritative)

> Tam SQL: PLAN_05 §9  
> **Önemli:** Rarity multiplier tablosu ekle (PLAN_05 §2.1)

**Adım 5.2** — Scroll gereksinimleri (PLAN_05 §2.2)

**Adım 5.3** — Rune crafting reçetelerini `craft_recipes`'e ekle (PLAN_05 §3.2)

**Tamamlandığında:** Oyuncu item'ı +0'dan +10'a çıkarabilir.

---

### 🟡 FAZ 6: Han/Mekan Sistemi (PLAN_07)

> Bağımlılık: FAZ 0 + FAZ 1 + FAZ 3 tamamlandı.

**Adım 6.1** — `game.mekans` + `game.mekan_stock` + `game.mekan_sales` tabloları

> Tam SQL: PLAN_07 §9

**Adım 6.2** — `open_mekan` RPC

> Tam SQL: PLAN_07 §10.1

**Adım 6.3** — `stock_mekan_item` + `buy_from_mekan` RPC'leri

> **Önemli:** `buy_from_mekan` içinde `is_han_only` kontrolü; han itemları direkt trade yasak.

**Adım 6.4** — Han-only item seed (`items` tablosuna PLAN_07 §5.2 + PLAN_08 §5.1 detox itemları)

**Adım 6.5** — `use_han_item` RPC (enerji verme + tolerance artışı + overdose kontrolü)

**Tamamlandığında:** Han açılabilir, enerji itemları satılabilir, detox alınabilir.

---

### 🟡 FAZ 7: Tolerans & Detox Sistemi (PLAN_08)

> Bağımlılık: FAZ 6 tamamlandı (detox sadece Han'da).

**Adım 7.1** — `use_potion` RPC'yi tolerance entegrasyonuyla güncelle

> Tam SQL: PLAN_08 §8.1  
> **Simyacı bonusları:**  
> `tolerance_gain *= 0.75` (-%25)  
> `overdose_chance *= 0.80` (-%20)  
> `efficiency *= 1.30` (+%30, max 1.0)

**Adım 7.2** — `use_detox` RPC

> Tam SQL: PLAN_08 §8.2  
> Detox sadece `game.mekan_stock`'ta bulunan Han-only detox itemlarından çalışır.

**Adım 7.3** — Tolerance bar UI bileşeni (HUD)

**Tamamlandığında:** İksir kullanımı tolerance/overdose sistemiyle çalışır.

---

### 🟡 FAZ 8: PvP & Reputation (PLAN_09)

> Bağımlılık: FAZ 6 (PvP sadece Han'da) + FAZ 0 (karakter sınıfı).

**Adım 8.1** — `game.pvp_matches` tablosu

> Tam SQL: PLAN_09 §7.2

**Adım 8.2** — `pvp_attack` RPC

> Tam SQL: PLAN_09 §8.1  
> **Sınıf modifiyerleri (PLAN_11 §9.3):**  
> Savaşçı saldırgan: `atk_dmg *= 1.20`, crit_chance `+= 0.10`  
> Gölge savunmacı: `dodge_chance = luck × 0.001 + 0.15`

**Adım 8.3** — Reputation güncelleme trigger/RPC (zindan, PvP, quest'ten)

**Tamamlandığında:** PvP Han'da çalışır; reputation kazanılır/kaybedilir.

---

### 🔴 FAZ 9: Lonca Anıtı (PLAN_10)

> Bağımlılık: FAZ 4 + FAZ 8 tamamlandı (boss blueprint drop; reputation'a bağlı sıralama).

**Adım 9.1** — Lonca tabloları + `contribute_to_monument` RPC

> Tam SQL: PLAN_10 §8

**Adım 9.2** — Anıt pasif bonuslarını ilgili RPC'lere ekle

> PLAN_10 §5.1 listesine göre (her 5 levelda tüm üyelere bonus):  
> - Lv 20: overdose_chance `-10%` → `use_potion` RPC'ye ekle  
> - Lv 30: zindan loot luck `+10` → `enter_dungeon` RPC'ye ekle  
> - Lv 35: crafting success `+3%` → `start_crafting` RPC'ye ekle  
> - Lv 55: boss damage `+5%` → `enter_dungeon` RPC'ye ekle  
> - Lv 60: hospital time `-%10` → `enter_dungeon` RPC'ye ekle  
> - Lv 80: overdose kurtulma (günde 1) → `use_potion` RPC'ye ekle  
> - Lv 90: enhancement gold `-%5` → `enhance_item` RPC'ye ekle

**Adım 9.3** — Boss blueprint drop (PLAN_10 §4.2)

> `enter_dungeon` içinde is_boss && Zone 5-7: `%0.5-%5` blueprint parça drop

**Tamamlandığında:** Lonca anıt sistemi çalışır; pasif bonuslar üyelere uygulanır.

---

### 🔴 FAZ 10: Karakter Seçim UI & Onboarding (PLAN_11)

> Bağımlılık: FAZ 0 tamamlandı; UI çalışması için FAZ 1-9 referans verebilir.

**Adım 10.1** — `/game/onboarding/character-select` sayfası

> UI taslağı: PLAN_11 §7  
> RPC: `select_character_class(p_class_id text)` — PLAN_11 §5.3

**Adım 10.2** — 30 dakika grace period (seçim sonrası yeniden seçim)

**Adım 10.3** — Sınıf özelliği implementasyonları:

| Sınıf | Özellik | Uygulandığı Yer |
|-------|---------|----------------|
| Savaşçı | "Kan Hırsı" — PvP kazanım sonrası 30dk ATK +%10 | `pvp_attack` RPC sonucu |
| Simyacı | "Formül Ustası" — Günlük 1 ücretsiz Minor Detox | Günlük reset sistemi |
| Gölge | "Hayalet Adımlar" — Global suspicion tavan 80 | Tesis/Han suspicion RPC'leri |

**Tamamlandığında:** Oyuncu sınıf seçer ve tüm pasif bonuslar aktif olur.

---

## 4. Kanonik Sayılar Özeti

> Bu tabloya bak; çelişki olursa bu tablo geçerlidir.

### 4.1 Level Cap & Power Hedefleri

| Metrik | Değer |
|--------|-------|
| Max level | 70 |
| Max power (end-game) | ~450,000 |
| Max reputation | ~356,000 (prestige; daha yüksek olabilir) |
| Max PvP rating (top) | ~2,500-3,000 |
| Sezon süresi | 365 gün |
| Başlangıç gold | 1,000 |
| Başlangıç gem | 100 |

### 4.2 Karakter Sınıfı Baz Statları

| Stat | Savaşçı (Lv1) | Simyacı (Lv1) | Gölge (Lv1) |
|------|--------------|--------------|------------|
| Attack | 18 | 10 | 12 |
| Defense | 12 | 12 | 10 |
| Health | 120 | 140 | 110 |
| Luck | 5 | 12 | 18 |

| Level büyümesi | Savaşçı | Simyacı | Gölge |
|---------------|---------|---------|-------|
| Attack/level | +3 | +1 | +2 |
| Defense/level | +2 | +2 | +1 |
| Health/level | +15 | +20 | +12 |
| Luck/level | +1 | +2 | +3 |

### 4.3 Item Rarity Stat Skalaları

| Rarity | Equipment Stats (base) | Enhancement ×2.50 (+10) |
|--------|----------------------|-------------------------|
| Common | ATK 500-2,000 | 1,250-5,000 |
| Uncommon | ATK 3,000-10,000 | 7,500-25,000 |
| Rare | ATK 15,000-50,000 | 37,500-125,000 |
| Epic | ATK 60,000-150,000 | 150,000-375,000 |
| Legendary | ATK 200,000-500,000 | 500,000-1,250,000 |
| Mythic | ATK 600,000-1,500,000 | 1,500,000-3,750,000 |

### 4.4 Tesis Üretim Hızları

```
actual_rate = base_rate × (1 + (facility_level - 1) × 0.15)
storage_capacity = 50 × facility_level
```

| Tesis | Base Rate/saat | Lv1 | Lv5 | Lv10 |
|-------|---------------|-----|-----|------|
| Maden Ocağı | 10.0 | 10.0 | 16.0 | 23.5 |
| Zaman Kuyusu | 3.0 | 3.0 | 4.8 | 7.05 |

### 4.5 Enhancement Başarı Oranları & Gold Maliyeti (Common)

| Level | Başarı | Başarısızlık Sonucu | Base Gold |
|-------|--------|---------------------|-----------|
| +0→+1 | 100% | — | 100,000 |
| +1→+2 | 100% | — | 200,000 |
| +2→+3 | 100% | — | 300,000 |
| +3→+4 | 70% | Seviye düşer (-1) | 500,000 |
| +4→+5 | 60% | Seviye düşer (-1) | 1,500,000 |
| +5→+6 | 50% | Eşya YOK edilir | 3,500,000 |
| +6→+7 | 35% | Eşya YOK edilir | 7,500,000 |
| +7→+8 | 20% | Eşya YOK edilir | 15,000,000 |
| +8→+9 | 10% | Eşya YOK edilir | 50,000,000 |
| +9→+10 | 3% | Eşya YOK edilir | 200,000,000 |

> Rarity multiplier: Common×1, Uncommon×1.5, Rare×2.5, Epic×4, Legendary×7, Mythic×12

### 4.6 Zindan Zone Power Gereksinimleri

| Zone | Power Aralığı | Enerji/Koşu | Zindan No |
|------|--------------|------------|-----------|
| Zone 1 | 0 - 10,000 | 5-8 | #1-10 |
| Zone 2 | 12,000 - 40,000 | 8-10 | #11-20 |
| Zone 3 | 44,000 - 100,000 | 12-18 | #21-30 |
| Zone 4 | 110,000 - 220,000 | 18-25 | #31-40 |
| Zone 5 | 230,000 - 340,000 | 25-35 | #41-50 |
| Zone 6 | 350,000 - 420,000 | 35-45 | #51-60 |
| Zone 7 | 425,000 - 450,000 | 45-50 | #61-65 |

### 4.7 Tolerance Sistemi

| Aralık | İksir Etkinliği | Overdose Çarpanı |
|--------|----------------|-----------------|
| 0-20 | %100 | ×0.0 (imkansız) |
| 21-40 | %85 | ×0.0 |
| 41-60 | %65 | ×1.0 |
| 61-80 | %45 | ×2.0 |
| 81-90 | %25 | ×4.0 |
| 91-100 | %25 | ×8.0 |

```
overdose_chance = item.overdose_risk × tolerance_multiplier(tolerance)
IF character_class = 'alchemist': overdose_chance *= 0.80
```

### 4.8 PvP Dövüş Formülü

```sql
-- Her tur:
crit_check    = random() < (luck × 0.002) ? 1.5 : 1.0
dodge_check   = random() < (luck × 0.001) ? 0.0 : 1.0

attacker_dmg  = attacker.attack × (0.8 + random() × 0.4) × crit_check
defender_dmg  = defender.attack × (0.8 + random() × 0.4) × crit_check

-- Savaşçı saldırırsa:
attacker_dmg *= 1.20; crit_check += 0.10 (warrior bonus)

-- Gölge savunursa:
dodge_check   = random() < (luck × 0.001 + 0.15) ? 0.0 : 1.0

net_to_defender = attacker_dmg × dodge_check - defender.defense × 0.3
net_to_attacker = defender_dmg × dodge_check - attacker.defense × 0.3

-- 3 tur; en çok HP kalan kazanır. Eşitse power yüksek olan kazanır.
```

### 4.9 Lonca Anıtı Toplam Kaynak Gereksinimleri (Lv 1-100, tam lonca)

| Kaynak | Toplam |
|--------|--------|
| Gold | ~577 Milyar |
| Structural | ~8.8 Milyon |
| Mystical | ~6.3 Milyon |
| Critical | ~972 Bin |

---

## 5. Sezon Ekonomisi Özeti

### 5.1 Günlük Gelir Banları

| Dönem | Günlük Gelir |
|-------|-------------|
| Gün 1-14 | 200K - 1M gold |
| Ay 2-4 | 5M - 30M gold |
| Ay 5-8 | 30M - 100M gold |
| Ay 9-12 | 80M - 265M gold |

### 5.2 Ana Gold Sink'ler (Önem Sırasıyla)

1. **Enhancement +6 ve üzeri yıkım riski** — en büyük sink
2. **Mythic set crafting** (200M gold/set)
3. **Lonca Anıtı** (577B toplam; aylık 500M - 10B)
4. **Tesis yükseltme** (Lv 10 toplam ~500M)
5. **Detox içecekleri** (30M - 150M/ay end-game)
6. **Han/Mekan kira ve yükseltme** (Lv 10: 1.94B toplam)

### 5.3 Oyuncu Profilleri (Sezon Sonu)

| Tip | Level | Set | Power | Zone |
|-----|-------|-----|-------|------|
| Hardcore | 68-70 | Mythic +7 (kısmi) | 420K-450K | Z7 |
| Casual | 55-60 | Legendary +5 | 250K-320K | Z5-6 |
| P2W (Whale) | 65-68 | Mythic +5 | 380K-430K | Z6-7 |

---

## 6. Sezon Reset Politikası

**Sıfırlananlar (sezon sonu):** Gold, Items, Level, Tesisler, Enhancement, Tolerance/Addiction, Reputation  
**Kalıcı olanlar:** Gems, Cosmetics, Unvanlar, Achievements, Sezon istatistikleri

---

## 7. API / RPC Özet Listesi

| RPC | Faz | Açıklama |
|-----|-----|---------|
| `select_character_class(p_class_id)` | FAZ 0 | Karakter sınıfı seç |
| `get_character_classes()` | FAZ 0 | 3 sınıf listesi |
| `apply_level_up_stats(p_user_id, p_new_level)` | FAZ 0 | Level atlama stat artışı |
| `get_current_user()` | FAZ 0 | Oyuncu profili (luck, class dahil) |
| `equip_item(p_row_id, p_slot)` | FAZ 1 | Item kuşanma |
| `market_list_item(...)` | FAZ 1 | Markete item ekle |
| `start_crafting(p_player_id, p_recipe_id)` | FAZ 3 | Craft başlat |
| `claim_crafting(p_queue_id)` | FAZ 3 | Tamamlanan craft'ı al |
| `enter_dungeon(p_player_id, p_dungeon_id)` | FAZ 4 | Zindana gir |
| `enhance_item(p_player_id, p_row_id, p_rune_type)` | FAZ 5 | Enhancement |
| `open_mekan(p_user_id, p_mekan_type, p_name)` | FAZ 6 | Han/Mekan aç |
| `buy_from_mekan(p_mekan_id, p_item_id, p_quantity)` | FAZ 6 | Han'dan satın al |
| `use_han_item(p_user_id, p_item_id)` | FAZ 6 | Han item kullan |
| `use_potion(p_user_id, p_item_id)` | FAZ 7 | İksir kullan (tolerance) |
| `use_detox(p_user_id, p_detox_type)` | FAZ 7 | Detox kullan |
| `pvp_attack(p_attacker_id, p_defender_id, p_mekan_id)` | FAZ 8 | PvP dövüş |
| `contribute_to_monument(p_user_id, p_resources, p_gold)` | FAZ 9 | Anıta kaynak bağışla |

---

## 8. PLAN Dosyaları Referans Tablosu

| PLAN | Konu | Anahtar Bölümler |
|------|------|-----------------|
| PLAN_01 | Item/Ekipman katalogu, 8 slot, 6 rarity | §1 Stat ölçeği, §2 Slot listesi, §3 DB şeması |
| PLAN_02 | 15 Tesis, 90 kaynak, üretim hızı | §3 Kaynak listesi, §4 Hız formülü, §5 Yükseltme |
| PLAN_03 | 212 Crafting reçetesi, craft kuyruğu | §2-5 Reçeteler, §6 Başarısızlık, §8 DB+RPC |
| PLAN_04 | 65 Zindan, 7 Zone, başarı formülü | §2 Zindan listesi, §3 Formül, §4 Power+Stat, §9 RPC |
| PLAN_05 | Enhancement +0→+10, rune sistemi | §2 Maliyet, §4 Stat artışı, §9 RPC |
| PLAN_06 | Ekonomi dengesi, gold akışı, sezon | §2 Gelir, §3 Harcamalar, §5 Power eğrisi |
| PLAN_07 | Han/Mekan açma, iksir ticareti, PvP arena | §2 Türler, §5 Han-only, §6 PvP, §9 DB |
| PLAN_08 | Tolerance, overdose, detox sistemi | §2 Tolerance bar, §3 Overdose, §5 Detox, §8 RPC |
| PLAN_09 | Reputation, PvP Elo, turnuva | §2 Kaynaklar, §3 PvP formülü, §7 DB |
| PLAN_10 | Lonca Anıtı Lv 1-100, blueprint | §3 Kaynak tablosu, §4 Blueprint, §5 Bonuslar |
| PLAN_11 | Karakter sınıfı seçimi, stat sistemi | §2 3 Sınıf, §3 Stat sistemi, §5 DB/RPC, §9 Entegrasyonlar |

---

*Bu belge PLAN_01–11 arası tüm tasarım belgelerinin tutarlılık merkezi ve yapay zeka uygulama rehberidir. Çelişki durumunda bu belge geçerlidir. Her faz tamamlandıkça ilgili PLAN belgesi de aynı yönde güncellenir.*
