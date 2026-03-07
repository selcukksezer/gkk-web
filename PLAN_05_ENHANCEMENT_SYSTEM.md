# PLAN 05 — Enhancement (Geliştirme) Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** Item sistemi (ekipman stat'ları), Crafting sistemi (scroll üretimi), Tesis sistemi (rune kaynakları)  
> **Mevcut Kod:** `src/hooks/useEnhancement.ts` (232 satır, çalışır durumda)

---

## 1. Genel Bakış

Enhancement sistemi, mevcut `useEnhancement.ts` hook'u üzerine kurulu. **+0 → +10** arası geliştirme yapılabilir.

### Mevcut Durum (Değişmez)
- +0 → +3: Güvenli bölge (%100 başarı)
- +4: %70 başarı
- +5: %60 başarı
- +6: %50 başarı — başarısızlıkta **eşya yok edilir**
- +7: %35 başarı — yok edilme riski
- +8: %20 başarı
- +9: %10 başarı
- +10: %3 başarı

### Yeni Eklemeler
Bu plan, mevcut sisteme yeni **rune** ve **kaynak** entegrasyonları ekler.

---

## 2. Enhancement Maliyetleri (Güncelleme)

### 2.1 Gold Maliyetleri (Nadirliğe Göre Ölçekleme)

Mevcut `ENHANCEMENT_GOLD_COSTS` sadece flat değerler içeriyor. Yeni sistem, item nadirliğine göre çarpan ekler:

```
rarity_multiplier:
  common:    × 1.0
  uncommon:  × 1.5
  rare:      × 2.5
  epic:      × 4.0
  legendary: × 7.0
  mythic:    × 12.0
```

| Level | Base Gold | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|-------|-----------|--------|----------|------|------|-----------|--------|
| +0→+1 | 100,000 | 100,000 | 150,000 | 250,000 | 400,000 | 700,000 | 1,200,000 |
| +1→+2 | 200,000 | 200,000 | 300,000 | 500,000 | 800,000 | 1,400,000 | 2,400,000 |
| +2→+3 | 300,000 | 300,000 | 450,000 | 750,000 | 1,200,000 | 2,100,000 | 3,600,000 |
| +3→+4 | 500,000 | 500,000 | 750,000 | 1,250,000 | 2,000,000 | 3,500,000 | 6,000,000 |
| +4→+5 | 1,500,000 | 1,500,000 | 2,250,000 | 3,750,000 | 6,000,000 | 10,500,000 | 18,000,000 |
| +5→+6 | 3,500,000 | 3,500,000 | 5,250,000 | 8,750,000 | 14,000,000 | 24,500,000 | 42,000,000 |
| +6→+7 | 7,500,000 | 7,500,000 | 11,250,000 | 18,750,000 | 30,000,000 | 52,500,000 | 90,000,000 |
| +7→+8 | 15,000,000 | 15,000,000 | 22,500,000 | 37,500,000 | 60,000,000 | 105,000,000 | 180,000,000 |
| +8→+9 | 50,000,000 | 50,000,000 | 75,000,000 | 125,000,000 | 200,000,000 | 350,000,000 | 600,000,000 |
| +9→+10 | 200,000,000 | 200,000,000 | 300,000,000 | 500,000,000 | 800,000,000 | 1,400,000,000 | 2,400,000,000 |

### 2.2 Scroll Gereksinimleri

| Item Rarity | Gerekli Scroll |
|-------------|---------------|
| Common, Uncommon | Liber Ascensionis Minor (`scroll_upgrade_low`) |
| Rare, Epic | Liber Ascensionis Medius (`scroll_upgrade_middle`) |
| Legendary, Mythic | Liber Ascensionis Major (`scroll_upgrade_high`) |

Her deneme **1 scroll** tüketir (başarılı veya başarısız).

---

## 3. Rune Sistemi (Genişletme)

### 3.1 Mevcut Rune'lar

```typescript
const RUNES = {
  none:       { successBonus: 0,    destructionReduction: 0,    cost: 0 },
  basic:      { successBonus: 0.05, destructionReduction: 0,    cost: 50000 },
  advanced:   { successBonus: 0.10, destructionReduction: 0,    cost: 200000 },
  superior:   { successBonus: 0.15, destructionReduction: 0.5,  cost: 500000 },
  legendary:  { successBonus: 0.25, destructionReduction: 0.75, cost: 1500000 },
  protection: { successBonus: 0,    destructionReduction: 1.0,  cost: 2500000 },
};
```

### 3.2 Yeni: Rune Crafting

Rune'lar artık tesis kaynaklarından **üretilecek** (satın alma yerine):

| Rune | Kaynak Gereksinimi | Gold | Craft Süresi |
|------|-------------------|------|-------------|
| Basic Rune | 5× Lapis Runicus + 2× Aqua Sacra | 50,000 | 3 dk |
| Advanced Rune | 3× Crystallum Magicum + 3× Crystallum Manae | 200,000 | 10 dk |
| Superior Rune | 3× Fragmentum Energiae + 2× Aqua Purificata + 1× Essentia Tenebrarum | 500,000 | 30 dk |
| Legendary Rune | 3× Nucleus Runicus + 2× Lacrimae Angelorum + 1× Cor Umbrae | 1,500,000 | 2 saat |
| Protection Rune | 5× Cor Arcanum + 3× Fons Vitae + 2× Nucleus Abyssi + 1× Essentia Chronos | 2,500,000 | 6 saat |

### 3.3 Yeni Rune: Blessed (Kutsal)

| Rune | Success Bonus | Destruction Reduction | Özel |
|------|---------------|----------------------|------|
| Blessed | +0.20 | 0.50 | Başarısızlıkta eşya seviyesi düşmez (sadece kalır) |

**Craft:** 3× Fons Vitae + 3× Aqua Aeterna + 2× Essentia Runica + 1× Infinitas Temporis  
**Gold:** 5,000,000  
**Craft Süresi:** 12 saat

---

## 4. Stat Artış Formülü

### 4.1 Enhancement Stat Bonusu

```
enhanced_stat = base_stat × (1 + enhancement_level × 0.15)
```

| Enhancement | Çarpan | Örnek (base 10,000 ATK) |
|-------------|--------|-------------------------|
| +0 | ×1.00 | 10,000 |
| +1 | ×1.15 | 11,500 |
| +2 | ×1.30 | 13,000 |
| +3 | ×1.45 | 14,500 |
| +4 | ×1.60 | 16,000 |
| +5 | ×1.75 | 17,500 |
| +6 | ×1.90 | 19,000 |
| +7 | ×2.05 | 20,500 |
| +8 | ×2.20 | 22,000 |
| +9 | ×2.35 | 23,500 |
| +10 | ×2.50 | 25,000 |

### 4.2 Toplam Güç Etkisi

+10 full set mythic kılıcın güç katkısı:
```
Animus Divinus (Mythic Kılıç): ATK 20,000, LUCK 3,500
+10 enhancement (×2.50): ATK 50,000, LUCK 8,750
Power contribution: 50,000 + 8,750×2 = 67,500
```

Tam +10 Mythic set toplam power (ekipman): ~350,000-380,000
Level 70 bonus: 35,000
Reputation (356K): 35,600
**End-game toplam: ~420,000-450,000**

---

## 5. Başarısızlık Mekanikleri (Detay)

### 5.1 +0 → +5 Arası (Güvenli & Orta Risk)

| Durum | Sonuç |
|-------|-------|
| Başarılı | Seviye +1 artar |
| Başarısız (+0→+3) | Hiçbir şey olmaz (seviye aynı kalır) |
| Başarısız (+4→+5) | Seviye -1 düşer (min +0) |

### 5.2 +6 → +10 Arası (Yüksek Risk)

| Durum | Sonuç |
|-------|-------|
| Başarılı | Seviye +1 artar |
| Başarısız (Protection Rune YOK) | **Eşya tamamen yok edilir** |
| Başarısız (Protection Rune VAR) | Eşya korunur, seviye -1 düşer |
| Başarısız (Blessed Rune VAR) | Eşya korunur, seviye aynı kalır |

### 5.3 Risk/Ödül Matrisi

Bir mythic kılıcı +0'dan +10'a çıkarmak için ortalama deneme/maliyet:

| Level | Başarı% | Ort. Deneme | Kümülatif Gold (Mythic) | Risk |
|-------|---------|-------------|------------------------|------|
| +0→+1 | 100% | 1 | 1,200,000 | Yok |
| +1→+2 | 100% | 1 | 3,600,000 | Yok |
| +2→+3 | 100% | 1 | 7,200,000 | Yok |
| +3→+4 | 70% | 1.4 | 15,600,000 | Düşük (seviye düşer) |
| +4→+5 | 60% | 1.7 | 46,200,000 | Orta |
| +5→+6 | 50% | 2.0 | 130,200,000 | Yüksek (yok edilme) |
| +6→+7 | 35% | 2.9 | 391,200,000 | Çok Yüksek |
| +7→+8 | 20% | 5.0 | 1,291,200,000 | Aşırı |
| +8→+9 | 10% | 10.0 | 7,291,200,000 | İmkansıza Yakın |
| +9→+10 | 3% | 33.3 | 87,291,200,000 | Efsanevi |

**Not:** +6 ve üzeri protection rune olmadan **çok riskli**. Protection rune kullanmak maliyeti artırır ama eşyayı korur.

---

## 6. İstatistiksel Analiz

### 6.1 +10 Ulaşma Olasılığı (Rune'suz)

```
P(+0 → +10 tek seferde) = 1.0 × 1.0 × 1.0 × 0.7 × 0.6 × 0.5 × 0.35 × 0.20 × 0.10 × 0.03
                         = 0.000000441 = %0.0000441
                         ≈ 2.27 milyonda 1
```

### 6.2 +10 Ulaşma Olasılığı (Full Legendary Rune)

```
Adjusted rates: +0.25 bonus → +3:%100, +4:%95, +5:%85, +6:%75, +7:%60, +8:%45, +9:%35, +10:%28
P(tek seferde) = 1.0³ × 0.95 × 0.85 × 0.75 × 0.60 × 0.45 × 0.35 × 0.28
               = 0.0000575 = %0.00575
               ≈ 17,391'de 1
```

+10 yapmak **yoğun yatırım** gerektirir ve sezon boyunca bile sadece birkaç oyuncu başarabilir.

---

## 7. UI/UX Tasarımı

### 7.1 Enhancement Ekranı

```
┌──────────────────────────────────────┐
│  ⚔️ EKIPMAN GELİŞTİRME             │
├──────────────────────────────────────┤
│                                      │
│  [Ekipman Resmi]  +5 Falcata Ignis  │
│  ★★★☆☆☆☆☆☆☆☆                       │
│  ATK: 60 → 66  DEF: 0  HP: 0       │
│  LUCK: 9 → 10                       │
│                                      │
│  ─── Geliştirme Detayları ───        │
│  Seviye: +5 → +6                     │
│  Başarı Oranı: 50%                  │
│  Rune Bonusu: +15% (Superior)       │
│  Final Oran: 65%                    │
│                                      │
│  ⚠️ Başarısızlıkta: Eşya YOK EDİLİR│
│  🛡️ Rune Koruması: %50 azaltma      │
│                                      │
│  ─── Maliyet ───                     │
│  Gold: 8,750,000 💰                     │
│  Scroll: Liber Ascensionis Medius 📜 │
│  Rune: Superior Rune 🔮             │
│                                      │
│  [🔮 Rune Seç ▼]                    │
│                                      │
│  [    ⚒️ GELİŞTİR    ]              │
│                                      │
│  ─── Geçmiş ───                      │
│  +4→+5 ✅ Başarılı                   │
│  +4→+5 ❌ Başarısız (-1 seviye)      │
│  +3→+4 ✅ Başarılı                   │
└──────────────────────────────────────┘
```

### 7.2 Animasyon Akışı

```
1. "Geliştir" butonuna basıldığında:
   - Ekipman titrer (0.5s)
   - Işın efekti yukarı doğru çıkar (1s)
   - Patlama efekti (0.5s)

2. Sonuç:
   BAŞARI → Altın parıltı + seviye sayısı animasyonla artar
   BAŞARISIZ (korundu) → Kırmızı titreme + "Seviye düştü" text
   BAŞARISIZ (yok edildi) → Parçalanma animasyonu + kırmızı toz efekti
```

---

## 8. Mevcut Kod Uyumluluğu

`useEnhancement.ts` zaten aşağıdaki yapıyı destekliyor:
- `getSuccessRate(level, rune)` ✓
- `getDestructionRate(level, rune)` ✓
- `getCost(level, rune)` — **güncellenmeli** (rarity multiplier ekle)
- `enhanceItem(item, rune)` — **güncellenmeli** (server RPC ekle)
- `RUNES` objesi — **genişletilmeli** (Blessed rune ekle)

### 8.1 Gereken Değişiklikler

```typescript
// getCost güncellemesi
const RARITY_MULTIPLIER: Record<Rarity, number> = {
  common: 1.0,
  uncommon: 1.5,
  rare: 2.5,
  epic: 4.0,
  legendary: 7.0,
  mythic: 12.0,
};

const getCost = (currentLevel: number, rune: RuneType, rarity: Rarity) => {
  const baseGold = ENHANCEMENT_GOLD_COSTS[currentLevel];
  const rarityMult = RARITY_MULTIPLIER[rarity];
  const goldCost = Math.floor(baseGold * rarityMult);
  const runeCost = RUNES[rune].cost;
  return { gold: goldCost, rune: runeCost, total: goldCost + runeCost };
};
```

---

## 9. Veritabanı: Enhancement RPC (Server-Authoritative)

```sql
CREATE OR REPLACE FUNCTION public.enhance_item(
  p_player_id UUID,
  p_row_id UUID,
  p_rune_type TEXT DEFAULT 'none'
) RETURNS JSONB AS $$
DECLARE
  v_item RECORD;
  v_player RECORD;
  v_rarity_mult NUMERIC;
  v_base_cost INTEGER;
  v_gold_cost INTEGER;
  v_rune_cost INTEGER;
  v_success_rate NUMERIC;
  v_destroy_rate NUMERIC;
  v_success BOOLEAN;
  v_destroyed BOOLEAN := false;
  v_new_level INTEGER;
  v_scroll_id TEXT;
  v_has_scroll BOOLEAN;
BEGIN
  -- Get item with catalog data
  SELECT inv.*, items.rarity, items.can_enhance
  INTO v_item
  FROM inventory inv
  JOIN items ON items.id = inv.item_id
  WHERE inv.row_id = p_row_id AND inv.player_id = p_player_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'item_not_found');
  END IF;
  
  IF NOT v_item.can_enhance THEN
    RETURN jsonb_build_object('error', 'cannot_enhance');
  END IF;
  
  IF v_item.enhancement_level >= 10 THEN
    RETURN jsonb_build_object('error', 'max_level');
  END IF;
  
  -- Get player
  SELECT * INTO v_player FROM players WHERE id = p_player_id;
  
  -- Calculate costs
  v_rarity_mult := CASE v_item.rarity
    WHEN 'common' THEN 1.0
    WHEN 'uncommon' THEN 1.5
    WHEN 'rare' THEN 2.5
    WHEN 'epic' THEN 4.0
    WHEN 'legendary' THEN 7.0
    WHEN 'mythic' THEN 12.0
    ELSE 1.0
  END;
  
  -- Gold check
  v_base_cost := (ARRAY[100000,200000,300000,500000,1500000,3500000,7500000,15000000,50000000,200000000,1000000000])[v_item.enhancement_level + 1];
  v_gold_cost := floor(v_base_cost * v_rarity_mult);
  
  IF v_player.gold < v_gold_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_gold');
  END IF;
  
  -- Scroll check
  v_scroll_id := CASE 
    WHEN v_item.rarity IN ('common', 'uncommon') THEN 'scroll_upgrade_low'
    WHEN v_item.rarity IN ('rare', 'epic') THEN 'scroll_upgrade_middle'
    ELSE 'scroll_upgrade_high'
  END;
  
  SELECT EXISTS(
    SELECT 1 FROM inventory 
    WHERE player_id = p_player_id AND item_id = v_scroll_id AND quantity > 0
  ) INTO v_has_scroll;
  
  IF NOT v_has_scroll THEN
    RETURN jsonb_build_object('error', 'no_scroll');
  END IF;
  
  -- Calculate rates
  v_success_rate := (ARRAY[1.0,1.0,1.0,1.0,0.7,0.6,0.5,0.35,0.2,0.1,0.03])[v_item.enhancement_level + 1];
  v_destroy_rate := (ARRAY[0,0,0,0,0,0,1.0,1.0,1.0,1.0,1.0])[v_item.enhancement_level + 1];
  
  -- Apply rune bonuses
  IF p_rune_type = 'basic' THEN v_success_rate := v_success_rate + 0.05;
  ELSIF p_rune_type = 'advanced' THEN v_success_rate := v_success_rate + 0.10;
  ELSIF p_rune_type = 'superior' THEN v_success_rate := v_success_rate + 0.15; v_destroy_rate := v_destroy_rate * 0.5;
  ELSIF p_rune_type = 'legendary' THEN v_success_rate := v_success_rate + 0.25; v_destroy_rate := v_destroy_rate * 0.25;
  ELSIF p_rune_type = 'protection' THEN v_destroy_rate := 0;
  ELSIF p_rune_type = 'blessed' THEN v_success_rate := v_success_rate + 0.20; v_destroy_rate := v_destroy_rate * 0.5;
  END IF;
  
  v_success_rate := LEAST(1.0, v_success_rate);
  v_destroy_rate := GREATEST(0, v_destroy_rate);
  
  -- Roll
  v_success := random() <= v_success_rate;
  v_new_level := v_item.enhancement_level;
  
  IF v_success THEN
    v_new_level := v_item.enhancement_level + 1;
  ELSE
    IF v_item.enhancement_level >= 6 AND p_rune_type != 'protection' AND p_rune_type != 'blessed' THEN
      IF random() <= v_destroy_rate THEN
        v_destroyed := true;
      END IF;
    ELSIF p_rune_type = 'blessed' THEN
      v_new_level := v_item.enhancement_level; -- Aynı kalır
    ELSE
      v_new_level := GREATEST(0, v_item.enhancement_level - 1);
    END IF;
  END IF;
  
  -- Consume gold + scroll
  UPDATE players SET gold = gold - v_gold_cost WHERE id = p_player_id;
  UPDATE inventory SET quantity = quantity - 1 WHERE player_id = p_player_id AND item_id = v_scroll_id;
  
  -- Apply result
  IF v_destroyed THEN
    DELETE FROM inventory WHERE row_id = p_row_id;
  ELSE
    UPDATE inventory SET enhancement_level = v_new_level WHERE row_id = p_row_id;
  END IF;
  
  RETURN jsonb_build_object(
    'success', v_success,
    'destroyed', v_destroyed,
    'new_level', v_new_level,
    'gold_spent', v_gold_cost,
    'success_rate', round(v_success_rate * 100, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enhance_item(UUID, UUID, TEXT) TO authenticated;
```

---

## 10. Ekonomik Uyum Notu (PLAN_06 ile)

Enhancement sistemi PLAN_06 yeni ekonomi modeliyle şu şekilde uyumludur:

| Enhancement Seviyesi | Tipik Kullanım Zamanı | PLAN_06 Aylık Gelir | Gold Sink Oranı |
|---------------------|----------------------|---------------------|----------------|
| +1 → +3 | Hafta 1-2 | ~50M/ay | Düşük (güvenli bölge) |
| +4 → +5 | Ay 1-3 | ~350M-1B/ay | Orta (%5-10 gelir) |
| +6 → +7 | Ay 4-8 | ~1.5B-5B/ay | Yüksek (%10-20 gelir) |
| +8 → +10 | Ay 9-12 | ~3B-8B/ay | Çok yüksek (ana sink) |

**Yeni ekonomiyle uyum noktaları:**
- Enerji regen kaldırıldı → Oyuncu Han'dan enerji alır → Enhancement gold'u ve Han harcamaları rekabet eder
- Fatigue sistemi kaldırıldı → Zindan koşu sayısı enerji bütçesiyle sınırlı (PLAN_04/06) → Enhancement odaklı oyuncu aktif kalabilir
- Enhancement başarısızlıkları (+6+) yıkım riski taşır → Büyük gold sink → Enflasyon kontrolü

## 10. Uygulama Öncelikleri

1. **Faz 1:** `useEnhancement.ts`'e rarity multiplier ve blessed rune ekle
2. **Faz 2:** `enhance_item` server RPC'si oluştur (server-authoritative)
3. **Faz 3:** Rune crafting reçetelerini `craft_recipes` tablosuna ekle
4. **Faz 4:** Enhancement UI animasyonlarını geliştir
5. **Faz 5:** Enhancement geçmişi log'lama

---

*Bu belge `PLAN_01_ITEMS_EQUIPMENT.md` ve `PLAN_06_ECONOMY_BALANCE.md` (ekonomik uyum) ile birlikte kullanılmalıdır. Han-only enerji itemları için bkz. `PLAN_07_MEKAN_SYSTEM.md`.*
