# PLAN 10 — Lonca Anıtı Sistemi (Guild Monument)

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** PLAN_04 (zindan boss — blueprint drop), PLAN_06 (ekonomi), PLAN_02 (tesis kaynakları)  
> **Kapsam:** 100 seviyeli lonca anıtı, 3 kaynak tipi, boss blueprint sistemi, lonca sıralaması

---

## 1. Genel Bakış

Lonca Anıtı, lonca üyelerinin birlikte inşa ettiği **100 seviyeli** devasa bir yapıdır. Oyunun **en büyük kolektif hedefi** ve uzun vadeli motivasyon kaynağıdır.

**Temel kurallar:**
- Her loncanın **1 anıtı** vardır (lonca kurulduğunda otomatik Lv 0)
- Anıt yükseltmek için **3 farklı kaynak tipi** gerekir
- Boss'lardan düşen **blueprint'ler** ile milestone seviyeleri açılır
- **100 seviyeye** ulaşan ilk lonca **özel ödül** alır (sezon bazlı yarış)
- Anıt seviyeleri lonca üyelerine **pasif bonus** verir
- Anıt yükseltme hem **gold** hem **kaynak** ister → büyük gold & kaynak sink

**Zaman çizelgesi:**
- Ay 1-3: Bireysel büyüme odağı, lonca kurma
- Ay 4-8: Anıt Lv 1-60 inşaat (orta zorluk; 30 aktif üyeli lonca ulaşılabilir hedef)
- Ay 9-12: Anıt Lv 60-100 yarışı (çok zor; Lv 100 yalnızca en organize, 40-50 üyeli lonca için ulaşılabilir)

**Lonca büyüklüğüne göre beklenen Lv 100 erişimi:**
- 10 üye: Lv 50-60 (sezon sonu)
- 20 üye: Lv 70-80 (sezon sonu)
- 30 üye: Lv 85-95 (sezon sonu; Lv 100 sınırda)
- 40-50 üye: Lv 95-100 (sezon sonu; Lv 100 ulaşılabilir ama trivial değil)

---

## 2. Kaynak Sistemi — 3 Temel Kaynak Tipi

### 2.1 Kaynak Tipleri

| Kaynak | Adı | Nereden Gelir | Kullanım |
|--------|-----|---------------|---------|
| **Structural** | Yapı Taşı | Tesis üretimi + Zindan drop | Anıt iskelet yapısı (Lv 1-50 ağırlıklı) |
| **Mystical** | Mistik Öz | Boss drop + Crafting yan ürünü | Anıt büyü sistemi (Lv 30-80 ağırlıklı) |
| **Critical** | Kritik Parça | Zone 6-7 exclusive drop + Boss blueprint | Anıt son katman (Lv 70-100 zorunlu) |

### 2.2 Kaynak Kazanma Yolları

#### Structural (Yapı Taşı)

| Kaynak | Miktar | Sıklık |
|--------|--------|--------|
| Tesis üretimi (her kaynak toplama) | 1-5 | Her toplama |
| Zindan clear (Zone 1-3) | 2-10 | Her koşu |
| Zindan clear (Zone 4-5) | 5-20 | Her koşu |
| Zindan clear (Zone 6-7) | 10-30 | Her koşu |
| Haftalık lonca görevi | 50-200 | Haftalık |
| Market satın alma | Değişken | Sürekli |

**Günlük ortalama Structural kazanım (bir oyuncu):** 50-200

#### Mystical (Mistik Öz)

| Kaynak | Miktar | Sıklık |
|--------|--------|--------|
| Boss clear (Zone 1-3) | 5-20 | Boss başına |
| Boss clear (Zone 4-5) | 15-40 | Boss başına |
| Boss clear (Zone 6-7) | 30-80 | Boss başına |
| Crafting yan ürünü (Epic+) | 1-5 | Her craft |
| Haftalık lonca görevi | 20-80 | Haftalık |
| Tesis üretimi (Lv 7+ tesis) | 1-3 | Her toplama |

**Günlük ortalama Mystical kazanım (bir oyuncu):** 20-80

#### Critical (Kritik Parça)

| Kaynak | Miktar | Sıklık |
|--------|--------|--------|
| Zone 6 zindan clear | 1-3 | Her koşu (%30 drop) |
| Zone 7 zindan clear | 2-5 | Her koşu (%50 drop) |
| Zone 5-7 Boss clear | 5-15 | Boss başına |
| Boss Blueprint parçalama | 3-10 | Blueprint başına |
| Sezon etkinlik ödülü | 20-50 | Etkinlik başına |

**Günlük ortalama Critical kazanım (bir oyuncu, end-game):** 5-30

### 2.3 Kaynak Biriktirme Mekanizması

Lonca üyeleri kaynaklarını **lonca deposuna** bağışlar (kişisel envanterden):

```
Bağış → Lonca Deposu → Anıt yükseltmede kullanım
   ↓
  Katkı puanı (contribution) → Lonca içi sıralama
```

---

## 3. Anıt Seviyeleri (1-100) — Detaylı Tablo

### 3.0 Lonca Büyüklüğüne Göre Maliyet Ölçeklendirmesi

Anıt maliyetleri aşağıdaki tabloda lonca büyüklüğüne (aktif üye sayısına) göre otomatik olarak ölçeklenir. Bu sayede küçük loncalar sezon boyunca anlamlı ilerleme yapabilirken, Lv 100 yalnızca büyük ve organize loncalara açık kalır.

**Etkin Maliyet = Tablo Maliyeti × Boyut Çarpanı**

| Aktif Üye Sayısı | Boyut Çarpanı | Açıklama |
|-----------------|--------------|---------|
| 1-10 | ×0.35 | Küçük lonca — maliyetler %65 düşük |
| 11-20 | ×0.55 | Orta lonca |
| 21-30 | ×0.75 | Büyük lonca |
| 31-40 | ×0.90 | Büyük-fazla lonca |
| 41-50 | ×1.00 | Maksimum lonca — tam tablo maliyeti |

> **Örnek:** Lv 50 yükseltmesi (tablo: 1.2B gold). 20 üyeli lonca için: 1.2B × 0.55 = 660M gold.

### 3.1 Seviye 1-25: Temel İnşaat

| Lv | Structural | Mystical | Critical | Gold | Toplam Maliyet (yaklaşık) |
|----|-----------|----------|----------|------|--------------------------|
| 1 | 100 | 0 | 0 | 500,000 | 500K |
| 2 | 200 | 0 | 0 | 1,000,000 | 1M |
| 3 | 350 | 10 | 0 | 1,500,000 | 1.5M |
| 4 | 500 | 20 | 0 | 2,000,000 | 2M |
| 5 | 700 | 30 | 0 | 3,000,000 | 3M |
| 6 | 900 | 50 | 0 | 4,000,000 | 4M |
| 7 | 1,200 | 70 | 0 | 5,000,000 | 5M |
| 8 | 1,500 | 100 | 0 | 7,000,000 | 7M |
| 9 | 2,000 | 130 | 0 | 9,000,000 | 9M |
| 10 | 2,500 | 170 | 0 | 12,000,000 | 12M |
| 11 | 3,000 | 220 | 0 | 15,000,000 | 15M |
| 12 | 3,500 | 280 | 0 | 18,000,000 | 18M |
| 13 | 4,000 | 350 | 0 | 22,000,000 | 22M |
| 14 | 4,500 | 420 | 0 | 26,000,000 | 26M |
| 15 | 5,000 | 500 | 5 | 30,000,000 | 30M |
| 16 | 5,500 | 600 | 10 | 35,000,000 | 35M |
| 17 | 6,000 | 700 | 15 | 40,000,000 | 40M |
| 18 | 6,500 | 800 | 20 | 45,000,000 | 45M |
| 19 | 7,000 | 900 | 30 | 50,000,000 | 50M |
| 20 | 8,000 | 1,000 | 40 | 60,000,000 | 60M |
| 21 | 9,000 | 1,200 | 50 | 70,000,000 | 70M |
| 22 | 10,000 | 1,400 | 65 | 80,000,000 | 80M |
| 23 | 11,000 | 1,600 | 80 | 90,000,000 | 90M |
| 24 | 12,000 | 1,800 | 100 | 100,000,000 | 100M |
| 25 | 13,000 | 2,000 | 120 | 120,000,000 | 120M |

**Lv 1-25 toplam:** ~845M gold, ~120K structural, ~14K mystical, ~535 critical

### 3.2 Seviye 26-50: Güçlendirme Aşaması

| Lv | Structural | Mystical | Critical | Gold |
|----|-----------|----------|----------|------|
| 26 | 14,000 | 2,500 | 150 | 140,000,000 |
| 27 | 15,000 | 3,000 | 180 | 160,000,000 |
| 28 | 16,000 | 3,500 | 220 | 180,000,000 |
| 29 | 17,000 | 4,000 | 260 | 200,000,000 |
| 30 | 18,000 | 5,000 | 300 | 250,000,000 |
| 31 | 19,000 | 5,500 | 350 | 280,000,000 |
| 32 | 20,000 | 6,000 | 400 | 310,000,000 |
| 33 | 21,000 | 6,500 | 450 | 340,000,000 |
| 34 | 22,000 | 7,000 | 500 | 370,000,000 |
| 35 | 23,000 | 8,000 | 560 | 400,000,000 |
| 36 | 24,000 | 9,000 | 620 | 440,000,000 |
| 37 | 25,000 | 10,000 | 680 | 480,000,000 |
| 38 | 26,000 | 11,000 | 750 | 520,000,000 |
| 39 | 27,000 | 12,000 | 820 | 560,000,000 |
| 40 | 28,000 | 13,000 | 900 | 600,000,000 |
| 41 | 30,000 | 14,000 | 1,000 | 650,000,000 |
| 42 | 32,000 | 15,000 | 1,100 | 700,000,000 |
| 43 | 34,000 | 16,000 | 1,200 | 750,000,000 |
| 44 | 36,000 | 17,000 | 1,300 | 800,000,000 |
| 45 | 38,000 | 18,000 | 1,400 | 850,000,000 |
| 46 | 40,000 | 19,000 | 1,500 | 900,000,000 |
| 47 | 42,000 | 20,000 | 1,600 | 950,000,000 |
| 48 | 44,000 | 22,000 | 1,800 | 1,000,000,000 |
| 49 | 46,000 | 24,000 | 2,000 | 1,100,000,000 |
| 50 | 50,000 | 26,000 | 2,200 | 1,200,000,000 |

**Lv 26-50 toplam:** ~16.0B gold, ~732K structural, ~282K mystical, ~24K critical

### 3.3 Seviye 51-75: İleri İnşaat

| Lv | Structural | Mystical | Critical | Gold |
|----|-----------|----------|----------|------|
| 51 | 52,000 | 28,000 | 2,500 | 1,300,000,000 |
| 52 | 54,000 | 30,000 | 2,800 | 1,400,000,000 |
| 53 | 56,000 | 32,000 | 3,100 | 1,500,000,000 |
| 54 | 58,000 | 34,000 | 3,400 | 1,600,000,000 |
| 55 | 60,000 | 36,000 | 3,700 | 1,700,000,000 |
| 56 | 63,000 | 38,000 | 4,000 | 1,850,000,000 |
| 57 | 66,000 | 40,000 | 4,300 | 2,000,000,000 |
| 58 | 69,000 | 42,000 | 4,600 | 2,150,000,000 |
| 59 | 72,000 | 44,000 | 4,900 | 2,300,000,000 |
| 60 | 75,000 | 48,000 | 5,200 | 2,500,000,000 |
| 61 | 78,000 | 50,000 | 5,500 | 2,700,000,000 |
| 62 | 81,000 | 52,000 | 5,800 | 2,900,000,000 |
| 63 | 84,000 | 54,000 | 6,200 | 3,100,000,000 |
| 64 | 87,000 | 56,000 | 6,600 | 3,300,000,000 |
| 65 | 90,000 | 58,000 | 7,000 | 3,500,000,000 |
| 66 | 93,000 | 60,000 | 7,500 | 3,700,000,000 |
| 67 | 96,000 | 63,000 | 8,000 | 3,900,000,000 |
| 68 | 100,000 | 66,000 | 8,500 | 4,200,000,000 |
| 69 | 104,000 | 69,000 | 9,000 | 4,500,000,000 |
| 70 | 108,000 | 72,000 | 9,500 | 4,800,000,000 |
| 71 | 112,000 | 75,000 | 10,000 | 5,100,000,000 |
| 72 | 116,000 | 78,000 | 10,500 | 5,400,000,000 |
| 73 | 120,000 | 81,000 | 11,000 | 5,700,000,000 |
| 74 | 125,000 | 85,000 | 11,500 | 6,000,000,000 |
| 75 | 130,000 | 90,000 | 12,000 | 6,500,000,000 |

**Lv 51-75 toplam:** ~86B gold, ~2.25M structural, ~1.37M mystical, ~169K critical

### 3.4 Seviye 76-100: Efsanevi İnşaat

| Lv | Structural | Mystical | Critical | Gold | Özel Gereksinim |
|----|-----------|----------|----------|------|----------------|
| 76 | 135,000 | 95,000 | 13,000 | 7,000,000,000 | — |
| 77 | 140,000 | 100,000 | 14,000 | 7,500,000,000 | — |
| 78 | 145,000 | 105,000 | 15,000 | 8,000,000,000 | — |
| 79 | 150,000 | 110,000 | 16,000 | 8,500,000,000 | — |
| 80 | 160,000 | 120,000 | 18,000 | 10,000,000,000 | **Blueprint: Phoenix** |
| 81 | 165,000 | 125,000 | 19,000 | 10,500,000,000 | — |
| 82 | 170,000 | 130,000 | 20,000 | 11,000,000,000 | — |
| 83 | 175,000 | 135,000 | 21,000 | 11,500,000,000 | — |
| 84 | 180,000 | 140,000 | 22,000 | 12,000,000,000 | — |
| 85 | 190,000 | 150,000 | 24,000 | 13,000,000,000 | **Blueprint: Leviathan** |
| 86 | 195,000 | 155,000 | 25,000 | 13,500,000,000 | — |
| 87 | 200,000 | 160,000 | 26,000 | 14,000,000,000 | — |
| 88 | 210,000 | 165,000 | 28,000 | 15,000,000,000 | — |
| 89 | 220,000 | 170,000 | 30,000 | 16,000,000,000 | — |
| 90 | 230,000 | 180,000 | 32,000 | 18,000,000,000 | **Blueprint: Titan** |
| 91 | 240,000 | 190,000 | 34,000 | 19,000,000,000 | — |
| 92 | 250,000 | 200,000 | 36,000 | 20,000,000,000 | — |
| 93 | 260,000 | 210,000 | 38,000 | 21,000,000,000 | — |
| 94 | 270,000 | 220,000 | 40,000 | 22,000,000,000 | — |
| 95 | 280,000 | 230,000 | 42,000 | 24,000,000,000 | **Blueprint: World Eater** |
| 96 | 300,000 | 245,000 | 45,000 | 26,000,000,000 | — |
| 97 | 320,000 | 260,000 | 48,000 | 28,000,000,000 | — |
| 98 | 340,000 | 280,000 | 52,000 | 30,000,000,000 | — |
| 99 | 360,000 | 300,000 | 56,000 | 35,000,000,000 | — |
| 100 | 400,000 | 350,000 | 60,000 | 50,000,000,000 | **Blueprint: Eternal** |

**Lv 76-100 toplam:** ~474B gold, ~5.68M structural, ~4.65M mystical, ~778K critical

### 3.5 Genel Toplam (Lv 1-100)

| Kaynak | Toplam Gereksinim |
|--------|------------------|
| **Gold** | ~577B |
| **Structural** | ~8.8M |
| **Mystical** | ~6.3M |
| **Critical** | ~972K |

> **Not:** Yukarıdaki değerler 41-50 üyeli (tam boyut) lonca için geçerlidir. Küçük loncalar §3.0 boyut çarpanını uygular.

---

## 4. Boss Blueprint Sistemi

### 4.1 Blueprint Nedir?

Belirli anıt milestone seviyelerinde (80, 85, 90, 95, 100) yükseltme için özel bir **blueprint** gerekir. Bu blueprint'ler sadece zone boss'larından düşer.

### 4.2 Blueprint Tablosu

| Blueprint | Gerekli Anıt Lv | Düşen Boss | Drop Oranı | Gerekli Parça |
|-----------|-----------------|-----------|-----------|---------------|
| Phoenix Blueprint | Lv 80 | Zone 5 Boss (#50) | %5 / kill | 10 parça |
| Leviathan Blueprint | Lv 85 | Zone 6 Boss (#59) | %3 / kill | 15 parça |
| Titan Blueprint | Lv 90 | Zone 6 Boss (#60) | %2 / kill | 20 parça |
| World Eater Blueprint | Lv 95 | Zone 7 Boss (#64) | %1 / kill | 25 parça |
| Eternal Blueprint | Lv 100 | Zone 7 Final Boss (#65) | %0.5 / kill | 30 parça |

### 4.3 Blueprint Toplama Süresi Tahmini

```
Zone 5 Boss: 3 kill/gün limit, 20 üye aktif
  → 60 kill/gün × %5 = 3 parça/gün → 10 parça = ~3.3 gün

Zone 7 Final Boss: 3 kill/gün limit, 20 üye, ancak hepsi Zone 7'ye ulaşamaz
  → Diyelim 10 üye Zone 7 erişimi: 30 kill/gün × %0.5 = 0.15 parça/gün → 30 parça = ~200 gün

> **Boss limiti uyumu:** Zone 5-7 boss'ları günlük 3 deneme limiti ile kısıtlıdır (PLAN_04). Bu,
> blueprint farming'in doğrudan üye sayısı ile ölçeklendiğini gösterir; daha fazla üye = daha çok boss
> kill = daha hızlı blueprint toplama. 30 üyeli lonca Eternal Blueprint'i ~130 günde tamamlar
> (30 üye × 3 kill × %0.5 = 0.45 parça/gün → 30 / 0.45 ≈ 67 gün Zone 7 erişimi varsayımıyla).
```

### 4.4 Blueprint Parçalama

Kullanılmayan veya fazla gelen blueprint parçaları → Critical kaynak dönüştürülebilir:

```
1 blueprint parçası → 3-10 Critical kaynak (rarity'e göre)
```

---

## 5. Anıt Bonusları (Pasif Etki)

Anıt seviyesi lonca üyelerine pasif bonus verir:

### 5.1 Milestone Bonusları

| Anıt Lv | Bonus | Etki |
|---------|-------|------|
| 5 | Lonca XP Bonusu | Üyelere +%5 XP |
| 10 | Lonca Gold Bonusu | Üyelere +%3 gold kazanımı |
| 15 | Enerji Bonusu | +5 max enerji |
| 20 | Overdose Koruması | Overdose şansı -%10 |
| 25 | Tesis Hız Bonusu | Tesis üretim süresi -%5 |
| 30 | Zindan Luck | Zindan loot luck +10 |
| 35 | Crafting Bonusu | Crafting başarı oranı +%3 |
| 40 | PvP Shield | PvP gold kaybı -%10 |
| 45 | Enhancement Bonusu | Enhancement gold maliyeti -%3 |
| 50 | **Büyük Milestone** | +10 max enerji, +%5 XP, lonca kozmetik |
| 55 | Boss Damage | Boss'lara +%5 hasar |
| 60 | Hospital Azaltma | Hastane süresi -%10 |
| 65 | Enhancement Shield | +6 yıkım oranı -%2 |
| 70 | Reputation Bonusu | Rep kazanımı +%5 |
| 75 | **Büyük Milestone** | +15 max enerji, +%8 XP, özel anıt görünümü |
| 80 | Phoenix Gücü | Overdose'dan ilk kurtulma (günde 1 kez) |
| 85 | Leviathan Gücü | Zindan enerji maliyeti -%2 |
| 90 | Titan Gücü | Enhancement gold maliyeti -%5 (toplam -%8) |
| 95 | World Eater Gücü | Tüm stat'lara +%3 |
| 100 | **ETERNAL** | +20 max enerji, tüm stat +%5, özel aura, sunucu duyurusu |

### 5.2 Sürekli Bonuslar (Her 5 Seviye)

Her 5 seviyede tüm üyelere:
- Attack/Defense/Health +%0.5
- Gold kazanımı +%0.2

Lv 100'de toplam sürekli bonus: +%10 stat, +%4 gold

---

## 6. Lonca Katkı Sistemi

### 6.1 Katkı Puanı (Contribution)

Oyuncular kaynak bağışladığında katkı puanı kazanır:

```
contribution = (structural_donated × 1) + (mystical_donated × 3) + (critical_donated × 10) + (gold_donated / 100,000)
```

### 6.2 Katkı Sıralaması ve Ödüller

| Sıra (lonca içi) | Haftalık Ödül |
|-------------------|-------------|
| 1. Katkıcı | 500,000 gold + 50 gem + "Loncanın Direği" unvanı |
| 2-3. Katkıcı | 250,000 gold + 25 gem |
| 4-10. Katkıcı | 100,000 gold |
| Tüm katkıcılar | Reputation +100 (bağış başına) |

### 6.3 Günlük Bağış Limitleri

anti-abuse ve devasa lonca avantajını dengelemek için:

| Kaynak | Günlük Max Bağış / Kişi |
|--------|------------------------|
| Structural | 200 |
| Mystical | 100 |
| Critical | 30 |
| Gold | 50,000,000 |

---

## 7. Lonca Yapısı

### 7.1 Lonca Parametreleri

| Parametre | Değer |
|-----------|-------|
| Min lonca kurma level | 20 |
| Lonca kurma maliyeti | 10,000,000 gold |
| Max üye sayısı | 30 (yükseltilebilir) |
| Max üye (Anıt Lv 25+) | 40 |
| Max üye (Anıt Lv 50+) | 50 |
| Roller | Lider, Komutan (3), Üye, Çırak |
| Lonca savaşları | v2'de (bu belgenin kapsamı dışı) |

### 7.2 Lonca Büyüklüğü ve Anıt İlerleme Hızı

Anıt ilerleme hızı lonca büyüklüğüne doğrudan bağlıdır:

| Lonca Boyutu | Günlük Structural | Günlük Mystical | Günlük Critical | Günlük Gold |
|-------------|------------------|----------------|----------------|------------|
| 10 üye (erken) | 500-2,000 | 200-800 | 50-300 | 50M-200M |
| 20 üye (orta) | 1,000-4,000 | 400-1,600 | 100-600 | 100M-500M |
| 30 üye (full) | 1,500-6,000 | 600-2,400 | 150-900 | 150M-750M |
| 50 üye (max, Lv 50+) | 2,500-10,000 | 1,000-4,000 | 250-1,500 | 250M-1.5B |

### 7.3 Anıt Tamamlama Süresi Tahmini (30 Aktif Üye)

| Milestone | Gerekli Kaynak (kümülatif) | Tahmini Süre |
|-----------|--------------------------|-------------|
| Lv 10 | 10K str, 500 mys, 0 crit, 46M gold | ~Hafta 2-3 |
| Lv 25 | 120K str, 14K mys, 535 crit, 845M gold | ~Ay 1.5-2 |
| Lv 50 | 852K str, 296K mys, 25K crit, 16.8B gold | ~Ay 5-6 |
| Lv 75 | 3.1M str, 1.7M mys, 194K crit, 103B gold | ~Ay 8-9 |
| Lv 100 | 8.8M str, 6.3M mys, 972K crit, 577B gold | ~Ay 11-12+ |

> **Tasarım amacı:** 30 kişilik aktif lonca Lv 85-95'e ulaşır; Lv 100 sınırda. 40-50 üyeli tam lonca Lv 100'e ulaşabilir. Sezon sonu yarışı gerilimli fakat erişilmez değil. Boyut çarpanı (§3.0) küçük loncaların sezon boyunca anlamlı ilerleme yapmasını sağlar.

---

## 8. Anıt Yarışı (Sezon Bazlı)

### 8.1 Sıralama Sistemi

Tüm loncalar anıt seviyesine göre sıralanır. Eşitlik durumunda: ilk ulaşan kazanır.

### 8.2 Sezon Sonu Ödülleri (Lonca Bazlı)

| Sıra | Tüm Üyelere Gem | Lonca Ödülü | Unvan |
|------|-----------------|-------------|-------|
| 1 | 5,000 gem/kişi | "Efsanevi Anıt" rozeti, altın anıt skin | "Dünya Mimarı" |
| 2 | 3,000 gem/kişi | Gümüş anıt skin | "Usta Mimar" |
| 3 | 2,000 gem/kişi | Bronz anıt skin | "Büyük Mimar" |
| 4-10 | 1,000 gem/kişi | Özel çerçeve | "Yetenekli Mimar" |
| 11-25 | 500 gem/kişi | — | "Mimar" |

### 8.3 İlk Lv 100 Başarımı

**Sunucu tarihinde ilk kez Lv 100'e ulaşan lonca:**
- Kalıcı sunucu duyurusu
- Özel "İlk" rozeti (tüm üyelere, kalıcı — sezon reset'i bile kaldırmaz)
- 10,000 gem / kişi
- Lonca ismi "Hall of Fame"'e eklenir

---

## 9. Veritabanı Şeması

### 9.1 Lonca Tablosu Güncellemeleri

```sql
-- game.guilds (mevcut tablo güncelleme)
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_level int NOT NULL DEFAULT 0;
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_structural bigint NOT NULL DEFAULT 0;
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_mystical bigint NOT NULL DEFAULT 0;
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_critical bigint NOT NULL DEFAULT 0;
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_gold_pool bigint NOT NULL DEFAULT 0;
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_100_first boolean NOT NULL DEFAULT false;
ALTER TABLE game.guilds ADD COLUMN IF NOT EXISTS monument_100_at timestamptz;
```

### 9.2 Yeni Tablolar

```sql
-- Blueprint envanteri (lonca bazlı)
CREATE TABLE game.guild_blueprints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id uuid REFERENCES game.guilds(id) NOT NULL,
  blueprint_type text NOT NULL CHECK (blueprint_type IN ('phoenix', 'leviathan', 'titan', 'world_eater', 'eternal')),
  fragments int NOT NULL DEFAULT 0,
  is_complete boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  
  UNIQUE(guild_id, blueprint_type)
);

-- Üye katkı takibi
CREATE TABLE game.guild_contributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id uuid REFERENCES game.guilds(id) NOT NULL,
  user_id uuid REFERENCES game.users(id) NOT NULL,
  structural_donated bigint NOT NULL DEFAULT 0,
  mystical_donated bigint NOT NULL DEFAULT 0,
  critical_donated bigint NOT NULL DEFAULT 0,
  gold_donated bigint NOT NULL DEFAULT 0,
  contribution_score bigint NOT NULL DEFAULT 0,
  last_donated_at timestamptz,
  
  UNIQUE(guild_id, user_id)
);

-- Günlük bağış tracking (limit enforcement)
CREATE TABLE game.guild_daily_donations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id uuid REFERENCES game.guilds(id) NOT NULL,
  user_id uuid REFERENCES game.users(id) NOT NULL,
  donation_date date NOT NULL DEFAULT CURRENT_DATE,
  structural_today int NOT NULL DEFAULT 0,
  mystical_today int NOT NULL DEFAULT 0,
  critical_today int NOT NULL DEFAULT 0,
  gold_today bigint NOT NULL DEFAULT 0,
  
  UNIQUE(guild_id, user_id, donation_date)
);

-- Anıt yükseltme geçmişi
CREATE TABLE game.monument_upgrades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id uuid REFERENCES game.guilds(id) NOT NULL,
  from_level int NOT NULL,
  to_level int NOT NULL,
  structural_spent bigint NOT NULL,
  mystical_spent bigint NOT NULL,
  critical_spent bigint NOT NULL,
  gold_spent bigint NOT NULL,
  upgraded_by uuid REFERENCES game.users(id) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Lonca sıralama snapshot
CREATE TABLE game.guild_leaderboard (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id uuid REFERENCES game.guilds(id) NOT NULL,
  week_start date NOT NULL,
  monument_level int NOT NULL,
  member_count int NOT NULL,
  rank int,
  
  UNIQUE(guild_id, week_start)
);
```

---

## 10. RPC Fonksiyonları (Önerilen)

### 10.1 Kaynak Bağışı

```sql
CREATE FUNCTION public.donate_to_monument(
  p_user_id uuid,
  p_structural int DEFAULT 0,
  p_mystical int DEFAULT 0,
  p_critical int DEFAULT 0,
  p_gold bigint DEFAULT 0
)
RETURNS json AS $$
DECLARE
  v_user record;
  v_guild_id uuid;
  v_daily record;
  v_contribution_score bigint;
BEGIN
  -- Kullanıcı ve lonca kontrolü
  SELECT * INTO v_user FROM game.users WHERE id = p_user_id;
  IF v_user.guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;
  v_guild_id := v_user.guild_id;

  -- Negatif değer kontrolü
  IF p_structural < 0 OR p_mystical < 0 OR p_critical < 0 OR p_gold < 0 THEN
    RETURN json_build_object('success', false, 'error', 'Geçersiz miktar');
  END IF;

  -- Günlük limit kontrolü
  SELECT * INTO v_daily FROM game.guild_daily_donations
  WHERE guild_id = v_guild_id AND user_id = p_user_id AND donation_date = CURRENT_DATE;

  IF v_daily IS NOT NULL THEN
    IF v_daily.structural_today + p_structural > 200 OR
       v_daily.mystical_today + p_mystical > 100 OR
       v_daily.critical_today + p_critical > 30 OR
       v_daily.gold_today + p_gold > 50000000 THEN
      RETURN json_build_object('success', false, 'error', 'Günlük bağış limiti aşıldı');
    END IF;
  END IF;

  -- Envanter/gold kontrolü (basitleştirilmiş)
  -- TODO: Monument kaynak envanterini game.users veya ayrı tabloda track et
  IF v_user.gold < p_gold THEN
    RETURN json_build_object('success', false, 'error', 'Gold yetersiz');
  END IF;

  -- Gold düşür
  UPDATE game.users SET gold = gold - p_gold WHERE id = p_user_id;

  -- Lonca deposuna ekle
  UPDATE game.guilds SET
    monument_structural = monument_structural + p_structural,
    monument_mystical = monument_mystical + p_mystical,
    monument_critical = monument_critical + p_critical,
    monument_gold_pool = monument_gold_pool + p_gold
  WHERE id = v_guild_id;

  -- Katkı puanı hesapla
  v_contribution_score := (p_structural * 1) + (p_mystical * 3) + (p_critical * 10) + (p_gold / 100000);

  -- Katkı kaydı güncelle
  INSERT INTO game.guild_contributions (guild_id, user_id, structural_donated, mystical_donated, critical_donated, gold_donated, contribution_score, last_donated_at)
  VALUES (v_guild_id, p_user_id, p_structural, p_mystical, p_critical, p_gold, v_contribution_score, now())
  ON CONFLICT (guild_id, user_id) DO UPDATE SET
    structural_donated = game.guild_contributions.structural_donated + p_structural,
    mystical_donated = game.guild_contributions.mystical_donated + p_mystical,
    critical_donated = game.guild_contributions.critical_donated + p_critical,
    gold_donated = game.guild_contributions.gold_donated + p_gold,
    contribution_score = game.guild_contributions.contribution_score + v_contribution_score,
    last_donated_at = now();

  -- Günlük tracking
  INSERT INTO game.guild_daily_donations (guild_id, user_id, donation_date, structural_today, mystical_today, critical_today, gold_today)
  VALUES (v_guild_id, p_user_id, CURRENT_DATE, p_structural, p_mystical, p_critical, p_gold)
  ON CONFLICT (guild_id, user_id, donation_date) DO UPDATE SET
    structural_today = game.guild_daily_donations.structural_today + p_structural,
    mystical_today = game.guild_daily_donations.mystical_today + p_mystical,
    critical_today = game.guild_daily_donations.critical_today + p_critical,
    gold_today = game.guild_daily_donations.gold_today + p_gold;

  -- Rep bonusu
  UPDATE game.users SET reputation = reputation + LEAST(v_contribution_score / 10, 100)
  WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'contribution_score', v_contribution_score
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 10.2 Anıt Yükseltme

```sql
CREATE FUNCTION public.upgrade_monument(p_user_id uuid)
RETURNS json AS $$
DECLARE
  v_user record;
  v_guild record;
  v_next_level int;
  v_req_structural int;
  v_req_mystical int;
  v_req_critical int;
  v_req_gold bigint;
  v_blueprint_needed text;
BEGIN
  -- Kullanıcı ve lonca kontrolü
  SELECT * INTO v_user FROM game.users WHERE id = p_user_id;
  IF v_user.guild_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Bir loncaya üye değilsiniz');
  END IF;

  -- Yetki kontrolü (sadece Lider veya Komutan)
  IF v_user.guild_role NOT IN ('leader', 'commander') THEN
    RETURN json_build_object('success', false, 'error', 'Yetkiniz yok (Lider veya Komutan gerekli)');
  END IF;

  SELECT * INTO v_guild FROM game.guilds WHERE id = v_user.guild_id;
  v_next_level := v_guild.monument_level + 1;

  IF v_next_level > 100 THEN
    RETURN json_build_object('success', false, 'error', 'Anıt zaten maksimum seviyede');
  END IF;

  -- Gereksinim tablosundan gereksinimleri al
  -- (Gerçek implementasyonda bir lookup tablosu veya fonksiyon olacak)
  -- Burada basitleştirilmiş hesaplama:
  v_req_structural := 100 * v_next_level + v_next_level * v_next_level * 3;
  v_req_mystical := GREATEST(0, (v_next_level - 2) * v_next_level * 2);
  v_req_critical := GREATEST(0, (v_next_level - 14) * v_next_level);
  v_req_gold := (500000 * v_next_level + v_next_level * v_next_level * 100000)::bigint;

  -- Blueprint kontrolü (milestone seviyeleri)
  v_blueprint_needed := CASE v_next_level
    WHEN 80 THEN 'phoenix'
    WHEN 85 THEN 'leviathan'
    WHEN 90 THEN 'titan'
    WHEN 95 THEN 'world_eater'
    WHEN 100 THEN 'eternal'
    ELSE NULL
  END;

  IF v_blueprint_needed IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM game.guild_blueprints
      WHERE guild_id = v_guild.id AND blueprint_type = v_blueprint_needed AND is_complete = true
    ) THEN
      RETURN json_build_object('success', false, 'error', v_blueprint_needed || ' blueprint tamamlanmamış');
    END IF;
  END IF;

  -- Kaynak kontrolü
  IF v_guild.monument_structural < v_req_structural OR
     v_guild.monument_mystical < v_req_mystical OR
     v_guild.monument_critical < v_req_critical OR
     v_guild.monument_gold_pool < v_req_gold THEN
    RETURN json_build_object('success', false, 'error', 'Kaynak yetersiz',
      'required', json_build_object(
        'structural', v_req_structural, 'mystical', v_req_mystical,
        'critical', v_req_critical, 'gold', v_req_gold
      ),
      'current', json_build_object(
        'structural', v_guild.monument_structural, 'mystical', v_guild.monument_mystical,
        'critical', v_guild.monument_critical, 'gold', v_guild.monument_gold_pool
      )
    );
  END IF;

  -- Kaynakları düşür ve seviye artır
  UPDATE game.guilds SET
    monument_level = v_next_level,
    monument_structural = monument_structural - v_req_structural,
    monument_mystical = monument_mystical - v_req_mystical,
    monument_critical = monument_critical - v_req_critical,
    monument_gold_pool = monument_gold_pool - v_req_gold,
    monument_100_first = CASE WHEN v_next_level = 100 AND NOT EXISTS (
      SELECT 1 FROM game.guilds WHERE monument_level >= 100 AND id != v_guild.id
    ) THEN true ELSE monument_100_first END,
    monument_100_at = CASE WHEN v_next_level = 100 THEN now() ELSE monument_100_at END
  WHERE id = v_guild.id;

  -- Yükseltme logu
  INSERT INTO game.monument_upgrades (guild_id, from_level, to_level, structural_spent, mystical_spent, critical_spent, gold_spent, upgraded_by)
  VALUES (v_guild.id, v_guild.monument_level, v_next_level, v_req_structural, v_req_mystical, v_req_critical, v_req_gold, p_user_id);

  RETURN json_build_object(
    'success', true,
    'new_level', v_next_level,
    'is_first_100', CASE WHEN v_next_level = 100 THEN true ELSE false END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 11. TypeScript Tipleri

```typescript
export interface GuildMonument {
  level: number;
  structural: number;
  mystical: number;
  critical: number;
  gold_pool: number;
  is_100_first: boolean;
  reached_100_at: string | null;
}

export interface GuildBlueprint {
  id: string;
  guild_id: string;
  blueprint_type: BlueprintType;
  fragments: number;
  is_complete: boolean;
  completed_at: string | null;
}

export type BlueprintType = 'phoenix' | 'leviathan' | 'titan' | 'world_eater' | 'eternal';

export const BLUEPRINT_REQUIREMENTS: Record<BlueprintType, { monument_level: number; fragments_needed: number }> = {
  phoenix:      { monument_level: 80,  fragments_needed: 10 },
  leviathan:    { monument_level: 85,  fragments_needed: 15 },
  titan:        { monument_level: 90,  fragments_needed: 20 },
  world_eater:  { monument_level: 95,  fragments_needed: 25 },
  eternal:      { monument_level: 100, fragments_needed: 30 },
};

export interface GuildContribution {
  guild_id: string;
  user_id: string;
  structural_donated: number;
  mystical_donated: number;
  critical_donated: number;
  gold_donated: number;
  contribution_score: number;
  last_donated_at: string | null;
}

export interface MonumentUpgradeResult {
  success: boolean;
  new_level?: number;
  is_first_100?: boolean;
  error?: string;
  required?: {
    structural: number;
    mystical: number;
    critical: number;
    gold: number;
  };
  current?: {
    structural: number;
    mystical: number;
    critical: number;
    gold: number;
  };
}

export const MONUMENT_BONUSES: Record<number, { type: string; description: string; value: number }> = {
  5:   { type: 'xp_bonus',          description: 'Lonca XP Bonusu',         value: 5 },
  10:  { type: 'gold_bonus',        description: 'Lonca Gold Bonusu',       value: 3 },
  15:  { type: 'energy_bonus',      description: 'Max Enerji +5',           value: 5 },
  20:  { type: 'overdose_protection', description: 'Overdose Şansı -%10',    value: 10 }, // 10 = yüzde puan azalma
  25:  { type: 'facility_speed',    description: 'Tesis Üretim -%5',        value: 5 },
  30:  { type: 'loot_luck',         description: 'Zindan Loot Luck +10',    value: 10 },
  35:  { type: 'craft_bonus',       description: 'Crafting Başarı +%3',     value: 3 },
  40:  { type: 'pvp_shield',        description: 'PvP Gold Kaybı -%10',     value: 10 },
  45:  { type: 'enhance_discount',  description: 'Enhancement Cost -%3',    value: 3 },
  50:  { type: 'mega_bonus',        description: 'Büyük Milestone',         value: 0 },
  55:  { type: 'boss_damage',       description: 'Boss Damage +%5',         value: 5 },
  60:  { type: 'hospital_reduce',   description: 'Hastane Süresi -%10',     value: 10 },
  65:  { type: 'enhance_shield',    description: 'Yıkım Oranı -%2',        value: 2 },
  70:  { type: 'rep_bonus',         description: 'Rep Kazanımı +%5',        value: 5 },
  75:  { type: 'mega_bonus_2',      description: 'Büyük Milestone 2',       value: 0 },
  80:  { type: 'phoenix_power',     description: 'Overdose Kurtulma (1/gün)', value: 1 },
  85:  { type: 'leviathan_power',   description: 'Zindan Enerji -%2',       value: 2 },
  90:  { type: 'titan_power',       description: 'Enhancement Cost -%5',    value: 5 },
  95:  { type: 'world_eater_power', description: 'Tüm Stat +%3',           value: 3 },
  100: { type: 'eternal_power',     description: 'ETERNAL: +%5 tüm stat',  value: 5 },
};
```

---

## 12. UI Sayfaları (Önerilen)

| Sayfa | Rota | Açıklama |
|-------|------|----------|
| Lonca Ana | `/game/guild` | Üye listesi, anıt seviyesi, genel bilgi |
| Anıt Detay | `/game/guild/monument` | 3D/2D anıt görünümü, seviye, gereksinimler |
| Bağış Yap | `/game/guild/monument/donate` | Kaynak bağışlama form, günlük limit gösterimi |
| Katkı Sıralaması | `/game/guild/contributions` | Üye katkı sıralaması |
| Blueprint Durumu | `/game/guild/blueprints` | Toplanan parçalar, tamamlanma durumu |
| Lonca Sıralaması | `/game/leaderboard/guilds` | Tüm loncalar anıt seviyesine göre |
| Anıt Bonusları | `/game/guild/monument/bonuses` | Aktif pasif bonuslar listesi |

---

## 13. Ekonomik Etki Analizi

### 13.1 Gold Sink Katkısı

Anıt sistemi oyunun **en büyük gold sink'i**:

| Anıt Aralığı | Gold Gereksinimi | Süre |
|-------------|-----------------|------|
| Lv 1-25 | ~845M | Ay 1-2 |
| Lv 26-50 | ~16B | Ay 3-6 |
| Lv 51-75 | ~86B | Ay 6-9 |
| Lv 76-100 | ~474B | Ay 9-12 |
| **TOPLAM** | **~577B** | **12 ay** |

### 13.2 PLAN_06 Tutarlılık

```
30 üyeli lonca, ayda toplam ~3B-8B gold kazanıyor (PLAN_06)
Gold'un %30-50'si anıta giderse: 900M - 4B / ay anıt gold sink

12 ay toplam anıt gold sink (30 üyeli lonca, ×0.75 çarpan): ~577B × 0.75 = ~433B
  → 30 üye × 12 ay × ort. 1.2B gold/ay (PLAN_06 gelir) = ~432B — neredeyse tam uyumlu ✓

Boyut çarpanı (§3.0) ekonomik tutarlılığı sağlar:
- 10 üye (×0.35): hedef ~201B (577B×0.35) → bütçe 10×12×1.2B=~144B (hedefin altında; Lv 55-65 ulaşılabilir)
- 20 üye (×0.55): hedef ~317B (577B×0.55) → bütçe 20×12×1.2B=~288B (yakın; sezon Lv 70-80 uyumlu)
- 30 üye (×0.75): hedef ~433B (577B×0.75) → bütçe 30×12×1.2B=~432B (neredeyse tam uyumlu; Lv 90-95)
- 50 üye (×1.00): hedef ~577B → bütçe 50×12×1.2B=~720B (fazla; Lv 100 ulaşılabilir)
```

> **Not:** Yukarıdaki seviye tablosu "ideal" değerlerdir. Gerçek implementasyonda daha detaylı balancing yapılacak. Temel prensip: Lv 100 sezon sonunda zar zor ulaşılabilir olmalı.

### 13.3 Kaynak Darboğazları

| Aşama | Darboğaz Kaynak | Çözüm |
|-------|----------------|-------|
| Lv 1-25 | Structural | Tesis üretimini artır |
| Lv 25-50 | Mystical | Boss farm yoğunlaştır |
| Lv 50-75 | Critical + Gold | Zone 6-7 farm + tüm üyelerin katkısı |
| Lv 75-100 | Blueprint + Critical | Düzenli boss farming, uzun soluklu planlama |

---

## 14. Uygulama Öncelikleri

1. **Faz 1:** DB tabloları oluştur (guild monument sütunları, blueprints, contributions)
2. **Faz 2:** `donate_to_monument` RPC + günlük limit tracking
3. **Faz 3:** `upgrade_monument` RPC + seviye gereksinim lookup tablosu
4. **Faz 4:** Monument UI (seviye gösterimi, bağış formu, katkı sıralaması)
5. **Faz 5:** Pasif bonus sistemi (her login'de bonus hesapla + uygula)
6. **Faz 6:** Blueprint drop sistemi (zindan boss loot tablosuna ekle)
7. **Faz 7:** Lonca sıralama tablosu + sezon sonu ödül sistemi
8. **Faz 8:** Anıt görsel gösterimi (seviyeye göre büyüyen 2D/3D yapı)

---

## 15. Seviye Gereksinim Formülleri (Implementasyon Referansı)

Yukarıdaki tablolar detaylı olsa da, implementasyonda bir formül kullanılabilir:

```sql
-- Yaklaşık formüller (tam tablo değerlerinden sapma ±%10)
structural(lv) = FLOOR(100 * lv + 3 * lv^2)
mystical(lv)   = GREATEST(0, FLOOR((lv - 2) * lv * 2))
critical(lv)   = GREATEST(0, FLOOR((lv - 14) * lv * 0.8))
gold(lv)       = FLOOR(500000 * lv + 100000 * lv^2)
```

Milestone seviyelerde (her 10. ve boss blueprint seviyeleri) %20-50 ek maliyet çarpanı uygulanmalı.
Lonca büyüklüğüne göre boyut çarpanı (§3.0) bu formül sonuçlarına uygulanır.

---

*Bu belge PLAN_04 (zindan boss — blueprint drop), PLAN_02 (tesis — structural kaynak), PLAN_06 (ekonomi — gold sink), PLAN_08 (tolerans — Lv 20 bonus: tolerance decay), PLAN_09 (PvP — Lv 40 bonus: PvP shield) ile entegredir.*
