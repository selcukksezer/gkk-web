# PLAN 06 — Ekonomi & Denge (Economy & Balance)

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** Tüm diğer plan dosyaları  
> **Kapsam:** Gold akışı, enerji bütçesi, sezon ilerleme hızı, oyuncu güç eğrisi

---

## 1. Genel Bakış

Bu belge, oyunun tüm ekonomik sistemlerini birbiriyle bütünleşik şekilde dengeler. Hedef:
- **1 yıllık sezonda (365 gün)** hardcore oyuncu Zone 7'yi zorlukla tamamlar, Full Mythic +8 set yapabilir, +10 sadece 1-2 parça
- **Casual oyuncu** yıl sonunda Zone 5-6'da, Legendary set +5 civarında kalır
- **Hiç kimse** kısa sürede tüm içeriği tüketemesin — 12 aylık derinlik
- **P2W avantajı** sınırlı olsun (gem ile hız kazanılır, güç kazanılmaz)
- **Büyük rakamlar:** Power ~450,000, Reputation ~356,000, günlük gold milyonlar seviyesinde

---

## 2. Gelir Kaynakları (Gold Girişi)

### 2.1 Günlük Gold Girişi — Dönemlere Göre

| Kaynak | Erken Oyun (Hafta 1-2) | Orta Oyun (Ay 2-4) | Geç Orta (Ay 5-8) | End-Game (Ay 9-12) |
|--------|------------------------|---------------------|--------------------|--------------------|
| Zindan koşuları | 75K - 800K | 600K - 8M | 5M - 20M | 12M - 70M |
| Tesis kaynakları (NPC satış) | 50K - 200K | 3M - 15M | 15M - 40M | 50M - 100M |
| Quest ödülleri | 10K - 50K | 200K - 1M | 1M - 5M | 3M - 10M |
| PvP ganimet | 0 - 50K | 100K - 500K | 500K - 2M | 1M - 5M |
| Market ticaret | 0 | 500K - 5M | 5M - 20M | 10M - 50M |
| Mekan geliri | 0 | 0 - 2M | 2M - 10M | 5M - 30M |
| **GÜNLÜK TOPLAM** | **~200K - 1M** | **~5M - 30M** | **~30M - 100M** | **~80M - 265M** |

> **Not:** Mekan geliri PLAN_07'de detaylandırılacak. PvP ganimet Mekan'da gerçekleşir.

### 2.2 Aylık Gold Girişi (Toplam Birikim)

| Dönem | Aylık Toplam | Kümülatif (Brüt) |
|-------|-------------|------------------|
| Ay 1 (Hafta 1-4) | ~30M - 80M | ~50M |
| Ay 2 | ~150M - 450M | ~350M |
| Ay 3 | ~300M - 900M | ~1B |
| Ay 4 | ~500M - 1.5B | ~2B |
| Ay 5-6 | ~1B - 3B / ay | ~6B |
| Ay 7-9 | ~2B - 5B / ay | ~18B |
| Ay 10-12 | ~3B - 8B / ay | ~38B |

> **Brüt gelir:** Gold sink'ler öncesi toplam. Net birikim brüt'ün %20-30'u olacak şekilde dengeli.

---

## 3. Harcama Kalemleri (Gold Çıkışı — Sink)

### 3.1 Ekipman Crafting Maliyetleri

Tam set (8 parça) crafting maliyeti (PLAN_03 referans):

| Set Rarity | Malzeme Değeri (NPC) | Gold Maliyeti | Toplam Set Maliyeti |
|------------|---------------------|---------------|---------------------|
| Common Set | ~40,000 | 80,000 | ~120,000 |
| Uncommon Set | ~200,000 | 400,000 | ~600,000 |
| Rare Set | ~1,000,000 | 2,000,000 | ~3,000,000 |
| Epic Set | ~4,000,000 | 8,000,000 | ~12,000,000 |
| Legendary Set | ~20,000,000 | 40,000,000 | ~60,000,000 |
| Mythic Set | ~100,000,000 | 200,000,000 | ~300,000,000 |

### 3.2 Enhancement Maliyetleri (Tam Set — 8 Parça)

**Baz gold maliyet** (başarısızlık olmadan, PLAN_05 referans):

| Enh. | Common (×1) | Rare (×4) | Epic (×6) | Legendary (×8) | Mythic (×12) |
|------|------------|-----------|-----------|----------------|--------------|
| +3 | 4.8M | 19.2M | 28.8M | 38.4M | 57.6M |
| +5 | 20.8M | 83.2M | 124.8M | 166.4M | 249.6M |
| +7 | 108.8M | 435.2M | 652.8M | 870.4M | 1.3B |
| +10 | 2.2B | 8.9B | 13.4B | 17.8B | 26.7B |

**Beklenen gerçek maliyet** (yıkım + yeniden craft + yeniden enhancement dahil):

| Enh. | Common Set | Rare Set | Epic Set | Legendary Set | Mythic Set |
|------|-----------|----------|----------|---------------|------------|
| +3 | 4.8M | 19.2M | 28.8M | 38.4M | 57.6M |
| +5 | 27M | 108M | 162M | 216M | 325M |
| +7 | 450M | 1.8B | 2.7B | 3.5B | 5.2B |
| +8 | 2B | 8B | 12B | 16B | 24B |
| +10 | 45B | 180B | 270B | 360B | 535B |

> **Tasarım notu:** ×10 enhancement gold skala (×100 değil) — birincil bariyer altın değil, item yıkımıdır. Mythic +10 tam set 1 yılda bile başarılamaz; bu end-game ötesi bir hedeftir.

### 3.3 Tesis Yükseltme Maliyetleri (PLAN_02 referans)

Tüm 15 tesisi belirli seviyeye çıkarma toplam maliyeti:

| Hedef Lv | Toplam Maliyet |
|----------|---------------|
| Lv 3 | ~7,500,000 |
| Lv 5 | ~30,000,000 |
| Lv 7 | ~90,000,000 |
| Lv 10 | ~500,000,000 |

### 3.4 Diğer Harcamalar

| Kalem | Maliyet |
|-------|---------|
| İksir crafting (günlük) | 50,000 - 1,000,000 |
| Market alımları | Değişken |
| Hastane healer | 100,000 - 1,000,000 |
| Lonca katkısı | Değişken |
| Tesis açma (toplam 15 tesis) | ~5,600,000 |
| Detox içecek (Mekan) | 50,000 - 500,000 |

### 3.5 Harcama Dengesi Özeti

| Dönem | Aylık Gelir | Ana Harcama | Birikim Oranı |
|-------|------------|-------------|---------------|
| Ay 1 | ~50M | Common+Uncommon set, ilk tesisler | %30 birikim |
| Ay 2-3 | ~350M-1B | Rare→Epic set, tesis Lv 3-5 | %25 birikim |
| Ay 4-6 | ~1.5B-3B | Epic→Legendary set, enh. +3-5 | %20 birikim |
| Ay 7-9 | ~2B-5B | Mythic craft, enh. +5-7 | %15-20 birikim |
| Ay 10-12 | ~3B-8B | Mythic enh. +7-8, tesis Lv 10 | %15 birikim |

---

## 4. Enerji Bütçesi

### 4.1 Enerji Kaynakları (Yeni Model)

Enerji regen (otomatik yenilenme) **kaldırılmıştır**. Enerji yalnızca aşağıdaki yollarla kazanılır:

| Kaynak | Enerji Miktarı | Notlar |
|--------|---------------|--------|
| **Han/Mekan enerji itemları** | 20-100 enerji/item | Sadece Han'da satılır; market/trade yasak |
| Zindan başarı ödülü (bazı) | 5-15 enerji | Zone 4+ zindanlarda küçük enerji bonusu |
| Quest tamamlama | 10-30 enerji | Günlük quest paketi |
| Günlük giriş bonusu | 30 enerji | Sadece ilk giriş |
| Premium enerji refill | 50-100 enerji | Gem ile, günde max 2 kez |

### 4.2 Han Enerji Itemları (Temel Kaynak)

Han/Mekan'da satılan 6-7 özel item, enerji ve tolerans yönetiminin ana mekanizmasıdır (bkz. PLAN_07 §5 Han Katalogu).

**Tasarım amacı:**
- Enerji kıtlığı → oyuncuyu Han'a çeker → Han trafiği artar → PvP ve sosyal etkileşim
- Han item üretimi zorlu → ekonomik değer yüksek → iyi bir gold sink
- Market/trade yasağı → Han monopolü korunur

### 4.3 Günlük Enerji Bütçesi (Tipik Oyuncu)

| Aktivite | Enerji/Koşu | Günlük Koşu | Günlük Enerji Harcama |
|----------|-------------|-------------|----------------------|
| Zindan (birincil) | 5-50 | 8-15 | 80-200 |
| Quest | 5-20 | 2-4 | 20-50 |
| PvP | 15 | 2-5 | 30-75 |
| **TOPLAM** | — | — | ~130-325 |

Günlük enerji arzı (Han item + quest + giriş bonusu): ~150-350

### 4.4 Enerji Darboğazı

Enerji sistemi doğal bir günlük limit oluşturur:
- Zone 1 (5 enerji): Günde ~30-60 zindan (Han item kullanımına bağlı)
- Zone 4 (20 enerji): Günde ~8-15 zindan
- Zone 6 (40 enerji): Günde ~4-8 zindan
- Zone 7 (50 enerji): Günde ~3-6 zindan

**Kritik kural:** Oyuncu Han'a gitmeden/item almadan enerji bitmesi durumunda aktivite kısıtlanır. Bu, Han trafiğini ekonomik olarak zorunlu kılar.

---

## 5. Oyuncu Güç Eğrisi (Power Curve)

### 5.1 Power Formülü

```
total_power = (level × 500) + equipment_power + (reputation × 0.1)
equipment_power = Σ(base_stat × (1 + enhancement × 0.15))  -- tüm 8 slot
```

### 5.2 Detaylı İlerleme Tablosu

| Zaman | Beklenen Ekipman | Enh. | Level | Reputation | Tahmini Power | Zone |
|-------|-----------------|------|-------|------------|---------------|------|
| Gün 1 | Yok → ilk Common parça | +0 | 1-2 | 0 | 500 - 2,000 | Z1 giriş |
| Gün 3 | Full Common | +0 | 5-7 | 100 | 5,000 - 10,000 | Z1 sonu |
| Hafta 1 (Gün 7) | Full Common | +1/+2 | 8-12 | 500 | 10,000 - 18,000 | Z1 tam, Z2 başlangıç |
| Hafta 2 (Gün 14) | Common +3 → Uncommon başlangıç | +2/+3 | 15-18 | 2,000 | 18,000 - 30,000 | Z2 ortası |
| Ay 1 (Gün 30) | Full Uncommon | +3 | 22-25 | 8,000 | 30,000 - 45,000 | Z2 sonu, Z3 giriş |
| Ay 2 (Gün 60) | Full Rare | +3/+4 | 30-35 | 20,000 | 55,000 - 85,000 | Z3 ortası-sonu |
| Ay 3 (Gün 90) | Rare +5 → Epic geçiş | +4/+5 | 38-42 | 40,000 | 85,000 - 120,000 | Z3 sonu, Z4 giriş |
| Ay 4 (Gün 120) | Full Epic +3/+5 | +4/+5 | 42-48 | 65,000 | 120,000 - 170,000 | Z4 ortası |
| Ay 5-6 (Gün 180) | Epic +5 → Legendary geçiş | +5/+6 | 48-55 | 100,000 | 170,000 - 250,000 | Z4 sonu, Z5 |
| Ay 7-8 (Gün 240) | Legendary +5/+7 | +5/+7 | 55-60 | 160,000 | 250,000 - 340,000 | Z5 sonu, Z6 giriş |
| Ay 9-10 (Gün 300) | Leg +7 → Mythic geçiş | +5/+7 | 60-65 | 230,000 | 340,000 - 400,000 | Z6 ortası-sonu |
| Ay 11-12 (Gün 365) | Mythic +5/+7 (kısmi) | +5/+8 | 65-70 | 320,000 | 400,000 - 450,000 | Z7 |

### 5.3 Power vs Zindan Gereksinim Grafiği

```
Power (×1000)
  ^
450|                                                          Z7■■ (425K-450K)
420|                                                    Z6■■■ (350K-420K)
340|                                              Z5■■■ (230K-340K)
220|                                       Z4■■■ (110K-220K)
100|                                Z3■■■ (44K-100K)
 40|                     Z2■■■ (12K-40K)
 10|         Z1■■■ (0-10K)
   |
   +--+--------+--------+--------+--------+--------+--------→ Ay
      1        2        4        6        8       10       12

Oyuncu Power Eğrisi (Hardcore):
  Common → Uncommon → Rare → Epic → Legendary → Mythic
   10K  →   35K    →  80K  → 150K →   280K    → 420K
```

### 5.4 Casual vs Hardcore Ayrımı

| Ay 12 | Hardcore | Casual | Whale (P2W) |
|-------|---------|--------|-------------|
| Level | 68-70 | 55-60 | 65-68 |
| Set | Mythic (kısmi +7) | Legendary +5 | Mythic +5 |
| Power | 420K - 450K | 250K - 320K | 380K - 430K |
| Zone | Z7 (zorlanarak) | Z5-Z6 | Z6-Z7 |
| Gold kazanılmış (toplam) | ~38B | ~12B | ~25B + gem avantajı |

---

## 6. Sezon Yapısı — 1 Yıl (365 Gün)

### 6.1 Aylık İlerleme Planı

| Ay | Aşama | PvE Hedef | Ekonomi Hedef | Sosyal Hedef |
|----|-------|-----------|---------------|-------------|
| 1 | **Keşif** | Common→Uncommon, Zone 1-2 | İlk tesisler, 50M gelir | İlk lonca girişi |
| 2 | **Büyüme** | Rare set, Zone 2-3 | 5-8 tesis, 350M gelir | Mekan keşfi |
| 3 | **Geçiş** | Rare +5 → Epic, Zone 3 tam | 10 tesis Lv 3, enh. +3-4 | İlk Anıt katkısı |
| 4 | **Güçlenme** | Full Epic +3-5, Zone 4 başlangıç | Tesis Lv 5, toplam 2B kazanılmış | Anıt Lv 10-15 |
| 5-6 | **Olgunluk** | Epic +5 → Legendary, Zone 4-5 | Tesis Lv 7, günlük 30-60M | Anıt Lv 25-40 |
| 7-8 | **End-Game Giriş** | Legendary +5-7, Zone 5-6 | Mythic kaynak biriktir, günlük 60-120M | Anıt Lv 50-65, PvP aktif |
| 9-10 | **Mythic Çağı** | Mythic ilk parça, Zone 6 | Enh. +7 girişimi, günlük 100-175M | Anıt Lv 70-85, Mekan ekonomisi |
| 11-12 | **Sezon Sonu Yarışı** | Mythic +5-7, Zone 7 push | Full end-game gelir, toplam ~38B | Anıt 100 yarışı, sıralama |

### 6.2 Çeyrek Dönem Özeti

| Çeyrek | Süre | Odak | Oyuncu Power |
|--------|------|------|-------------|
| Q1 (Ay 1-3) | Gün 1-90 | Set kurulumu, tesis açma, zone 1-3 | 500 → 120K |
| Q2 (Ay 4-6) | Gün 91-180 | Enhancement odak, zone 3-5, lonca oluşum | 120K → 250K |
| Q3 (Ay 7-9) | Gün 181-270 | Legendary→Mythic geçiş, zone 5-6, PvP | 250K → 400K |
| Q4 (Ay 10-12) | Gün 271-365 | Mythic enhancement, zone 7, sıralama | 400K → 450K |

### 6.3 Gün 1 Yapılabilirlik (Day 1 Feasibility)

Yeni oyuncu Gün 1'de yapabilmesi gerekenler:

| Adım | Gereksinim | Süre |
|------|-----------|------|
| İlk zindan (Z1 #1) | Hiç ekipman gerekmez, power 0 OK | 2 dk |
| 3-5 zindan koşusu | 5 enerji × 5 = 25 enerji | 15 dk |
| İlk Common parça craft | ~10K gold + kaynaklar (Z1 drop) | İlk 1 saat |
| Full Common set | ~80K gold + Zone 1 farm | 4-6 saat |
| İlk tesis açma (Maden Ocağı) | 50K gold | Gün 1-2 arası |

> **Başlangıç goldu:** 1,000 (DB default). İlk 5 zindan koşusunda (Z1 #1-3) 25K-100K kazanılır → ilk parça craft'ına yeter.

### 6.4 Sezon Sonu Reset

Sezon bittiğinde sıfırlananlar:
- Gold
- Items (Envanter)
- Level → 1
- Buildings (Tesisler)
- Enhancement seviyeleri
- Tolerance / addiction
- Reputation (PvP rating dahil)

Kalıcı olanlar:
- Gems (premium para)
- Cosmetics
- Titles (unvanlar, ör: "Sezon 1 Şampiyonu")
- Achievements
- Sezon İstatistikleri (profil görüntüleme)

### 6.5 Sezon Ödülleri

| Sıralama | Gem Ödülü | Unvan | Kozmetik |
|----------|-----------|-------|----------|
| 1 | 10,000 | "Sezon Efsanesi" | Altın Aura + Özel Çerçeve |
| 2-10 | 5,000 | "Elit Savaşçı" | Gümüş Aura |
| 11-50 | 2,500 | "Usta" | Bronz Aura |
| 51-100 | 1,000 | "Uzman" | Özel Çerçeve |
| 101-500 | 500 | "Savaşçı" | Rozet |
| 501-1000 | 200 | — | — |

### 6.6 Sezon Sıralama Puanı

```
season_score = (max_dungeon_cleared × 1000)
             + (total_power × 1)
             + (pvp_rating × 2)
             + (guild_monument_level × 500)
             + (total_gold_earned / 1,000,000)
             + (crafting_count × 10)
```

---

## 7. Para Kazanma (Monetization) Dengesi

### 7.1 Gem Kullanım Alanları

| Kullanım | Gem Maliyeti | Etki | P2W Seviyesi |
|----------|-------------|------|-------------|
| Enerji yenileme | 50 gem | +100 enerji | Düşük (hız) |
| Hastane çıkış | 3 gem/dk | Bekleme atlama | Düşük (kolaylık) |
| Ekstra enerji refill | 50 gem | +50 enerji (günde max 2) | Düşük (hız) |
| 2. Crafting slot | 100 gem/ay | Paralel üretim | Düşük (kolaylık) |
| Kozmetikler | 50-500 gem | Görünüm | Yok |
| Premium Battle Pass | 500 gem/sezon | Ekstra ödüller | Orta |

### 7.2 P2W Sınırları

**ASLA gem ile satın alınamaz:**
- Ekipman (craft gerekir)
- Kaynaklar (tesis gerekir)
- Doğrudan güç artışı
- Zindan atlaması

**Gem avantajı:** Zaman tasarrufu (%20-30 daha hızlı ilerleme), kozmetik farklılık.

---

## 8. Enflasyon Kontrolü (Gold Sinks)

### 8.1 Otomatik Gold Sinks

| Mekanizma | Etkisi |
|-----------|--------|
| Enhancement başarısızlığı (+6 üstü) | Büyük gold kaybı |
| Crafting başarısızlığı | Kaynak + gold kaybı |
| NPC vergileri (alım/satım farkı) | %20-30 spread |
| Market işlem ücreti | %2 fee |
| Tesis yükseltme | Katlanarak artan maliyet |
| Hastane healer | Sabit maliyet |
| Han-only item craft maliyeti | Yüksek kaynak/gold gereksinimi |
| Hastane/hapishane fırsat maliyeti | Aktivite kaybı = ekonomik maliyet |

### 8.2 Enflasyon Senaryoları

| Senaryo | Risk | Çözüm |
|---------|------|-------|
| Çok fazla zindan gold'u | Orta | Enerji kıtlığı (Han itemı gereksinimi) + Boss deneme limitleri |
| Tesis kaynak satışı | Düşük | NPC fiyatları düşük tutulur |
| Market manipülasyonu | Orta | Max order limiti + expiry |
| Bot farming | Yüksek | Rate limiting + CAPTCHA + ban |

### 8.3 Aylık Gold Dengesi Hedefi

```
Gold Girişi (aylık) ≈ Gold Çıkışı (aylık) × 1.2-1.5
```

Oyuncu aylık gelirinin %70-80'ini harcamalı, %20-30 birikim yapabilmeli. Bu, sürekli bir "bir sonraki hedef" hissi verir.

### 8.4 Enflasyon Kontrolü — 1 Yıllık Sezon İçin

12 aylık sezonda enflasyon kritik tehlike:
- **Ay 1-3:** Düşük risk — oyuncular hâlâ set kuruyor, gold sink'ler yeterli
- **Ay 4-6:** Orta risk — tesis gelirleri artıyor, enhancement harcamaları henüz yüksek değil
- **Ay 7-9:** Yüksek risk — end-game oyuncular çok kazanıyor, mythic craft pahalı ama tek seferlik
- **Ay 10-12:** Kritik — gold birikimi çok yüksek, enhancement +7-8 yıkımları ana sink

**Dinamik sink mekanizmaları:**
- Anıt katkısı (PLAN_10): lonca bazlı gold sink, ayda 500M-5B
- Mekan işletme maliyetleri (PLAN_07): kira + stok + bakım
- PvP bahis/ganimet vergisi: %10 cut
- Sezon sonu altın sıralaması: birikim motivasyonu ama reset ile temizlenir

---

## 9. Zorluk Eğrisi Detayı

### 9.1 Zone Geçiş Süreleri (PLAN_04 Power Gereksinimleri ile)

| Geçiş | Power Gereksinimi | Gerekli Gold (Set+Enh.) | Gerekli Kaynak | Tahmini Süre |
|-------|-------------------|------------------------|----------------|-------------|
| Başlangıç → Z1 | 0 - 10,000 | Common set: ~120K | Zone 1 drop | Gün 1-7 |
| Z1 → Z2 | 12,000 - 40,000 | Uncommon set +3: ~660K | 40 Uncommon kaynak | Hafta 1.5 - Ay 1 |
| Z2 → Z3 | 44,000 - 100,000 | Rare set +3-5: ~6M | 40 Rare kaynak | Ay 1 - Ay 2 |
| Z3 → Z4 | 110,000 - 220,000 | Epic set +5: ~174M | 40 Epic kaynak | Ay 2 - Ay 4 |
| Z4 → Z5 | 230,000 - 340,000 | Legendary set +5-7: ~3.6B | 40 Legendary kaynak | Ay 4 - Ay 7 |
| Z5 → Z6 | 350,000 - 420,000 | Mythic craft + Leg +7: ~5.5B | 40 Mythic kaynak | Ay 7 - Ay 10 |
| Z6 → Z7 | 425,000 - 450,000 | Mythic +5-7: ~5.5B ek | Enhancement materyali | Ay 10 - Ay 12 |

### 9.2 Toplam Oyun İçi Saat (İlk Clear)

| Hedef | Tahmini Saat | Gerçek Süre (6 sa/gün) |
|-------|-------------|----------------------|
| Zone 1 tam clear | 15-25 saat | 3-5 gün |
| Zone 2 tam clear | 80-120 saat | 2-3 hafta |
| Zone 3 tam clear | 200-300 saat | 1-2 ay |
| Zone 4 tam clear | 400-600 saat | 2-4 ay |
| Zone 5 tam clear | 700-1000 saat | 4-6 ay |
| Zone 6 tam clear | 1200-1600 saat | 7-10 ay |
| Zone 7 (65. zindan) | 1800-2200+ saat | 10-12 ay |

> **1 yıl (365 gün × 6 saat = 2,190 saat):** Hardcore oyuncu Zone 7'yi zorla tamamlar. Casual (~3 sa/gün = 1,095 saat) Zone 5-6'da kalır.

### 9.3 İçerik Tüketim Kontrolü

Zone'lar arası "doğal duvar" mekanizmaları:
1. **Power requirement duvarı:** Equipment upgrade + enhancement gerektir
2. **Enerji kıtlığı:** Han itemı gerektiren enerji sistemi yüksek zone'larda koşu sayısını sınırlar
3. **Boss günlük limit:** Zone boss'larında 3 deneme/gün
4. **Hospital riski:** Başarısız koşuda hastaneye düşme; overdose → Han enerji potionı riski (PLAN_04, PLAN_08)
5. **Kaynak darboğazı:** Mythic malzeme sadece Z6-7'de düşer
6. **Enhancement RNG duvarı:** +6 sonrası yıkım riski, haftalarca geri atabilir

---

## 10. Oyuncu Arketipleri ve Deneyim

### 10.1 Savaşçı (Dungeon Farmer)

- **Odak:** Zindan koşuları, boss clear
- **Günlük rutin:** 20-30 zindan koşu, 3 boss denemesi
- **Gelir:** Gold + XP + item drop
- **Harcama:** Enhancement, iksir

### 10.2 Zanaatkar (Crafter)

- **Odak:** Tesis yönetimi, crafting, market satışı
- **Günlük rutin:** Tesis toplama (3-4 kez), crafting kuyruğu, market order
- **Gelir:** Kaynak satışı, crafted item satışı
- **Harcama:** Tesis yükseltme, kaynak alımı

### 10.3 Tüccar (Trader)

- **Odak:** Market fiyat arbitrajı, toplu alım/satım
- **Günlük rutin:** Market takip, düşük fiyat avı, yüksek fiyat satışı
- **Gelir:** Spread karı
- **Harcama:** Market alımları

### 10.4 Savaşçı (PvP Player)

- **Odak:** PvP saldırıları, rating climb
- **Günlük rutin:** PvP dövüşleri, equipment optimization
- **Gelir:** PvP ganimetleri
- **Harcama:** Enhancement (güç odaklı)

---

## 11. XP & Seviye Sistemi

### 11.1 Seviye Atlama Gereksinimleri

```
XP_needed(level) = 100 × level × (1 + level × 0.15)
Level cap: 70
```

| Level | Gerekli XP | Kümülatif XP | Beklenen Ulaşım |
|-------|-----------|-------------|-----------------|
| 1→2 | 230 | 230 | Gün 1 |
| 5→6 | 1,075 | 3,450 | Gün 2 |
| 10→11 | 2,500 | 13,750 | Gün 4-5 |
| 15→16 | 4,275 | 33,188 | Hafta 1.5 |
| 20→21 | 6,400 | 62,500 | Hafta 3 |
| 25→26 | 8,875 | 103,438 | Ay 1 |
| 30→31 | 11,700 | 157,750 | Ay 1.5-2 |
| 35→36 | 14,875 | 227,188 | Ay 2.5 |
| 40→41 | 18,400 | 312,000 | Ay 3-3.5 |
| 45→46 | 22,275 | 413,438 | Ay 4-5 |
| 50→51 | 26,500 | 533,750 | Ay 5-6 |
| 55→56 | 31,075 | 673,438 | Ay 7 |
| 60→61 | 36,000 | 831,000 | Ay 8-9 |
| 65→66 | 41,275 | 1,010,438 | Ay 10-11 |
| 69→70 | 46,585 | 1,175,000 | Ay 11-12 |

### 11.2 XP Kaynakları

| Kaynak | XP/aktivite | Günlük XP (Erken) | Günlük XP (Geç) |
|--------|-------------|-------------------|------------------|
| Zindan (Zone 1-2) | 30 - 470 | 1,000 - 5,000 | — |
| Zindan (Zone 3-4) | 520 - 3,080 | — | 5,000 - 30,000 |
| Zindan (Zone 5-7) | 3,380 - 20,650 | — | 20,000 - 100,000 |
| Quest | 100 - 2,000 | 500 - 2,000 | 2,000 - 10,000 |
| PvP | 50 - 500 | 200 - 1,000 | 500 - 5,000 |
| First Clear Bonus | base × 10 | Tek seferlik | Tek seferlik |
| Crafting XP | 50 - 500 | 200 - 1,000 | 500 - 3,000 |
| Mekan etkinlik | 100 - 1,000 | 0 | 500 - 3,000 |

### 11.3 Seviye Atlama Hızı

| Dönem | Level Aralığı | Günlük XP | Level/Hafta |
|-------|--------------|-----------|-------------|
| Erken (Ay 1) | 1 - 25 | 3,000 - 10,000 | 7-10 level/hafta |
| Orta (Ay 2-4) | 25 - 45 | 10,000 - 30,000 | 3-5 level/hafta |
| Geç (Ay 5-8) | 45 - 60 | 30,000 - 60,000 | 1-2 level/hafta |
| Son (Ay 9-12) | 60 - 70 | 50,000 - 100,000 | 0.5-1 level/hafta |

> **Level hızı:** Level 70'e ulaşmak ~11-12 ay (hardcore) veya 8-9 ay (sadece level kasan). Ama level tek başına power'ı belirlemez; ekipman + enhancement çok daha büyük katkı yapar.

### 11.4 Level Katkısı vs Ekipman Katkısı

```
Level 70: level × 500 = 35,000 power (toplam ~450K'nın %8'i)
Ekipman: ~380,000 power (%84)
Reputation (×0.1): ~35,600 power (%8)
```

Level, toplam power'ın sadece %8'ini oluşturur → **ekipman ve enhancement asıl belirleyici**.

---

## 12. Kritik Denge Parametreleri (Ayar Noktaları)

Oyun test edilirken bu parametreler ilk ayarlanacaklardır:

| Parametre | Dosya | Varsayılan | Ayar Aralığı |
|-----------|-------|-----------|-------------|
| Zindan Power Requirement eğrisi | `dungeons` seed | Üstel | Doğrusal ↔ Üstel |
| Tesis drop rate tablosu | `collect_facility` RPC | Bölüm 2 tablo | ±10% |
| Enhancement yıkım oranları | `enhance_item` RPC | Mevcut | ±20% |
| Gold reward çarpanları | `dungeons` seed | Mevcut | ±30% |
| Crafting başarı oranları | `craft_recipes` seed | Bölüm 2 | ±10% |
| Han enerji item miktarı | GameConstants | 20-100 | 10-150 |
| Boss günlük limit | `dungeons` seed | 3 | 1-5 |

---

## 13. Anti-Exploit Mekanizmaları

| Tehdit | Önlem |
|--------|-------|
| Zindan botu | Enerji limiti + rate limit + sunucu zaman doğrulaması |
| Gold çoğaltma | Server-authoritative economy (tüm gold hareketleri RPC'de) |
| Envanter manipülasyonu | RLS + server-side inventory management |
| Multi-account abuse | IP tracking + device fingerprint |
| Market wash trading | Same-player order detection |
| İksir stacking | Server buff tracking, max 1 buff/tip |

---

## 14. KPI & Metrikler

Oyun dengesi izlemek için takip edilecek metrikler:

| Metrik | Hedef | Alarm |
|--------|-------|-------|
| Ortalama günlük oturum süresi | 45-90 dk | < 20 dk |
| Günlük zindan koşu sayısı (ort) | 15-25 | < 5 veya > 50 |
| Haftalık gold enflasyon oranı | < %5 | > %10 |
| Zone dağılımı (aktif oyuncular) | Normal dağılım | Bimodal |
| Enhancement +6+ başarı sayısı/gün (sunucu) | < %5 oyuncu pool | > %15 |
| Churn rate (haftalık) | < %10 | > %20 |
| P2W spending / aktif oyuncu | Sağlıklı | Whale dominance |

---

## 15. Uygulama Öncelikleri

1. **Faz 1:** GameConstants güncelleme (fatigue, power formülleri, ×100 stat, ×500 level çarpanı)
2. **Faz 2:** XP tablosu (level 70 cap) ve seviye atlama sistemini doğrula
3. **Faz 3:** Tesis ekonomisi seed data + test (×100 gold)
4. **Faz 4:** Zindan ekonomisi seed data + test (×100 power, custom zone gereksinimleri)
5. **Faz 5:** Enhancement ekonomisi test (×10 gold, yıkım oranları)
6. **Faz 6:** Market fee'leri ve NPC fiyatlarını ayarla (×100)
7. **Faz 7:** Mekan sistemi, Tolerance sistemi, PvP ekonomisi
8. **Faz 8:** Lonca Anıtı ekonomik etkisi (PLAN_10)
9. **Faz 9:** Soft launch sonrası metrik tabanlı dengeleme (KPI Section 14)

---

## 16. Çapraz Referans Tablosu

| Değer | Kaynak PLAN | Tutar |
|-------|------------|-------|
| Common set craft gold | PLAN_03 | 8 × 10,000 = 80,000 |
| Mythic set craft gold | PLAN_03 | 8 × 25,000,000 = 200,000,000 |
| Enhancement +10 Mythic (beklenen) | PLAN_05 | ~87.3B / parça |
| Tesis açma (toplam) | PLAN_02 | ~5,600,000 |
| Tesis Lv 10 (toplam 15) | PLAN_02 | ~500,000,000 |
| Zone 1 gold/run | PLAN_04 | 5,000 - 40,000 |
| Zone 7 gold/run | PLAN_04 | 3,000,000 - 8,860,000 |
| NPC Common kaynak | PLAN_02 | 500 gold |
| NPC Mythic kaynak | PLAN_02 | 500,000 gold |
| Power formülü | PLAN_01 | level×500 + equip + rep×0.1 |
| Enhancement formülü | PLAN_01/05 | base × (1 + enh × 0.15) |
| Max power | PLAN_01 | ~450,000 |
| Level cap | Bu belge | 70 |
| Sezon süresi | Bu belge | 365 gün |
| Başlangıç goldu | DB schema | 1,000 |
| Başlangıç gem | DB schema | 100 |

---

*Bu belge tüm PLAN_01 - PLAN_10 dosyalarının ekonomik tutarlılığını sağlamak için master referanstır. Tüm gold, power ve zaman değerleri güncel sezon süresi (1 yıl) ve ×100 stat/gold skalası ile uyumludur.*
