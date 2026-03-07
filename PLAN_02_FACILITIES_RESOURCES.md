# PLAN 02 — Tesis & Kaynak Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** Crafting sistemi (kaynak tüketimi), Item sistemi (üretilen ekipmanlar), PLAN_11 (Gölge sınıfı tesis şüphe azalması)

---

## 1. Genel Bakış

Oyunda **15 tesis** bulunur. Her tesis **6 nadirlik seviyesinde** kaynak üretir.  
Toplam: **15 × 6 = 90 benzersiz kaynak türü**.

Tesisler 3 kategoriye ayrılır:
- **Temel Kaynaklar (1-5):** Maden, Taş, Kereste, Kil, Kum
- **Organik Kaynaklar (6-10):** Çiftlik, Ot Bahçesi, Hayvancılık, Arıcılık, Mantar
- **Mistik Kaynaklar (11-15):** Rune Madeni, Kutsal Kaynak, Gölge Çukuru, Elementel Ocak, Zaman Kuyusu

### Önemli Kural
Tesis seviyesi, o tesisten çıkacak kaynak nadirliğini belirler:
- Tesis Lv 1-2: Sadece **Common** kaynak
- Tesis Lv 3-4: **Common + Uncommon**
- Tesis Lv 5-6: **Common + Uncommon + Rare**
- Tesis Lv 7-8: **+ Epic**
- Tesis Lv 9: **+ Legendary**
- Tesis Lv 10: **+ Mythic** (çok düşük oran)

---

## 2. Nadirlik Drop Oranları (Tesis Seviyesine Göre)

| Tesis Lv | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|----------|--------|----------|------|------|-----------|--------|
| 1 | 100% | — | — | — | — | — |
| 2 | 90% | 10% | — | — | — | — |
| 3 | 70% | 25% | 5% | — | — | — |
| 4 | 55% | 30% | 13% | 2% | — | — |
| 5 | 40% | 30% | 20% | 8% | 2% | — |
| 6 | 30% | 28% | 22% | 14% | 5% | 1% |
| 7 | 22% | 25% | 23% | 18% | 9% | 3% |
| 8 | 15% | 22% | 24% | 22% | 12% | 5% |
| 9 | 10% | 18% | 24% | 24% | 16% | 8% |
| 10 | 5% | 14% | 22% | 26% | 20% | 13% |

---

## 3. Tam Kaynak Kataloğu (90 Kaynak)

### 3.1 Maden Ocağı (Mining) — `mining`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_mining_common` | Ferrum Crudum | Ham Demir |
| Uncommon | `res_mining_uncommon` | Cuprum Purum | Saf Bakır |
| Rare | `res_mining_rare` | Argentum Vena | Gümüş Damarı |
| Epic | `res_mining_epic` | Aurum Nobile | Asil Altın |
| Legendary | `res_mining_legendary` | Mithrilium | Mithril |
| Mythic | `res_mining_mythic` | Celestium Purus | Saf Celestium |

**Birincil Kullanım:** Silahlar, Zırhlar (Plate/Chain)  
**Base Rate:** 10.0/saat (Lv 1)

---

### 3.2 Taş Ocağı (Quarry) — `quarry`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_quarry_common` | Saxum Vulgare | Sıradan Taş |
| Uncommon | `res_quarry_uncommon` | Granitus Solidus | Katı Granit |
| Rare | `res_quarry_rare` | Marmor Album | Beyaz Mermer |
| Epic | `res_quarry_epic` | Obsidianum Nigrum | Kara Obsidyen |
| Legendary | `res_quarry_legendary` | Adamantium Fragmentum | Adamantit Parçası |
| Mythic | `res_quarry_mythic` | Petra Aeterna | Ebedi Taş |

**Birincil Kullanım:** Kafalıklar (Helm/Crown), Yüzükler  
**Base Rate:** 8.0/saat

---

### 3.3 Kereste Fabrikası (Lumber Mill) — `lumber_mill`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_lumber_common` | Lignum Quercus | Meşe Kerestesi |
| Uncommon | `res_lumber_uncommon` | Lignum Pinus | Çam Kerestesi |
| Rare | `res_lumber_rare` | Lignum Ebenum | Abanoz |
| Epic | `res_lumber_epic` | Lignum Draconum | Ejder Ağacı |
| Legendary | `res_lumber_legendary` | Lignum Mundi | Dünya Ağacı Dalı |
| Mythic | `res_lumber_mythic` | Lignum Yggdrasil | Yggdrasil Dalı |

**Birincil Kullanım:** Silahlar (Staff/Bow kabzası), Botlar  
**Base Rate:** 12.0/saat

---

### 3.4 Kil Ocağı (Clay Pit) — `clay_pit`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_clay_common` | Argilla Vulgaris | Sıradan Kil |
| Uncommon | `res_clay_uncommon` | Argilla Ceramica | Seramik Kili |
| Rare | `res_clay_rare` | Argilla Aurata | Altın Kil |
| Epic | `res_clay_epic` | Argilla Draconis | Ejder Kili |
| Legendary | `res_clay_legendary` | Argilla Elementalis | Elementel Kil |
| Mythic | `res_clay_mythic` | Argilla Primaeva | İlkel Kil |

**Birincil Kullanım:** Ayaklıklar, İksir şişeleri  
**Base Rate:** 15.0/saat

---

### 3.5 Kum Ocağı (Sand Quarry) — `sand_quarry`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_sand_common` | Arena Vulgaris | Sıradan Kum |
| Uncommon | `res_sand_uncommon` | Arena Vitrea | Cam Kumu |
| Rare | `res_sand_rare` | Arena Crystallina | Kristal Kum |
| Epic | `res_sand_epic` | Arena Aurata | Altın Kum |
| Legendary | `res_sand_legendary` | Arena Stellaris | Yıldız Kumu |
| Mythic | `res_sand_mythic` | Arena Temporis | Zaman Kumu |

**Birincil Kullanım:** Botlar, Cam eşyalar  
**Base Rate:** 20.0/saat

---

### 3.6 Çiftlik (Farming) — `farming`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_farming_common` | Triticum Vulgare | Sıradan Buğday |
| Uncommon | `res_farming_uncommon` | Hordeum Robustum | Güçlü Arpa |
| Rare | `res_farming_rare` | Gossypium Aureum | Altın Pamuk |
| Epic | `res_farming_epic` | Fructus Draconis | Ejder Meyvesi |
| Legendary | `res_farming_legendary` | Semen Vitae | Yaşam Tohumu |
| Mythic | `res_farming_mythic` | Flora Aeterna | Ebedi Bitki |

**Birincil Kullanım:** Kafalıklar (Hood), Cüppeler, İksirler  
**Base Rate:** 18.0/saat

---

### 3.7 Ot Bahçesi (Herb Garden) — `herb_garden`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_herb_common` | Herba Medicinalis | Şifalı Ot |
| Uncommon | `res_herb_uncommon` | Herba Venenata | Zehirli Ot |
| Rare | `res_herb_rare` | Flos Lunaris | Ay Çiçeği |
| Epic | `res_herb_epic` | Radix Draconis | Ejder Kökü |
| Legendary | `res_herb_legendary` | Herba Immortalis | Ölümsüzlük Otu |
| Mythic | `res_herb_mythic` | Essentia Vitalis | Hayat Özü |

**Birincil Kullanım:** İksirler, Eldivenler (Wraps), Buff yiyecekler  
**Base Rate:** 10.0/saat

---

### 3.8 Hayvancılık (Ranch) — `ranch`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_ranch_common` | Corium Vulgare | Sıradan Deri |
| Uncommon | `res_ranch_uncommon` | Lana Fortis | Güçlü Yün |
| Rare | `res_ranch_rare` | Cornu Bestiae | Canavar Boynuzu |
| Epic | `res_ranch_epic` | Pellis Wyvernae | Wyvern Derisi |
| Legendary | `res_ranch_legendary` | Ungula Unicornis | Unicorn Tırnağı |
| Mythic | `res_ranch_mythic` | Sanguis Phoenicis | Anka Kanı |

**Birincil Kullanım:** Deri Zırhlar, Ayaklıklar, Botlar, Eldivenler  
**Base Rate:** 12.0/saat

---

### 3.9 Arıcılık (Apiary) — `apiary`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_apiary_common` | Mel Silvestre | Orman Balı |
| Uncommon | `res_apiary_uncommon` | Cera Pura | Saf Balmumu |
| Rare | `res_apiary_rare` | Mel Regale | Kraliyet Jelesi |
| Epic | `res_apiary_epic` | Venenum Apis | Arı Zehiri Özü |
| Legendary | `res_apiary_legendary` | Mel Aureum | Altın Bal |
| Mythic | `res_apiary_mythic` | Ambrosia Divina | İlahi Ambrosia |

**Birincil Kullanım:** İksirler, Buff yiyecekler, Kolyeler  
**Base Rate:** 8.0/saat

---

### 3.10 Mantar Çiftliği (Mushroom Farm) — `mushroom_farm`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_mushroom_common` | Fungus Medicinalis | Şifalı Mantar |
| Uncommon | `res_mushroom_uncommon` | Fungus Luminescens | Parlayan Mantar |
| Rare | `res_mushroom_rare` | Fungus Venenatus | Zehirli Mantar |
| Epic | `res_mushroom_epic` | Fungus Crystallinus | Kristal Mantar |
| Legendary | `res_mushroom_legendary` | Fungus Temporis | Zaman Mantarı |
| Mythic | `res_mushroom_mythic` | Fungus Primordialis | İlkel Mantar |

**Birincil Kullanım:** İksirler (zehir/buff), Scroll malzemeleri  
**Base Rate:** 10.0/saat

---

### 3.11 Rune Madeni (Rune Mine) — `rune_mine`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_rune_common` | Lapis Runicus | Ham Rune Taşı |
| Uncommon | `res_rune_uncommon` | Crystallum Magicum | Büyü Kristali |
| Rare | `res_rune_rare` | Fragmentum Energiae | Enerji Parçası |
| Epic | `res_rune_epic` | Nucleus Runicus | Rune Çekirdeği |
| Legendary | `res_rune_legendary` | Cor Arcanum | Gizemli Kalp |
| Mythic | `res_rune_mythic` | Essentia Runica | Rune Özü |

**Birincil Kullanım:** Yüzükler, Enhancement Rune'ları, Scroll'lar  
**Base Rate:** 5.0/saat

---

### 3.12 Kutsal Kaynak (Holy Spring) — `holy_spring`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_holy_common` | Aqua Sacra | Kutsal Su |
| Uncommon | `res_holy_uncommon` | Crystallum Manae | Mana Kristali |
| Rare | `res_holy_rare` | Aqua Purificata | Arındırma Suyu |
| Epic | `res_holy_epic` | Lacrimae Angelorum | Melek Gözyaşı |
| Legendary | `res_holy_legendary` | Fons Vitae | Yaşam Kaynağı |
| Mythic | `res_holy_mythic` | Aqua Aeterna | Ebedi Su |

**Birincil Kullanım:** Kolyeler, Kutsal iksirler, Holy enhancement  
**Base Rate:** 6.0/saat

---

### 3.13 Gölge Çukuru (Shadow Pit) — `shadow_pit`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_shadow_common` | Pulvis Umbrae | Gölge Tozu |
| Uncommon | `res_shadow_uncommon` | Crystallum Umbrale | Gölge Kristali |
| Rare | `res_shadow_rare` | Essentia Tenebrarum | Karanlık Esansı |
| Epic | `res_shadow_epic` | Cor Umbrae | Gölge Kalbi |
| Legendary | `res_shadow_legendary` | Nucleus Abyssi | Uçurum Çekirdeği |
| Mythic | `res_shadow_mythic` | Vacuum Aeternale | Ebedi Boşluk |

**Birincil Kullanım:** Kolyeler, Gölge silahları, Zehirli iksirler  
**Base Rate:** 4.0/saat

---

### 3.14 Elementel Ocak (Elemental Forge) — `elemental_forge`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_elemental_common` | Ignis Scintilla | Ateş Kıvılcımı |
| Uncommon | `res_elemental_uncommon` | Glacies Fragmentum | Buz Parçası |
| Rare | `res_elemental_rare` | Fulmen Nucleus | Yıldırım Çekirdeği |
| Epic | `res_elemental_epic` | Terra Cor | Toprak Kalbi |
| Legendary | `res_elemental_legendary` | Elementum Purum | Saf Element |
| Mythic | `res_elemental_mythic` | Quintessentia | Beşinci Element |

**Birincil Kullanım:** Silahlar (üst tier), Mistik zırhlar, Enhancement  
**Base Rate:** 5.0/saat

---

### 3.15 Zaman Kuyusu (Time Well) — `time_well`

| Rarity | Resource ID | Latince İsim | Türkçe |
|--------|------------|--------------|--------|
| Common | `res_time_common` | Pulvis Temporis | Zaman Tozu |
| Uncommon | `res_time_uncommon` | Fragmentum Horae | Saat Parçası |
| Rare | `res_time_rare` | Crystallum Temporale | Zaman Kristali |
| Epic | `res_time_epic` | Essentia Chronos | Kronos Esansı |
| Legendary | `res_time_legendary` | Momentum Aeternum | Ebedi An |
| Mythic | `res_time_mythic` | Infinitas Temporis | Sonsuz Zaman |

**Birincil Kullanım:** Mythic crafting zorunlu katalizör, Hızlandırma, Özel buff  
**Base Rate:** 3.0/saat

---

## 4. Üretim Hızı Formülü

```
actual_rate = base_rate × (1 + (facility_level - 1) × 0.15)
```

| Tesis Lv | Çarpan | Maden Ocağı (base 10) | Zaman Kuyusu (base 3) |
|----------|--------|----------------------|----------------------|
| 1 | ×1.00 | 10.0/saat | 3.0/saat |
| 2 | ×1.15 | 11.5/saat | 3.45/saat |
| 3 | ×1.30 | 13.0/saat | 3.90/saat |
| 5 | ×1.60 | 16.0/saat | 4.80/saat |
| 7 | ×1.90 | 19.0/saat | 5.70/saat |
| 10 | ×2.35 | 23.5/saat | 7.05/saat |

### Üretim Depolama Kapasitesi

Her tesis belirli miktarda kaynak depolayabilir. Taşarsa üretim durur:

```
storage_capacity = 50 × facility_level
```

| Tesis Lv | Kapasite |
|----------|----------|
| 1 | 50 |
| 5 | 250 |
| 10 | 500 |

Oyuncu düzenli olarak gelip kaynakları toplamalı.

---

## 5. Tesis Yükseltme Sistemi

### 5.1 Yükseltme Maliyetleri

```
upgrade_cost = base_upgrade_cost × upgrade_multiplier^(current_level - 1)
```

| Tesis | Base Cost | Multiplier | Lv2 | Lv5 | Lv10 |
|-------|-----------|------------|-----|-----|------|
| Maden Ocağı | 100,000 | ×1.50 | 150,000 | 506,300 | 3,844,300 |
| Taş Ocağı | 120,000 | ×1.50 | 180,000 | 607,500 | 4,613,200 |
| Kereste | 150,000 | ×1.50 | 225,000 | 759,400 | 5,766,500 |
| Kil Ocağı | 180,000 | ×1.50 | 270,000 | 911,300 | 6,919,800 |
| Kum Ocağı | 200,000 | ×1.50 | 300,000 | 1,012,500 | 7,688,600 |
| Çiftlik | 250,000 | ×1.50 | 375,000 | 1,265,600 | 9,610,800 |
| Ot Bahçesi | 300,000 | ×1.50 | 450,000 | 1,518,800 | 11,532,900 |
| Hayvancılık | 350,000 | ×1.50 | 525,000 | 1,771,900 | 13,455,100 |
| Arıcılık | 400,000 | ×1.50 | 600,000 | 2,025,000 | 15,377,200 |
| Mantar | 500,000 | ×1.50 | 750,000 | 2,531,300 | 19,221,600 |
| Rune Madeni | 600,000 | ×1.60 | 960,000 | 3,932,200 | 40,317,800 |
| Kutsal Kaynak | 700,000 | ×1.60 | 1,120,000 | 4,587,500 | 47,037,500 |
| Gölge Çukuru | 800,000 | ×1.60 | 1,280,000 | 5,242,900 | 53,757,100 |
| Elementel Ocak | 1,000,000 | ×1.60 | 1,600,000 | 6,553,600 | 67,196,400 |
| Zaman Kuyusu | 1,200,000 | ×1.70 | 2,040,000 | 10,084,200 | 166,798,800 |

### 5.2 Yükseltme Süreleri

```
upgrade_time_hours = 0.5 × current_level × tier_multiplier
```

| Tier | Multiplier | Lv1→2 | Lv5→6 | Lv9→10 |
|------|-----------|-------|-------|--------|
| Temel | ×1.0 | 30 dk | 2.5 saat | 4.5 saat |
| Organik | ×1.2 | 36 dk | 3 saat | 5.4 saat |
| Mistik | ×1.5 | 45 dk | 3.75 saat | 6.75 saat |

### 5.3 Tesis Açma Gereksinimleri

| Tesis | Gerekli Seviye | Açma Maliyeti (Gold) |
|-------|---------------|---------------------|
| Maden Ocağı | 1 | 50,000 |
| Taş Ocağı | 2 | 80,000 |
| Kereste Fabrikası | 3 | 100,000 |
| Kil Ocağı | 4 | 120,000 |
| Kum Ocağı | 5 | 150,000 |
| Çiftlik | 6 | 200,000 |
| Ot Bahçesi | 7 | 250,000 |
| Hayvancılık | 8 | 300,000 |
| Arıcılık | 9 | 350,000 |
| Mantar Çiftliği | 10 | 400,000 |
| Rune Madeni | 15 | 500,000 |
| Kutsal Kaynak | 20 | 600,000 |
| Gölge Çukuru | 25 | 700,000 |
| Elementel Ocak | 30 | 800,000 |
| Zaman Kuyusu | 40 | 1,000,000 |

---

## 6. Kaynak → Ekipman Slot Eşleştirmesi

Hangi slottaki ekipman hangi tesislerden kaynak gerektirir:

| Ekipman Slotu | Birincil Tesis | İkincil Tesis | Üçüncül Tesis |
|---------------|---------------|---------------|---------------|
| **Weapon** (Silah) | Mining | Lumber Mill | Elemental Forge |
| **Chest** (Zırh) | Mining | Ranch | Quarry |
| **Head** (Kafalık) | Quarry | Mining | Farming |
| **Legs** (Ayaklık) | Ranch | Farming | Clay Pit |
| **Boots** (Bot) | Ranch | Lumber Mill | Sand Quarry |
| **Gloves** (Eldiven) | Ranch | Mining | Herb Garden |
| **Ring** (Yüzük) | Rune Mine | Mining | Holy Spring |
| **Necklace** (Kolye) | Holy Spring | Rune Mine | Shadow Pit |

### Özel Not: Mythic Crafting

Tüm **Mythic** rarity ekipmanlar, yukarıdaki 3 kaynağa ek olarak:
- **1× Zaman Kuyusu Mythic kaynağı** (`res_time_mythic` — Infinitas Temporis)
- **1× Mythic Catalyst** (`catalyst_mythic` — Zindan drop'u)

gerektirir. Bu, Mythic itemleri son derece nadir ve değerli yapar.

---

## 7. Veritabanı Şeması

### 7.1 `resources` Tablosu (Catalog)

```sql
CREATE TABLE IF NOT EXISTS public.resources (
  id TEXT PRIMARY KEY,                     -- res_mining_common
  name TEXT NOT NULL,                      -- Ferrum Crudum
  name_tr TEXT NOT NULL,                   -- Ham Demir
  description TEXT DEFAULT '',
  icon TEXT DEFAULT 'default_resource',
  facility_type TEXT NOT NULL,             -- mining, quarry, lumber_mill...
  rarity TEXT NOT NULL DEFAULT 'common',   -- common..mythic
  base_value INTEGER DEFAULT 10,           -- NPC satış fiyatı
  is_stackable BOOLEAN DEFAULT true,
  max_stack INTEGER DEFAULT 999,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index
CREATE INDEX idx_resources_facility ON public.resources(facility_type);
CREATE INDEX idx_resources_rarity ON public.resources(rarity);
```

### 7.2 `player_resources` Tablosu

```sql
CREATE TABLE IF NOT EXISTS public.player_resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id),
  resource_id TEXT NOT NULL REFERENCES resources(id),
  quantity INTEGER NOT NULL DEFAULT 0,
  UNIQUE(player_id, resource_id)
);

CREATE INDEX idx_player_resources_player ON public.player_resources(player_id);
```

### 7.3 Kaynak Fiyatları (NPC Sell)

| Rarity | Base Value (Gold) |
|--------|------------------|
| Common | 500 |
| Uncommon | 2,000 |
| Rare | 8,000 |
| Epic | 30,000 |
| Legendary | 120,000 |
| Mythic | 500,000 |

---

## 8. Günlük Kaynak Üretim Projeksiyonu

Bir oyuncu bütün gün (24 saat) tesislerini çalıştırırsa:

### 8.1 Tek Tesis (Maden Ocağı, Lv 5)

```
Rate: 10 × 1.60 = 16/saat
Depolama: 250
Dolum süresi: 250 / 16 = ~15.6 saat
```

24 saatte (2 kez toplama ile): ~384 kaynak
- ~40% common = 154 × 500g = 77,000g
- ~30% uncommon = 115 × 2,000g = 230,000g
- ~20% rare = 77 × 8,000g = 616,000g
- ~8% epic = 31 × 30,000g = 930,000g
- ~2% legendary = 8 × 120,000g = 960,000g

**Toplam günlük değer (tek tesis): ~2,813,000 gold**

### 8.2 Tam Tesis Parkı (15 tesis, karışık seviyeler)

Erken oyun (hepsi Lv 1-3): ~1,500,000-3,000,000 gold/gün
Orta oyun (hepsi Lv 5-7): ~10,000,000-20,000,000 gold/gün  
Son oyun (hepsi Lv 8-10): ~50,000,000-100,000,000 gold/gün

---

## 9. Uygulama Öncelikleri

1. **Faz 1:** `resources` tablosunu oluştur, 90 kaynağı seed et
2. **Faz 2:** `player_resources` tablosu ve toplama RPC'si
3. **Faz 3:** Tesis seviyesine göre nadirlik drop sistemi
4. **Faz 4:** Mevcut `FacilityConfig.ts` güncelleme (yeni kaynak ID'leri)
5. **Faz 5:** Facilities UI'ındaki kaynak gösterimini güncelle

---

*Bu belge `PLAN_01_ITEMS_EQUIPMENT.md` ve `PLAN_03_CRAFTING_SYSTEM.md` ile birlikte kullanılmalıdır. Han-only item craft için gerekli kaynaklar (Mel Aureum, Fons Vitae, Herba Immortalis vb.) bu planda tanımlıdır; bkz. `PLAN_07_MEKAN_SYSTEM.md §5`. Gölge sınıfının tesis şüphe azaltma bonusu için bkz. `PLAN_11_CHARACTER_CLASS_SYSTEM.md`.*
