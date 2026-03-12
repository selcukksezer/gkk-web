# PLAN 09 — Reputation & PvP Sistemi

> **Durum:** ✅ Uygulandı (20260307_070000 + 20260312_030000_fix_pvp_attack_null_safety.sql)  
> **Son Güncelleme:** 2026-03-12 (Audit v2 — Warrior Bloodlust kaybı, tournament eksikliği, şema düzeltmesi)  
> **Bağımlılıklar:** PLAN_07 (Mekan — PvP arenası), PLAN_04 (hastane), PLAN_06 (ekonomi), PLAN_11 (Savaşçı PvP bonusu, Gölge dodge bonusu)  
> **Kapsam:** Reputation puanı, PvP mekanikleri, PvP rating, ganimet, sıralama

> ### ⚠️ Bilinen Sorunlar (Audit v2)
>
> **1. Warrior "Kan Hırsı" Bonusu Kayboldu:**  
> `20260307_090000` migration'ı `warrior_bloodlust_until` kolonunu ekledi ve kazanan Warrior için 30dk ATK boost sağladı. Ancak `20260312_030000_fix_pvp_attack_null_safety.sql` pvp_attack'ı sıfırdan yeniden yazdı ve bu bonusu **dahil etmedi**. Warrior PvP kazandığında `warrior_bloodlust_until = now() + interval '30 minutes'` set edilmeli; bu sonra `enter_dungeon` ve PvP'de ATK × 1.10 çarpanı olarak kullanılmalı.
>
> **2. PvP Turnuva Sistemi Uygulanmadı:**  
> Bu belgede tanımlanan turnuva sistemi **hiçbir migration'da uygulanmamıştır**. Ölü sistem olarak işaretlendi.
>
> **3. `game.users` Referansları Hatalı:**  
> Aşağıdaki tüm `game.users` referansları `public.users` olarak okunmalıdır.

---

## 1. Genel Bakış

Reputation, oyuncunun **toplumsal statüsünü** ve güç sıralamasını temsil eder. PvP ise Mekan'larda gerçekleşen, kontrollü ve ödüllü bir dövüş sistemidir.

**Mevcut DB sütunları (`public.users` — düzeltildi):**
- `reputation` — int, toplam itibar puanı
- `pvp_wins` — int, kazanılan PvP sayısı
- `pvp_losses` — int, kaybedilen PvP sayısı
- `pvp_rating` — int, Elo benzeri rating (başlangıç: 1000)

**Hedef değerler (Level 70 end-game):**
- Reputation: ~356,000
- Power: ~450,000
- PvP Rating: Top oyuncular ~2,500-3,000

**Temel kurallar:**
- PvP **sadece Han/Mekan içinde** gerçekleşir (PLAN_07: Dövüş Kulübü/Han merkezi, Lüks Lounge, Yeraltı); Han PvP'nin kalbidir
- Reputation kaynakları: PvP, zindan, quest, sosyal — çok yönlü
- Reputation **power formülüne katkı** yapar: `power += reputation × 0.1`
- PvP'de yenilen reputation kaybeder, kazanan kazanır → **reputation hırsızlığı**
- Reputation, prestige unvanları ve oyun-sonu sıralaması için kritik

---

## 2. Reputation Sistemi

### 2.1 Reputation Kaynakları

| Kaynak | Rep Kazanımı | Günlük Limit | Açıklama |
|--------|-------------|-------------|---------|
| Zindan clear (normal) | 10-100 / koşu | — | Zone'a göre artar |
| Zindan first clear | 200-5,000 | Tek seferlik | Her zindan 1 kez |
| Boss clear | 500-10,000 | 3 boss/gün | Zone boss'ları |
| PvP kazanma | 50-500 | — | Rating farkına göre |
| Quest tamamlama | 50-200 | — | Quest zorluğuna göre |
| Crafting (Mythic) | 200-1,000 | — | Yüksek tier craft |
| Mekan işletme | 10-50 / müşteri | — | Mekan sahibi bonusu |
| Lonca katkısı | 20-100 | — | Anıt katkısı, lonca görevleri |
| Sosyal (arkadaş davet) | 100 | 1/gün | Arkadaş referansı |

### 2.1.1 Han Trafiği ve Reputation Döngüsü

PvP ve reputation sistemi, Han/Mekan ekonomisiyle entegre bir döngü oluşturur:

```
Enerji kıtlığı → Oyuncu Han'a gider (enerji item alır)
  → Han'da diğer oyuncularla karşılaşır
    → PvP meydan okuması (isteğe bağlı)
      → Kazanan: rep + gold ganimet + Han üzerinden kazanç
        → Daha fazla Han trafiği → Mekan sahibine komisyon
          → Han ekonomisi güçlenir → daha iyi stok → daha fazla oyuncu çeker
```

Bu döngü şu güçlendiricilerle desteklenir:
- **Han-only enerji itemları:** Oyuncuyu fiziksel olarak Han'a getirir
- **PvP rep kazanımı:** Han'da olmak reputation için avantajlıdır
- **Mekan sahipleri:** Daha fazla PvP → daha fazla komisyon → daha iyi mekan
- **Reputation → Power:** Rep kazanımı güç artışına dönüşür (`power += rep × 0.1`)

### 2.2 Reputation Kaybı

| Kaynak | Rep Kaybı | Açıklama |
|--------|----------|---------|
| PvP kaybetme | -30 - -300 | Rating farkına göre |
| Hapis | -500 - -5,000 | Suça göre |
| Mekan kapatılması (polis) | -2,000 | Kaçak ticaret cezası |
| Overdose (hastane) | -100 | Sosyal damga |
| Zindan'da ölüm (Z6-7) | -50 | İtibar kaybı |

### 2.3 Reputation İlerleme Tablosu

| Dönem | Beklenen Günlük Rep | Kümülatif Rep | Milestone |
|-------|-------------------|--------------|-----------|
| Hafta 1 | 200-500 | ~2,000 | "Acemi" |
| Ay 1 | 500-1,500 | ~20,000 | "Tanınan" |
| Ay 2-3 | 1,500-3,000 | ~80,000 | "Saygın" |
| Ay 4-6 | 2,000-4,000 | ~170,000 | "Ünlü" |
| Ay 7-9 | 3,000-5,000 | ~280,000 | "Efsanevi" |
| Ay 10-12 | 3,000-5,000 | ~356,000 | "Destansı" |

### 2.4 Reputation Unvanları

| Reputation Aralığı | Unvan | Görsel |
|-------------------|-------|--------|
| 0 - 5,000 | Acemi | Gri çerçeve |
| 5,001 - 20,000 | Tanınan | Yeşil çerçeve |
| 20,001 - 80,000 | Saygın | Mavi çerçeve |
| 80,001 - 170,000 | Ünlü | Mor çerçeve |
| 170,001 - 280,000 | Efsanevi | Turuncu çerçeve |
| 280,001 - 356,000 | Destansı | Kırmızı çerçeve + parıltı |
| 356,001+ | İmparator | Altın çerçeve + aura |

### 2.5 Reputation Power Katkısı

```
power += reputation × 0.1
```

| Reputation | Power Katkısı | Toplam Power'a Oranı |
|-----------|--------------|---------------------|
| 20,000 (Ay 1) | +2,000 | ~%5 (40K toplam) |
| 80,000 (Ay 3) | +8,000 | ~%7 (120K toplam) |
| 170,000 (Ay 6) | +17,000 | ~%7 (250K toplam) |
| 280,000 (Ay 9) | +28,000 | ~%7 (400K toplam) |
| 356,000 (Ay 12) | +35,600 | ~%8 (450K toplam) |

> **Power dağılımı:** Level ×500 = %8, Reputation ×0.1 = %8, Ekipman = %84

---

## 3. PvP Sistemi

### 3.1 PvP Temelleri

| Kural | Değer |
|-------|-------|
| Mekan gereksinimi | Dövüş Kulübü, Lüks Lounge, veya Yeraltı |
| Enerji maliyeti | 15 |
| Min level | 10 |
| Günlük PvP limiti | 20 dövüş |
| Bekleme süresi | 30 saniye matchmaking |
| Dövüş süresi | Max 3 tur (otomatik hesaplama) |

### 3.2 PvP Dövüş Mekanizması

Dövüş, **power + RNG** tabanlı otomatik hesaplamadır:

```
Tur 1:
  attacker_damage = attacker.attack × (0.8 + random() × 0.4) × crit_check
  defender_damage = defender.attack × (0.8 + random() × 0.4) × crit_check

  crit_check = random() < (luck × 0.002) ? 1.5 : 1.0
  dodge_check = random() < (luck × 0.001) ? 0.0 : 1.0

  net_damage_to_defender = attacker_damage × dodge_check - defender.defense × 0.3
  net_damage_to_attacker = defender_damage × dodge_check - attacker.defense × 0.3

HP azaltma → 3 tur sonunda en çok HP kalan kazanır.
HP eşitse → power yüksek olan kazanır.
```

**Karakter Sınıfı Modifiyerleri (PLAN_11):**

```
-- Savaşçı saldırgan ise:
  attacker_damage = attacker_damage × 1.20        (PvP hasar +%20)
  crit_check += 0.10                              (Kritik şans +%10)

-- Gölge savunmacı ise:
  dodge_check = random() < (luck × 0.001 + 0.15) ? 0.0 : 1.0  (Dodge +%15)
```

### 3.3 PvP Rating (Elo Sistemi)

```
K = 32  (standard Elo K-factor)
expected_a = 1 / (1 + 10^((rating_b - rating_a) / 400))
new_rating_a = rating_a + K × (result - expected_a)
  result: 1.0 = kazanma, 0.0 = kaybetme
```

**Rating aralıkları:**

| Rating | Tier | Oyuncu Oranı |
|--------|------|-------------|
| 0-800 | Bronz | Alt %20 |
| 801-1200 | Gümüş | %40 |
| 1201-1600 | Altın | %25 |
| 1601-2000 | Platin | %10 |
| 2001-2500 | Elmas | %4 |
| 2501+ | Şampiyonlar | Top %1 |

### 3.4 PvP Gold Ganimet

Kazanan oyuncu, kaybedenden gold çalar:

```
gold_stolen = kaybeden.gold × steal_rate

steal_rate = CASE
  WHEN rating_diff > 200 THEN 0.01   -- çok güçlü vs zayıf: az gold
  WHEN rating_diff > 0   THEN 0.02   -- favoriye karşı kazanma
  WHEN rating_diff > -200 THEN 0.03  -- eşit maç
  ELSE 0.05                           -- underdog kazanırsa: büyük ödül
END

Min gold_stolen: 10,000
Max gold_stolen: 5,000,000
```

**Mekan komisyonu:** Toplam gold'un %5'i Mekan sahibine gider (PLAN_07).

### 3.5 PvP Reputation Ganimet

```
rep_change = base_rep × rating_multiplier

base_rep_win  = 100
base_rep_loss = -50

rating_multiplier:
  rating_diff > 200  → ×0.5 (kolay maç, az rep)
  rating_diff > 0    → ×1.0
  rating_diff > -200 → ×1.5
  rating_diff <= -200 → ×2.5 (underdog bonus!)
```

### 3.6 PvP Sonuç Tablosu

| Durum | Gold | Reputation | Rating |
|-------|------|-----------|--------|
| Kazanan (favori) | +gold çalma (%1-2) | +50-100 | +8-16 |
| Kazanan (eşit) | +gold çalma (%3) | +100-150 | +16-24 |
| Kazanan (underdog) | +gold çalma (%5) | +150-250 | +24-32 |
| Kaybeden | -gold kaybı | -50-150 | -8-24 |
| Kaybeden (hastane) | -gold + hospital maliyeti | -100-200 | -16-24 |

### 3.7 Hastane Riski (PvP Sonrası)

Kaybeden oyuncunun hastaneye düşme şansı:

```
pvp_hospital_chance = 0.10 × (1 + power_diff / winner_power)
Min: %5
Max: %30
Süre: 15-60 dk (power farkına göre)
```

---

## 4. PvP Koruma Mekanizmaları

### 4.1 Güçlü vs Zayıf Koruma

| Mekanizma | Açıklama |
|-----------|---------|
| Rating matchmaking | ±300 rating farkı dahilinde eşleşme |
| Gold çalma tavanı | Max 5M gold / dövüş |
| Yeni oyuncu koruması | Level 10 altı PvP yapamaz |
| Günlük saldırı limiti | Aynı oyuncuya max 3 kez/gün |
| "Barış bayrağı" | 100 gem ile 24 saat PvP koruması |
| Lonca koruması | Aynı lonca üyeleri birbirine saldıramaz |

### 4.2 Anti-Abuse

| Tehdit | Önlem |
|--------|-------|
| Win trading | Aynı iki oyuncu arası max 3 maç/gün, tekrarlanan patternlerde flag |
| Smurf account | Level 10 min + 3 gün oyun süresi gereksinimi |
| Bot PvP | Sunucu tarafı dövüş hesaplama (client manipüle edemez) |
| Griefing | Çok düşük rating oyuncuyu sürekli hedefleme: matchmaking engeli |

---

## 5. Turnuva Sistemi

### 5.1 Haftalık Turnuva

Her hafta Dövüş Kulübü mekanlarında otomatik turnuva:

| Aşama | Format | Katılım |
|-------|--------|---------|
| Ön eleme | Rating bazlı 4 grup | Top 100 rating |
| Çeyrek final | 1v1 elimination | Top 32 |
| Yarı final | 1v1 best-of-3 | Top 8 |
| Final | 1v1 best-of-5 | Top 2 |

### 5.2 Turnuva Ödülleri

| Sıra | Gold | Gem | Reputation | Özel |
|------|------|-----|-----------|------|
| 1 | 5,000,000 | 200 | +5,000 | "Haftalık Şampiyon" unvanı |
| 2 | 3,000,000 | 100 | +3,000 | — |
| 3-4 | 1,500,000 | 50 | +1,500 | — |
| 5-8 | 750,000 | 25 | +750 | — |
| Katılım | 100,000 | — | +100 | — |

### 5.3 Sezon Sonu Büyük Turnuva

Sezon bitiminden 2 hafta önce başlayan büyük turnuva:

| Ödül | 1. | 2. | 3. |
|------|------|------|------|
| Gold | 50,000,000 | 25,000,000 | 10,000,000 |
| Gem | 2,000 | 1,000 | 500 |
| Reputation | +25,000 | +15,000 | +10,000 |
| Unvan | "Sezon Gladyatörü" | "Yenilmez" | "Savaş Lordu" |
| Kozmetik | Altın Silah Skin | Gümüş Zırh Skin | Bronz Kalkan Skin |

---

## 6. Critical Success (Şahlanma) Sistemi

### 6.1 Critical Success Koşulları

PvP'de "Critical Success" özel bir zafer anıdır:

```
critical_success = (kazanma) AND (HP farkı > %50) AND (rating farkı < -100)
```

Yani: Underdog olarak ezici bir zafer kazandığında.

### 6.2 Critical Success Ödülleri

| Ödül | Miktar |
|------|--------|
| Reputation bonus | Normal ×3 (+300-750 rep) |
| Gold bonus | Normal ×2 |
| XP bonus | +1,000 |
| Özel mesaj | Sunucu genelinde duyuru: "X, Y'yi ezici bir zaferle yendi!" |
| Streak bonus | 3 ardışık Critical Success: "Yıkılmaz" unvanı (1 hafta) |

---

## 7. Veritabanı Şeması

### 7.1 Mevcut Sütunlar (Güncelleme Gerekmez)

```sql
-- game.users tablosunda zaten var:
-- reputation int DEFAULT 0
-- pvp_wins int DEFAULT 0
-- pvp_losses int DEFAULT 0
-- pvp_rating int DEFAULT 1000
```

### 7.2 Yeni Tablolar (Önerilen)

```sql
-- PvP maç geçmişi
CREATE TABLE game.pvp_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id uuid REFERENCES game.mekans(id),
  attacker_id uuid REFERENCES game.users(id) NOT NULL,
  defender_id uuid REFERENCES game.users(id) NOT NULL,
  winner_id uuid REFERENCES game.users(id),
  
  attacker_power int NOT NULL,
  defender_power int NOT NULL,
  attacker_hp_remaining int NOT NULL DEFAULT 0,
  defender_hp_remaining int NOT NULL DEFAULT 0,
  
  gold_stolen bigint NOT NULL DEFAULT 0,
  rep_change_winner int NOT NULL DEFAULT 0,
  rep_change_loser int NOT NULL DEFAULT 0,
  
  attacker_rating_before int NOT NULL,
  attacker_rating_after int NOT NULL,
  defender_rating_before int NOT NULL,
  defender_rating_after int NOT NULL,
  
  is_critical_success boolean NOT NULL DEFAULT false,
  hospital_triggered boolean NOT NULL DEFAULT false,
  
  rounds int NOT NULL DEFAULT 3,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- PvP sıralama tablosu (weekly snapshot)
CREATE TABLE game.pvp_leaderboard (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES game.users(id) NOT NULL,
  week_start date NOT NULL,
  rating int NOT NULL,
  wins int NOT NULL DEFAULT 0,
  losses int NOT NULL DEFAULT 0,
  gold_earned bigint NOT NULL DEFAULT 0,
  rep_earned int NOT NULL DEFAULT 0,
  rank int,
  
  UNIQUE(user_id, week_start)
);

-- PvP günlük saldırı tracking
CREATE TABLE game.pvp_daily_attacks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attacker_id uuid REFERENCES game.users(id) NOT NULL,
  defender_id uuid REFERENCES game.users(id) NOT NULL,
  attack_date date NOT NULL DEFAULT CURRENT_DATE,
  attack_count int NOT NULL DEFAULT 1,
  
  UNIQUE(attacker_id, defender_id, attack_date)
);
```

---

## 8. RPC Fonksiyonları (Önerilen)

### 8.1 PvP Saldırı

```sql
CREATE FUNCTION public.pvp_attack(p_attacker_id uuid, p_defender_id uuid, p_mekan_id uuid)
RETURNS json AS $$
DECLARE
  v_attacker record;
  v_defender record;
  v_mekan record;
  v_attacker_hp int;
  v_defender_hp int;
  v_winner_id uuid;
  v_gold_stolen bigint;
  v_rep_win int;
  v_rep_loss int;
  v_rating_diff int;
  v_expected_a numeric;
  v_new_rating_a int;
  v_new_rating_d int;
  v_hospital boolean := false;
  v_critical boolean := false;
  v_steal_rate numeric;
  v_total_gold bigint;
  v_mekan_commission bigint;
  v_daily_count int;
BEGIN
  -- Oyuncu kontrolü
  SELECT * INTO v_attacker FROM game.users WHERE id = p_attacker_id;
  SELECT * INTO v_defender FROM game.users WHERE id = p_defender_id;

  IF v_attacker.level < 10 OR v_defender.level < 10 THEN
    RETURN json_build_object('success', false, 'error', 'PvP için minimum level 10');
  END IF;

  -- Enerji kontrolü
  IF v_attacker.energy < 15 THEN
    RETURN json_build_object('success', false, 'error', 'Enerji yetersiz (15 gerekli)');
  END IF;

  -- Hastane/hapis kontrolü
  IF v_attacker.hospital_until > now() OR v_attacker.prison_until > now() THEN
    RETURN json_build_object('success', false, 'error', 'Hastanede/hapiste PvP yapılamaz');
  END IF;
  IF v_defender.hospital_until > now() OR v_defender.prison_until > now() THEN
    RETURN json_build_object('success', false, 'error', 'Rakip müsait değil');
  END IF;

  -- Aynı lonca kontrolü
  IF v_attacker.guild_id IS NOT NULL AND v_attacker.guild_id = v_defender.guild_id THEN
    RETURN json_build_object('success', false, 'error', 'Aynı lonca üyesine saldırılamaz');
  END IF;

  -- Günlük aynı hedefe saldırı limiti
  SELECT COALESCE(attack_count, 0) INTO v_daily_count
  FROM game.pvp_daily_attacks
  WHERE attacker_id = p_attacker_id AND defender_id = p_defender_id AND attack_date = CURRENT_DATE;
  IF v_daily_count >= 3 THEN
    RETURN json_build_object('success', false, 'error', 'Bu oyuncuya bugün 3 kez saldırdınız');
  END IF;

  -- Mekan kontrolü (PvP destekleyen mekan mı?)
  SELECT * INTO v_mekan FROM game.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND OR v_mekan.mekan_type NOT IN ('dovus_kulubu', 'luks_lounge', 'yeralti') THEN
    RETURN json_build_object('success', false, 'error', 'Bu mekanda PvP yapılamaz');
  END IF;

  -- Rating matchmaking (±300 kontrol)
  IF ABS(v_attacker.pvp_rating - v_defender.pvp_rating) > 300 THEN
    RETURN json_build_object('success', false, 'error', 'Rating farkı çok yüksek (max ±300)');
  END IF;

  -- === DÖVÜŞ HESAPLAMASI ===
  v_attacker_hp := v_attacker.health;
  v_defender_hp := v_defender.health;

  -- 3 tur simülasyonu (basitleştirilmiş)
  FOR i IN 1..3 LOOP
    DECLARE
      v_atk_dmg numeric;
      v_def_dmg numeric;
      v_atk_crit boolean;
      v_def_crit boolean;
    BEGIN
      v_atk_crit := random() < (v_attacker.luck * 0.002);
      v_def_crit := random() < (v_defender.luck * 0.002);

      v_atk_dmg := v_attacker.attack * (0.8 + random() * 0.4)
                   * CASE WHEN v_atk_crit THEN 1.5 ELSE 1.0 END
                   - v_defender.defense * 0.3;
      v_def_dmg := v_defender.attack * (0.8 + random() * 0.4)
                   * CASE WHEN v_def_crit THEN 1.5 ELSE 1.0 END
                   - v_attacker.defense * 0.3;

      v_atk_dmg := GREATEST(v_atk_dmg, 1);
      v_def_dmg := GREATEST(v_def_dmg, 1);

      v_defender_hp := v_defender_hp - v_atk_dmg::int;
      v_attacker_hp := v_attacker_hp - v_def_dmg::int;
    END;
  END LOOP;

  -- Kazanan belirleme
  IF v_attacker_hp > v_defender_hp THEN
    v_winner_id := p_attacker_id;
  ELSIF v_defender_hp > v_attacker_hp THEN
    v_winner_id := p_defender_id;
  ELSE -- eşit ise power yüksek kazanır
    v_winner_id := CASE WHEN v_attacker.power >= v_defender.power THEN p_attacker_id ELSE p_defender_id END;
  END IF;

  -- Enerji düşür
  UPDATE game.users SET energy = energy - 15 WHERE id = p_attacker_id;

  -- === RATING HESAPLAMASI (Elo) ===
  v_rating_diff := v_defender.pvp_rating - v_attacker.pvp_rating;
  v_expected_a := 1.0 / (1.0 + power(10.0, v_rating_diff::numeric / 400.0));

  IF v_winner_id = p_attacker_id THEN
    v_new_rating_a := v_attacker.pvp_rating + (32 * (1.0 - v_expected_a))::int;
    v_new_rating_d := v_defender.pvp_rating + (32 * (0.0 - (1.0 - v_expected_a)))::int;
  ELSE
    v_new_rating_a := v_attacker.pvp_rating + (32 * (0.0 - v_expected_a))::int;
    v_new_rating_d := v_defender.pvp_rating + (32 * (1.0 - (1.0 - v_expected_a)))::int;
  END IF;

  v_new_rating_a := GREATEST(v_new_rating_a, 0);
  v_new_rating_d := GREATEST(v_new_rating_d, 0);

  -- === GOLD GANIMET ===
  v_rating_diff := v_attacker.pvp_rating - v_defender.pvp_rating; -- saldırgan perspektifinden

  IF v_winner_id = p_attacker_id THEN
    v_steal_rate := CASE
      WHEN v_rating_diff > 200  THEN 0.01
      WHEN v_rating_diff > 0    THEN 0.02
      WHEN v_rating_diff > -200 THEN 0.03
      ELSE 0.05
    END;
    v_gold_stolen := GREATEST(LEAST((v_defender.gold * v_steal_rate)::bigint, 5000000), 10000);
    v_mekan_commission := (v_gold_stolen * 0.05)::bigint;
    v_total_gold := v_gold_stolen - v_mekan_commission;
  ELSE
    v_steal_rate := CASE
      WHEN v_rating_diff < -200 THEN 0.01
      WHEN v_rating_diff < 0    THEN 0.02
      WHEN v_rating_diff < 200  THEN 0.03
      ELSE 0.05
    END;
    v_gold_stolen := GREATEST(LEAST((v_attacker.gold * v_steal_rate)::bigint, 5000000), 10000);
    v_mekan_commission := (v_gold_stolen * 0.05)::bigint;
    v_total_gold := v_gold_stolen - v_mekan_commission;
  END IF;

  -- === REPUTATION ===
  v_rep_win := (100 * CASE
    WHEN ABS(v_attacker.pvp_rating - v_defender.pvp_rating) > 200 THEN 0.5
    WHEN ABS(v_attacker.pvp_rating - v_defender.pvp_rating) > 0   THEN 1.0
    WHEN ABS(v_attacker.pvp_rating - v_defender.pvp_rating) > -200 THEN 1.5
    ELSE 2.5
  END)::int;
  v_rep_loss := (50 * 1.0)::int;

  -- Critical success kontrolü
  IF v_winner_id IS NOT NULL THEN
    DECLARE
      v_hp_diff numeric;
      v_winner_hp int := CASE WHEN v_winner_id = p_attacker_id THEN v_attacker_hp ELSE v_defender_hp END;
      v_loser_hp int := CASE WHEN v_winner_id = p_attacker_id THEN v_defender_hp ELSE v_attacker_hp END;
      v_winner_rating int := CASE WHEN v_winner_id = p_attacker_id THEN v_attacker.pvp_rating ELSE v_defender.pvp_rating END;
      v_loser_rating int := CASE WHEN v_winner_id = p_attacker_id THEN v_defender.pvp_rating ELSE v_attacker.pvp_rating END;
    BEGIN
      v_hp_diff := (v_winner_hp - v_loser_hp)::numeric / GREATEST(v_winner_hp, 1);
      IF v_hp_diff > 0.5 AND (v_loser_rating - v_winner_rating) > 100 THEN
        v_critical := true;
        v_rep_win := v_rep_win * 3;
        v_total_gold := v_total_gold * 2;
      END IF;
    END;
  END IF;

  -- === GÜNCELLEMELER ===
  IF v_winner_id = p_attacker_id THEN
    UPDATE game.users SET
      pvp_wins = pvp_wins + 1,
      pvp_rating = v_new_rating_a,
      gold = gold + v_total_gold,
      reputation = reputation + v_rep_win
    WHERE id = p_attacker_id;

    -- Kaybeden: hastane riski %10
    v_hospital := random() < 0.10;
    UPDATE game.users SET
      pvp_losses = pvp_losses + 1,
      pvp_rating = v_new_rating_d,
      gold = GREATEST(gold - v_gold_stolen, 0),
      reputation = GREATEST(reputation - v_rep_loss, 0),
      hospital_until = CASE WHEN v_hospital THEN now() + '30 minutes'::interval ELSE hospital_until END,
      hospital_reason = CASE WHEN v_hospital THEN 'pvp_defeat' ELSE hospital_reason END
    WHERE id = p_defender_id;
  ELSE
    v_hospital := random() < 0.10;
    UPDATE game.users SET
      pvp_losses = pvp_losses + 1,
      pvp_rating = v_new_rating_a,
      gold = GREATEST(gold - v_gold_stolen, 0),
      reputation = GREATEST(reputation - v_rep_loss, 0),
      hospital_until = CASE WHEN v_hospital THEN now() + '30 minutes'::interval ELSE hospital_until END,
      hospital_reason = CASE WHEN v_hospital THEN 'pvp_defeat' ELSE hospital_reason END
    WHERE id = p_attacker_id;

    UPDATE game.users SET
      pvp_wins = pvp_wins + 1,
      pvp_rating = v_new_rating_d,
      gold = gold + v_total_gold,
      reputation = reputation + v_rep_win
    WHERE id = p_defender_id;
  END IF;

  -- Mekan komisyon
  UPDATE game.users SET gold = gold + v_mekan_commission WHERE id = v_mekan.owner_id;

  -- Günlük saldırı sayacı
  INSERT INTO game.pvp_daily_attacks (attacker_id, defender_id, attack_date, attack_count)
  VALUES (p_attacker_id, p_defender_id, CURRENT_DATE, 1)
  ON CONFLICT (attacker_id, defender_id, attack_date) DO UPDATE SET attack_count = game.pvp_daily_attacks.attack_count + 1;

  -- Maç kaydı
  INSERT INTO game.pvp_matches (
    mekan_id, attacker_id, defender_id, winner_id,
    attacker_power, defender_power,
    attacker_hp_remaining, defender_hp_remaining,
    gold_stolen, rep_change_winner, rep_change_loser,
    attacker_rating_before, attacker_rating_after,
    defender_rating_before, defender_rating_after,
    is_critical_success, hospital_triggered
  ) VALUES (
    p_mekan_id, p_attacker_id, p_defender_id, v_winner_id,
    v_attacker.power, v_defender.power,
    GREATEST(v_attacker_hp, 0), GREATEST(v_defender_hp, 0),
    v_gold_stolen, v_rep_win, v_rep_loss,
    v_attacker.pvp_rating, v_new_rating_a,
    v_defender.pvp_rating, v_new_rating_d,
    v_critical, v_hospital
  );

  RETURN json_build_object(
    'success', true,
    'winner', v_winner_id,
    'attacker_hp', GREATEST(v_attacker_hp, 0),
    'defender_hp', GREATEST(v_defender_hp, 0),
    'gold_stolen', v_gold_stolen,
    'rep_change', CASE WHEN v_winner_id = p_attacker_id THEN v_rep_win ELSE -v_rep_loss END,
    'new_rating', v_new_rating_a,
    'critical_success', v_critical,
    'hospital', v_hospital
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 9. TypeScript Tipleri

```typescript
export interface PvpMatchResult {
  success: boolean;
  winner: string;
  attacker_hp: number;
  defender_hp: number;
  gold_stolen: number;
  rep_change: number;
  new_rating: number;
  critical_success: boolean;
  hospital: boolean;
  error?: string;
}

export interface PvpMatch {
  id: string;
  mekan_id: string;
  attacker_id: string;
  defender_id: string;
  winner_id: string | null;
  attacker_power: number;
  defender_power: number;
  attacker_hp_remaining: number;
  defender_hp_remaining: number;
  gold_stolen: number;
  rep_change_winner: number;
  rep_change_loser: number;
  attacker_rating_before: number;
  attacker_rating_after: number;
  defender_rating_before: number;
  defender_rating_after: number;
  is_critical_success: boolean;
  hospital_triggered: boolean;
  rounds: number;
  created_at: string;
}

export type PvpTier = 'bronze' | 'silver' | 'gold' | 'platinum' | 'diamond' | 'champions';

export function getPvpTier(rating: number): PvpTier {
  if (rating <= 800) return 'bronze';
  if (rating <= 1200) return 'silver';
  if (rating <= 1600) return 'gold';
  if (rating <= 2000) return 'platinum';
  if (rating <= 2500) return 'diamond';
  return 'champions';
}

export type ReputationTitle = 'acemi' | 'tanınan' | 'saygın' | 'ünlü' | 'efsanevi' | 'destansı' | 'imparator';

export function getReputationTitle(reputation: number): ReputationTitle {
  if (reputation <= 5000) return 'acemi';
  if (reputation <= 20000) return 'tanınan';
  if (reputation <= 80000) return 'saygın';
  if (reputation <= 170000) return 'ünlü';
  if (reputation <= 280000) return 'efsanevi';
  if (reputation <= 356000) return 'destansı';
  return 'imparator';
}
```

---

## 10. UI Sayfaları (Önerilen)

| Sayfa | Rota | Açıklama |
|-------|------|----------|
| PvP Sıralama | `/game/pvp` | Rating sıralaması, tier dağılımı |
| PvP Maç Geçmişi | `/game/pvp/history` | Son maçlar, istatistikler |
| PvP Arena | `/game/mekans/[id]/arena` | Canlı eşleşme (PLAN_07 ile ortak) |
| Reputation Profil | `/game/profile/reputation` | Rep geçmişi, unvan, power katkısı |
| Turnuva | `/game/pvp/tournament` | Haftalık turnuva bracket'ı |

---

## 11. Denge Analizi

### 11.1 PLAN_06 Tutarlılık

| Kontrol | PLAN_06 Değeri | PLAN_09 Değeri | Uyum |
|---------|---------------|---------------|------|
| PvP enerji maliyeti | 15 (enerji kıtlık sisteminde — bkz. PLAN_06 §4) | 15 | ✓ |
| Günlük PvP geliri | 1-5M (end-game) | Max 5M gold_stolen × 20 dövüş = max 100M ama gerçekte 3-10M | ✓ |
| End-game reputation | ~356,000 | 356,000 (12 ay birikim) | ✓ |
| Power'a rep katkısı | rep × 0.1 | rep × 0.1 = 35,600 power | ✓ |
| PvP ganimet Mekan komisyonu | PLAN_07 %5 | %5 | ✓ |

### 11.2 Han-Merkezli PvP Ekonomik Doğrulaması

Han/Mekan PvP döngüsünün ekonomik sürdürülebilirliği:

| Metrik | Değer | Not |
|--------|-------|-----|
| Han'a gelen oyuncu (enerji alım için) | Günde tüm aktif oyuncular | Enerji kıtlığı zorunlu kılar |
| Han PvP tetiklenme oranı | Ziyaret başına ~%30 | Fırsat ve rakip varlığı |
| PvP komisyonu (Mekan sahibine) | Ganimet'in %5'i | Mekan sahibi gelir motivasyonu |
| Günlük PvP rep kazanımı | 200-400 rep | Toplam rep hedefine %25-40 katkı |
| Han item satışından Mekan geliri | 1-10M/gün (aktif mekan) | PLAN_06 §2.1 ile uyumlu |

### 11.3 Rep İlerleme Doğrulaması

```
Ay 12'de hedef: 356,000 reputation
Günlük ortalama: 356,000 / 365 ≈ 975 rep/gün

Bileşenler:
- Zindan: 300-500 rep/gün (10-20 koşu)
- PvP: 200-400 rep/gün (5-10 dövüş)
- Quest: 100-200 rep/gün
- Mekan/Lonca: 50-100 rep/gün
- Boss/First clear: Değişken bonus

Toplam: 650-1,200 rep/gün → Ortalama ~975 ✓
```

---

## 12. Uygulama Öncelikleri

1. **Faz 1:** pvp_matches tablosu oluştur, pvp_attack RPC
2. **Faz 2:** Elo rating sistemi + matchmaking
3. **Faz 3:** PvP Arena UI (Mekan entegrasyonu, PLAN_07)
4. **Faz 4:** Gold ganimet + reputation sistemi
5. **Faz 5:** PvP koruma mekanizmaları (günlük limit, lonca, barış bayrağı)
6. **Faz 6:** Haftalık turnuva sistemi
7. **Faz 7:** Critical Success + sıralama UI
8. **Faz 8:** Sezon sonu büyük turnuva

---

*Bu belge PLAN_07 (Han/Mekan — PvP arenası, Han-only enerji itemları, komisyon), PLAN_04 (hastane — PvP sonrası), PLAN_06 (ekonomi — PvP gelir/gider, enerji kıtlık modeli), PLAN_08 (tolerans — çekme belirtileri PvP etkisi, Han-only detox) ve PLAN_11 (Savaşçı: PvP hasar +%20 / kritik +%10; Gölge: dodge +%15) ile entegredir.*
