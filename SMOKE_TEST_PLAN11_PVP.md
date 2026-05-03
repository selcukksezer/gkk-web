# PLAN_11 PvP Smoke Test

Bu dokuman, [supabase/migrations/20260503_040000_apply_plan11_pvp_class_bonuses.sql](supabase/migrations/20260503_040000_apply_plan11_pvp_class_bonuses.sql) icin hizli dogrulama setidir.

## 0) Kapsam

Asagidaki mekanikler dogrulanir:
- Warrior PvP hasar bonusu (+20%)
- Warrior crit bonusu (+10% luck ustu)
- Shadow dodge bonusu (+15%)
- Luck tabanli crit ve dodge etkisi
- Bloodlust aktifligi (30 dk), streak birikimi (3'e kadar), 3 streakte 1.20 carpan
- Kaybetme durumunda warrior bloodlust reset

## 1) On Kosullar

- Migration uygulanmis olmali.
- Test icin en az 4 kullanici hazir olmali:
  - warrior_a
  - warrior_b
  - shadow_a
  - neutral_a (warrior/shadow olmayan)
- Tum test hesaplari:
  - level >= 10
  - energy >= 60
  - hospital_until/prison_until null veya gecmis
  - ayni guild icinde olmamali
- Teste uygun bir mekan id'si olmali (mekan_type: dovus_kulubu, luks_lounge, yeralti)

## 2) Hizli Smoke (5 Dakika)

1. RPC cagrisinin calistigini dogrula
- Beklenen: success true/false donmeli, unauthorized hatasi olmamali (dogru kullaniciyla).

2. Warrior kazancindan sonra bloodlust set ediliyor mu
- Beklenen: warrior_bloodlust_until > now, warrior_bloodlust_streak = 1.

3. Ust uste 3 galibiyette streak 3 oluyor mu
- Beklenen: warrior_bloodlust_streak = 3.

4. Streak 3 iken donen payload carpani 1.20 mi
- Beklenen: attacker_bloodlust_mult = 1.20.

5. Warrior kaybederse bloodlust reset oluyor mu
- Beklenen: warrior_bloodlust_streak = 0, warrior_bloodlust_until null.

## 3) Test Cagrisi Notu (Kritik)

public.pvp_attack icinde auth.uid() kontrolu oldugu icin SQL Editor'dan direkt SELECT ile test etmek dogru degildir. Testler authenticated client oturumu ile (uygulama veya supabase-js test script) kosulmalidir.

## 4) Supabase-JS Ornek Smoke Script Akisi

Asagidaki akis tek bir test scriptinde sirayla uygulanabilir.

```ts
// pseudo-flow
// 1) warrior_a ile login
// 2) rpc('pvp_attack', { p_attacker_id: warrior_a, p_defender_id: neutral_a, p_mekan_id })
// 3) users tablosundan warrior_a bloodlust alanlarini oku
// 4) 2 adimini toplam 3 kez kazanma saglayacak sekilde tekrarla
// 5) 3. kazanimdan sonra rpc cevabinda attacker_bloodlust_mult === 1.20 kontrol et
// 6) warrior_a'nin kaybettigi bir mac kos, sonra streak reset kontrol et
```

## 5) Detayli Kontrol Matrisi

### A) Warrior +20% hasar
- Senaryo:
  - warrior_a vs neutral_a, esit attack/defense/luck'e yakin profile sahip iki grup olustur.
  - 30-50 maclik kucuk orneklemde warrior tarafinin ortalama vurusu/galibiyet orani karsilastirilir.
- Beklenen:
  - Warrior tarafinda anlamli avantaj gorulmeli.
- Not:
  - random oldugu icin tek maca bakilmaz.

### B) Warrior +10% crit
- Senaryo:
  - warrior ve neutral icin benzer luck degerleriyle 100+ tur log topla.
- Beklenen:
  - Warrior crit frekansi, luck tabanina gore yaklasik +0.10 offsetli gorulmeli.

### C) Shadow +15% dodge
- Senaryo:
  - shadow_a ve neutral_a benzer luck ile karsilastirilir.
- Beklenen:
  - Shadow dodge olasiligi neutraldan yuksek.

### D) Luck tabanli dodge/crit
- Senaryo:
  - Ayni sinifta luck=0, luck=50, luck=100 profilleriyle orneklem al.
- Beklenen:
  - Crit olasiligi luck ile artmali (luck * 0.002).
  - Dodge olasiligi luck ile artmali (luck * 0.001).

### E) Bloodlust 30 dk ve streak
- Senaryo:
  - Warrior 1. galibiyet -> streak 1
  - 2. galibiyet -> streak 2
  - 3. galibiyet -> streak 3, mult 1.20
  - Kayip -> streak 0, until null
- Beklenen:
  - Her adimda users tablosu alanlari tutarli.

## 6) Veri Kontrol Sorgulari

Bu sorgulari SQL Editor'da sadece gozlem icin kullan.

```sql
-- Kullanici bloodlust durumu
select auth_id, character_class, warrior_bloodlust_streak, warrior_bloodlust_until
from public.users
where auth_id in (
  'WARRIOR_A_UUID',
  'WARRIOR_B_UUID',
  'SHADOW_A_UUID',
  'NEUTRAL_A_UUID'
);

-- Son PvP maclari
select created_at, attacker_id, defender_id, winner_id, gold_stolen, rating_change_attacker
from public.pvp_matches
where attacker_id in ('WARRIOR_A_UUID','WARRIOR_B_UUID','SHADOW_A_UUID','NEUTRAL_A_UUID')
   or defender_id in ('WARRIOR_A_UUID','WARRIOR_B_UUID','SHADOW_A_UUID','NEUTRAL_A_UUID')
order by created_at desc
limit 30;

-- Gunluk limit sayaci
select *
from public.pvp_daily_attacks
where attacker_id = 'WARRIOR_A_UUID' and defender_id = 'NEUTRAL_A_UUID'
order by attack_date desc
limit 5;
```

## 7) Kabul Kriterleri

- RPC regress etmemis olmali (yetki, enerji, guild, rating cap, daily cap hala calisiyor).
- Warrior/Shadow/Luck bonuslari istatistiksel olarak etkili gorulmeli.
- Bloodlust state yonetimi (set, stack, reset) beklendigi gibi olmali.
- Beklenmeyen null/constraint hatasi olmamali.

## 8) Hata Gorulurse Ilk Bakilacaklar

- Test cagrisini yapan session kullanicisi ile p_attacker_id ayni mi?
- Kullanici level/energy/hospital/prison durumlari uygun mu?
- Test kullanicilari ayni guildde mi?
- p_mekan_id uygun tipte ve acik mi?
- pvp_daily_attacks limiti dolmus mu?
