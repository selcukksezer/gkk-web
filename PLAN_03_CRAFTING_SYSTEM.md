# PLAN 03 — Crafting (Üretim) Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-04  
> **Bağımlılıklar:** Tesis sistemi (kaynak temini), Item sistemi (üretilen ekipmanlar)

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
  - 1× res_time_mythic (Infinitas Temporis — Zaman Kuyusu Mythic)
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
| Common | 5× Ferrum Crudum | 3× Lignum Quercus | 1× Ignis Scintilla | — | 10,000 | 5dk |
| Uncommon | 4× Cuprum Purum | 6× Lignum Quercus | 3× Ignis Scintilla | — | 50,000 | 15dk |
| Rare | 4× Argentum Vena | 5× Lignum Pinus | 3× Glacies Fragmentum | 1× catalyst_rare | 250,000 | 1s |
| Epic | 4× Aurum Nobile | 6× Lignum Ebenum | 4× Fulmen Nucleus | 1× catalyst_epic | 1,000,000 | 4s |
| Legendary | 5× Mithrilium | 6× Lignum Draconum | 5× Terra Cor | 1× catalyst_legendary | 5,000,000 | 12s |
| Mythic | 5× Celestium Purus | 6× Lignum Mundi | 5× Elementum Purum | catalyst_mythic + Infinitas Temporis | 25,000,000 | 24s |

### 3.2 Chest (Zırh) Reçeteleri

**Tesisler:** Mining (birincil) → Ranch (ikincil) → Quarry (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Ferrum Crudum | 3× Corium Vulgare | 1× Saxum Vulgare | 10,000 | 5dk |
| Uncommon | 4× Cuprum Purum | 6× Corium Vulgare | 3× Saxum Vulgare | 50,000 | 15dk |
| Rare | 4× Argentum Vena | 5× Lana Fortis | 3× Granitus Solidus | 250,000 | 1s |
| Epic | 4× Aurum Nobile | 6× Cornu Bestiae | 4× Marmor Album | 1,000,000 | 4s |
| Legendary | 5× Mithrilium | 6× Pellis Wyvernae | 5× Obsidianum Nigrum | 5,000,000 | 12s |
| Mythic | 5× Celestium Purus | 6× Ungula Unicornis | 5× Adamantium Fragmentum | 25,000,000 | 24s |

### 3.3 Head (Kafalık) Reçeteleri

**Tesisler:** Quarry (birincil) → Mining (ikincil) → Farming (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Saxum Vulgare | 3× Ferrum Crudum | 1× Triticum Vulgare | 10,000 | 5dk |
| Uncommon | 4× Granitus Solidus | 6× Ferrum Crudum | 3× Triticum Vulgare | 50,000 | 15dk |
| Rare | 4× Marmor Album | 5× Cuprum Purum | 3× Hordeum Robustum | 250,000 | 1s |
| Epic | 4× Obsidianum Nigrum | 6× Argentum Vena | 4× Gossypium Aureum | 1,000,000 | 4s |
| Legendary | 5× Adamantium Fragmentum | 6× Aurum Nobile | 5× Fructus Draconis | 5,000,000 | 12s |
| Mythic | 5× Petra Aeterna | 6× Mithrilium | 5× Semen Vitae | 25,000,000 | 24s |

### 3.4 Legs (Ayaklık) Reçeteleri

**Tesisler:** Ranch (birincil) → Farming (ikincil) → Clay Pit (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Corium Vulgare | 3× Triticum Vulgare | 1× Argilla Vulgaris | 10,000 | 5dk |
| Uncommon | 4× Lana Fortis | 6× Triticum Vulgare | 3× Argilla Vulgaris | 50,000 | 15dk |
| Rare | 4× Cornu Bestiae | 5× Hordeum Robustum | 3× Argilla Ceramica | 250,000 | 1s |
| Epic | 4× Pellis Wyvernae | 6× Gossypium Aureum | 4× Argilla Aurata | 1,000,000 | 4s |
| Legendary | 5× Ungula Unicornis | 6× Fructus Draconis | 5× Argilla Draconis | 5,000,000 | 12s |
| Mythic | 5× Sanguis Phoenicis | 6× Semen Vitae | 5× Argilla Elementalis | 25,000,000 | 24s |

### 3.5 Boots (Bot) Reçeteleri

**Tesisler:** Ranch (birincil) → Lumber Mill (ikincil) → Sand Quarry (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Corium Vulgare | 3× Lignum Quercus | 1× Arena Vulgaris | 10,000 | 5dk |
| Uncommon | 4× Lana Fortis | 6× Lignum Quercus | 3× Arena Vulgaris | 50,000 | 15dk |
| Rare | 4× Cornu Bestiae | 5× Lignum Pinus | 3× Arena Vitrea | 250,000 | 1s |
| Epic | 4× Pellis Wyvernae | 6× Lignum Ebenum | 4× Arena Crystallina | 1,000,000 | 4s |
| Legendary | 5× Ungula Unicornis | 6× Lignum Draconum | 5× Arena Aurata | 5,000,000 | 12s |
| Mythic | 5× Sanguis Phoenicis | 6× Lignum Mundi | 5× Arena Stellaris | 25,000,000 | 24s |

### 3.6 Gloves (Eldiven) Reçeteleri

**Tesisler:** Ranch (birincil) → Mining (ikincil) → Herb Garden (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Corium Vulgare | 3× Ferrum Crudum | 1× Herba Medicinalis | 10,000 | 5dk |
| Uncommon | 4× Lana Fortis | 6× Ferrum Crudum | 3× Herba Medicinalis | 50,000 | 15dk |
| Rare | 4× Cornu Bestiae | 5× Cuprum Purum | 3× Herba Venenata | 250,000 | 1s |
| Epic | 4× Pellis Wyvernae | 6× Argentum Vena | 4× Flos Lunaris | 1,000,000 | 4s |
| Legendary | 5× Ungula Unicornis | 6× Aurum Nobile | 5× Radix Draconis | 5,000,000 | 12s |
| Mythic | 5× Sanguis Phoenicis | 6× Mithrilium | 5× Herba Immortalis | 25,000,000 | 24s |

### 3.7 Ring (Yüzük) Reçeteleri

**Tesisler:** Rune Mine (birincil) → Mining (ikincil) → Holy Spring (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Lapis Runicus | 3× Ferrum Crudum | 1× Aqua Sacra | 10,000 | 5dk |
| Uncommon | 4× Crystallum Magicum | 6× Ferrum Crudum | 3× Aqua Sacra | 50,000 | 15dk |
| Rare | 4× Fragmentum Energiae | 5× Cuprum Purum | 3× Crystallum Manae | 250,000 | 1s |
| Epic | 4× Nucleus Runicus | 6× Argentum Vena | 4× Aqua Purificata | 1,000,000 | 4s |
| Legendary | 5× Cor Arcanum | 6× Aurum Nobile | 5× Lacrimae Angelorum | 5,000,000 | 12s |
| Mythic | 5× Essentia Runica | 6× Mithrilium | 5× Fons Vitae | 25,000,000 | 24s |

### 3.8 Necklace (Kolye) Reçeteleri

**Tesisler:** Holy Spring (birincil) → Rune Mine (ikincil) → Shadow Pit (üçüncül)

| Rarity | Birincil | İkincil | Üçüncül | Gold | Süre |
|--------|----------|---------|---------|------|------|
| Common | 5× Aqua Sacra | 3× Lapis Runicus | 1× Pulvis Umbrae | 10,000 | 5dk |
| Uncommon | 4× Crystallum Manae | 6× Lapis Runicus | 3× Pulvis Umbrae | 50,000 | 15dk |
| Rare | 4× Aqua Purificata | 5× Crystallum Magicum | 3× Crystallum Umbrale | 250,000 | 1s |
| Epic | 4× Lacrimae Angelorum | 6× Fragmentum Energiae | 4× Essentia Tenebrarum | 1,000,000 | 4s |
| Legendary | 5× Fons Vitae | 6× Nucleus Runicus | 5× Cor Umbrae | 5,000,000 | 12s |
| Mythic | 5× Aqua Aeterna | 6× Cor Arcanum | 5× Nucleus Abyssi | 25,000,000 | 24s |

---

## 4. İksir Reçeteleri

| İksir | Kaynaklar | Gold | Süre |
|-------|-----------|------|------|
| Elixir Vitae Minor | 3× Herba Medicinalis + 2× Mel Silvestre | 5,000 | 2dk |
| Elixir Vitae Major | 3× Flos Lunaris + 2× Mel Regale | 50,000 | 10dk |
| Elixir Vitae Suprema | 3× Herba Immortalis + 2× Mel Aureum | 500,000 | 30dk |
| Essentia Vigoris Minor | 2× Fungus Medicinalis + 1× Aqua Sacra | 5,000 | 2dk |
| Essentia Vigoris Major | 2× Fungus Luminescens + 1× Crystallum Manae | 50,000 | 10dk |
| Essentia Vigoris Suprema | 2× Fungus Temporis + 1× Fons Vitae | 500,000 | 30dk |
| Furor Bellicum (ATK Buff) | 3× Radix Draconis + 2× Venenum Apis + 1× Ignis Scintilla | 200,000 | 15dk |
| Scutum Magicum (DEF Buff) | 3× Aqua Purificata + 2× Cera Pura + 1× Saxum Vulgare | 200,000 | 15dk |
| Fortuna Aurea (LUCK Buff) | 3× Mel Regale + 2× Flos Lunaris + 1× Crystallum Temporale | 300,000 | 20dk |
| Sapientia Accelerata (XP Buff) | 3× Fungus Crystallinus + 2× Essentia Chronos + 1× Fragmentum Energiae | 500,000 | 30dk |

---

## 5. Scroll Reçeteleri

| Scroll | Kaynaklar | Gold | Süre |
|--------|-----------|------|------|
| Liber Ascensionis Minor | 5× Lapis Runicus + 3× Lignum Quercus + 2× Argilla Vulgaris | 20,000 | 5dk |
| Liber Ascensionis Medius | 5× Fragmentum Energiae + 3× Lignum Ebenum + 2× Arena Crystallina | 200,000 | 20dk |
| Liber Ascensionis Major | 5× Cor Arcanum + 3× Lignum Mundi + 2× Essentia Tenebrarum | 2,000,000 | 2s |

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
| **TOPLAM** | **205** |

---

## 10. Uygulama Öncelikleri

1. **Faz 1:** `craft_recipes` tablosu + seed data (205 reçete)
2. **Faz 2:** `craft_queue` tablosu + `start_crafting` RPC
3. **Faz 3:** `claim_crafting` RPC (tamamlananı toplama + başarı/başarısızlık roll)
4. **Faz 4:** Crafting UI sayfası (reçete listesi + filtre + kuyruk gösterimi)
5. **Faz 5:** Başarı oranı artırıcıları (luck, tesis lv, guild)

---

*Bu belge `PLAN_01_ITEMS_EQUIPMENT.md` ve `PLAN_02_FACILITIES_RESOURCES.md` ile birlikte kullanılmalıdır.*
