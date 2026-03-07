# PLAN 08 — Tolerans & Detox Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** PLAN_01 (iksir verileri), PLAN_04 (hastane), PLAN_07 (Mekan — detox satışı)  
> **Kapsam:** Tolerance bar, overdose mekanizması, addiction, detox içecekleri

---

## 1. Genel Bakış

Tolerans sistemi, iksir kullanımının **bir maliyeti** olmasını sağlar. Oyuncular iksir kullanarak güçlenir ama vücutları zamanla dayanıklılık geliştirir (tolerance) ve aşırı kullanımda **overdose** riski oluşur.

**Mevcut DB sütunları (game.users):**
- `tolerance` — int, 0-100 arası
- `addiction_level` — int, bağımlılık seviyesi

**Mevcut DB sütunları (public.items):**
- `tolerance_increase` — int, bu iksirin tolerans artışı (1-25)
- `overdose_risk` — numeric, baz overdose olasılığı (0.0-0.2)

**Temel kurallar:**
- Her iksir kullanımı `tolerance` artırır
- Tolerance yükseldikçe iksir etkinliği düşer
- Tolerance 80+ ise overdose riski ciddi
- Overdose = hastaneye düşme (PLAN_04)
- Detox içecekleri tolerance düşürür (sadece Mekan'da satılır, PLAN_07)

---

## 2. Tolerans Mekanizması

### 2.1 Tolerance Bar (0-100)

| Aralık | Durum | İksir Etkinliği | Yan Etki |
|--------|-------|----------------|---------|
| 0-20 | **Temiz** | %100 | Yok |
| 21-40 | **Alışma** | %85 | Hafif titreme efekti (kozmetik) |
| 41-60 | **Toleranslı** | %65 | İksir süreleri %20 kısalır |
| 61-80 | **Bağımlı** | %45 | Overdose riski aktif |
| 81-100 | **Kritik** | %25 | Yüksek overdose riski |

### 2.2 Tolerance Artışı (İksir Bazlı)

PLAN_01'deki mevcut `tolerance_increase` değerleri:

| İksir Tipi | Tolerance Artışı | Baz Overdose Riski |
|-----------|-----------------|-------------------|
| Minor HP Potion | +1 | %0 |
| Lesser HP Potion | +2 | %0 |
| HP Potion | +3 | %1 |
| Greater HP Potion | +5 | %3 |
| Superior HP Potion | +8 | %5 |
| Suprema HP Potion | +12 | %8 |
| ATK Buff Potion | +5 | %3 |
| DEF Buff Potion | +5 | %3 |
| Crit Buff Potion | +8 | %5 |
| Luck Buff Potion | +10 | %5 |
| Berserker Tonik (kaçak) | +25 | %20 |
| Shadow Elixir (kaçak) | +10 | %5 |
| Güçlendirilmiş İksir (kaçak) | +15 | %10 |

### 2.3 Etkinlik Formülü

```
effective_heal = base_heal × potion_efficiency(tolerance)
effective_buff = base_buff × potion_efficiency(tolerance)

potion_efficiency(tol) =
  tol <= 20  → 1.00
  tol <= 40  → 0.85
  tol <= 60  → 0.65
  tol <= 80  → 0.45
  tol <= 100 → 0.25
```

Pratik etki: Suprema HP Potion (20,000 HP) → tolerance 70'te sadece 9,000 HP iyileştirir.

---

## 3. Overdose Sistemi

### 3.1 Overdose Olasılığı

Her iksir kullanımında overdose kontrolü yapılır:

```
overdose_chance = item.overdose_risk × tolerance_multiplier(tolerance)

tolerance_multiplier(tol) =
  tol <= 40  → 0.0  (overdose imkansız)
  tol <= 60  → 1.0
  tol <= 80  → 2.0
  tol <= 90  → 4.0
  tol <= 100 → 8.0
```

**Örnek hesaplama:**
- Greater HP Potion (overdose_risk: 0.03) + tolerance 75 → 0.03 × 2.0 = **%6 overdose şansı**
- Suprema HP Potion (overdose_risk: 0.08) + tolerance 90 → 0.08 × 4.0 = **%32 overdose şansı!**
- Berserker Tonik (overdose_risk: 0.20) + tolerance 85 → 0.20 × 4.0 = **%80 overdose!!**

### 3.2 Overdose Sonuçları

Overdose gerçekleştiğinde:

| Sonuç | Etki |
|-------|------|
| **Hastaneye düşme** | PLAN_04 hospital sistemi, 30 dk - 4 saat |
| **HP = %10'a düşer** | Anlık HP kaybı |
| **Tüm aktif buff'lar iptal** | Buff süresi sıfırlanır |
| **Tolerance +10 ek artış** | Zaten yüksek tolerance daha da artar |
| **Addiction level +1** | Bağımlılık seviyesi artar (kalıcı-ish etki) |
| **Gold kaybı** | Hastane masrafı: power × 10 gold |

### 3.3 Overdose Hastane Süresi

```
overdose_hospital_minutes = 30 + (tolerance × 2)
```

| Tolerance | Hastane Süresi |
|-----------|---------------|
| 50 | 130 dk (2.2 saat) |
| 70 | 170 dk (2.8 saat) |
| 85 | 200 dk (3.3 saat) |
| 100 | 230 dk (3.8 saat) |

---

## 4. Bağımlılık Sistemi (Addiction Level)

### 4.1 Addiction Level (0-10)

Addiction level, uzun süreli iksir alışkanlığının etkisidir:

| Addiction Level | Etki |
|----------------|------|
| 0 | Normal |
| 1-2 | Hafif huzursuzluk |
| 3-4 | Çekme belirtileri |
| 5-6 | Şiddetli çekme: ATK %5 düşüş |
| 7-8 | Ağır bağımlılık: ATK/DEF %10 düşüş |
| 9-10 | Kritik bağımlılık: tüm stat'lar %15 düşüş |

### 4.2 Addiction Artışı

```
Her overdose → addiction_level += 1
Detox Supreme kullanımı → addiction_level -= 2
```

### 4.3 Çekme Belirtileri (Withdrawal)

Addiction level 3+ olan oyuncu **24 saat iksir kullanmazsa**:

| Belirti | Etki |
|---------|------|
| Titreme | Zindan başarı oranı -%5 |
| Konsantrasyon kaybı | Crafting başarı oranı -%5 |
| Huzursuzluk | PvP damage -%10 |

**İksir kullanınca:** Belirtiler anında geçer (ama tolerance artar → kısır döngü)

---

## 5. Detox Sistemi

### 5.1 Detox İçecekleri

**Sadece Mekan'dan satın alınabilir** (PLAN_07). NPC dükkanında YOK.

| Detox İçecek | Tolerance Azaltma | Addiction Etkisi | Craft Maliyeti | Mekan Satış Fiyatı |
|-------------|------------------|-----------------|---------------|-------------------|
| Minor Detox Drink | -15 tolerance | — | 50,000 | 75K - 250K |
| Major Detox Drink | -35 tolerance | -1 addiction | 200,000 | 300K - 1M |
| Supreme Detox Drink | -60 tolerance | -2 addiction | 500,000 | 750K - 2.5M |
| Full Cleanse Elixir | tolerance → 0 | addiction → 0 | 2,000,000 | 3M - 10M |

### 5.2 Detox Bekleme Süresi (Cooldown)

- Minor Detox: 4 saat cooldown
- Major Detox: 8 saat cooldown
- Supreme Detox: 12 saat cooldown
- Full Cleanse: 24 saat cooldown (günde 1)

### 5.3 Doğal İyileşme Yok

Tolerance ve addiction değerleri **zamanla kendiliğinden düşmez**. Yalnızca şu yollarla azalır:
- **Detox itemları** (bkz. §5.1 tablosu) — sadece Mekan/Han'da satılır
- **Full Cleanse Elixir** — tolerance ve addiction'ı tamamen sıfırlar
- Zamanla otomatik iyileşme **kaldırılmıştır**; oyuncu detox almadan temizlenemez.

Bu tasarım Han/Mekan trafiğini artırır ve enerji kıtlığı + detox maliyeti kombinasyonunu ana sınırlayıcı olarak kullanır.

---

## 6. Stratejik Derinlik

### 6.1 Oyuncu Kararları

```
İksir kullanmak → Zindan daha kolay → Ama tolerance artar → İksir daha az etkili
  → Daha güçlü iksir kullan → Tolerance daha hızlı artar → Overdose riski
    → Overdose → Hastane (zaman kaybı) + Addiction artışı
      → Detox al (Mekan'dan, gold harcaması)
        → Temizlen → Tekrar iksir kullanmaya başla → Döngü
```

### 6.2 Optimal Stratejiler

| Strateji | Hedef | Tolerance Yönetimi |
|----------|-------|-------------------|
| **Temiz Savaşçı** | İksir kullanmadan zindan | Tolerance 0, ama ekipman çok güçlü olmalı |
| **Kontrollü Kullanıcı** | Sadece büyük boss'larda iksir | Tolerance 20-40 arası kalır, haftalık Minor Detox |
| **Aktif Kullanıcı** | Her zindanda 1-2 iksir | Tolerance 40-60, günlük Major Detox gerekir |
| **Aşırı Kullanıcı** | Max DPS, risk toleransı yüksek | Tolerance 60-80, sık overdose riski, günlük Supreme Detox |
| **Berserker** | Kaçak madde + max damage | Tolerance 80+, sık overdose, Full Cleanse zorunlu |

### 6.3 Ekonomik Etki

Tolerance sistemi önemli bir **gold sink** oluşturur:

| Oyuncu Tipi | Aylık Detox Harcaması |
|-------------|---------------------|
| Kontrollü | ~500K - 2M |
| Aktif | ~5M - 15M |
| Aşırı | ~20M - 50M |
| Berserker | ~50M - 150M |

---

## 7. Veritabanı Güncellemeleri

### 7.1 Mevcut Sütunlar (Güncelleme Gerekmez)

```sql
-- game.users tablosunda zaten var:
-- tolerance int DEFAULT 0        -- 0-100
-- addiction_level int DEFAULT 0   -- 0-10

-- public.items tablosunda zaten var:
-- tolerance_increase int          -- iksirin tolerance artışı
-- overdose_risk numeric           -- baz overdose olasılığı
```

### 7.2 Yeni Sütunlar (Önerilen)

```sql
ALTER TABLE game.users ADD COLUMN IF NOT EXISTS
  last_potion_used_at timestamptz;  -- çekme belirtisi hesaplama

ALTER TABLE game.users ADD COLUMN IF NOT EXISTS
  last_detox_used_at timestamptz;   -- detox cooldown

ALTER TABLE game.users ADD COLUMN IF NOT EXISTS
  detox_type_last text;             -- son kullanılan detox tipi (cooldown tracking)
```

### 7.3 `game.tolerance_log` Tablosu (Analitik)

```sql
CREATE TABLE game.tolerance_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES game.users(id) NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('potion_use', 'overdose', 'detox')),
  item_id text,
  tolerance_before int NOT NULL,
  tolerance_after int NOT NULL,
  addiction_before int NOT NULL,
  addiction_after int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

---

## 8. RPC Fonksiyonları (Önerilen)

### 8.1 İksir Kullanımı (Tolerance Entegrasyonu)

```sql
CREATE FUNCTION public.use_potion(p_user_id uuid, p_item_id text)
RETURNS json AS $$
DECLARE
  v_item record;
  v_user record;
  v_new_tolerance int;
  v_overdose boolean := false;
  v_efficiency numeric;
  v_overdose_chance numeric;
  v_roll numeric;
BEGIN
  -- Item bilgisi
  SELECT * INTO v_item FROM public.items WHERE item_id = p_item_id;
  IF NOT FOUND OR v_item.item_type != 'potion' THEN
    RETURN json_build_object('success', false, 'error', 'Geçersiz iksir');
  END IF;

  -- Kullanıcı bilgisi
  SELECT * INTO v_user FROM game.users WHERE id = p_user_id;

  -- Envanterde var mı?
  IF NOT EXISTS (
    SELECT 1 FROM game.inventory
    WHERE user_id = p_user_id AND item_id = p_item_id AND quantity > 0
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Envanterde yok');
  END IF;

  -- Tolerance artışı
  v_new_tolerance := LEAST(v_user.tolerance + v_item.tolerance_increase, 100);

  -- Etkinlik hesaplama
  v_efficiency := CASE
    WHEN v_user.tolerance <= 20 THEN 1.0
    WHEN v_user.tolerance <= 40 THEN 0.85
    WHEN v_user.tolerance <= 60 THEN 0.65
    WHEN v_user.tolerance <= 80 THEN 0.45
    ELSE 0.25
  END;

  -- Overdose kontrolü
  v_overdose_chance := v_item.overdose_risk * CASE
    WHEN v_user.tolerance <= 40 THEN 0.0
    WHEN v_user.tolerance <= 60 THEN 1.0
    WHEN v_user.tolerance <= 80 THEN 2.0
    WHEN v_user.tolerance <= 90 THEN 4.0
    ELSE 8.0
  END;

  v_roll := random();
  IF v_roll < v_overdose_chance THEN
    v_overdose := true;
  END IF;

  -- Tolerance güncelle
  UPDATE game.users
  SET tolerance = v_new_tolerance,
      last_potion_used_at = now()
  WHERE id = p_user_id;

  -- Envanterden düş
  UPDATE game.inventory
  SET quantity = quantity - 1
  WHERE user_id = p_user_id AND item_id = p_item_id;

  -- Overdose ise hastaneye gönder
  IF v_overdose THEN
    UPDATE game.users
    SET addiction_level = LEAST(addiction_level + 1, 10),
        tolerance = LEAST(v_new_tolerance + 10, 100),
        hospital_until = now() + ((30 + v_new_tolerance * 2) || ' minutes')::interval,
        hospital_reason = 'overdose'
    WHERE id = p_user_id;

    -- Log
    INSERT INTO game.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
    VALUES (p_user_id, 'overdose', p_item_id, v_user.tolerance, LEAST(v_new_tolerance + 10, 100), v_user.addiction_level, LEAST(v_user.addiction_level + 1, 10));

    RETURN json_build_object(
      'success', true,
      'overdose', true,
      'hospital_minutes', 30 + v_new_tolerance * 2,
      'efficiency', 0
    );
  END IF;

  -- Normal kullanım logu
  INSERT INTO game.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
  VALUES (p_user_id, 'potion_use', p_item_id, v_user.tolerance, v_new_tolerance, v_user.addiction_level, v_user.addiction_level);

  RETURN json_build_object(
    'success', true,
    'overdose', false,
    'efficiency', v_efficiency,
    'new_tolerance', v_new_tolerance,
    'heal_amount', FLOOR(COALESCE(v_item.heal_amount, 0) * v_efficiency)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 8.2 Detox Kullanımı

```sql
CREATE FUNCTION public.use_detox(p_user_id uuid, p_detox_type text)
RETURNS json AS $$
DECLARE
  v_user record;
  v_tolerance_reduction int;
  v_addiction_reduction int;
  v_cooldown_hours int;
  v_new_tolerance int;
  v_new_addiction int;
BEGIN
  SELECT * INTO v_user FROM game.users WHERE id = p_user_id;

  -- Detox tipi kontrolü
  SELECT
    CASE p_detox_type
      WHEN 'minor' THEN 15
      WHEN 'major' THEN 35
      WHEN 'supreme' THEN 60
      WHEN 'full_cleanse' THEN 100
    END,
    CASE p_detox_type
      WHEN 'minor' THEN 0
      WHEN 'major' THEN 1
      WHEN 'supreme' THEN 2
      WHEN 'full_cleanse' THEN 10
    END,
    CASE p_detox_type
      WHEN 'minor' THEN 4
      WHEN 'major' THEN 8
      WHEN 'supreme' THEN 12
      WHEN 'full_cleanse' THEN 24
    END
  INTO v_tolerance_reduction, v_addiction_reduction, v_cooldown_hours;

  -- Cooldown kontrolü
  IF v_user.last_detox_used_at IS NOT NULL
     AND v_user.last_detox_used_at + (v_cooldown_hours || ' hours')::interval > now() THEN
    RETURN json_build_object('success', false, 'error', 'Detox cooldown aktif');
  END IF;

  -- Envanter kontrolü (detox item_id format: detox_minor, detox_major, etc.)
  IF NOT EXISTS (
    SELECT 1 FROM game.inventory
    WHERE user_id = p_user_id AND item_id = 'detox_' || p_detox_type AND quantity > 0
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Detox içeceğiniz yok');
  END IF;

  v_new_tolerance := GREATEST(v_user.tolerance - v_tolerance_reduction, 0);
  v_new_addiction := GREATEST(v_user.addiction_level - v_addiction_reduction, 0);

  -- Güncelle
  UPDATE game.users
  SET tolerance = v_new_tolerance,
      addiction_level = v_new_addiction,
      last_detox_used_at = now(),
      detox_type_last = p_detox_type
  WHERE id = p_user_id;

  -- Envanterden düş
  UPDATE game.inventory
  SET quantity = quantity - 1
  WHERE user_id = p_user_id AND item_id = 'detox_' || p_detox_type;

  -- Log
  INSERT INTO game.tolerance_log (user_id, event_type, item_id, tolerance_before, tolerance_after, addiction_before, addiction_after)
  VALUES (p_user_id, 'detox', 'detox_' || p_detox_type, v_user.tolerance, v_new_tolerance, v_user.addiction_level, v_new_addiction);

  RETURN json_build_object(
    'success', true,
    'new_tolerance', v_new_tolerance,
    'new_addiction', v_new_addiction
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 9. TypeScript Tipleri

```typescript
export interface ToleranceState {
  tolerance: number;        // 0-100
  addiction_level: number;  // 0-10
  last_potion_used_at: string | null;
  last_detox_used_at: string | null;
  detox_type_last: string | null;
}

export type ToleranceRange = 'clean' | 'accustomed' | 'tolerant' | 'addicted' | 'critical';

export function getToleranceRange(tolerance: number): ToleranceRange {
  if (tolerance <= 20) return 'clean';
  if (tolerance <= 40) return 'accustomed';
  if (tolerance <= 60) return 'tolerant';
  if (tolerance <= 80) return 'addicted';
  return 'critical';
}

export function getPotionEfficiency(tolerance: number): number {
  if (tolerance <= 20) return 1.0;
  if (tolerance <= 40) return 0.85;
  if (tolerance <= 60) return 0.65;
  if (tolerance <= 80) return 0.45;
  return 0.25;
}

export interface PotionUseResult {
  success: boolean;
  overdose: boolean;
  efficiency: number;
  new_tolerance: number;
  heal_amount?: number;
  hospital_minutes?: number;
  error?: string;
}

export interface DetoxResult {
  success: boolean;
  new_tolerance: number;
  new_addiction: number;
  error?: string;
}

export type DetoxType = 'minor' | 'major' | 'supreme' | 'full_cleanse';

export const DETOX_ITEMS: Record<DetoxType, { tolerance_reduction: number; addiction_reduction: number; cooldown_hours: number }> = {
  minor:        { tolerance_reduction: 15, addiction_reduction: 0, cooldown_hours: 4 },
  major:        { tolerance_reduction: 35, addiction_reduction: 1, cooldown_hours: 8 },
  supreme:      { tolerance_reduction: 60, addiction_reduction: 2, cooldown_hours: 12 },
  full_cleanse: { tolerance_reduction: 100, addiction_reduction: 10, cooldown_hours: 24 },
};
```

---

## 10. UI Bileşenleri (Önerilen)

### 10.1 Tolerance Bar (HUD)

Her zaman görünür, profile yakın:
```
[████████░░] 72/100 — Bağımlı
 🔴 Overdose riski aktif!
```

### 10.2 İksir Kullanım Uyarıları

| Tolerance | Uyarı |
|-----------|-------|
| 0-40 | Yeşil: "Güvenli" |
| 41-60 | Sarı: "Tolerans yükseliyor — iksir etkinliği %65" |
| 61-80 | Turuncu: "DİKKAT: Overdose riski aktif! Etkinlik %45" |
| 81-100 | Kırmızı: "TEHLİKE: Yüksek overdose riski! Etkinlik %25" |

### 10.3 Sayfalar

| Sayfa | Konum | İçerik |
|-------|-------|--------|
| Tolerance Detay | Profil → Tolerance sekmesi | Tam tolerance/addiction bilgisi, geçmiş log |
| İksir Kullanma | Envanter → İksir tıklama | Onay diyalogu: etkinlik, overdose riski gösterimi |
| Detox Mağaza | Mekan Detay → Detox sekmesi | Detox alım, cooldown timer |

---

## 11. Denge Analizi

### 11.1 Tipik Zindan Senaryosu

Bir oyuncu Zone 5 Boss (#45) ile savaşırken:

```
Ekipman power: 280,000 (Legendary +5)
Boss power req: 300,000
Fark: -20,000 → başarı oranı düşük (%35)

İksir öncesi:
- Tolerance: 55 (Toleranslı)
- Suprema HP Potion etkinliği: %65 → 13,000 HP iyileşme (baz 20,000)
- ATK Buff etkinliği: %65 → +6,500 ATK (baz +10,000)
- Overdose riski: 0.08 × 1.0 = %8

İksir kullanımı sonrası:
- Tolerance: 55 + 12 = 67 (Bağımlı aralığa geçti!)
- Bir sonraki iksir: etkinlik %45, overdose çarpanı 2×

Karar: İkinci iksir kullanmak mı yoksa %35 başarıyla denemek mi?
```

### 11.2 Aylık Tolerance Yönetim Maliyeti

| Oyun Aşaması | Aylık İksir Kullanımı | Tolerance Yönetimi | Aylık Detox Maliyeti |
|-------------|---------------------|-------------------|---------------------|
| Erken (Ay 1) | 20-30 iksir | Tolerance 20-30, haftalık minor detox | ~500K |
| Orta (Ay 3-5) | 50-80 iksir | Tolerance 40-50, hergün major detox | ~10M |
| Geç (Ay 7-9) | 80-120 iksir | Tolerance 50-70, günlük supreme detox | ~30M |
| End-game (Ay 10-12) | 100+ iksir | Tolerance 60-80, sık full cleanse | ~60M |

> **PLAN_06 tutarlılık:** End-game aylık detox maliyeti ~60M, toplam iksir+detox ~100M/ay → PLAN_06'daki toplam gelire göre %1-3 oranında (kabul edilebilir gold sink)

---

## 12. Çapraz Sistem Etkileşimleri

| Sistem | Etkileşim |
|--------|-----------|
| **PLAN_04 Zindan** | Overdose → hastane (hospital_until güncellenir) |
| **PLAN_07 Mekan** | Detox SADECE Mekan'da satılır → Mekan trafiği artırır |
| **PLAN_09 PvP** | Addiction 3+: çekme belirtileri PvP damage %10 düşürür |
| **PLAN_05 Enhancement** | Tolerance etkinlik kaybı, enhancement yerine iksir bağımlılığı → alternatif güçlenme |
| **PLAN_06 Ekonomi** | Detox = önemli gold sink ($500K - $150M/ay arası) |
| **PLAN_10 Anıt** | Anıt Lv 80: overdose'dan ilk kurtulma (günde 1 kez) bonusu |

---

## 13. Uygulama Öncelikleri

1. **Faz 1:** `use_potion` RPC'yi tolerance entegrasyonuyla güncelle
2. **Faz 2:** Tolerance bar UI bileşeni (HUD)
3. **Faz 3:** Overdose → hastane entegrasyonu (PLAN_04 hospital sistemiyle)
4. **Faz 4:** Detox item'ları oluştur (items seed data)
5. **Faz 5:** `use_detox` RPC + Mekan entegrasyonu (PLAN_07)
6. **Faz 6:** Addiction çekme belirtileri (stat debuff'lar)
7. **Faz 7:** tolerance_log tablosu + analitik dashboard

---

*Bu belge PLAN_04 (hastane — overdose sonucu), PLAN_07 (Mekan — detox satışı) ve PLAN_01 (iksir verileri: tolerance_increase, overdose_risk) ile entegredir.*
