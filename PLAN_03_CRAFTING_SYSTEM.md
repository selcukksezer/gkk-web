# PLAN 03 — Crafting (Üretim) Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** Tesis sistemi (kaynak temini), Item sistemi (üretilen ekipmanlar), PLAN_11 (Simyacı sınıfı crafting bonusu)

---

## 1. Genel Bakış

Crafting sistemi, tesislerden toplanan kaynakları kullanarak ekipman, iksir, scroll ve özel eşyalar üretir. Toplam **192 ekipman** + **10 iksir** + **3 scroll** + **6 catalyst** = **211+ reçete**.

### Temel İlkeler
- Her ekipman üretimi **3 farklı tesisten** kaynak gerektirir
- Nadirlik arttıkça gereken kaynak miktarı ve nadirliği artar
- Üretim **başarı oranına** tabidir (yeternce kaynak kaybedilir)
- Üretim **zaman** alır (nadirliğe göre artar)
- **Gold maliyeti** her üretimde ödenir

---

## 2. Reçete Yapısı (Nadirliğe Göre)

### 2.1 Common Reçeteler

```
Gerekli Kaynaklar:
  - 5× [Birincil Tesis Common Kaynak]
  - 3× [İkincil Tesis Common Kaynak]
  - 1× [Üçüncül Tesis Common Kaynak]
Gold Maliyeti: 10,000
Üretim Süresi: 5 dakika
Başarı Oranı: 100%
Gerekli Oyuncu Seviyesi: 1
Gerekli Tesis Seviyesi: 1
```

### 2.2 Uncommon Reçeteler

```
Gerekli Kaynaklar:
  - 4× [Birincil Tesis Uncommon Kaynak]
  - 6× [İkincil Tesis Common Kaynak]
  - 3× [Üçüncül Tesis Common Kaynak]
Gold Maliyeti: 50,000
Üretim Süresi: 15 dakika
Başarı Oranı: 95%
Gerekli Oyuncu Seviyesi: 5
Gerekli Tesis Seviyesi: 3 (birincil)
```

### 2.3 Rare Reçeteler

```
Gerekli Kaynaklar:
  - 4× [Birincil Tesis Rare Kaynak]
  - 5× [İkincil Tesis Uncommon Kaynak]
  - 3× [Üçüncül Tesis Uncommon Kaynak]
  - 1× catalyst_rare (zindan drop)
Gold Maliyeti: 250,000
Üretim Süresi: 1 saat
Başarı Oranı: 85%
Gerekli Oyuncu Seviyesi: 15
Gerekli Tesis Seviyesi: 5 (birincil)
```

### 2.4 Epic Reçeteler

```
Gerekli Kaynaklar:
  - 4× [Birincil Tesis Epic Kaynak]
  - 6× [İkincil Tesis Rare Kaynak]
  - 4× [Üçüncül Tesis Rare Kaynak]
  - 1× catalyst_epic (zindan drop)
Gold Maliyeti: 1,000,000
Üretim Süresi: 4 saat
Başarı Oranı: 70%
Gerekli Oyuncu Seviyesi: 25
Gerekli Tesis Seviyesi: 7 (birincil)
```

### 2.5 Legendary Reçeteler

```
Gerekli Kaynaklar:
  - 5× [Birincil Tesis Legendary Kaynak]
  - 6× [İkincil Tesis Epic Kaynak]
  - 5× [Üçüncül Tesis Rare Kaynak]
  - 1× catalyst_legendary (Zone 5-6 zindan drop)
Gold Maliyeti: 5,000,000
Üretim Süresi: 12 saat
Başarı Oranı: 50%
Gerekli Oyuncu Seviyesi: 40
Gerekli Tesis Seviyesi: 9 (birincil)
```

### 2.6 Mythic Reçeteler

```
Gerekli Kaynaklar:
  - 5× [Birincil Tesis Mythic Kaynak]
  - 6× [İkincil Tesis Legendary Kaynak]
  - 5× [Üçüncül Tesis Epic Kaynak]
  - 1× catalyst_mythic (Zone 7 zindan drop)
  - 1× res_time_mythic (Reverse Infinitas Temporis — Zaman Kuyusu Mythic)
Gold Maliyeti: 25,000,000
Üretim Süresi: 24 saat
Başarı Oranı: 30%
Gerekli Oyuncu Seviyesi: 55
Gerekli Tesis Seviyesi: 10 (birincil)
```

---

## 3. Slot-Kaynak Reçete Detayları

Her slot için birincil/ikincil/üçüncül tesis atamaları:

### 3.1 Weapon (Silah) Reçeteleri

**Tesisler:** Mining (birincil) → Lumber Mill (ikincil) → Elemental Forge (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Ekstra | Gold | Süre |
|--------|----------|---------|---------|--------|------|------|
| Common | 5× Ferrum Crudum | 3× Oak Lumber | 1× Ignis Scintilla | — | 10,000 | 5dk |
| Uncommon | 4× Sturdy Cuprum Purum | 6× Oak Lumber | 3× Ignis Scintilla | — | 50,000 | 15dk |
| Rare | 4× Enhanced Argentum Vena | 5× Pine Lumber | 3× Sturdy Glacies Fragmentum | 1× catalyst_rare | 250,000 | 1s |
| Epic | 4× Exceptional Aurum Nobile | 6× Maple Lumber | 4× Enhanced Fulmen Nucleus | 1× catalyst_epic | 1,000,000 | 4s |
| Legendary | 5× Unique Mithrilium | 6× Ebony Lumber | 5× Exceptional Terra Cor | 1× catalyst_legendary | 5,000,000 | 12s |
| Mythic | 5× Reverse Celestium Purus | 6× Ironwood Lumber | 5× Unique Elementum Purum | catalyst_mythic + Reverse Infinitas Temporis | 25,000,000 | 24s |

### 3.2 Chest (Zırh) Reçeteleri

**Tesisler:** Mining (birincil) → Ranch (ikincil) → Quarry (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Ferrum Crudum | 3× Basic Hide | 1× Saxum Vulgare | 10,000 | 5dk |
| Uncommon | 4× Sturdy Cuprum Purum | 6× Basic Hide | 3× Saxum Vulgare | 50,000 | 15dk |
| Rare | 4× Enhanced Argentum Vena | 5× Thick Hide | 3× Sturdy Granitus Solidus | 250,000 | 1s |
| Epic | 4× Exceptional Aurum Nobile | 6× Hard Hide | 4× Enhanced Marmor Album | 1,000,000 | 4s |
| Legendary | 5× Unique Mithrilium | 6× Dragon Hide | 5× Exceptional Obsidianum Nigrum | 5,000,000 | 12s |
| Mythic | 5× Reverse Celestium Purus | 6× Manticore Hide | 5× Unique Adamantium Fragmentum | 25,000,000 | 24s |

### 3.3 Head (Kafalık) Reçeteleri

**Tesisler:** Quarry (birincil) → Mining (ikincil) → Farming (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Saxum Vulgare | 3× Ferrum Crudum | 1× Triticum Vulgare | 10,000 | 5dk |
| Uncommon | 4× Sturdy Granitus Solidus | 6× Ferrum Crudum | 3× Triticum Vulgare | 50,000 | 15dk |
| Rare | 4× Enhanced Marmor Album | 5× Sturdy Cuprum Purum | 3× Sturdy Hordeum Robustum | 250,000 | 1s |
| Epic | 4× Exceptional Obsidianum Nigrum | 6× Enhanced Argentum Vena | 4× Enhanced Gossypium Aureum | 1,000,000 | 4s |
| Legendary | 5× Unique Adamantium Fragmentum | 6× Exceptional Aurum Nobile | 5× Exceptional Fructus Draconis | 5,000,000 | 12s |
| Mythic | 5× Reverse Petra Aeterna | 6× Unique Mithrilium | 5× Unique Semen Vitae | 25,000,000 | 24s |

### 3.4 Legs (Ayaklık) Reçeteleri

**Tesisler:** Ranch (birincil) → Farming (ikincil) → Clay Pit (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Basic Hide | 3× Triticum Vulgare | 1× Argilla Vulgaris | 10,000 | 5dk |
| Uncommon | 4× Thick Hide | 6× Triticum Vulgare | 3× Argilla Vulgaris | 50,000 | 15dk |
| Rare | 4× Hard Hide | 5× Sturdy Hordeum Robustum | 3× Sturdy Argilla Ceramica | 250,000 | 1s |
| Epic | 4× Dragon Hide | 6× Enhanced Gossypium Aureum | 4× Enhanced Argilla Aurata | 1,000,000 | 4s |
| Legendary | 5× Manticore Hide | 6× Exceptional Fructus Draconis | 5× Exceptional Argilla Draconis | 5,000,000 | 12s |
| Mythic | 5× Behemoth Hide | 6× Unique Semen Vitae | 5× Unique Argilla Elementalis | 25,000,000 | 24s |

### 3.5 Boots (Bot) Reçeteleri

**Tesisler:** Ranch (birincil) → Lumber Mill (ikincil) → Sand Quarry (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Basic Hide | 3× Oak Lumber | 1× Arena Vulgaris | 10,000 | 5dk |
| Uncommon | 4× Thick Hide | 6× Oak Lumber | 3× Arena Vulgaris | 50,000 | 15dk |
| Rare | 4× Hard Hide | 5× Pine Lumber | 3× Sturdy Arena Vitrea | 250,000 | 1s |
| Epic | 4× Dragon Hide | 6× Maple Lumber | 4× Enhanced Arena Crystallina | 1,000,000 | 4s |
| Legendary | 5× Manticore Hide | 6× Ebony Lumber | 5× Exceptional Arena Aurata | 5,000,000 | 12s |
| Mythic | 5× Behemoth Hide | 6× Ironwood Lumber | 5× Unique Arena Stellaris | 25,000,000 | 24s |

### 3.6 Gloves (Eldiven) Reçeteleri

**Tesisler:** Ranch (birincil) → Mining (ikincil) → Herb Garden (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Basic Hide | 3× Ferrum Crudum | 1× Wild Herb | 10,000 | 5dk |
| Uncommon | 4× Thick Hide | 6× Ferrum Crudum | 3× Wild Herb | 50,000 | 15dk |
| Rare | 4× Hard Hide | 5× Sturdy Cuprum Purum | 3× Mint Herb | 250,000 | 1s |
| Epic | 4× Dragon Hide | 6× Enhanced Argentum Vena | 4× Sage Herb | 1,000,000 | 4s |
| Legendary | 5× Manticore Hide | 6× Exceptional Aurum Nobile | 5× Ginseng | 5,000,000 | 12s |
| Mythic | 5× Behemoth Hide | 6× Unique Mithrilium | 5× Mandrake | 25,000,000 | 24s |

### 3.7 Ring (Yüzük) Reçeteleri

**Tesisler:** Rune Mine (birincil) → Mining (ikincil) → Holy Spring (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Lapis Runicus | 3× Ferrum Crudum | 1× Aqua Sacra | 10,000 | 5dk |
| Uncommon | 4× Sturdy Crystallum Magicum | 6× Ferrum Crudum | 3× Aqua Sacra | 50,000 | 15dk |
| Rare | 4× Enhanced Fragmentum Energiae | 5× Sturdy Cuprum Purum | 3× Sturdy Crystallum Manae | 250,000 | 1s |
| Epic | 4× Exceptional Nucleus Runicus | 6× Enhanced Argentum Vena | 4× Enhanced Aqua Purificata | 1,000,000 | 4s |
| Legendary | 5× Unique Cor Arcanum | 6× Exceptional Aurum Nobile | 5× Exceptional Lacrimae Angelorum | 5,000,000 | 12s |
| Mythic | 5× Reverse Essentia Runica | 6× Unique Mithrilium | 5× Unique Fons Vitae | 25,000,000 | 24s |

### 3.8 Necklace (Kolye) Reçeteleri

**Tesisler:** Holy Spring (birincil) → Rune Mine (ikincil) → Shadow Pit (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Aqua Sacra | 3× Lapis Runicus | 1× Pulvis Umbrae | 10,000 | 5dk |
| Uncommon | 4× Sturdy Crystallum Manae | 6× Lapis Runicus | 3× Pulvis Umbrae | 50,000 | 15dk |
| Rare | 4× Enhanced Aqua Purificata | 5× Sturdy Crystallum Magicum | 3× Sturdy Crystallum Umbrale | 250,000 | 1s |
| Epic | 4× Exceptional Lacrimae Angelorum | 6× Enhanced Fragmentum Energiae | 4× Enhanced Essentia Tenebrarum | 1,000,000 | 4s |
| Legendary | 5× Unique Fons Vitae | 6× Exceptional Nucleus Runicus | 5× Exceptional Cor Umbrae | 5,000,000 | 12s |
| Mythic | 5× Reverse Aqua Aeterna | 6× Unique Cor Arcanum | 5× Unique Nucleus Abyssi | 25,000,000 | 24s |

---

## 4. İksir Reçeteleri

| İksir | Kaynaklar | Gold | Süre |
|-------|-----------|------|------|
| Elixir Vitae Minor | 3× Wild Herb + 2× Mel Silvestre | 5,000 | 2dk |
| Elixir Vitae Major | 3× Sage Herb + 2× Enhanced Mel Regale | 50,000 | 10dk |
| Elixir Vitae Suprema | 3× Mandrake + 2× Unique Mel Aureum | 500,000 | 30dk |
| Essentia Vigoris Minor | 2× Fungus Medicinalis + 1× Aqua Sacra | 5,000 | 2dk |
| Essentia Vigoris Major | 2× Sturdy Fungus Luminescens + 1× Sturdy Crystallum Manae | 50,000 | 10dk |
| Essentia Vigoris Suprema | 2× Unique Fungus Temporis + 1× Unique Fons Vitae | 500,000 | 30dk |
| Furor Bellicum (ATK Buff) | 3× Ginseng + 2× Exceptional Venenum Apis + 1× Ignis Scintilla | 200,000 | 15dk |
| Scutum Magicum (DEF Buff) | 3× Enhanced Aqua Purificata + 2× Sturdy Cera Pura + 1× Saxum Vulgare | 200,000 | 15dk |
| Fortuna Aurea (LUCK Buff) | 3× Enhanced Mel Regale + 2× Sage Herb + 1× Enhanced Crystallum Temporale | 300,000 | 20dk |
| Sapientia Accelerata (XP Buff) | 3× Exceptional Fungus Crystallinus + 2× Exceptional Essentia Chronos + 1× Enhanced Fragmentum Energiae | 500,000 | 30dk |

---

## 5. Scroll Reçeteleri

| Scroll | Kaynaklar | Gold | Süre |
|--------|-----------|------|------|
| Liber Ascensionis Minor | 5× Lapis Runicus + 3× Oak Lumber + 2× Argilla Vulgaris | 20,000 | 5dk |
| Liber Ascensionis Medius | 5× Enhanced Fragmentum Energiae + 3× Maple Lumber + 2× Enhanced Arena Crystallina | 200,000 | 20dk |
| Liber Ascensionis Major | 5× Unique Cor Arcanum + 3× Ironwood Lumber + 2× Enhanced Essentia Tenebrarum | 2,000,000 | 2s |

---

## 5.5 Han-Only Item Reçeteleri

Han/Mekan'a özel itemlar (PLAN_07 §5 kataloğu) normal crafting sistemiyle üretilir ancak ayrı bir recipe kategorisine girer.

**Kategori:** `recipe_type = 'han_only'`

| Item | Item ID | Kaynaklar | Gold | Süre | Başarı |
|------|---------|-----------|------|------|--------|
| Küçük Han Şarabı | `han_item_vigor_minor` | 3× Enhanced Mel Regale + 2× Wild Herb | 50,000 | 30 dk | %95 |
| Büyük Han Şarabı | `han_item_vigor_major` | 5× Unique Mel Aureum + 3× Sage Herb | 200,000 | 2 saat | %85 |
| Arındırma İçeceği | `han_item_elixir_purge` | 4× Enhanced Aqua Purificata + 3× Fungus Medicinalis | 100,000 | 1 saat | %90 |
| Berraklık Potionı | `han_item_clarity` | 5× Unique Fons Vitae + 4× Reverse Aqua Aeterna | 500,000 | 4 saat | %80 |
| Berserker Özü | `han_item_berserk` | 5× Ginseng + 3× Exceptional Venenum Apis + 3× Ignis Scintilla | 1,000,000 | 6 saat | %60 |
| Gölge Karışımı | `han_item_shadow_brew` | 4× Exceptional Cor Umbrae + 3× Pulvis Umbrae | 800,000 | 5 saat | %70 |
| Büyük Restorasyon | `han_item_restoration` | 5× Mandrake + 4× Unique Mel Aureum + 3× Aqua Sacra | 800,000 | 5 saat | %75 |

**Önemli kurallar:**
- Bu reçeteler `craft_recipes` tablosunda `recipe_type = 'han_only'` olarak işaretlenir
- Üretilen item `items` tablosunda `is_han_only = true`, `is_market_tradeable = false`, `is_direct_tradeable = false` değerlere sahip olur
- Başarısız craft: kaynak %50 kaybı, gold tam kayıp (normal crafting kuralları)
- Stok akışı: craft → hanın stokuna gönder (kişisel envanteri bypass eder — `start_han_crafting` RPC ile)
- **Trade kısıtı uygulama:** `market_list_item` ve `trade_item_direct` RPC'leri, `is_market_tradeable` ve `is_direct_tradeable` bayraklarını kontrol ederek Han-only itemların piyasaya/direkt trade'e çıkmasını engeller

**Reçete sayısına katkı:** 7 adet Han-only reçetesi, toplam reçete sayısını **205 → 212**'ye çıkarır.

---

## 6. Başarısız Crafting Mekanikleri

Crafting başarısız olduğunda:

### 6.1 Kaynak Kaybı
- **Başarısızlık:** Tüm kaynakların **%50**'si kaybedilir (yuvarlama aşağı)
- **Gold:** Tam gold maliyeti **kaybedilir** (geri ödeme yok)
- **Catalyst:** Catalyst **her zaman kaybedilir** (başarılı da olsa başarısız da olsa tüketilir)

### 6.2 Başarı Oranı Artırıcılar
- **Luck stat bonus:** Her 10 luck puanı = +1% crafting success rate
- **Tesis seviye bonusu:** Birincil tesis her lv = +0.5% success rate
- **Guild bonus:** Guild level'a göre +1-5% crafting success rate

```
final_success_rate = base_rate + (luck / 10 × 0.01) + (facility_lv × 0.005) + guild_bonus
```

Örnek: Rare crafting (%85 base) + 30 luck (+3%) + Lv7 tesis (+3.5%) + Lv3 guild (+3%) = **94.5%**

---

## 7. Crafting Kuyruğu

- Oyuncu aynı anda **1 crafting** yapabilir (free)
- **Premium:** 2. crafting slot = 100 gem/ay
- Crafting sürerken oyuncu başka şeyler yapabilir
- Crafting tamamlandığında bildirim gelir
- Tamamlanan craft 24 saat içinde toplanmazsa otomatik envantere eklenir

---

## 8. Veritabanı Şeması

### 8.1 `craft_recipes` Tablosu

```sql
CREATE TABLE IF NOT EXISTS public.craft_recipes (
  id TEXT PRIMARY KEY,                        -- recipe_wpn_sword_common
  output_item_id TEXT NOT NULL REFERENCES items(id),
  output_quantity INTEGER DEFAULT 1,
  recipe_type TEXT NOT NULL,                  -- equipment, potion, scroll, catalyst
  rarity TEXT NOT NULL DEFAULT 'common',
  
  -- Requirements
  required_level INTEGER DEFAULT 1,
  required_facility TEXT DEFAULT NULL,         -- birincil tesis tipi
  required_facility_level INTEGER DEFAULT 1,
  
  -- Cost
  gold_cost INTEGER DEFAULT 0,
  production_time_seconds INTEGER DEFAULT 300, -- 5 dk default
  success_rate NUMERIC DEFAULT 1.0,            -- 0.0 - 1.0
  
  -- Ingredients (JSONB array)
  ingredients JSONB NOT NULL DEFAULT '[]',
  -- Format: [{"resource_id": "res_mining_common", "quantity": 5}, ...]
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_craft_recipes_type ON public.craft_recipes(recipe_type);
CREATE INDEX idx_craft_recipes_rarity ON public.craft_recipes(rarity);
```

### 8.2 `craft_queue` Tablosu

```sql
CREATE TABLE IF NOT EXISTS public.craft_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id),
  recipe_id TEXT NOT NULL REFERENCES craft_recipes(id),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completes_at TIMESTAMPTZ NOT NULL,
  is_completed BOOLEAN DEFAULT false,
  success BOOLEAN DEFAULT NULL,              -- NULL = devam ediyor
  claimed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_craft_queue_player ON public.craft_queue(player_id);
```

### 8.3 Craft RPC

```sql
CREATE OR REPLACE FUNCTION public.start_crafting(
  p_player_id UUID,
  p_recipe_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_recipe RECORD;
  v_ingredient RECORD;
  v_player RECORD;
  v_have INTEGER;
  v_cost JSONB;
  v_success BOOLEAN;
  v_completes_at TIMESTAMPTZ;
  v_queue_count INTEGER;
BEGIN
  -- Get recipe
  SELECT * INTO v_recipe FROM craft_recipes WHERE id = p_recipe_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'recipe_not_found');
  END IF;
  
  -- Get player
  SELECT * INTO v_player FROM players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;
  
  -- Level check
  IF v_player.level < v_recipe.required_level THEN
    RETURN jsonb_build_object('error', 'insufficient_level');
  END IF;
  
  -- Gold check
  IF v_player.gold < v_recipe.gold_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_gold');
  END IF;
  
  -- Queue check (max 1 active)
  SELECT COUNT(*) INTO v_queue_count 
  FROM craft_queue 
  WHERE player_id = p_player_id AND is_completed = false;
  
  IF v_queue_count >= 1 THEN
    RETURN jsonb_build_object('error', 'queue_full');
  END IF;
  
  -- Check and consume ingredients
  FOR v_ingredient IN 
    SELECT * FROM jsonb_to_recordset(v_recipe.ingredients) 
    AS x(resource_id TEXT, quantity INTEGER)
  LOOP
    SELECT quantity INTO v_have 
    FROM player_resources 
    WHERE player_id = p_player_id AND resource_id = v_ingredient.resource_id;
    
    IF v_have IS NULL OR v_have < v_ingredient.quantity THEN
      RETURN jsonb_build_object('error', 'insufficient_resources', 
                                 'resource', v_ingredient.resource_id);
    END IF;
    
    -- Consume resources
    UPDATE player_resources 
    SET quantity = quantity - v_ingredient.quantity
    WHERE player_id = p_player_id AND resource_id = v_ingredient.resource_id;
  END LOOP;
  
  -- Consume gold
  UPDATE players SET gold = gold - v_recipe.gold_cost WHERE id = p_player_id;
  
  -- Calculate completion time
  v_completes_at := now() + (v_recipe.production_time_seconds || ' seconds')::INTERVAL;
  
  -- Insert into queue
  INSERT INTO craft_queue (player_id, recipe_id, completes_at)
  VALUES (p_player_id, p_recipe_id, v_completes_at);
  
  RETURN jsonb_build_object(
    'success', true,
    'completes_at', v_completes_at,
    'recipe_id', p_recipe_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 9. Reçete Sayısı Özeti

| Kategori | Adet |
|----------|------|
| Weapon (4 tip × 6 rarity) | 24 |
| Chest (4 tip × 6 rarity) | 24 |
| Head (4 tip × 6 rarity) | 24 |
| Legs (4 tip × 6 rarity) | 24 |
| Boots (4 tip × 6 rarity) | 24 |
| Gloves (4 tip × 6 rarity) | 24 |
| Ring (4 tip × 6 rarity) | 24 |
| Necklace (4 tip × 6 rarity) | 24 |
| İksirler | 10 |
| Scroll'lar | 3 |
| Han-Only Itemlar | 7 |
| **TOPLAM** | **212** |

---

## 10. Uygulama Öncelikleri

1. **Faz 1:** `craft_recipes` tablosu + seed data (205 reçete)
2. **Faz 2:** `craft_queue` tablosu + `start_crafting` RPC
3. **Faz 3:** `claim_crafting` RPC (tamamlananı toplama + başarı/başarısızlık roll)
4. **Faz 4:** Crafting UI sayfası (reçete listesi + filtre + kuyruk gösterimi)
5. **Faz 5:** Başarı oranı artırıcıları (luck, tesis lv, guild)

---

*Bu belge `PLAN_01_ITEMS_EQUIPMENT.md` ve `PLAN_02_FACILITIES_RESOURCES.md` ile birlikte kullanılmalıdır. Simyacı sınıfının crafting başarı bonusu (+%15) ve Han craft süresi azaltması (-%20) için bkz. `PLAN_11_CHARACTER_CLASS_SYSTEM.md`.*
