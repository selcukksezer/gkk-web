# PLAN 11 — Karakter Sınıfı & Stat Sistemi (Character Class & Stat System)

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** PLAN_01 (item stats), PLAN_04 (dungeon), PLAN_06 (ekonomi/power), PLAN_08 (tolerans), PLAN_09 (PvP), PLAN_02 (tesisler)  
> **Kapsam:** 3 karakter sınıfı seçimi, sınıfa özgü stat bonusları, stat sistemi (attack/defense/health/luck), tüm sınıflar için evrensel item erişimi  
> **Önemli:** Karakter statları **hem PvP hem zindan** sisteminde geçerlidir (bkz. §3.1 ve §9.1). MASTER_GAMEPLAN.md §1.4 kanonik stat etki tablosuna başvurun.

---

## 1. Genel Bakış

Oyuna başlayan her oyuncuya **3 farklı karakter sınıfı** sunulur. Oyuncu yalnızca 1 tanesini seçer ve sezon boyunca o sınıfla oynar. Sezon sıfırlandığında yeniden seçim yapılabilir.

**Temel kurallar:**
- Tüm sınıflar **tüm itemleri** kullanabilir — sınıf kısıtlaması yoktur
- Her sınıfın farklı **baz statları** vardır (attack, defense, health, luck)
- Her sınıfın oyun mekaniğine entegre **pasif bufları** vardır
- Sınıf seçimi `character_class` alanına kaydedilir; sonradan değiştirilemez (sezon başı hariç)
- `luck` stat sisteme resmi olarak eklenmektedir; PLAN_01 ve PLAN_09'da referans alınıyordu, artık DB şemasında tanımlanmaktadır

---

## 2. Karakter Sınıfları

### 2.1 🗡️ Savaşçı (Warrior)

**Kimliği:** Yeraltı dünyasının sert dövüşçüsü. Han'ın en güçlü PvP oyuncusu.

**Baz Statlar (Level 1 başlangıç):**
| Stat | Savaşçı | Açıklama |
|------|---------|---------|
| Attack | 18 | En yüksek başlangıç saldırısı |
| Defense | 12 | Ortalama savunma |
| Health | 120 | Ortalama can |
| Max Health | 120 | — |
| Luck | 5 | Düşük şans |

**Pasif Bonuslar:**
| Bonus | Değer | Etkilenen Sistem |
|-------|-------|-----------------|
| PvP hasar artışı | +20% | PLAN_09 PvP |
| Boss hasar artışı | +15% | PLAN_04 Zindan |
| PvP kritik şans | +10% (luck üstüne) | PLAN_09 PvP |
| Zindan başarı oranı | +5% (ek bonus) | PLAN_04 Zindan |
| Hastane süresi azalma | -20% | PLAN_04 Hastane |

**Sınıf Özelliği:** "Kan Hırsı" — PvP kazandıktan sonra 30 dk boyunca attack %10 artar (üst üste 3 kazanımda %20'ye çıkar).

---

### 2.2 ⚗️ Simyacı (Alchemist)

**Kimliği:** İksirlerin ve formüllerin efendisi. Crafting ve üretim odaklı oyuncunun tercihi.

**Baz Statlar (Level 1 başlangıç):**
| Stat | Simyacı | Açıklama |
|------|---------|---------|
| Attack | 10 | Düşük saldırı |
| Defense | 12 | Ortalama savunma |
| Health | 140 | En yüksek başlangıç canı |
| Max Health | 140 | — |
| Luck | 12 | Yüksek şans |

**Pasif Bonuslar:**
| Bonus | Değer | Etkilenen Sistem |
|-------|-------|-----------------|
| İksir etkinliği | +30% | PLAN_08 Tolerans |
| Tolerans artış hızı | -25% | PLAN_08 Tolerans |
| Overdose şansı | -20% | PLAN_08 Tolerans |
| Crafting başarı oranı | +15% | PLAN_03 Crafting |
| Han-only item craft süresi | -20% | PLAN_07 Han |
| Detox etkinliği | +25% | PLAN_08 Tolerans |

**Sınıf Özelliği:** "Formül Ustası" — Her gün 1 adet ücretsiz Minor Detox Drink üretme hakkı (craft malzemesi gerekmez, Han'a eklenmez — kişisel kullanım).

---

### 2.3 🌑 Gölge (Shadow)

**Kimliği:** Şüphe altında faaliyet gösteren, gizliliği ve kaçınmayı benimseyen karakter.

**Baz Statlar (Level 1 başlangıç):**
| Stat | Gölge | Açıklama |
|------|-------|---------|
| Attack | 12 | Ortalama saldırı |
| Defense | 10 | Düşük savunma |
| Health | 110 | Düşük can |
| Max Health | 110 | — |
| Luck | 18 | En yüksek şans |

**Pasif Bonuslar:**
| Bonus | Değer | Etkilenen Sistem |
|-------|-------|-----------------|
| Tesis şüphe artış hızı | -30% | PLAN_02 Tesisler |
| Rüşvet maliyeti | -25% | PLAN_02 Tesisler |
| Hapishaneden kaçış şansı | +20% | PLAN_04 Hapishane |
| Zindan loot luck bonus | +40% | PLAN_04 Zindan |
| PvP dodge (kaçınma) | +15% | PLAN_09 PvP |
| Kaçak ticaret ceza riski | -20% | PLAN_07 Mekan |

**Sınıf Özelliği:** "Hayalet Adımlar" — Global suspicion level maksimumdan %100'den yavaş artar; 100'e ulaştığında %80 olarak sayılır (etkin tavan 80).

---

## 3. Stat Sistemi

### 3.1 Statlar ve Tanımları

| Stat | Sütun | Tür | Açıklama |
|------|-------|-----|---------|
| **Attack** | `attack` | `integer` | Saldırı gücü; **hem zindan hem PvP** hasarını belirler |
| **Defense** | `defense` | `integer` | Savunma gücü; hem zindan hastane süresini hem PvP hasarını azaltır |
| **Health** | `health` | `integer` | Mevcut can puanı; zindan/PvP hayatta kalma kapasitesi |
| **Max Health** | `max_health` | `integer` | Maksimum can puanı |
| **Luck** | `luck` | `integer` | Şans; zindan başarı/loot, PvP kritik/dodge |
| **Power** | `power` | `integer` | Hesaplanan toplam güç (formülle) |

> **Zindan stat entegrasyonu (PLAN_04 §4.1 ile tutarlı):**  
> - `attack` → Boss loot ödülü modifiyeri (Savaşçı: ×1.15)  
> - `defense` → Hastane süresi azaltma: `× (1 - defense×0.001)`, max %30  
> - `luck` → Zindan başarı `+luck×0.001`, loot multiplier `× (1+luck×0.002)`  
> - `health` → Hayatta kalma kapasitesi (loot/animasyon için kozmetik)

### 3.2 Stat Büyüme (Level Başına)

Her sınıfın level atladığında kazandığı stat büyümesi:

| Stat | Savaşçı | Simyacı | Gölge |
|------|---------|---------|-------|
| Attack | +3 | +1 | +2 |
| Defense | +2 | +2 | +1 |
| Health | +15 | +20 | +12 |
| Luck | +1 | +2 | +3 |

**Örnek:** Level 70 Savaşçı baz statları (Level 1 baz stat + büyüme formülü):
```
-- Level 1 baz statlardan başlanır; level 1 → level N için: baz + (N-1) × büyüme
Attack:  18 + (70-1) × 3 = 18 + 207 = 225  (+ ekipman)
Defense: 12 + (70-1) × 2 = 12 + 138 = 150  (+ ekipman)
Health:  120 + (70-1) × 15 = 120 + 1035 = 1155 (+ ekipman)
Luck:    5 + (70-1) × 1 = 5 + 69 = 74
```

> **Not:** Baz statlar, ekipman istatistiklerinden (×100-×1000 ölçek) çok küçüktür. Ekipman asıl güç kaynağıdır. Sınıf statları **yönlendirici** olup orantısal fark yaratır (% bazlı pasif bonuslar kritiktir).

### 3.3 Luck Stat Etkileri

`luck` statı aşağıdaki formüllerde kullanılır (mevcut PLAN belgelerindeki değerlere eklenir):

| Etki | Formül |
|------|--------|
| Zindan başarı bonus | `+luck × 0.001` (max +5%) |
| Zindan gold loot | `× (1 + luck × 0.002)` |
| Zindan XP bonus | `× (1 + luck × 0.001)` |
| Kritik vuruş (PvP) | `random() < (luck × 0.002)` |
| Kaçınma (PvP) | `random() < (luck × 0.001)` |
| Hastane riski azalma | `× (1 - luck × 0.003)` |
| Enhancement loot kalite | luck bonus (enhancement drop rate) |

---

## 4. Karakter Seçim Akışı (Onboarding)

### 4.1 Akış Adımları

```
Yeni Oyuncu Kaydı (Auth)
  ↓
Tutorial Başlangıcı
  ↓
Karakter Seçim Ekranı (3 kart)
  [Savaşçı]    [Simyacı]    [Gölge]
  ATK:18        ATK:10       ATK:12
  DEF:12        DEF:12       DEF:10
  HP:120        HP:140       HP:110
  LUCK:5        LUCK:12      LUCK:18
  
  "PvP & Boss   "İksir &     "Gizli Ops &
   uzmanı"       Craft"       Şans"
  ↓ Seçim
  
select_character_class RPC çağrısı
  ↓
users tablosu güncelleme
  (character_class, luck, attack, defense, health, max_health)
  ↓
Tutorial devam
  ↓
Oyun başlangıcı
```

### 4.2 Seçim Sonrası Kısıtlamalar

- Seçim **bir kez** yapılır; sezon başında sıfırlanabilir
- Seçim sonrası `class_selected_at` zaman damgası kaydedilir
- Yanlış seçim için grace period: **kayıt sonrası 30 dakika** (yeniden seçim yapılabilir)

---

## 5. Veritabanı Şeması

### 5.1 `users` Tablosuna Eklenen Alanlar

```sql
-- Karakter sınıfı ve luck stat eklentileri
-- Not: luck DEFAULT 0 → sınıf seçmemiş kullanıcılar için 0 kalır.
-- character_class NULL ise oyuncu henüz sınıf seçmemiştir.
-- Sistem, character_class NULL olan kullanıcılarda pasif bonus uygulamaz.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS character_class text
    CHECK (character_class IN ('warrior', 'alchemist', 'shadow')),
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS class_selected_at timestamptz;

-- items tablosuna luck eklentisi
ALTER TABLE public.items
  ADD COLUMN IF NOT EXISTS luck integer NOT NULL DEFAULT 0;
```

### 5.2 `character_classes` Referans Tablosu (Seed Data)

```sql
CREATE TABLE IF NOT EXISTS public.character_classes (
  id text PRIMARY KEY,                    -- 'warrior', 'alchemist', 'shadow'
  name_tr text NOT NULL,                  -- 'Savaşçı'
  name_en text NOT NULL,                  -- 'Warrior'
  description_tr text,
  
  -- Baz statlar (Level 1)
  base_attack integer NOT NULL DEFAULT 10,
  base_defense integer NOT NULL DEFAULT 10,
  base_health integer NOT NULL DEFAULT 100,
  base_luck integer NOT NULL DEFAULT 0,
  
  -- Level başına büyüme
  attack_per_level integer NOT NULL DEFAULT 2,
  defense_per_level integer NOT NULL DEFAULT 2,
  health_per_level integer NOT NULL DEFAULT 15,
  luck_per_level integer NOT NULL DEFAULT 1,
  
  -- Pasif bonus multiplier'ları (JSONB)
  passive_bonuses jsonb NOT NULL DEFAULT '{}',
  
  -- Görsel
  icon_url text,
  color_hex text,
  
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Seed data
INSERT INTO public.character_classes VALUES
  (
    'warrior', 'Savaşçı', 'Warrior',
    'Yeraltı dünyasının sert dövüşçüsü. PvP ve boss uzmanı.',
    18, 12, 120, 5,
    3, 2, 15, 1,
    '{
      "pvp_damage_bonus": 0.20,
      "boss_damage_bonus": 0.15,
      "pvp_crit_bonus": 0.10,
      "dungeon_success_bonus": 0.05,
      "hospital_duration_reduction": 0.20
    }',
    NULL, '#E53935'
  ),
  (
    'alchemist', 'Simyacı', 'Alchemist',
    'İksirlerin ve formüllerin efendisi. Crafting odaklı.',
    10, 12, 140, 12,
    1, 2, 20, 2,
    '{
      "potion_effectiveness_bonus": 0.30,
      "tolerance_increase_reduction": 0.25,
      "overdose_chance_reduction": 0.20,
      "crafting_success_bonus": 0.15,
      "han_craft_time_reduction": 0.20,
      "detox_effectiveness_bonus": 0.25
    }',
    NULL, '#7B1FA2'
  ),
  (
    'shadow', 'Gölge', 'Shadow',
    'Şüphe altında faaliyet gösteren gizli operatör.',
    12, 10, 110, 18,
    2, 1, 12, 3,
    '{
      "facility_suspicion_reduction": 0.30,
      "bribe_cost_reduction": 0.25,
      "prison_escape_bonus": 0.20,
      "loot_luck_bonus": 0.40,
      "pvp_dodge_bonus": 0.15,
      "black_market_risk_reduction": 0.20
    }',
    NULL, '#212121'
  )
ON CONFLICT (id) DO UPDATE SET
  passive_bonuses = EXCLUDED.passive_bonuses;
```

### 5.3 Karakter Seçim RPC

```sql
CREATE OR REPLACE FUNCTION public.select_character_class(
  p_class_id text
)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user record;
  v_class record;
  v_grace_minutes integer := 30;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Sınıf geçerliliğini kontrol et
  SELECT * INTO v_class FROM public.character_classes WHERE id = p_class_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Geçersiz sınıf: ' || p_class_id);
  END IF;

  -- Mevcut kullanıcı bilgisini al
  SELECT * INTO v_user FROM public.users WHERE auth_id = v_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;

  -- Sınıf zaten seçilmiş mi ve grace period geçti mi?
  IF v_user.character_class IS NOT NULL
     AND v_user.class_selected_at IS NOT NULL
     AND v_user.class_selected_at < (now() - (v_grace_minutes || ' minutes')::interval) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Sınıf değiştirilemez. Grace period (' || v_grace_minutes || ' dk) dolmuş.',
      'selected_class', v_user.character_class,
      'selected_at', v_user.class_selected_at
    );
  END IF;

  -- Kullanıcıyı güncelle: sınıf statlarını uygula
  UPDATE public.users SET
    character_class     = p_class_id,
    class_selected_at   = now(),
    attack              = v_class.base_attack,
    defense             = v_class.base_defense,
    health              = v_class.base_health,
    max_health          = v_class.base_health,
    luck                = v_class.base_luck
  WHERE auth_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'class_id', p_class_id,
    'class_name', v_class.name_tr,
    'stats', jsonb_build_object(
      'attack', v_class.base_attack,
      'defense', v_class.base_defense,
      'health', v_class.base_health,
      'luck', v_class.base_luck
    ),
    'passive_bonuses', v_class.passive_bonuses
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.select_character_class(text) TO authenticated;
```

### 5.4 Karakter Sınıfları Sorgulama RPC

```sql
CREATE OR REPLACE FUNCTION public.get_character_classes()
RETURNS jsonb AS $$
BEGIN
  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'classes', jsonb_agg(
        jsonb_build_object(
          'id', id,
          'name_tr', name_tr,
          'name_en', name_en,
          'description_tr', description_tr,
          'base_stats', jsonb_build_object(
            'attack', base_attack,
            'defense', base_defense,
            'health', base_health,
            'luck', base_luck
          ),
          'growth', jsonb_build_object(
            'attack_per_level', attack_per_level,
            'defense_per_level', defense_per_level,
            'health_per_level', health_per_level,
            'luck_per_level', luck_per_level
          ),
          'passive_bonuses', passive_bonuses,
          'color_hex', color_hex,
          'icon_url', icon_url
        )
        ORDER BY id
      )
    )
    FROM public.character_classes
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_character_classes() TO anon, authenticated;
```

### 5.5 Level Atlama Stat Güncelleme (handle_level_up eklentisi)

```sql
-- Level atlama sırasında sınıfa göre stat artışı
-- Mevcut level-up mantığına entegre edilecek snippet:
CREATE OR REPLACE FUNCTION public.apply_level_up_stats(
  p_user_id uuid,
  p_new_level integer
) RETURNS void AS $$
DECLARE
  v_user record;
  v_class record;
  v_levels_gained integer;
BEGIN
  -- Kullanıcıyı al (level güncellenmeden ÖNCE çağrılmalıdır)
  SELECT * INTO v_user FROM public.users WHERE id = p_user_id;
  IF NOT FOUND OR v_user.character_class IS NULL THEN
    RETURN; -- Sınıf seçilmemişse güncelleme yapma
  END IF;

  -- Sınıf büyüme verilerini al
  SELECT * INTO v_class FROM public.character_classes WHERE id = v_user.character_class;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_levels_gained := p_new_level - v_user.level; -- mevcut level'dan fark (güncelleme öncesi)
  IF v_levels_gained <= 0 THEN
    RETURN;
  END IF;

  UPDATE public.users SET
    attack     = attack     + (v_class.attack_per_level  * v_levels_gained),
    defense    = defense    + (v_class.defense_per_level * v_levels_gained),
    max_health = max_health + (v_class.health_per_level  * v_levels_gained),
    health     = health     + (v_class.health_per_level  * v_levels_gained),
    luck       = luck       + (v_class.luck_per_level    * v_levels_gained),
    level      = p_new_level
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 6. TypeScript Tipleri

```typescript
export type CharacterClassId = 'warrior' | 'alchemist' | 'shadow';

export interface CharacterClass {
  id: CharacterClassId;
  name_tr: string;
  name_en: string;
  description_tr: string;
  base_stats: {
    attack: number;
    defense: number;
    health: number;
    luck: number;
  };
  growth: {
    attack_per_level: number;
    defense_per_level: number;
    health_per_level: number;
    luck_per_level: number;
  };
  passive_bonuses: Partial<PassiveBonuses>;
  color_hex: string;
  icon_url: string | null;
}

export interface PassiveBonuses {
  // Savaşçı
  pvp_damage_bonus: number;
  boss_damage_bonus: number;
  pvp_crit_bonus: number;
  dungeon_success_bonus: number;
  hospital_duration_reduction: number;
  // Simyacı
  potion_effectiveness_bonus: number;
  tolerance_increase_reduction: number;
  overdose_chance_reduction: number;
  crafting_success_bonus: number;
  han_craft_time_reduction: number;
  detox_effectiveness_bonus: number;
  // Gölge
  facility_suspicion_reduction: number;
  bribe_cost_reduction: number;
  prison_escape_bonus: number;
  loot_luck_bonus: number;
  pvp_dodge_bonus: number;
  black_market_risk_reduction: number;
}

export interface UserWithClass {
  // Mevcut alanlar
  id: string;
  username: string;
  level: number;
  gold: number;
  energy: number;
  attack: number;
  defense: number;
  health: number;
  max_health: number;
  power: number;
  // Yeni alanlar
  luck: number;
  character_class: CharacterClassId | null;
  class_selected_at: string | null;
}

// Pasif bonus sabitleri — modül seviyesinde tanımlanır (her çağrıda yeniden oluşturulmasın)
export const CLASS_BONUSES: Record<CharacterClassId, Partial<PassiveBonuses>> = {
  warrior: {
    pvp_damage_bonus: 0.20,
    boss_damage_bonus: 0.15,
    pvp_crit_bonus: 0.10,
    dungeon_success_bonus: 0.05,
    hospital_duration_reduction: 0.20,
  },
  alchemist: {
    potion_effectiveness_bonus: 0.30,
    tolerance_increase_reduction: 0.25,
    overdose_chance_reduction: 0.20,
    crafting_success_bonus: 0.15,
    han_craft_time_reduction: 0.20,
    detox_effectiveness_bonus: 0.25,
  },
  shadow: {
    facility_suspicion_reduction: 0.30,
    bribe_cost_reduction: 0.25,
    prison_escape_bonus: 0.20,
    loot_luck_bonus: 0.40,
    pvp_dodge_bonus: 0.15,
    black_market_risk_reduction: 0.20,
  },
};

// Pasif bonus hesaplama yardımcısı
export function getClassBonus(
  user: UserWithClass,
  bonusKey: keyof PassiveBonuses
): number {
  if (!user.character_class) return 0;
  return CLASS_BONUSES[user.character_class][bonusKey] ?? 0;
}
```

---

## 7. UI — Karakter Seçim Ekranı

### 7.1 Sayfa Yapısı

```
/game/onboarding/character-select
```

Üç büyük kart, yan yana:

```
┌─────────────────────────────────────────────────────────────┐
│           KARAKTERINI SEÇ                                    │
│    Sezon boyunca bu sınıfla oynayacaksın.                   │
│    Tüm karakterler tüm itemleri kullanabilir.               │
├──────────────────┬──────────────┬──────────────────────────-┤
│  🗡️ SAVAŞÇI     │ ⚗️ SİMYACI  │  🌑 GÖLGE               │
│  (Warrior)      │ (Alchemist) │  (Shadow)                 │
│                 │             │                             │
│  ATK: 18 ████  │  ATK: 10 ██ │  ATK: 12 ██               │
│  DEF: 12 ███   │  DEF: 12 ███│  DEF: 10 ██               │
│  HP:  120████  │  HP: 140 ████│  HP:  110 ███             │
│  LUCK: 5 █     │  LUCK: 12 ███│  LUCK: 18 █████           │
│                 │             │                             │
│  ✓ PvP +20%    │  ✓ İksir    │  ✓ Şüphe -30%             │
│  ✓ Boss +15%   │    +30%     │  ✓ Luck +40%              │
│  ✓ Hastane -20%│  ✓ Craft    │  ✓ PvP Dodge +15%         │
│                 │    +15%     │                             │
│  [SEÇ]         │  [SEÇ]      │  [SEÇ]                     │
└──────────────────┴──────────────┴──────────────────────────-┘
                   [Detaylar için tıkla]
```

### 7.2 Tooltip/Detay Ekranı

Her sınıfa tıklandığında açılan detay sayfası:
- Tüm pasif bonusların listesi
- Sınıf özelliği açıklaması (Kan Hırsı, Formül Ustası, Hayalet Adımlar)
- Level 70'deki beklenen baz statlar
- Hangi oyun stiline uygun olduğuna dair kısa açıklama
- "Bu sınıfı seç" butonu

### 7.3 Onay Diyalogu

```
"Savaşçı sınıfını seçmek üzeresin.
Bu seçim sezon boyunca geçerli olacak.
İlk 30 dakika içinde değiştirebilirsin.

[Onayla]  [Geri Dön]"
```

---

## 8. Güncellenen `get_current_user` RPC

`get_current_user` fonksiyonu yeni alanları içerecek şekilde güncellenmeli:

```sql
-- get_current_user fonksiyonuna eklenen alanlar:
'luck',             luck,
'character_class',  character_class,
'class_selected_at', class_selected_at,
'class_passive_bonuses', (
  SELECT cc.passive_bonuses
  FROM public.character_classes cc
  WHERE cc.id = u.character_class
)
```

---

## 9. Etkilenen Sistem Özetleri

### 9.1 PLAN_04 Zindan Sistemi (Değişiklikler)

> **Özet:** Karakter statları artık hem PvP'de hem zindanda geçerlidir. `enter_dungeon` RPC'ye aşağıdaki bloklar eklenmiştir (tam uygulama: PLAN_04 §4.1 ve §9.4).

```sql
-- enter_dungeon RPC — sınıf entegrasyon noktaları:

-- 1. Savaşçı: Zindan başarı oranı bonusu (+5%)
IF v_player.character_class = 'warrior' THEN
  v_success_rate := v_success_rate + 0.05;
END IF;
v_success_rate := LEAST(0.95, v_success_rate);

-- 2. Gölge: Tüm zindanlarda loot luck bonusu (×1.40)
IF v_player.character_class = 'shadow' THEN
  v_luck_for_loot := COALESCE(v_player.luck, 0) * 1.40;
  v_gold := floor(v_gold * (1 + v_luck_for_loot * 0.002));
END IF;

-- 3. Savaşçı: Boss gold bonusu (+15%) — boss hasarının gold karşılığı
IF v_player.character_class = 'warrior' AND v_dungeon.is_boss THEN
  v_gold := floor(v_gold * 1.15);
END IF;

-- 4. Defense bazlı hastane süresi azaltma (tüm sınıflar)
v_defense_mitigation := LEAST(0.30, COALESCE(v_player.defense, 0) * 0.001);
IF v_hospitalized THEN
  v_hospital_minutes := floor(v_hospital_minutes * (1 - v_defense_mitigation));
  -- Savaşçı ek indirim (-20%)
  IF v_player.character_class = 'warrior' THEN
    v_hospital_minutes := floor(v_hospital_minutes * 0.80);
  END IF;
END IF;
```

### 9.2 PLAN_08 Tolerans Sistemi (Değişiklikler)

```sql
-- use_potion RPC güncelleme noktaları:

-- 1. Simyacı: Tolerance artış azalma
v_tolerance_gain := v_item.tolerance_increase;
IF v_player.character_class = 'alchemist' THEN
  v_tolerance_gain := floor(v_tolerance_gain * 0.75); -- %25 azalma
END IF;

-- 2. Simyacı: Overdose şansı azalma
IF v_player.character_class = 'alchemist' THEN
  v_overdose_chance := v_overdose_chance * 0.80;
END IF;

-- 3. Simyacı: İksir etkinliği artışı
IF v_player.character_class = 'alchemist' THEN
  v_efficiency := LEAST(v_efficiency * 1.30, 1.0);
END IF;
```

### 9.3 PLAN_09 PvP Sistemi (Değişiklikler)

```sql
-- pvp_attack RPC güncelleme noktaları:

-- 1. Savaşçı: PvP hasar bonusu
IF v_attacker.character_class = 'warrior' THEN
  v_atk_dmg := v_atk_dmg * 1.20;
END IF;

-- 2. Gölge: PvP dodge bonusu
IF v_defender.character_class = 'shadow' THEN
  v_dodge_chance := COALESCE(v_defender.luck * 0.001, 0) + 0.15;
  IF random() < v_dodge_chance THEN
    v_atk_dmg := 0;
  END IF;
END IF;
```

### 9.4 PLAN_02 Tesis Sistemi (Değişiklikler)

```sql
-- increment_facility_suspicion RPC güncelleme noktaları:

-- Gölge: Şüphe artış azalma
IF v_player.character_class = 'shadow' THEN
  p_amount := floor(p_amount * 0.70); -- %30 azalma
END IF;
```

---

## 10. Power Formülü Güncellemesi

Luck, power formülüne katkı yapar (PLAN_06 §5.1 ile tutarlı):

```
total_power = (level × 500)
            + equipment_power           -- Σ(attack + defense + hp/10 + luck×2) per item
            + reputation × 0.1
            + character_luck_contribution  -- Yeni: baz luck × 50

character_luck_contribution = player.luck × 50
```

| Level 70 | Savaşçı | Simyacı | Gölge |
|----------|---------|---------|-------|
| Baz luck | 74 | 117 | 212 |
| Luck power katkısı | +3,700 | +5,850 | +10,600 |
| Toplam power farkı | ~1% | ~1.3% | ~2.4% |

> **Denge notu:** Luck power katkısı kasıtlı olarak küçük tutulmuştur. Gölge sınıfının avantajı doğrudan güçten değil, fırsat maliyeti azaltmasından (şüphe, rüşvet) gelir.

---

## 11. Uygulama Öncelikleri

1. **Faz 1:** DB Migration — `luck` ve `character_class` sütunları, `character_classes` tablosu, `select_character_class` RPC
2. **Faz 2:** `get_character_classes` RPC + `get_current_user` güncellemesi
3. **Faz 3:** Karakter seçim UI (onboarding/character-select sayfası)
4. **Faz 4:** Pasif bonus entegrasyonları — dungeon (`enter_dungeon`), tolerance (`use_potion`), PvP (`pvp_attack`)
5. **Faz 5:** Tesis şüphe entegrasyonu (Gölge bonusu)
6. **Faz 6:** Sınıf özelliği uygulaması (Kan Hırsı, Formül Ustası, Hayalet Adımlar)
7. **Faz 7:** Balancing — ilk 2 hafta metrik takibi; sınıf seçim dağılımı, winrate farkları

---

## 12. Denge Analizi

### 12.1 Oyun Stili vs Sınıf Eşleşmesi

| Oyun Stili | En Uygun Sınıf | Sebep |
|-----------|---------------|-------|
| PvP odaklı | **Savaşçı** | +20% PvP hasar, kritik bonus |
| Zindan farmer | **Savaşçı** / **Gölge** | Boss bonus / Loot luck |
| Crafting/ekonomi | **Simyacı** | Craft bonus, tolerans yönetimi |
| Tesis işletmeci | **Gölge** | Şüphe azaltma, rüşvet indirimi |
| PvP savunmacı | **Gölge** | Dodge bonus |
| İksir kullanıcı | **Simyacı** | Tolerans ve overdose bonusu |

### 12.2 Sınıf Güç Dengesi Hedefi

Her sınıf kendi alanında %20-30 daha avantajlıdır, ancak diğer alanlarda dezavantaj yoktur — yalnızca bonus alamamazlar. Bu, sınıfların farklı oynantı stillerini teşvik etmesini sağlarken, oyunun tüm içeriğine erişimi kısıtlamaz.

---

*Bu belge PLAN_01 (item stats/luck), PLAN_04 (zindan/hastane), PLAN_06 (power formülü), PLAN_07 (Han crafting), PLAN_08 (tolerans/iksir), PLAN_09 (PvP), PLAN_02 (tesisler) ile entegredir.*
