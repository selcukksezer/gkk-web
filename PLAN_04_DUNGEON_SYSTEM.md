# PLAN 04 — Zindan (Dungeon) Sistemi

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-04  
> **Bağımlılıklar:** Item sistemi (power hesabı), Tesis sistemi (catalyst drop'ları), Enhancement sistemi (item güçlendirme)

---

## 1. Genel Bakış

**65 solo zindan**, **7 bölge (zone)** içinde organize edilir. Tüm zindanlar baştan **açıktır** ancak başarı oranı oyuncunun **toplam gücüne (power)** bağlıdır.

### Temel İlkeler
- Seviye 1 oyuncu → Zindan 1'i **%100 başarıyla** geçer
- Aynı oyuncu → Zindan 2'de düşük başarı oranına sahip olur (ekipmansız ~%25-40)
- Oyuncu aynı zindanı tekrarlayarak para/item/XP kasmalıdır
- **Günlük limit mekanikleri:** Enerji + Yorgunluk (Fatigue)
- 1 yıllık sezonda, hardcore oyuncu bile tüm 65 zindanı kolayca bitiremez

---

## 2. Zindan Bölgeleri & Tam Katalog (65 Zindan)

### Zone 1: Silva Obscura (Karanlık Orman) — Zindan 1-10

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 1 | `dng_001` | Luporum Cubile | Kurt İni | 0 | 5 | 5,000-12,000 | 30 |
| 2 | `dng_002` | Aranearum Nidus | Örümcek Yuvası | 1,500 | 5 | 6,000-14,000 | 40 |
| 3 | `dng_003` | Goblinorum Castra | Goblin Kampı | 2,500 | 5 | 7,000-16,000 | 50 |
| 4 | `dng_004` | Fungorum Caverna | Mantar Mağarası | 3,500 | 6 | 8,000-18,000 | 60 |
| 5 | `dng_005` | Silvani Templum | Orman Tapınağı | 4,500 | 6 | 9,000-20,000 | 75 |
| 6 | `dng_006` | Veneficae Domus | Cadı Kulübesi | 5,500 | 6 | 10,000-23,000 | 90 |
| 7 | `dng_007` | Mortuorum Silva | Ölü Orman | 6,500 | 7 | 11,000-26,000 | 105 |
| 8 | `dng_008` | Lupus Rex Tana | Kurt Kralın İni | 7,500 | 7 | 13,000-30,000 | 120 |
| 9 | `dng_009` | Arbor Antiqua | Kadim Ağaç | 8,500 | 7 | 15,000-34,000 | 140 |
| 10 | `dng_010` | Silva Maledictus | Lanetli Orman Kalbi | 10,000 | 8 | 18,000-40,000 | 160 |

**Boss:** #10 — Silva Maledictus (Günlük 3 deneme limiti)
**Loot:** Common ekipman, Common kaynak, catalyst_common
**Hastane riski:** %0 (#1-7), başarı oranına ters orantılı (#8-10, bkz. Bölüm 7)

---

### Zone 2: Caverna Profunda (Derin Mağaralar) — Zindan 11-20

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 11 | `dng_011` | Fodina Deserta | Terk Edilmiş Maden | 12,000 | 8 | 20,000-45,000 | 180 |
| 12 | `dng_012` | Crystallorum Camera | Kristal Odası | 14,500 | 8 | 22,000-50,000 | 200 |
| 13 | `dng_013` | Vermium Tunnelus | Solucan Tüneli | 17,000 | 9 | 25,000-56,000 | 225 |
| 14 | `dng_014` | Subterraneum Lacus | Yeraltı Gölü | 19,500 | 9 | 28,000-62,000 | 250 |
| 15 | `dng_015` | Pipistrellorum Caverna | Yarasa Mağarası | 22,000 | 9 | 31,000-68,000 | 280 |
| 16 | `dng_016` | Trogloditarum Oppidum | Troglodyt Şehri | 25,000 | 10 | 35,000-75,000 | 310 |
| 17 | `dng_017` | Aquae Subterraneae | Yeraltı Nehri | 28,000 | 10 | 39,000-83,000 | 340 |
| 18 | `dng_018` | Fungorum Regnum | Mantar Krallığı | 31,000 | 10 | 43,000-92,000 | 380 |
| 19 | `dng_019` | Dracunculus Nidus | Genç Ejder Yuvası | 35,000 | 11 | 48,000-102,000 | 420 |
| 20 | `dng_020` | Abyssi Ostium | Uçurumun Kapısı | 40,000 | 12 | 55,000-115,000 | 470 |

**Boss:** #20 — Abyssi Ostium (Günlük 3 deneme)
**Loot:** Uncommon ekipman, Common-Uncommon kaynak, catalyst_uncommon
**Hastane riski:** Başarı oranına ters orantılı (#11-17 düşük, #18-20 orta, bkz. Bölüm 7)

---

### Zone 3: Desertum Ignis (Ateş Çölü) — Zindan 21-30

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 21 | `dng_021` | Scorpionis Vallis | Akrep Vadisi | 44,000 | 12 | 60,000-130,000 | 520 |
| 22 | `dng_022` | Oasis Venenata | Zehirli Vaha | 50,000 | 12 | 66,000-143,000 | 570 |
| 23 | `dng_023` | Pyramidis Ruinae | Piramit Harabeleri | 56,000 | 13 | 73,000-158,000 | 630 |
| 24 | `dng_024` | Sphingis Aenigma | Sfenks Bilmecesi | 62,000 | 13 | 80,000-173,000 | 690 |
| 25 | `dng_025` | Tempestas Arenae | Kum Fırtınası Tapınağı | 68,000 | 14 | 88,000-190,000 | 760 |
| 26 | `dng_026` | Mummiarum Crypta | Mumya Mezarı | 74,000 | 14 | 97,000-210,000 | 830 |
| 27 | `dng_027` | Solis Templum | Güneş Tapınağı | 80,000 | 15 | 107,000-231,000 | 910 |
| 28 | `dng_028` | Djinn Palatium | Cin Sarayı | 86,000 | 15 | 118,000-255,000 | 1,000 |
| 29 | `dng_029` | Pharaonis Maledictio | Firavunun Laneti | 93,000 | 16 | 130,000-281,000 | 1,100 |
| 30 | `dng_030` | Ignis Cor | Çölün Ateş Kalbi | 100,000 | 18 | 145,000-310,000 | 1,200 |

**Boss:** #30 — Ignis Cor (Günlük 3 deneme)
**Loot:** Rare ekipman, Uncommon-Rare kaynak, catalyst_rare
**Hastane riski:** Başarı oranına ters orantılı (bkz. Bölüm 7)

---

### Zone 4: Mons Tempestatis (Fırtına Dağı) — Zindan 31-40

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 31 | `dng_031` | Caprarum Via | Keçi Yolu Geçidi | 110,000 | 18 | 160,000-340,000 | 1,320 |
| 32 | `dng_032` | Aquilae Nidus | Kartal Yuvası | 122,000 | 18 | 177,000-375,000 | 1,450 |
| 33 | `dng_033` | Gigantum Rupes | Dev Kayalıkları | 134,000 | 19 | 195,000-413,000 | 1,590 |
| 34 | `dng_034` | Glaciei Caverna | Buz Mağarası | 146,000 | 19 | 215,000-454,000 | 1,750 |
| 35 | `dng_035` | Fulminis Turris | Yıldırım Kulesi | 158,000 | 20 | 237,000-500,000 | 1,920 |
| 36 | `dng_036` | Nanorum Fodina | Cüce Madeni | 170,000 | 20 | 261,000-550,000 | 2,110 |
| 37 | `dng_037` | Draconis Scopulus | Ejder Kayalığı | 182,000 | 22 | 288,000-606,000 | 2,320 |
| 38 | `dng_038` | Ventorum Templum | Rüzgar Tapınağı | 194,000 | 22 | 317,000-667,000 | 2,550 |
| 39 | `dng_039` | Titanis Ossa | Titanın Kemikleri | 207,000 | 24 | 350,000-734,000 | 2,800 |
| 40 | `dng_040` | Caelum Vertex | Gökyüzü Zirvesi | 220,000 | 25 | 385,000-808,000 | 3,080 |

**Boss:** #40 — Caelum Vertex (Günlük 3 deneme)
**Loot:** Epic ekipman, Rare-Epic kaynak, catalyst_epic
**Hastane riski:** Başarı oranına ters orantılı (bkz. Bölüm 7)

---

### Zone 5: Infernum Subterra (Yeraltı Cehennemi) — Zindan 41-50

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 41 | `dng_041` | Lavae Flumen | Lav Nehri | 230,000 | 25 | 425,000-890,000 | 3,380 |
| 42 | `dng_042` | Daemonum Porta | Şeytan Kapısı | 242,000 | 26 | 470,000-980,000 | 3,720 |
| 43 | `dng_043` | Ossium Palatium | Kemik Sarayı | 254,000 | 26 | 520,000-1,080,000 | 4,090 |
| 44 | `dng_044` | Animarum Carcer | Ruh Hapishanesi | 268,000 | 28 | 570,000-1,190,000 | 4,500 |
| 45 | `dng_045` | Necromantis Lab | Ölü Büyücünün Lab. | 282,000 | 28 | 630,000-1,310,000 | 4,950 |
| 46 | `dng_046` | Sanguinis Fons | Kan Çeşmesi | 296,000 | 30 | 695,000-1,440,000 | 5,440 |
| 47 | `dng_047` | Umbrae Labyrinthus | Gölge Labirenti | 310,000 | 30 | 766,000-1,590,000 | 5,990 |
| 48 | `dng_048` | Mortis Thronus | Ölüm Tahtı | 320,000 | 32 | 845,000-1,750,000 | 6,580 |
| 49 | `dng_049` | Inferni Cor | Cehennem Kalbi | 330,000 | 32 | 932,000-1,925,000 | 7,240 |
| 50 | `dng_050` | Abyssi Rex | Uçurum Kralı | 340,000 | 35 | 1,030,000-2,120,000 | 7,960 |

**Boss:** #50 — Abyssi Rex (Günlük 3 deneme)
**Loot:** Legendary ekipman, Epic-Legendary kaynak, catalyst_legendary
**Hastane riski:** Başarı oranına ters orantılı (bkz. Bölüm 7)

---

### Zone 6: Caelum Fractum (Kırık Gökyüzü) — Zindan 51-60

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 51 | `dng_051` | Nubium Insula | Bulut Adası | 350,000 | 35 | 1,140,000-2,330,000 | 8,760 |
| 52 | `dng_052` | Angelorum Ruinae | Melek Harabeleri | 358,000 | 36 | 1,250,000-2,560,000 | 9,630 |
| 53 | `dng_053` | Stellarum Via | Yıldız Yolu | 366,000 | 36 | 1,380,000-2,820,000 | 10,590 |
| 54 | `dng_054` | Lunae Palatium | Ay Sarayı | 374,000 | 38 | 1,520,000-3,100,000 | 11,650 |
| 55 | `dng_055` | Solis Forgia | Güneş Dökümhanesi | 382,000 | 38 | 1,680,000-3,410,000 | 12,810 |
| 56 | `dng_056` | Temporis Fissura | Zaman Yarığı | 390,000 | 40 | 1,850,000-3,750,000 | 14,100 |
| 57 | `dng_057` | Dimensionis Nexus | Boyut Kavşağı | 398,000 | 40 | 2,040,000-4,130,000 | 15,500 |
| 58 | `dng_058` | Deorum Atrium | Tanrılar Avlusu | 406,000 | 42 | 2,250,000-4,540,000 | 17,050 |
| 59 | `dng_059` | Fati Thronus | Kader Tahtı | 414,000 | 42 | 2,480,000-5,000,000 | 18,750 |
| 60 | `dng_060` | Omnium Finis | Her Şeyin Sonu | 420,000 | 45 | 2,730,000-5,500,000 | 20,650 |

**Boss:** #60 — Omnium Finis (Günlük 3 deneme)
**Loot:** Legendary-Mythic ekipman, Legendary kaynak, catalyst_legendary
**Hastane riski:** Başarı oranına ters orantılı (bkz. Bölüm 7)

---

### Zone 7: Mythica Pericula (Mitik Tehlikeler) — Zindan 61-65

| # | Dungeon ID | Latince İsim | Türkçe İsim | Power Req | Enerji | Gold Min-Max | XP |
|---|------------|-------------|-------------|-----------|--------|-------------|-----|
| 61 | `dng_061` | Chronos Aeternus | Sonsuz Zaman | 425,000 | 45 | 3,000,000-6,050,000 | 22,700 |
| 62 | `dng_062` | Chaos Primordiale | İlkel Kaos | 432,000 | 48 | 3,300,000-6,650,000 | 25,000 |
| 63 | `dng_063` | Nihilum Absolutum | Mutlak Hiçlik | 438,000 | 48 | 3,630,000-7,320,000 | 27,500 |
| 64 | `dng_064` | Creatrix Nexus | Yaratıcı Bağlantı | 444,000 | 50 | 4,000,000-8,050,000 | 30,200 |
| 65 | `dng_065` | Ultimus Provocatio | Son Meydan Okuma | 450,000 | 50 | 4,400,000-8,860,000 | 33,200 |

**Boss:** Hepsi boss zindanı (Günlük 3 deneme her biri)
**Loot:** Mythic ekipman, Mythic kaynak, catalyst_mythic
**Hastane riski:** Başarı oranına ters orantılı (bkz. Bölüm 7)
**Özel:** #65 clear = sezon şampiyonluğu rozeti

---

## 3. Başarı Oranı Formülü

### 3.1 Ana Formül

```
power_ratio = player_total_power / dungeon_power_requirement

if dungeon_power_requirement == 0:
    success_rate = 1.00  (Zindan #1 özel durum)

elif power_ratio >= 1.5:
    success_rate = 0.95  (cap)

elif power_ratio >= 1.0:
    success_rate = 0.70 + (power_ratio - 1.0) × 0.50

elif power_ratio >= 0.5:
    success_rate = 0.25 + (power_ratio - 0.5) × 0.90

elif power_ratio >= 0.25:
    success_rate = 0.10 + (power_ratio - 0.25) × 0.60

else:
    success_rate = max(0.05, power_ratio × 0.40)
```

### 3.2 Bonus Modifiyerler

```
luck_bonus = player_luck × 0.001          (max +5%)
reputation_bonus = reputation × 0.0005     (max +2.5%)
guild_bonus = guild_level × 0.01           (max +5%)
season_modifier = season_specific_bonus     (değişken, 0-10%)

final_rate = clamp(success_rate + luck_bonus + reputation_bonus + guild_bonus + season_modifier, 0.05, 0.95)
```

### 3.3 Örnek Senaryolar

**Senaryo A: Yeni oyuncu (Lv 1, power 500, no gear) → Zindan #1**
```
power_req = 0 → success = 100% ✓
```

**Senaryo B: Yeni oyuncu → Zindan #2 (power req 1,500)**
```
power_ratio = 500 / 1500 = 0.33
success_rate = 0.10 + (0.33 - 0.25) × 0.60 = 0.148 ≈ 15%
```
Oyuncu %15 şansla girebilir ama büyük olasılıkla kaybeder.

**Senaryo C: Tam common set oyuncu (power ~10,000) → Zindan #2 (power req 1,500)**
```
power_ratio = 10000 / 1500 = 6.67 → capped at 95%
```
Tam common set ile Zindan 2 artık rahat.

**Senaryo D: Tam common set → Zindan #5 (power req 4,500)**
```
power_ratio = 10000 / 4500 = 2.22 → capped at 95%
```
Common set ile Zone 1 rahatça geçilir.

**Senaryo E: Tam common +3 set (power ~15,000) → Zindan #11 (power req 12,000)**
```
power_ratio = 15000 / 12000 = 1.25
success_rate = 0.70 + (1.25 - 1.0) × 0.50 = 0.825 ≈ 83%
```
Zone 2'ye geçmek için common +3 veya uncommon başlangıcı yeterli.

**Senaryo F: Tam uncommon +5 set (power ~40,000) → Zindan #20 (power req 40,000)**
```
power_ratio = 40000 / 40000 = 1.0
success_rate = 0.70 + 0 = 0.70 = 70%
```
Zone 2 boss için enhancement ve rare geçişi gerekir.

**Senaryo G: Tam mythic +10 set (power ~450,000) → Zindan #65 (power req 450,000)**
```
power_ratio = 450000 / 450000 = 1.0
success_rate = 0.70 = 70%
```
End-game'de bile %100 garantili değil. Enhancement, luck, guild bonusu kritik.

---

## 4. Toplam Güç (Total Power) Hesaplaması

```typescript
function calculateTotalPower(player: PlayerProfile, equippedItems: InventoryItem[]): number {
  let power = 0;
  
  // Equipment power
  for (const item of equippedItems) {
    const enhMultiplier = 1 + (item.enhancement_level * 0.15);
    power += Math.floor((item.attack + item.defense + item.health / 10 + item.luck * 2) * enhMultiplier);
  }
  
  // Level bonus
  power += player.level * 500;
  
  // Reputation bonus
  power += Math.floor((player.reputation ?? 0) * 0.1);
  
  return power;
}
```

---

## 5. Yorgunluk (Fatigue) Sistemi

### 5.1 Mekanik

Her zindan koşusu **+1 Fatigue** ekler. Fatigue, başarı oranından düşer.

```
fatigue_penalty = fatigue_points × 0.02  (her fatigue = -%2 başarı)
```

- **Max Fatigue:** 50 (= -%100, pratikte %5'e düşürür)
- **Fatigue Reset:** Her gün gece yarısı (00:00 UTC)
- **Fatigue Azaltma:** 1 gem = -1 fatigue (opsiyonel P2W)

### 5.2 Günlük Örnek

Bir oyuncu 20 zindan koştu:
```
fatigue = 20 → penalty = 40%
95% başarı oranı → 95% - 40% = 55%'e düşer
```

Bu sistem, oyuncuları günde ~15-25 zindan koşmaya yönlendirir (ötesi çok riskli).

### 5.3 Enerji + Fatigue Kombine Limiti

- Günlük enerji: ~480 (24 saat full regen)
- Zone 1 (5 enerji): 480/5 = 96 koşu, ama 50 fatigue'den sonra pratikte imkansız
- Zone 6 (40 enerji): 480/40 = 12 koşu, fatigue minimal etki
- **Etkili günlük limit:** ~20-30 koşu (casual), ~40-50 koşu (hardcore, gem ile fatigue reset)

---

## 6. Ödül (Loot) Sistemi

### 6.1 Gold & XP

Başarılı koşu:
```
gold = random(min_gold, max_gold) × (1 + player_luck × 0.002)
xp = base_xp × (1 + player_luck × 0.001)
```

Kritik Başarı (%10 şans):
```
gold × 1.5
xp × 1.5
```

Başarısız koşu:
```
gold = min_gold × 0.3 (teselli ödülü)
xp = base_xp × 0.2
```

### 6.2 İtem Drop Tablosu

Her başarılı koşuda item drop şansı:

| Zone | Ekipman Drop % | Kaynak Drop % | Catalyst Drop % | Scroll Drop % |
|------|---------------|---------------|-----------------|---------------|
| Zone 1 | 15% | 40% | 5% | 2% |
| Zone 2 | 18% | 45% | 7% | 3% |
| Zone 3 | 20% | 50% | 10% | 5% |
| Zone 4 | 22% | 50% | 12% | 6% |
| Zone 5 | 25% | 55% | 15% | 8% |
| Zone 6 | 28% | 55% | 18% | 10% |
| Zone 7 | 35% | 60% | 25% | 15% |

### 6.3 Drop Nadirlik Dağılımı

Ekipman drop'u olduğunda, nadirlik:

| Zone | Common | Uncommon | Rare | Epic | Legendary | Mythic |
|------|--------|----------|------|------|-----------|--------|
| 1 | 80% | 18% | 2% | — | — | — |
| 2 | 50% | 35% | 13% | 2% | — | — |
| 3 | 20% | 40% | 30% | 9% | 1% | — |
| 4 | 5% | 20% | 40% | 28% | 6% | 1% |
| 5 | — | 5% | 25% | 40% | 25% | 5% |
| 6 | — | — | 10% | 35% | 40% | 15% |
| 7 | — | — | — | 15% | 45% | 40% |

### 6.4 Boss Zindanları Özel Loot

Boss zindanları (her zone'un son zindanı) ek olarak:
- **Garantili 1 catalyst** (zone'un seviyesinde)
- **%50 fazla gold**
- **İlk clear bonusu:** İlk kez geçişte 1× garantili o zone rarity ekipman + büyük XP bonusu

```
first_clear_bonus_xp = base_xp × 10
first_clear_gold = max_gold × 5
```

---

## 7. Hastane (Hospitalization) Sistemi

### 7.1 Kurallar

Başarısız zindan koşusunda hastane riski **başarı oranına ters orantılıdır**:

```
hospital_chance = clamp(1.0 - success_rate, 0.05, 0.90) × (1 - player_luck × 0.003)
hospital_duration = base_duration × zone_multiplier
```

**Örnek:**
- Başarı oranı %10 → Hastane şansı %90
- Başarı oranı %50 → Hastane şansı %50
- Başarı oranı %80 → Hastane şansı %20
- Başarı oranı %95 → Hastane şansı %5 (minimum)

**Zone bazlı süre çarpanları:**

| Zone | Süre Çarpanı | Süre Aralığı (dk) | Mantık |
|------|-------------|-------------------|--------|
| 1 | ×1.0 | 15-45 | Başlangıç, hafif ceza |
| 2 | ×1.5 | 30-90 | Orta seviye tehlike |
| 3 | ×2.0 | 45-150 | Ciddi tehlike |
| 4 | ×3.0 | 60-240 | Ağır yaralanma |
| 5 | ×4.0 | 90-360 | Çok tehlikeli |
| 6 | ×5.0 | 120-480 | Ölümcül tehlike |
| 7 | ×6.0 | 180-720 | Mitik yaralanma |

**Kritik İlke:** Güçsüz oyuncu = düşük başarı = yüksek hastane riski. Bu, oyuncuları güçlerine uygun zindanlara girmeye teşvik eder.

> **Not:** Zone 1 #1-7 için hastane riski %0'a sabitlenir (başlangıç koruması).

### 7.2 Hastaneden Çıkış

- **Bekleme:** Süre dolana kadar bekle (ücretsiz)
- **Gem ile çıkış:** 3 gem/dakika
- **İksir:** Elixir Vitae Major = hastane süresini %50 azaltır
- **Lonca yardımı:** Guild üyesi %20 süre azaltma (4 saatte 1)

---

## 8. Zindan Savaş Animasyonu

### 8.1 Savaş Akışı (UI)

```
1. [0s] "Zindana giriliyor..." — kapı animasyonu
2. [1s] "Düşmanlarla karşılaşıldı!" — düşman sprite'ları
3. [1.5s] Savaş animasyonu (kılıç sallama, büyü efektleri)
4. [3s] Sonuç belirleniyor... (server response bekle)
5. [3.5s] Sonuç ekranı:
   - BAŞARI: Altın yağmuru animasyonu + loot kartları
   - KRİTİK BAŞARI: Parlama efekti + ekstra loot
   - BAŞARISIZ: Karartma + teselli ödülü
   - HASTANE: Kırmızı ekran + ambulans animasyonu
```

### 8.2 Savaş Logu

Her koşu için detaylı battle log:
```
[Tur 1] Oyuncu → Lupus'a 45 hasar verdi
[Tur 1] Lupus → Oyuncuya 12 hasar verdi  
[Tur 2] Oyuncu → Kritik vuruş! 89 hasar
[Tur 3] Lupus yenildi!
Ödüller: 87 gold, 35 XP
```

Bu log tamamen kozmetik (sonuç server'da zaten belirlendi).

---

## 9. Veritabanı Şeması

### 9.1 `dungeons` Tablosu (Catalog)

```sql
CREATE TABLE IF NOT EXISTS public.dungeons (
  id TEXT PRIMARY KEY,                     -- dng_001
  name TEXT NOT NULL,                      -- Luporum Cubile
  name_tr TEXT NOT NULL,                   -- Kurt İni
  description TEXT DEFAULT '',
  zone INTEGER NOT NULL,                   -- 1-7
  zone_name TEXT NOT NULL,                 -- Silva Obscura
  dungeon_order INTEGER NOT NULL,          -- 1-65
  
  -- Difficulty
  power_requirement INTEGER DEFAULT 0,
  energy_cost INTEGER DEFAULT 5,
  is_boss BOOLEAN DEFAULT false,
  daily_boss_limit INTEGER DEFAULT 3,
  
  -- Rewards
  gold_min INTEGER DEFAULT 0,
  gold_max INTEGER DEFAULT 0,
  xp_reward INTEGER DEFAULT 0,
  
  -- Risk
  hospital_chance NUMERIC DEFAULT 0.0,
  hospital_min_minutes INTEGER DEFAULT 0,
  hospital_max_minutes INTEGER DEFAULT 0,
  
  -- Loot
  equipment_drop_chance NUMERIC DEFAULT 0.15,
  resource_drop_chance NUMERIC DEFAULT 0.40,
  catalyst_drop_chance NUMERIC DEFAULT 0.05,
  scroll_drop_chance NUMERIC DEFAULT 0.02,
  loot_rarity_weights JSONB DEFAULT '{}',
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_dungeons_zone ON public.dungeons(zone);
CREATE INDEX idx_dungeons_order ON public.dungeons(dungeon_order);
```

### 9.2 `dungeon_runs` Tablosu

```sql
CREATE TABLE IF NOT EXISTS public.dungeon_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id),
  dungeon_id TEXT NOT NULL REFERENCES dungeons(id),
  
  -- Result
  success BOOLEAN NOT NULL,
  is_critical BOOLEAN DEFAULT false,
  
  -- Rewards earned
  gold_earned INTEGER DEFAULT 0,
  xp_earned INTEGER DEFAULT 0,
  items_dropped JSONB DEFAULT '[]',
  
  -- Hospital
  hospitalized BOOLEAN DEFAULT false,
  hospital_until TIMESTAMPTZ,
  
  -- Stats at time of run
  player_power INTEGER DEFAULT 0,
  success_rate_at_run NUMERIC DEFAULT 0,
  fatigue_at_run INTEGER DEFAULT 0,
  
  -- First clear bonus
  is_first_clear BOOLEAN DEFAULT false,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_dungeon_runs_player ON public.dungeon_runs(player_id);
CREATE INDEX idx_dungeon_runs_date ON public.dungeon_runs(created_at);
```

### 9.3 `player_dungeon_stats` Tablosu

```sql
CREATE TABLE IF NOT EXISTS public.player_dungeon_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID NOT NULL REFERENCES players(id),
  dungeon_id TEXT NOT NULL REFERENCES dungeons(id),
  
  total_attempts INTEGER DEFAULT 0,
  total_successes INTEGER DEFAULT 0,
  total_failures INTEGER DEFAULT 0,
  first_clear_at TIMESTAMPTZ,
  best_power_at_clear INTEGER DEFAULT 0,
  today_attempts INTEGER DEFAULT 0,
  today_boss_attempts INTEGER DEFAULT 0,
  
  -- Daily fatigue
  fatigue INTEGER DEFAULT 0,
  fatigue_reset_at DATE DEFAULT CURRENT_DATE,
  
  UNIQUE(player_id, dungeon_id)
);

CREATE INDEX idx_player_dungeon_player ON public.player_dungeon_stats(player_id);
```

### 9.4 Enter Dungeon RPC

```sql
CREATE OR REPLACE FUNCTION public.enter_dungeon(
  p_player_id UUID,
  p_dungeon_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_dungeon RECORD;
  v_player RECORD;
  v_power INTEGER;
  v_fatigue INTEGER;
  v_success_rate NUMERIC;
  v_success BOOLEAN;
  v_is_critical BOOLEAN;
  v_gold INTEGER;
  v_xp INTEGER;
  v_hospitalized BOOLEAN := false;
  v_hospital_until TIMESTAMPTZ;
  v_is_first BOOLEAN := false;
  v_items JSONB := '[]'::JSONB;
  v_today_attempts INTEGER;
  v_today_boss INTEGER;
BEGIN
  -- Get dungeon
  SELECT * INTO v_dungeon FROM dungeons WHERE id = p_dungeon_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'dungeon_not_found');
  END IF;
  
  -- Get player
  SELECT * INTO v_player FROM players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'player_not_found');
  END IF;
  
  -- Hospital check
  IF v_player.hospital_until IS NOT NULL AND v_player.hospital_until > now() THEN
    RETURN jsonb_build_object('error', 'in_hospital');
  END IF;
  
  -- Prison check
  IF v_player.prison_until IS NOT NULL AND v_player.prison_until > now() THEN
    RETURN jsonb_build_object('error', 'in_prison');
  END IF;
  
  -- Energy check
  IF v_player.energy < v_dungeon.energy_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_energy');
  END IF;
  
  -- Get/create daily stats
  INSERT INTO player_dungeon_stats (player_id, dungeon_id)
  VALUES (p_player_id, p_dungeon_id)
  ON CONFLICT (player_id, dungeon_id) DO NOTHING;
  
  -- Reset daily counters if new day
  UPDATE player_dungeon_stats 
  SET today_attempts = 0, today_boss_attempts = 0, fatigue = 0, fatigue_reset_at = CURRENT_DATE
  WHERE player_id = p_player_id AND fatigue_reset_at < CURRENT_DATE;
  
  -- Get fatigue
  SELECT fatigue, today_boss_attempts INTO v_fatigue, v_today_boss
  FROM player_dungeon_stats 
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
  
  -- Boss daily limit check
  IF v_dungeon.is_boss AND v_today_boss >= v_dungeon.daily_boss_limit THEN
    RETURN jsonb_build_object('error', 'boss_daily_limit');
  END IF;
  
  -- Calculate total power (simplified — full calc on client)
  v_power := v_player.attack + v_player.defense + v_player.level * 500;
  
  -- Calculate success rate
  IF v_dungeon.power_requirement = 0 THEN
    v_success_rate := 1.0;
  ELSE
    DECLARE v_ratio NUMERIC;
    BEGIN
      v_ratio := v_power::NUMERIC / v_dungeon.power_requirement;
      IF v_ratio >= 1.5 THEN v_success_rate := 0.95;
      ELSIF v_ratio >= 1.0 THEN v_success_rate := 0.70 + (v_ratio - 1.0) * 0.50;
      ELSIF v_ratio >= 0.5 THEN v_success_rate := 0.25 + (v_ratio - 0.5) * 0.90;
      ELSIF v_ratio >= 0.25 THEN v_success_rate := 0.10 + (v_ratio - 0.25) * 0.60;
      ELSE v_success_rate := GREATEST(0.05, v_ratio * 0.40);
      END IF;
    END;
  END IF;
  
  -- Apply fatigue penalty
  v_success_rate := GREATEST(0.05, v_success_rate - (v_fatigue * 0.02));
  
  -- Apply luck bonus
  v_success_rate := LEAST(0.95, v_success_rate + COALESCE(v_player.luck, 0) * 0.001);
  
  -- Roll for success
  v_success := random() <= v_success_rate;
  v_is_critical := v_success AND random() <= 0.10;
  
  -- Calculate rewards
  IF v_success THEN
    v_gold := v_dungeon.gold_min + floor(random() * (v_dungeon.gold_max - v_dungeon.gold_min));
    v_xp := v_dungeon.xp_reward;
    IF v_is_critical THEN
      v_gold := floor(v_gold * 1.5);
      v_xp := floor(v_xp * 1.5);
    END IF;
  ELSE
    v_gold := floor(v_dungeon.gold_min * 0.3);
    v_xp := floor(v_dungeon.xp_reward * 0.2);
    
    -- Hospital check on failure (inverse of success rate)
    DECLARE v_hospital_chance NUMERIC;
    BEGIN
      v_hospital_chance := GREATEST(0.05, LEAST(0.90, 1.0 - v_success_rate));
      v_hospital_chance := v_hospital_chance * (1 - COALESCE(v_player.luck, 0) * 0.003);
      IF random() <= v_hospital_chance THEN
        v_hospitalized := true;
        v_hospital_until := now() + (
          (v_dungeon.hospital_min_minutes + floor(random() * (v_dungeon.hospital_max_minutes - v_dungeon.hospital_min_minutes)))
          || ' minutes'
        )::INTERVAL;
        
        UPDATE players SET hospital_until = v_hospital_until WHERE id = p_player_id;
      END IF;
    END;
  END IF;
  
  -- First clear check
  IF v_success THEN
    SELECT (first_clear_at IS NULL) INTO v_is_first
    FROM player_dungeon_stats
    WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
    
    IF v_is_first THEN
      v_gold := v_gold + (v_dungeon.gold_max * 5);
      v_xp := v_xp + (v_dungeon.xp_reward * 10);
    END IF;
  END IF;
  
  -- Update player (energy, gold, xp)
  UPDATE players SET 
    energy = energy - v_dungeon.energy_cost,
    gold = gold + v_gold,
    xp = xp + v_xp
  WHERE id = p_player_id;
  
  -- Update dungeon stats
  UPDATE player_dungeon_stats SET
    total_attempts = total_attempts + 1,
    total_successes = total_successes + CASE WHEN v_success THEN 1 ELSE 0 END,
    total_failures = total_failures + CASE WHEN v_success THEN 0 ELSE 1 END,
    first_clear_at = CASE WHEN v_success AND first_clear_at IS NULL THEN now() ELSE first_clear_at END,
    today_attempts = today_attempts + 1,
    today_boss_attempts = today_boss_attempts + CASE WHEN v_dungeon.is_boss THEN 1 ELSE 0 END,
    fatigue = fatigue + 1
  WHERE player_id = p_player_id AND dungeon_id = p_dungeon_id;
  
  -- Insert run record
  INSERT INTO dungeon_runs (
    player_id, dungeon_id, success, is_critical,
    gold_earned, xp_earned, items_dropped,
    hospitalized, hospital_until,
    player_power, success_rate_at_run, fatigue_at_run, is_first_clear
  ) VALUES (
    p_player_id, p_dungeon_id, v_success, v_is_critical,
    v_gold, v_xp, v_items,
    v_hospitalized, v_hospital_until,
    v_power, v_success_rate, v_fatigue, v_is_first
  );
  
  RETURN jsonb_build_object(
    'success', v_success,
    'is_critical', v_is_critical,
    'gold_earned', v_gold,
    'xp_earned', v_xp,
    'items_dropped', v_items,
    'hospitalized', v_hospitalized,
    'hospital_until', v_hospital_until,
    'is_first_clear', v_is_first,
    'fatigue', v_fatigue + 1,
    'success_rate', round(v_success_rate * 100, 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.enter_dungeon(UUID, TEXT) TO authenticated;
```

---

## 10. İlerleme Zaman Çizelgesi (1 Yıllık Sezon)

### Hardcore Oyuncu (Günde 4-6 saat)

| Dönem | Aktivite | Beklenen İlerleme |
|-------|----------|-------------------|
| Hafta 1-2 | Zone 1 farm, full common set craft | Level 5-8, Zindan 1-10 clear, power ~10K |
| Hafta 3-4 | Zone 1 tekrar + Zone 2 başlangıç | Level 10-14, Uncommon set başlangıcı, power ~18K |
| Hafta 5-8 | Zone 2 farm, Uncommon set + enh +3-4 | Level 18-25, Zindan 11-20 clear, power ~35K |
| Ay 3-4 | Zone 3 farm, Rare set + enh +3-5 | Level 30-38, Zindan 21-30 clear, power ~90K |
| Ay 5-6 | Zone 4 farm, Epic set + enh +5-6 | Level 40-48, Zindan 31-40 clear, power ~200K |
| Ay 7-8 | Zone 5 farm, Legendary set + enh +5-7 | Level 50-55, Zindan 41-50 clear, power ~320K |
| Ay 9-10 | Zone 6 farm, Mythic set başlangıcı + enh +5-7 | Level 58-63, Zindan 51-60 clear, power ~400K |
| Ay 11-12 | Zone 7 push, Mythic +8-10, end-game | Level 65-70, Zindan 61-65 clear, power ~450K |

### Casual Oyuncu (Günde 1-2 saat)

| Dönem | Aktivite | Beklenen İlerleme |
|-------|----------|-------------------|
| Hafta 1-3 | Zone 1 farm, common set | Level 5-8, power ~10K |
| Hafta 4-8 | Zone 1-2, uncommon set | Level 12-18, power ~25K |
| Ay 3-5 | Zone 2-3, enhancement +3-4 | Level 22-32, power ~70K |
| Ay 6-8 | Zone 3-4, Rare set + enh +4-5 | Level 35-45, power ~150K |
| Ay 9-10 | Zone 4-5, Epic set + enh +5 | Level 48-55, power ~250K |
| Ay 11-12 | Zone 5-6, Legendary set başlangıcı | Level 55-60, power ~320K |

---

## 11. Uygulama Öncelikleri

1. **Faz 1:** `dungeons` catalog tablosu + 65 dungeon seed data
2. **Faz 2:** `dungeon_runs` + `player_dungeon_stats` tabloları
3. **Faz 3:** `enter_dungeon` RPC fonksiyonu
4. **Faz 4:** Dungeon sayfası UI rebuild (zone listesi, success rate preview, battle animation)
5. **Faz 5:** Loot drop sistemi (item verme)
6. **Faz 6:** Leaderboard entegrasyonu

---

*Bu belge `PLAN_01_ITEMS_EQUIPMENT.md`, `PLAN_02_FACILITIES_RESOURCES.md` ve `PLAN_03_CRAFTING_SYSTEM.md` ile birlikte kullanılmalıdır.*
