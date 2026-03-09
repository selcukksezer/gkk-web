# PLAN 07 — Mekan/Han Sistemi (Business & Social Hub)

> **Durum:** Tasarım Aşaması  
> **Son Güncelleme:** 2026-03-07  
> **Bağımlılıklar:** PLAN_01 (iksirler), PLAN_06 (ekonomi), PLAN_08 (tolerans), PLAN_09 (PvP)  
> **Kapsam:** Mekan/Han açma, işletme, Han-only item ticareti, enerji ve tolerans yönetimi, PvP arenası

> **Terminoloji Notu:** "Mekan" genel işletme türlerini kapsar. "Han" ise oyunun merkezi sosyal/PvP hub'ı olarak ayrıca vurgulanır. Tüm Mekan türleri Han çekirdeği etrafında şekillenir; özellikle Dövüş Kulübü türü Han/Circus rolünü üstlenir.

---

## 1. Genel Bakış

Mekan sistemi oyuncuların **kendi işletmelerini** kurabilecekleri, iksir ve detox içecek satabilecekleri, PvP dövüşlerine ev sahipliği yapabilecekleri ve sosyal etkileşim kurabilecekleri fiziksel alanlardır.

**Temel kurallar:**
- **Han/Mekan Tekeli:** İksirler, Han-only enerji itemları ve detox içecekleri SADECE Mekan'lardan satın alınabilir (NPC dükkanı yok!)
- Her oyuncu **en fazla 1 Mekan** sahibi olabilir
- Mekan sahipleri fiyat belirler (min-max sınır dahilinde)
- PvP sadece Mekan içinde gerçekleşir; Han/Dövüş Kulübü merkezi PvP arena'sıdır
- Han-only itemlar: craft → han stock → satış akışı; market veya direkt trade **yasak**
- Mekan **açık** olmak için sahibinin online olması gerekmez (otonom çalışır)
- **Enerji kıtlığı** oyuncuları Han'a çeker; Han enerji itemları temel enerji kaynağıdır (PLAN_06 §4)

---

## 2. Mekan Türleri

### 2.1 Türler ve Açma Gereksinimleri

| Tür | Açıklama | Açma Maliyeti | Level Req | Aylık Kira |
|-----|----------|--------------|-----------|------------|
| **Bar** | İksir satışı + sosyal alan | 5,000,000 | 15 | 500,000 |
| **Kahvehane** | Buff iksir + detox satışı | 8,000,000 | 20 | 800,000 |
| **Dövüş Kulübü** | PvP arena + bahis | 15,000,000 | 30 | 1,500,000 |
| **Lüks Lounge** | Tüm özellikler + VIP | 50,000,000 | 45 | 5,000,000 |
| **Yeraltı İmparatorluğu** | Tüm özellikler + kaçak ticaret | 200,000,000 | 60 | 15,000,000 |

### 2.2 Tür Özellikleri

| Özellik | Bar | Kahvehane | Dövüş Kulübü | Lüks Lounge | Yeraltı |
|---------|-----|----------|-------------|-------------|---------|
| HP İksir satışı | ✓ | ✗ | ✗ | ✓ | ✓ |
| Buff İksir satışı | ✗ | ✓ | ✗ | ✓ | ✓ |
| Detox içecek | ✗ | ✓ | ✗ | ✓ | ✓ |
| PvP Arena | ✗ | ✗ | ✓ | ✓ | ✓ |
| Bahis sistemi | ✗ | ✗ | ✓ | ✓ | ✓ |
| VIP oda | ✗ | ✗ | ✗ | ✓ | ✓ |
| Kaçak madde ticareti | ✗ | ✗ | ✗ | ✗ | ✓ |
| Max stok kapasitesi | 100 | 100 | 50 | 200 | 300 |
| Müşteri kapasitesi | 20 | 15 | 30 | 25 | 40 |
| Reputation kazanımı | ×1 | ×1 | ×2 | ×1.5 | ×3 |

---

## 3. Mekan Yükseltme Sistemi

### 3.1 Mekan Seviyeleri (1-10)

| Seviye | Yükseltme Maliyeti | Ek Stok Kapasitesi | Ek Müşteri | Kâr Bonusu |
|--------|-------------------|-------------------|-----------|-----------|
| 1 | Açılış maliyeti | Baz | Baz | — |
| 2 | 2,000,000 | +20 | +5 | +5% |
| 3 | 5,000,000 | +30 | +5 | +10% |
| 4 | 10,000,000 | +40 | +10 | +15% |
| 5 | 25,000,000 | +50 | +10 | +20% |
| 6 | 50,000,000 | +60 | +15 | +30% |
| 7 | 100,000,000 | +80 | +15 | +40% |
| 8 | 250,000,000 | +100 | +20 | +50% |
| 9 | 500,000,000 | +120 | +25 | +65% |
| 10 | 1,000,000,000 | +150 | +30 | +80% |

**Toplam yükseltme maliyeti (Lv 1→10):** ~1.942B gold

### 3.2 Yükseltme Etkileri

Her seviye ile:
- **Stok kapasitesi** artar (daha fazla iksir stoklayabilir)
- **Müşteri kapasitesi** artar (aynı anda daha fazla oyuncu ağırlayabilir)
- **Kâr bonusu** artar (satış fiyatına % ek)
- **Görünüm** iyileşir (kozmetik: daha büyük, süslü mekan)

---

## 4. İksir Ticareti

### 4.1 Temel Kural: İksirler Sadece Mekan'da

Craft edilmiş iksirler (PLAN_03):
- **Crafting:** Oyuncu kendi iksirini craft eder (her zaman mümkün)
- **Satın alma:** Sadece Mekan'lardan (NPC dükkanı YOK)
- **Market'te:** İksir trade edilemez (Mekan monopolü)

### 4.2 İksir Fiyat Sistemi

Mekan sahibi fiyat belirler, ama min-max sınır vardır:

| İksir | Craft Maliyeti | Min Satış | Max Satış | Önerilen Kâr |
|-------|---------------|-----------|-----------|-------------|
| Minor HP Potion | 5,000 | 7,500 | 25,000 | 10,000 (%100) |
| Lesser HP Potion | 15,000 | 22,500 | 75,000 | 30,000 (%100) |
| HP Potion | 40,000 | 60,000 | 200,000 | 80,000 (%100) |
| Greater HP Potion | 100,000 | 150,000 | 500,000 | 200,000 (%100) |
| Superior HP Potion | 200,000 | 300,000 | 1,000,000 | 400,000 (%100) |
| Suprema HP Potion | 500,000 | 750,000 | 2,500,000 | 1,000,000 (%100) |
| ATK Buff Potion | 200,000 | 300,000 | 1,000,000 | 400,000 |
| DEF Buff Potion | 200,000 | 300,000 | 1,000,000 | 400,000 |
| Crit Buff Potion | 300,000 | 450,000 | 1,500,000 | 600,000 |
| Luck Buff Potion | 500,000 | 750,000 | 2,500,000 | 1,000,000 |
| Detox İçecek (Minor) | 50,000 | 75,000 | 250,000 | 100,000 |
| Detox İçecek (Major) | 200,000 | 300,000 | 1,000,000 | 400,000 |
| Detox İçecek (Supreme) | 500,000 | 750,000 | 2,500,000 | 1,000,000 |

### 4.3 Stok Mekanizması

- Mekan sahibi, kendi craft'ladığı VEYA market'ten aldığı iksirlerle stoğunu doldurur
- Stok bittiğinde = satış durur
- **Restok:**
  - Manuel: Sahip craft eder veya başka oyuncudan alır
  - Otomatik (Lv 5+ mekan): Sahip craft kuyruğunu Mekan'a bağlayabilir
- **Bozulma sistemi:** Stokta 7 gün kalan iksirler %10 etkinlik kaybeder (freshness)

### 4.4 Mekan Sahibi Günlük Gelir Tahmini

| Mekan Seviyesi | Günlük Müşteri | Ort. Satış/Müşteri | Brüt Gelir | Net Kâr (kira düşülmüş) |
|----------------|---------------|-------------------|-----------|-------------------------|
| Lv 1 Bar | 10-15 | 50,000 | 500K - 750K | 480K - 730K |
| Lv 3 Bar | 20-30 | 80,000 | 1.6M - 2.4M | 1.5M - 2.3M |
| Lv 5 Lounge | 30-45 | 200,000 | 6M - 9M | 5.8M - 8.8M |
| Lv 7 Lounge | 45-60 | 350,000 | 15.8M - 21M | 15.5M - 20.7M |
| Lv 10 Yeraltı | 60-70 | 500,000 | 30M - 35M | 29.5M - 34.5M |

> **PLAN_06 uyumu:** End-game Mekan geliri ~5-30M/gün (PLAN_06 §2.1 Mekan geliri satırı)

---

## 5. Han-Only Item Katalogu

Bu itemlar The Crim tarzı han/kulüp ortamına özgüdür. Oyuncular tarafından craft edilir, **yalnızca Han/Mekan stokunda** satışa sunulur. Market veya direkt trade ile el değiştiremez.

### 5.1 Teknik Kısıtlamalar

Her Han-only item için veritabanında şu bayraklar kullanılır:

```sql
-- items tablosuna eklenen bayraklar (PLAN_01 §3 item şemasıyla uyumlu)
is_han_only          BOOLEAN DEFAULT false,   -- Han-only item ise true
is_market_tradeable  BOOLEAN DEFAULT true,    -- Han-only itemlarda false
is_direct_tradeable  BOOLEAN DEFAULT true,    -- Han-only itemlarda false
```

Han-only itemların stok akışı:
```
Oyuncu craft → Han/Mekan stokuna ekle → Müşteri satın alır → Han stoku azalır
           ↑ SADECE bu yol mevcut — market veya trade yasak
```

### 5.2 Han-Only Item Listesi (6 Temel Item)

| Item ID | Latince Adı | Türkçe | Etki | Craft Maliyeti | Han Satış Bandı | Overdose Riski |
|---------|------------|--------|------|---------------|-----------------|----------------|
| `han_item_vigor_minor` | Vinum Vigor Minor | Küçük Han Şarabı | +50 enerji; tolerance +3 | 3× Mel Regale + 2× Herba Medicinalis + 50K gold | 80K - 200K | — |
| `han_item_vigor_major` | Vinum Vigor Major | Büyük Han Şarabı | +100 enerji; tolerance +8 | 5× Mel Aureum + 3× Flos Lunaris + 200K gold | 300K - 800K | %5 (tol > 60) |
| `han_item_elixir_purge` | Elixir Purgationis | Arındırma İçeceği | tolerance -20; addiction -1 | 4× Aqua Purificata + 3× Fungus Medicinalis + 100K gold | 150K - 400K | — |
| `han_item_clarity` | Potio Claritatis | Berraklık Potionı | tolerance -40; addiction -2 | 5× Fons Vitae + 4× Aqua Aeterna + 500K gold | 700K - 2M | — |
| `han_item_berserk` | Furor Berserkium | Berserker Özü | ATK ×1.5 / 5 dk; tolerance +20; overdose riski yüksek | 5× Radix Draconis + 3× Venenum Apis + 3× Ignis Scintilla + 1M gold | 1.5M - 5M | %25 (tol > 50) |
| `han_item_shadow_brew` | Potio Umbrarum | Gölge Karışımı | PvP dodge +15% / 10 dk; tolerance +10 | 4× Cor Umbrae + 3× Pulvis Umbrae + 800K gold | 1.2M - 3.5M | %10 |
| `han_item_restoration` | Restoratio Magna | Büyük Restorasyon | HP +15,000; tolerance +5; addiction -1 | 5× Herba Immortalis + 4× Mel Aureum + 3× Aqua Sacra + 800K gold | 1.2M - 3.5M | — |

### 5.3 Craft Gereksinimleri Detayı

- **Üretim:** Oyuncular bu itemları kendi tesis kaynaklarıyla üretir (PLAN_03 Han recipe kategorisi)
- **Zorluk:** Craft maliyeti yüksek tutulmuş; bu itemlar sıradan kaynaktan pahalı
- **Stok:** Craft edilen item direkt Han stokuna girer; oyuncu kendisi kullanamaz (trade yasağı kapsamı dışında)
- **Bozulma:** Han stokunda 7 günden fazla kalan item %10 etkinlik kaybeder

### 5.4 Enerji Potionı Overdose Kuralı

`han_item_vigor_major` gibi enerji veren itemların overdose kuralı (PLAN_08 ile tutarlı):

```
Tolerance > 60 → overdose_chance = 0.05 × tolerance_multiplier
Overdose → hastaneye düş (PLAN_04 §7), tolerance +10 ek artış
```

Overdose kontrolü `use_han_item` RPC'sinde uygulanır (PLAN_08 `use_potion` mantığıyla aynı).

## 6. PvP Arena (Dövüş Kulübü)

### 5.1 PvP Kuralları (Mekan İçi)

- PvP **sadece** Dövüş Kulübü, Lüks Lounge veya Yeraltı mekanlarında gerçekleşir
- Her PvP dövüşü **15 enerji** harcar
- Kazanan: PvP rating +15-25, gold ganimet, reputation
- Kaybeden: PvP rating -10-15, gold kaybı (ganimetin %80'i)
- **Mekan sahibine komisyon:** Her PvP dövüşünden toplam gold'un %5'i
- Hastane riski: Kaybeden %10 hastaneye düşebilir (PLAN_04 hospital sistemi)

### 5.2 PvP Bahis Sistemi

Dövüş Kulübü ve üstü mekanlarda seyirciler bahis oynayabilir:

| Bahis Tipi | Min Bahis | Max Bahis | Mekan Komisyonu |
|-----------|-----------|-----------|----------------|
| 1v1 Bahis | 10,000 | 5,000,000 | %8 |
| Turnuva (4 kişi) | 50,000 | 10,000,000 | %10 |
| Şampiyon maçı | 100,000 | 50,000,000 | %12 |

### 5.3 Arena Sıralaması

PvP rating'e dayalı haftalık sıralama:

| Sıra | Haftalık Ödül |
|------|-------------|
| 1 | 2,000,000 gold + 100 gem |
| 2-5 | 1,000,000 gold + 50 gem |
| 6-10 | 500,000 gold + 25 gem |
| 11-25 | 200,000 gold |
| 26-50 | 100,000 gold |

---

## 7. Sosyal Özellikler

### 6.1 Mekan İçi Aktiviteler

| Aktivite | Açıklama | Enerji | Reward |
|----------|---------|--------|--------|
| Sohbet | Global chat, mekan-only chat | 0 | Sosyal |
| Zar oyunu | Kumar mini-game (gold) | 0 | Gold (+/-) |
| Davet | Arkadaş daveti (bonus XP) | 0 | XP boost %10 (1 saat) |
| Happy Hour | Mekan sahibi aktive eder, tüm alımlara %20 indirim | 0 | Müşteri çekimi |
| Fight Night | Turnuva etkinliği (haftalık) | 15/maç | PvP rating + gold |

### 6.2 Mekan Ünü (Fame)

Her mekan bir "ün" puanına sahiptir:

```
mekan_fame = (toplam_satış × 0.001)
           + (pvp_maç_sayısı × 10)
           + (günlük_müşteri_ortalaması × 5)
           + (mekan_seviyesi × 100)
```

Fame etkileri:
- Top 10 mekan: Haritada öne çıkar (parlayan ikon)
- Top 3 mekan: "Efsanevi Mekan" rozeti
- Fame 10,000+: Özel dekorasyon açılır
- Fame 50,000+: Müşteri kapasitesi +%25 bonus

---

## 8. Kaçak Ticaret (Yeraltı İmparatorluğu Özel)

### 7.1 Kaçak Maddeler

Sadece Yeraltı İmparatorluğu mekanlarında satılabilir:

| Madde | Etki | Tolerance Artışı | Overdose Riski | Craft Maliyeti | Satış Fiyatı |
|-------|------|-----------------|---------------|---------------|-------------|
| Güçlendirilmiş İksir | HP+ATK dual etki | +15 | %10 | 500,000 | 750K - 2.5M |
| Berserker Tonik | ATK ×2 / 3 dk, sonra %50 HP kaybı | +25 | %20 | 1,000,000 | 1.5M - 5M |
| Shadow Elixir | Stealth (PvP'de %30 dodge) | +10 | %5 | 800,000 | 1.2M - 4M |
| Overdose Antidot | Overdose'u anında iyileştir | -20 | 0 | 2,000,000 | 3M - 10M |

### 7.2 Risk-Reward

- **Yüksek kâr:** Kaçak maddeler normal iksirlerden 3-5× kârlı
- **Yüksek risk:** Polis baskını olasılığı (rastgele event)
- **Polis baskını:** Yakalanırsa: 24 saat hapis, mekan 48 saat kapalı, gold ceza
- **Baskın olasılığı:** Her satışta %2 baz, suspicion arttıkça yükselir
- **Suspicion** her kaçak satışta +5, yalnızca belirli "temizleme" etkinliğiyle azalır (otomatik azalma yok)

### 7.3 Polis Baskını Cezaları

| Ceza | Miktar |
|------|--------|
| Hapis süresi | 24 saat |
| Mekan kapalı | 48 saat |
| Gold cezası | Stok değerinin %50'si |
| Fame kaybı | -500 |
| Suspicion reset | 0 |

---

## 9. Veritabanı Şeması (Önerilen)

### 8.1 `game.mekans` Tablosu

```sql
CREATE TABLE game.mekans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid REFERENCES game.users(id) NOT NULL,
  mekan_type text NOT NULL CHECK (mekan_type IN ('bar', 'kahvehane', 'dovus_kulubu', 'luks_lounge', 'yeralti')),
  name text NOT NULL,
  level int NOT NULL DEFAULT 1 CHECK (level >= 1 AND level <= 10),
  fame int NOT NULL DEFAULT 0,
  suspicion int NOT NULL DEFAULT 0 CHECK (suspicion >= 0 AND suspicion <= 100),
  is_open boolean NOT NULL DEFAULT true,
  closed_until timestamptz,
  monthly_rent_paid_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  
  UNIQUE(owner_id) -- her oyuncu max 1 mekan
);
```

### 8.2 `game.mekan_stock` Tablosu

```sql
CREATE TABLE game.mekan_stock (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id uuid REFERENCES game.mekans(id) NOT NULL,
  item_id text REFERENCES public.items(item_id) NOT NULL,
  quantity int NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  sell_price bigint NOT NULL CHECK (sell_price > 0),
  stocked_at timestamptz NOT NULL DEFAULT now(),
  
  UNIQUE(mekan_id, item_id)
);
```

### 8.3 `game.mekan_sales` Tablosu (Log)

```sql
CREATE TABLE game.mekan_sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id uuid REFERENCES game.mekans(id) NOT NULL,
  buyer_id uuid REFERENCES game.users(id) NOT NULL,
  item_id text NOT NULL,
  quantity int NOT NULL,
  price_per_unit bigint NOT NULL,
  total_price bigint NOT NULL,
  owner_profit bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

### 8.4 `game.mekan_pvp_matches` Tablosu

```sql
CREATE TABLE game.mekan_pvp_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mekan_id uuid REFERENCES game.mekans(id) NOT NULL,
  attacker_id uuid REFERENCES game.users(id) NOT NULL,
  defender_id uuid REFERENCES game.users(id) NOT NULL,
  winner_id uuid REFERENCES game.users(id),
  gold_wagered bigint NOT NULL DEFAULT 0,
  gold_won bigint NOT NULL DEFAULT 0,
  mekan_commission bigint NOT NULL DEFAULT 0,
  attacker_rating_change int NOT NULL DEFAULT 0,
  defender_rating_change int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

---

## 10. RPC Fonksiyonları (Önerilen)

### 9.1 Mekan Açma

```sql
CREATE FUNCTION public.open_mekan(p_user_id uuid, p_mekan_type text, p_name text)
RETURNS json AS $$
DECLARE
  v_cost bigint;
  v_level_req int;
  v_user_level int;
  v_user_gold bigint;
BEGIN
  -- Maliyet ve level kontrolü
  SELECT CASE p_mekan_type
    WHEN 'bar' THEN 5000000
    WHEN 'kahvehane' THEN 8000000
    WHEN 'dovus_kulubu' THEN 15000000
    WHEN 'luks_lounge' THEN 50000000
    WHEN 'yeralti' THEN 200000000
  END,
  CASE p_mekan_type
    WHEN 'bar' THEN 15
    WHEN 'kahvehane' THEN 20
    WHEN 'dovus_kulubu' THEN 30
    WHEN 'luks_lounge' THEN 45
    WHEN 'yeralti' THEN 60
  END INTO v_cost, v_level_req;

  SELECT level, gold INTO v_user_level, v_user_gold
  FROM game.users WHERE id = p_user_id;

  IF v_user_level < v_level_req THEN
    RETURN json_build_object('success', false, 'error', 'Level yetersiz');
  END IF;
  IF v_user_gold < v_cost THEN
    RETURN json_build_object('success', false, 'error', 'Gold yetersiz');
  END IF;

  -- Mevcut mekan kontrolü
  IF EXISTS (SELECT 1 FROM game.mekans WHERE owner_id = p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'Zaten bir mekanınız var');
  END IF;

  -- Gold düş, mekan oluştur
  UPDATE game.users SET gold = gold - v_cost WHERE id = p_user_id;
  INSERT INTO game.mekans (owner_id, mekan_type, name)
  VALUES (p_user_id, p_mekan_type, p_name);

  RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 9.2 İksir Satın Alma (Mekan'dan)

```sql
CREATE FUNCTION public.buy_from_mekan(p_buyer_id uuid, p_mekan_id uuid, p_item_id text, p_quantity int)
RETURNS json AS $$
DECLARE
  v_stock record;
  v_mekan record;
  v_total_price bigint;
  v_owner_profit bigint;
  v_buyer_gold bigint;
BEGIN
  -- Mekan açık mı?
  SELECT * INTO v_mekan FROM game.mekans WHERE id = p_mekan_id AND is_open = true;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Mekan kapalı veya bulunamadı');
  END IF;

  -- Stok kontrolü
  SELECT * INTO v_stock FROM game.mekan_stock
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id AND quantity >= p_quantity;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Stok yetersiz');
  END IF;

  v_total_price := v_stock.sell_price * p_quantity;

  -- Alıcı gold kontrolü
  SELECT gold INTO v_buyer_gold FROM game.users WHERE id = p_buyer_id;
  IF v_buyer_gold < v_total_price THEN
    RETURN json_build_object('success', false, 'error', 'Gold yetersiz');
  END IF;

  -- Mekan sahibi kendi mekanından alamaz
  IF p_buyer_id = v_mekan.owner_id THEN
    RETURN json_build_object('success', false, 'error', 'Kendi mekanınızdan satın alamazsınız');
  END IF;

  v_owner_profit := v_total_price; -- %100 sahibe gider

  -- Transaction
  UPDATE game.users SET gold = gold - v_total_price WHERE id = p_buyer_id;
  UPDATE game.users SET gold = gold + v_owner_profit WHERE id = v_mekan.owner_id;
  UPDATE game.mekan_stock SET quantity = quantity - p_quantity
  WHERE mekan_id = p_mekan_id AND item_id = p_item_id;

  -- Alıcıya item ver
  PERFORM public.add_inventory_item(p_buyer_id, p_item_id, p_quantity);

  -- Satış logu
  INSERT INTO game.mekan_sales (mekan_id, buyer_id, item_id, quantity, price_per_unit, total_price, owner_profit)
  VALUES (p_mekan_id, p_buyer_id, p_item_id, p_quantity, v_stock.sell_price, v_total_price, v_owner_profit);

  -- Fame artışı
  UPDATE game.mekans SET fame = fame + p_quantity WHERE id = p_mekan_id;

  RETURN json_build_object('success', true, 'total_price', v_total_price);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 11. TypeScript Tipleri

```typescript
export type MekanType = 'bar' | 'kahvehane' | 'dovus_kulubu' | 'luks_lounge' | 'yeralti';

export interface Mekan {
  id: string;
  owner_id: string;
  mekan_type: MekanType;
  name: string;
  level: number;
  fame: number;
  suspicion: number;
  is_open: boolean;
  closed_until: string | null;
  monthly_rent_paid_at: string;
  created_at: string;
}

export interface MekanStock {
  id: string;
  mekan_id: string;
  item_id: string;
  quantity: number;
  sell_price: number;
  stocked_at: string;
}

export interface MekanSale {
  id: string;
  mekan_id: string;
  buyer_id: string;
  item_id: string;
  quantity: number;
  price_per_unit: number;
  total_price: number;
  owner_profit: number;
  created_at: string;
}

export interface MekanPvpMatch {
  id: string;
  mekan_id: string;
  attacker_id: string;
  defender_id: string;
  winner_id: string | null;
  gold_wagered: number;
  gold_won: number;
  mekan_commission: number;
  attacker_rating_change: number;
  defender_rating_change: number;
  created_at: string;
}
```

---

## 12. UI Sayfaları (Önerilen)

| Sayfa | Rota | Açıklama |
|-------|------|----------|
| Mekan Listesi | `/game/mekans` | Tüm açık mekanları listele (tür, seviye, fame sıralaması) |
| Mekan Detay | `/game/mekans/[id]` | Stok, fiyat, PvP arena, sohbet |
| Benim Mekanım | `/game/my-mekan` | Mekan yönetimi: stok, fiyat, yükseltme, istatistik |
| Mekan Aç | `/game/mekans/create` | Yeni mekan açma formu |
| PvP Arena | `/game/mekans/[id]/arena` | PvP eşleşme, bahis, sıralama |

---

## 13. Ekonomik Etki Analizi

### 12.1 Gold Sink Katkısı

| Mekanizma | Aylık Gold Sink (sunucu geneli, 1000 oyuncu) |
|-----------|----------------------------------------------|
| Mekan açılış maliyetleri | ~500M (ilk aylar yoğun) |
| Aylık kiralar | ~50M - 200M |
| Mekan yükseltmeleri | ~200M - 1B |
| PvP komisyonları | ~100M - 500M |
| İksir craft (Mekan için stok) | ~500M - 2B |

### 12.2 İksir Ekonomisi Akışı

```
Crafter → (craft maliyeti: gold sink) → İksir
  ↓
Mekan sahibi (stok) → (fiyat markup: gold redistribution) → Müşteri
  ↓
Müşteri → (iksir kullanımı: tüketim) → İksir yok olur

Gold akışı: Crafter → Mekan Sahibi → (kira gold sink) → Sunucu
```

### 12.3 PLAN_06 Tutarlılık Kontrolü

| Kontrol | PLAN_06 Değeri | PLAN_07 Değeri | Uyum |
|---------|---------------|---------------|------|
| Mekan günlük gelir (end-game) | 5-30M/gün | Lv 10 Yeraltı: ~30M/gün | ✓ |
| Mekan açma maliyeti vs gelir | Ay 1 toplam: 50M | Bar: 5M (ilk hafta karşılanır) | ✓ |
| İksir craft maliyeti | PLAN_03: 5K-500K | Aynı değerler | ✓ |
| PvP enerji maliyeti | PLAN_06 §4.3: 15 enerji | 15 enerji | ✓ |

---

## 14. Uygulama Öncelikleri

1. **Faz 1:** DB tabloları oluştur (mekans, mekan_stock, mekan_sales); `items` tablosuna `is_han_only`, `is_market_tradeable`, `is_direct_tradeable` kolonlarını ekle
2. **Faz 2:** `open_mekan`, `buy_from_mekan` RPC'leri; `use_han_item` RPC (tolerance + overdose entegrasyonlu)
3. **Faz 3:** Mekan listesi ve detay UI sayfaları
4. **Faz 4:** Stok yönetimi ve fiyatlandırma UI
5. **Faz 5:** PvP Arena (PLAN_09 ile birlikte)
6. **Faz 6:** Bahis sistemi, kaçak ticaret, polis baskını
7. **Faz 7:** Mekan ünü ve sıralama sistemi

---

*Bu belge PLAN_08 (Tolerance — detox satışı), PLAN_09 (PvP — arena mekanikleri) ve PLAN_06 (ekonomi — gelir/gider dengesi) ile doğrudan bağlantılıdır.*
